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
