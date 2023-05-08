#!/bin/bash

set -e

REPO_ROOT=$(realpath $(dirname $0))
SCRIPTS_DIR=${REPO_ROOT}/infrastructure/gcp/scripts
TERRAFORM_DIR=${REPO_ROOT}/infrastructure/gcp/terraform

if [[ -z "$GCP_PROJECT_ID" ]]; then
    >&2 echo 'Undefined GCP_PROJECT_ID'
    exit 1
fi
if [[ -z "$BQ_DATASET" ]]; then
    >&2 echo 'Undefined BQ_DATASET'
    exit 1
fi
if [[ -z "$GCS_DATA_BUCKET_NAME" ]]; then
    >&2 echo 'Undefined GCS_DATA_BUCKET_NAME'
    exit 1
fi

if [[ $RUN_ALL = true ]]; then
    APPLY_TERRAFORM=true
    BUILD_DOCKER_OPERATORS=true
    UPDATE_DBT_CREDENTIALS_FILE=true
    if [[ $LOCAL_AIRFLOW = true ]]; then
        UPLOAD_COMPOSER_DAGS=false
        UPDATE_ORCHESTRATOR_CREDENTIALS_FILE=true
    else
        UPLOAD_COMPOSER_DAGS=true
        UPDATE_ORCHESTRATOR_CREDENTIALS_FILE=true  # false
    fi
fi

# Provisioning
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
        -var "project_id=$GCP_PROJECT_ID"
fi

TERRAFORM_OUTPUT=$(terraform -chdir=$TERRAFORM_DIR output -json)
if [[ $TERRAFORM_OUTPUT == "{}" ]]; then
     >&2 echo "Terraform output is unexpectedly empty"
    exit 1
fi

# dbt service account credentials file
if [[ $UPDATE_DBT_CREDENTIALS_FILE = true ]]; then
    if [[ -z "$GCP_DBT_CREDENTIALS_FILE" ]]; then
        >&2 echo 'Undefined GCP_DBT_CREDENTIALS_FILE'
        exit 1
    fi
    GCP_SA_DBT="$(jq -r '.dbt_sa.value' <<< "$TERRAFORM_OUTPUT")"
    mkdir -p "$(dirname $GCP_DBT_CREDENTIALS_FILE)"
    gcloud iam service-accounts keys create "$GCP_DBT_CREDENTIALS_FILE" --iam-account="$GCP_SA_DBT"
    echo "dbt credentials file for BigQuery: ${GCP_DBT_CREDENTIALS_FILE}"
fi

if [[ $UPDATE_ORCHESTRATOR_CREDENTIALS_FILE = true ]]; then
    if [[ -z "$ORCHESTRATOR_GCP_CREDENTIALS_FILE" ]]; then
        >&2 echo 'Undefined ORCHESTRATOR_GCP_CREDENTIALS_FILE'
        exit 1
    fi
    SA_EMAIL="$(jq -r '.external_orchestrator_sa.value' <<< "$TERRAFORM_OUTPUT")"
    mkdir -p "$(dirname $ORCHESTRATOR_GCP_CREDENTIALS_FILE)"
    gcloud iam service-accounts keys create "$ORCHESTRATOR_GCP_CREDENTIALS_FILE" --iam-account="$SA_EMAIL"
    echo "External orchestrator credentials file: ${ORCHESTRATOR_GCP_CREDENTIALS_FILE}"
fi

if [[ $BUILD_DOCKER_OPERATORS = true ]]; then
    chmod +x $REPO_ROOT/dtc_de/build-docker-extras.sh
    if [[ $LOCAL_AIRFLOW = true ]]; then
        echo "Building Airflow Docker Operators locally..."
        if [[ -z "$ORCHESTRATOR_GCP_CREDENTIALS_FILE" ]]; then
            echo >&2 'Undefined ORCHESTRATOR_GCP_CREDENTIALS_FILE'
            exit 1
        fi
        LOCAL=true \
        GOOGLE_APPLICATION_CREDENTIALS=$ORCHESTRATOR_GCP_CREDENTIALS_FILE \
        $REPO_ROOT/dtc_de/build-docker-extras.sh
    else
        echo "Building Composer Docker Operators using Cloud Build..."
        REGISTRY_URL=$(
            jq -r .composer.value.docker_operators_registry_url <<< "$TERRAFORM_OUTPUT"
        )
        REGISTRY_URL=$REGISTRY_URL \
        $REPO_ROOT/dtc_de/build-docker-extras.sh
    fi
fi

if [[ $UPLOAD_COMPOSER_DAGS = true ]]; then
    COMPOSER_OUTPUT="$(jq -c .composer.value <<< "$TERRAFORM_OUTPUT")"

    COMPOSER_ENV_LOCATION="$(echo "$COMPOSER_OUTPUT" | jq -r .location)" \
    COMPOSER_ENV_NAME="$(echo "$COMPOSER_OUTPUT" | jq -r .name)" \
    REPO_ROOT="$REPO_ROOT" \
    UPLOAD_COMPOSER_DAGS="$UPLOAD_COMPOSER_DAGS" \
    ${SCRIPTS_DIR}/update-composer-env.sh
fi
