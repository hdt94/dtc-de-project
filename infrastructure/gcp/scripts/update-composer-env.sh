#!/bin/bash

set -e

if [[ -z $COMPOSER_ENV_LOCATION ]]; then
    echo "COMPOSER_ENV_LOCATION is not defined" >&2
    exit 1
fi
if [[ -z $COMPOSER_ENV_NAME ]]; then
    echo "COMPOSER_ENV_NAME is not defined" >&2
    exit 1
fi

if [[ ! -z "$SOURCE_DAGS_DIR" ]]; then
    echo "Uploading Composer DAGs based on: ${REPO_ROOT}"

    COMPOSER_DAGS_URI=$(gcloud composer environments describe $COMPOSER_ENV_NAME \
        --location $COMPOSER_ENV_LOCATION \
        --format="get(config.dagGcsPrefix)")

    # Copy contents from SOURCE_DAGS_DIR
    if [[ "${SOURCE_DAGS_DIR: -1}" != "/"  ]]; then
        SOURCE_DAGS_DIR="${SOURCE_DAGS_DIR}/"
    fi
    gsutil -mq rsync -r "${SOURCE_DAGS_DIR}" "${COMPOSER_DAGS_URI}" --exclude="__pycache__"
fi
