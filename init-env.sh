#!/bin/bash

set -e

REPO_ROOT="$(realpath $(dirname $0))"
GCP_SCRIPTS_DIR="${REPO_ROOT}/infrastructure/gcp/scripts"
TERRAFORM_DIR="${REPO_ROOT}/infrastructure/gcp/terraform"
VENVS_DIR="${REPO_ROOT}/venvs"  # only for hybrid setup

if [[ -z "$BQ_DATASET" ]]; then
    echo >&2 'Undefined BQ_DATASET'
    exit 1
elif [[ -z "$GCP_PROJECT_ID" ]]; then
    echo >&2 'Undefined GCP_PROJECT_ID'
    exit 1
elif [[ -z "$GCP_REGION" ]]; then
    echo >&2 'Undefined GCP_REGION'
    exit 1
elif [[ -z "$GCS_DATA_BUCKET_NAME" ]]; then
    echo >&2 'Undefined GCS_DATA_BUCKET_NAME'
    exit 1
fi

if [[ $RUN_ALL = true ]]; then
    APPLY_TERRAFORM=true
    BUILD_CONTAINER_IMAGES=true
    INIT_VENVS=true
    UPDATE_DBT_CREDENTIALS_FILE=true
    if [[ $LOCAL_AIRFLOW = true ]]; then
        UPLOAD_COMPOSER_DAGS=false
        UPDATE_ORCHESTRATOR_CREDENTIALS_FILE=true
    else
        UPLOAD_COMPOSER_DAGS=true
        UPDATE_ORCHESTRATOR_CREDENTIALS_FILE=false
    fi
fi

# initialize python venvs if using hybrid setup
if [[ ($INIT_VENVS = true) && (($LOCAL_AIRFLOW = true) || ($LOCAL_DBT = true))]]; then
    INIT_VENV_SCRIPT="${REPO_ROOT}/infrastructure/local/scripts/init-python-venv.sh"
    chmod +x "$INIT_VENV_SCRIPT"

    if [[ $LOCAL_AIRFLOW = true ]]; then
        REQUIREMENTS="$REPO_ROOT/orchestration/airflow/local/requirements.txt" \
        VENV_NAME=venv-airflow \
        VENVS_DIR="$VENVS_DIR" \
        "$INIT_VENV_SCRIPT"
    fi

    if [[ $LOCAL_DBT = true ]]; then
        DBT_DIR="${REPO_ROOT}/datawarehouse/dbt/trips"

        REQUIREMENTS="$DBT_DIR/requirements.txt" \
        VENV_NAME=venv-dbt \
        VENVS_DIR="$VENVS_DIR" \
        "$INIT_VENV_SCRIPT"

        chmod +x "$DBT_DIR/init-local-profiles.sh"
        "$DBT_DIR/init-local-profiles.sh"
    fi
fi

# provision cloud resources
if [[ $APPLY_TERRAFORM = true ]]; then
    if [[ $LOCAL_AIRFLOW = true ]]; then
        CLOUD_COMPOSER=false
        EXTERNAL_ORCHESTRATOR=true
    else
        CLOUD_COMPOSER=true
        EXTERNAL_ORCHESTRATOR=false
    fi

    terraform -chdir=$TERRAFORM_DIR init
    terraform -chdir=$TERRAFORM_DIR apply \
        -var "bq_dataset=$BQ_DATASET"\
        -var "composer=$CLOUD_COMPOSER"\
        -var "external_orchestrator=$EXTERNAL_ORCHESTRATOR" \
        -var "gcs_datalake_bucket_name=$GCS_DATA_BUCKET_NAME"\
        -var "project_id=$GCP_PROJECT_ID" \
        -var "region=${GCP_REGION}"
fi

TERRAFORM_OUTPUT=$(terraform -chdir=$TERRAFORM_DIR output -json)
if [[ $TERRAFORM_OUTPUT == "{}" ]]; then
    echo >&2 "Terraform output is unexpectedly empty"
    exit 1
fi

if [[ $LOCAL_AIRFLOW = true ]]; then
    COMPOSER_ENV_LOCATION="not_available_as_using_local_airflow"
    COMPOSER_ENV_NAME="not_available_as_using_local_airflow"
    GCP_CONTAINER_REGISTRY_URL="not_available_as_using_local_airflow"
else
    COMPOSER_OUTPUT="$(jq -c .composer.value <<< "$TERRAFORM_OUTPUT")"
    COMPOSER_ENV_LOCATION="$(jq -r .location <<< "$COMPOSER_OUTPUT")"
    COMPOSER_ENV_NAME="$(jq -r .name <<< "$COMPOSER_OUTPUT")"
    GCP_CONTAINER_REGISTRY_URL=$(
        jq -r .docker_operators_registry_url <<< "$COMPOSER_OUTPUT"
    )
fi

