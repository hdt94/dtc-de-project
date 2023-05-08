#!/bin/bash

set -e

BASE_DIR=$(realpath $(dirname $0))

AIRFLOW_DIR="$BASE_DIR/orchestration/airflow"
AIRFLOW_VENV_NAME=venv-airflow
DBT_DIR="$BASE_DIR/datawarehouse/dbt/trips"
DBT_VENV_NAME=venv-dbt
VENV_DIR="$BASE_DIR/venvs"

init_venv() {
    VENV_NAME=$1
    REQUIREMENTS=$2
    if [[ -d "$VENV_DIR/$VENV_NAME" ]]; then
        echo "Virtual environment found: $VENV_NAME"
        return
    fi
    pushd $VENV_DIR >/dev/null
    echo "Creating virtual environment: $VENV_NAME"
    if [[ ! -z "$BASE_PYTHON" ]]; then
        $BASE_PYTHON -m venv $VENV_NAME
    elif [[ ! -z "$BASE_CONDA_ENV" ]]; then
        source ~/anaconda3/etc/profile.d/conda.sh
        conda activate $BASE_CONDA_ENV
        python -m venv $VENV_NAME
        conda deactivate
    else
        echo 'Missing BASE_PYTHON or BASE_CONDA_ENV' >&2
        exit 1
    fi
    source $VENV_NAME/bin/activate
    pip install --upgrade pip setuptools >/dev/null
    echo "Installing requirements: $REQUIREMENTS"
    pip install -r "$REQUIREMENTS" >/dev/null
    popd >/dev/null
}

mkdir -p $VENV_DIR

if [[ "$LOCAL_AIRFLOW" = "true" ]]; then
    init_venv "$AIRFLOW_VENV_NAME" "$AIRFLOW_DIR/requirements.txt"

    echo "Building Airflow Docker Operators locally..."
    chmod +x "$REPO_ROOT/dtc_de/build-composer-docker-operators.sh"
    LOCAL=true "$REPO_ROOT/dtc_de/build-docker-extras.sh"
fi

if [[ "$LOCAL_DBT" = "true" ]]; then
    init_venv "$DBT_VENV_NAME" "$DBT_DIR/requirements.txt"
    $DBT_DIR/init-local-profiles.sh
fi
