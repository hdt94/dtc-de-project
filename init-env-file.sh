#!/bin/bash

if [[ -z "$BQ_DATASET" ]]; then
    >&2 echo 'Undefined BQ_DATASET'
    exit 1
fi
if [[ -z "$GCP_PROJECT_ID" ]]; then
    >&2 echo 'Undefined GCP_PROJECT_ID'
    exit 1
fi
if [[ -z "$GCS_DATA_BUCKET_NAME" ]]; then
    >&2 echo 'Undefined GCS_DATA_BUCKET_NAME'
    exit 1
fi

BASE_DIR=$(realpath $(dirname $0))

cat << EOF > "${BASE_DIR}/.env"
PYTHONPATH=${PYTHONPATH}:${BASE_DIR}/dtc-de-project

BQ_DATASET=${BQ_DATASET}
GCP_APPLICATION_CREDENTIALS_FILE="$(realpath ~/.config/gcloud/application_default_credentials.json)"
GCP_PROJECT_ID=${GCP_PROJECT_ID}
GCS_DATA_BUCKET_NAME=${GCS_DATA_BUCKET_NAME}

AIRFLOW_HOME=/home/vagrant/airflow
AIRFLOW__CORE__DAGS_FOLDER="${BASE_DIR}/orchestration/airflow/dags"
AIRFLOW__CORE__LOAD_EXAMPLES=False
AIRFLOW__WEBSERVER__WORKERS=2
AIRFLOW_VAR_DATA_BUCKET_NAME=${GCS_DATA_BUCKET_NAME}

DBT_DATABASE=${GCP_PROJECT_ID}
DBT_HOME="${BASE_DIR}/datawarehouse/dbt/trips"
DBT_SCHEMA=$BQ_DATASET
DBT_VENV_DIR="${BASE_DIR}/venvs/venv-dbt"

GS_FHV_RAW_URI="gs://$GCS_DATA_BUCKET_NAME/raw/fhv/*.parquet"
GS_GREEN_RAW_URI="gs://$GCS_DATA_BUCKET_NAME/raw/green/*.parquet"
EOF