# dbt service account credentials file
if [[ $UPDATE_DBT_CREDENTIALS_FILE = true ]]; then
    if [[ -z "$DBT_GCP_CREDENTIALS_FILE" ]]; then
        echo >&2 'Undefined DBT_GCP_CREDENTIALS_FILE'
        exit 1
    fi
    SA_EMAIL="$(jq -r '.dbt_sa.value' <<< "$TERRAFORM_OUTPUT")"
    mkdir -p "$(dirname $DBT_GCP_CREDENTIALS_FILE)"
    gcloud iam service-accounts keys create "$DBT_GCP_CREDENTIALS_FILE" --iam-account="$SA_EMAIL"
    echo "dbt credentials file for BigQuery: ${DBT_GCP_CREDENTIALS_FILE}"
fi

# external orchestrator service account credentials file, only if LOCAL_AIRFLOW=true
if [[ $UPDATE_ORCHESTRATOR_CREDENTIALS_FILE = true ]]; then
    if [[ -z "$ORCHESTRATOR_GCP_CREDENTIALS_FILE" ]]; then
        echo >&2 'Undefined ORCHESTRATOR_GCP_CREDENTIALS_FILE'
        exit 1
    fi
    SA_EMAIL="$(jq -r '.external_orchestrator_sa.value' <<< "$TERRAFORM_OUTPUT")"
    mkdir -p "$(dirname $ORCHESTRATOR_GCP_CREDENTIALS_FILE)"
    gcloud iam service-accounts keys create "$ORCHESTRATOR_GCP_CREDENTIALS_FILE" --iam-account="$SA_EMAIL"
    echo "External orchestrator credentials file: ${ORCHESTRATOR_GCP_CREDENTIALS_FILE}"
fi

if [[ $BUILD_CONTAINER_IMAGES = true ]]; then
    chmod +x "$REPO_ROOT/dtc_de/build-docker-extras.sh"
    if [[ $LOCAL_AIRFLOW = true ]]; then
        echo "Building Airflow Docker Operators locally..."
        if [[ -z "$ORCHESTRATOR_GCP_CREDENTIALS_FILE" ]]; then
            echo >&2 'Undefined ORCHESTRATOR_GCP_CREDENTIALS_FILE'
            exit 1
        fi
        LOCAL=true \
        GOOGLE_APPLICATION_CREDENTIALS=$ORCHESTRATOR_GCP_CREDENTIALS_FILE \
        "$REPO_ROOT/dtc_de/build-docker-extras.sh"
    else
        echo "Building Composer Docker Operators using Cloud Build..."
        REGISTRY_URL=$GCP_CONTAINER_REGISTRY_URL \
        "$REPO_ROOT/dtc_de/build-docker-extras.sh"
    fi
fi

if [[ $UPLOAD_COMPOSER_DAGS = true ]]; then
    chmod +x "${GCP_SCRIPTS_DIR}/update-composer-env.sh"

    COMPOSER_ENV_LOCATION="$COMPOSER_ENV_LOCATION" \
    COMPOSER_ENV_NAME="$COMPOSER_ENV_NAME" \
    SOURCE_DAGS_DIR="${REPO_ROOT}/orchestration/airflow/composer/dags/" \
    "${GCP_SCRIPTS_DIR}/update-composer-env.sh"
fi

# write environment file
cat << EOF > "${REPO_ROOT}/.env"
BQ_DATASET=${BQ_DATASET}
GCP_PROJECT_ID=${GCP_PROJECT_ID}
GCP_REGION=${GCP_REGION}
GCS_DATA_BUCKET_NAME=${GCS_DATA_BUCKET_NAME}

DBT_GCP_CREDENTIALS_FILE="${DBT_GCP_CREDENTIALS_FILE}"
ORCHESTRATOR_GCP_CREDENTIALS_FILE="${ORCHESTRATOR_GCP_CREDENTIALS_FILE}"

AIRFLOW_HOME=/home/vagrant/airflow
AIRFLOW__CORE__DAGS_FOLDER="${REPO_ROOT}/orchestration/airflow/local/dags"
AIRFLOW__CORE__LOAD_EXAMPLES=False
AIRFLOW__WEBSERVER__WORKERS=2
AIRFLOW_VAR_CLOUD_BATCH_PARENT=$(jq -r .cloud_batch_parent.value <<< "$TERRAFORM_OUTPUT")
AIRFLOW_VAR_CLOUD_RUN_JOBS_PARENT=$(jq -r .cloud_run_jobs_parent.value <<< "$TERRAFORM_OUTPUT")
AIRFLOW_VAR_DATA_BUCKET_NAME=${GCS_DATA_BUCKET_NAME}

COMPOSER_ENV_LOCATION=${COMPOSER_ENV_LOCATION}
COMPOSER_ENV_NAME=${COMPOSER_ENV_NAME}
GCP_CONTAINER_REGISTRY_URL=${GCP_CONTAINER_REGISTRY_URL}

DBT_DATABASE=${GCP_PROJECT_ID}
DBT_HOME="${REPO_ROOT}/datawarehouse/dbt/trips"
DBT_SCHEMA=$BQ_DATASET

GS_FHV_RAW_URI="gs://$GCS_DATA_BUCKET_NAME/raw/fhv/*.parquet"
GS_GREEN_RAW_URI="gs://$GCS_DATA_BUCKET_NAME/raw/green/*.parquet"
GS_YELLOW_RAW_URI="gs://$GCS_DATA_BUCKET_NAME/raw/yellow/*.parquet"
EOF
