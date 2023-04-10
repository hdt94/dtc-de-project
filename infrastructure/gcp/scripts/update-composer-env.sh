#!/bin/bash

set -e


if [[ -z $REPO_ROOT ]]; then
    echo 'REPO_ROOT is undefined' >&2
    exit 1
fi
if [[ -z $COMPOSER_ENV_LOCATION ]]; then
    echo "COMPOSER_ENV_LOCATION is not defined" >&2
    exit 1
fi
if [[ -z $COMPOSER_ENV_NAME ]]; then
    echo "COMPOSER_ENV_NAME is not defined" >&2
    exit 1
fi

if [[ -z $UPLOAD_COMPOSER_DAGS ]]; then
    UPLOAD_COMPOSER_DAGS=false
fi

if [[ $UPLOAD_COMPOSER_DAGS = true ]]; then
    echo "Uploading Composer DAGs based on: ${REPO_ROOT}"

    COMPOSER_DAGS_URI=$(gcloud composer environments describe $COMPOSER_ENV_NAME \
        --location $COMPOSER_ENV_LOCATION \
        --format="get(config.dagGcsPrefix)")

    TMP_DAGS_DIR=$(mktemp -d -t etl-stocks-dags-XXXXXXX)

    rsync -r "${REPO_ROOT}/orchestration/airflow/dags/" "${TMP_DAGS_DIR}"

    # Copy DAG module dependencies as these are imported from DAG files
    # Copy only .py files, .json files, .txt files, including subdirectories
    # Note that trailing forward-slash in sources is omitted to copy each directory
    rsync -rm --include="*.py" --include="*.json" --include="*.txt" --include="*/" --exclude="*" \
        "${REPO_ROOT}/dtc_de" \
        "${TMP_DAGS_DIR}/"

    # Copy contents from TMP_DAGS_DIR
    gsutil -mq rsync -r "${TMP_DAGS_DIR}/" "${COMPOSER_DAGS_URI}"

    rm -rf $TMP_DAGS_DIR
fi
