#!/bin/bash

set -e

if [[ -z "$GCP_PROJECT_ID" ]]; then
    >&2 echo 'Undefined GCP_PROJECT_ID'
    exit 1
fi
if [[ -z "$BQ_DATASET" ]]; then
    >&2 echo 'Undefined BQ_DATASET'
    exit 1
fi
if [[ -z "$GCP_DBT_CREDENTIALS_FILE" ]]; then
    >&2 echo 'Undefined GCP_DBT_CREDENTIALS_FILE'
    exit 1
fi
if [[ -z "$GCS_DATA_BUCKET_NAME" ]]; then
    >&2 echo 'Undefined GCS_DATA_BUCKET_NAME'
    exit 1
fi

BASE_DIR="$(realpath $(dirname $0))"
TERRAFORM_DIR=$BASE_DIR/infrastructure/gcp/terraform

# Provisioning
terraform -chdir=$TERRAFORM_DIR init
terraform -chdir=$TERRAFORM_DIR apply \
    -var "bq_dataset=$BQ_DATASET"\
    -var "gcs_datalake_bucket_name=$GCS_DATA_BUCKET_NAME"\
    -var "project=$GCP_PROJECT_ID"
TERRAFORM_OUTPUT="$(terraform -chdir="$TERRAFORM_DIR" output -json)"

# dbt service account credentials file
GCP_SA_DBT="$(jq -r '.dbt_sa.value' <<< "$TERRAFORM_OUTPUT")"
mkdir -p "$(dirname $GCP_DBT_CREDENTIALS_FILE)"
gcloud iam service-accounts keys create "$GCP_DBT_CREDENTIALS_FILE" --iam-account="$GCP_SA_DBT"
echo "dbt credentials file for BigQuery: ${GCP_DBT_CREDENTIALS_FILE}"
