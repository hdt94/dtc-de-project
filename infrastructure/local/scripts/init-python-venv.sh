#!/bin/bash

set -e

BASE_DIR=$(realpath $(dirname $0))

if [[ -z "$REQUIREMENTS" ]]; then
    echo >&2 'Undefined REQUIREMENTS'
    exit 1
elif [[ ! -f "$REQUIREMENTS" ]]; then
    echo >&2 "Requirements file not existing: ${REQUIREMENTS}"
    exit 1
elif [[ -z "$VENVS_DIR" ]]; then
    echo >&2 'Undefined VENVS_DIR'
    exit 1
elif [[ -z "$VENV_NAME" ]]; then
    echo >&2 'Undefined VENV_NAME'
    exit 1
fi

mkdir -p "$VENVS_DIR"
if [[ -d "$VENVS_DIR/$VENV_NAME" ]]; then
    echo "Virtual environment found: $VENV_NAME"
    return
fi

pushd "$VENVS_DIR" >/dev/null

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
