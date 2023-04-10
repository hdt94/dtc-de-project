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
    UPLOAD_COMPOSER_DAGS=true
    UPDATE_DBT_CREDENTIALS_FILE=true
fi

# Provisioning
if [[ $APPLY_TERRAFORM = true ]]; then
    if [[ $LOCAL_AIRFLOW = true ]]; then
        CLOUD_COMPOSER=false
    else
        CLOUD_COMPOSER=true
    fi

    terraform -chdir=$TERRAFORM_DIR init
    terraform -chdir=$TERRAFORM_DIR apply \
        -var "bq_dataset=$BQ_DATASET"\
        -var "composer=$CLOUD_COMPOSER"\
        -var "gcs_datalake_bucket_name=$GCS_DATA_BUCKET_NAME"\
        -var "project=$GCP_PROJECT_ID"
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

if [[ $UPLOAD_COMPOSER_DAGS = true ]]; then
    COMPOSER_OUTPUT="$(jq -c .composer.value <<< "$TERRAFORM_OUTPUT")"

    COMPOSER_ENV_LOCATION="$(echo "$COMPOSER_OUTPUT" | jq -r .location)" \
    COMPOSER_ENV_NAME="$(echo "$COMPOSER_OUTPUT" | jq -r .name)" \
    REPO_ROOT="$REPO_ROOT" \
    UPLOAD_COMPOSER_DAGS="$UPLOAD_COMPOSER_DAGS" \
    ${SCRIPTS_DIR}/update-composer-env.sh
fi
