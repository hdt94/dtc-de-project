#!/bin/bash

set -e

if [[ -z "$DBT_HOME" ]]; then
    DBT_HOME=$(realpath $(dirname $0))
fi

cat << EOF > $DBT_HOME/profiles.yml
default:
  target: dev
  outputs:
    dev:
      type: bigquery
      method: oauth
      dataset: "{{ env_var('BQ_DATASET') }}"
      project: "{{ env_var('GCP_PROJECT_ID') }}"
      keyfile: "{{ env_var('GCP_APPLICATION_CREDENTIALS_FILE') }}"
EOF
