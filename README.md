# Project for Data Engineering course from DataTalksClub

Data engineering project for TLC taxi Parquet data following an ELT model (extraction, load, transform) and using several technologies used during the [Data Engineering course from DataTalksClub](https://github.com/DataTalksClub/data-engineering-zoomcamp/). Personal course notes and work area available at: [https://github.com/hdt94/dtc-de-course](https://github.com/hdt94/dtc-de-course)

Contents:
- [Description](#description)
- [Setup (reproducibility)](#setup-reproducibility)

Datasets: https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page

Guiding references:
- https://github.com/DataTalksClub/data-engineering-zoomcamp/tree/main/week_7_project
- https://github.com/DataTalksClub/data-engineering-zoomcamp/blob/main/cohorts/2023/project.md

# Description

Public information provided by the New York city Taxi & Limousine Commission - TLC regarding taxi trips allows extracting insights about rates, demand, and mobility. The purpose of doing analytics on this data is to present most valuable descriptors of such dimensions.

Analytics dashboard is available at: https://lookerstudio.google.com/reporting/cf68a74a-c790-4b9b-98d0-d900966ebd6c

The system design follows an ELT model:
- Extraction/ingestion as batch process from web source: https://www.nyc.gov/site/tlc/about/tlc-trip-record-data.page
- Load into datalake and datawarehouse as external tables.
- Transform data within datawarehouse using semantic layer.

The system is implemented using Google Cloud, dbt, and Looker; the provisioning is made through Terraform; and the data pipeline has been developed for execution in a scheduled basis as well as ad-hoc basis, allowing custom parameterization for extracting/ingesting multiple years and vehicle types through Airflow/Composer manual DAG Run with config.

System design high-level diagram:
![project diagram](./diagram.png)

# Setup (reproducibility)
Setup may have two deployment options:
- Fully on cloud with Google Cloud and dbt Cloud.
- Hybrid optionally using local Airflow and/or local dbt core.

Setup requirements:
- GCP project, gcloud, git, jq, and terraform. Using [Cloud Shell](https://console.cloud.google.com/welcome?cloudshell=true) is recommended as it complies with all these requirements.
- Local Airflow and/or local dbt require a Python distribution.
- Local Airflow setup additionally requires docker.

Log in with gcloud if using other than Cloud Shell:
```bash
gcloud auth application-default login
```

Clone repo:
```bash
git clone https://github.com/hdt94/dtc-de-project && cd dtc-de-project
```

Define base environment variables:
- note that `secrets/` directory is part of [.gitignore](./.gitignore)
```bash
# if using Cloud Shell
export GCP_PROJECT_ID=$DEVSHELL_PROJECT_ID

# set value if using other than Cloud Shell
export GCP_PROJECT_ID=

# customizable variables
export BQ_DATASET=trips
export GCP_REGION=us-central1
export GCS_DATA_BUCKET_NAME="datalake-$GCP_PROJECT_ID"

# customizable credential file paths
export DBT_GCP_CREDENTIALS_FILE="$PWD/secrets/dbt_gcp_sa_credentials.json"
export ORCHESTRATOR_GCP_CREDENTIALS_FILE="$PWD/secrets/orchestrator_gcp_sa_credentials.json"  # only for LOCAL_AIRFLOW=true

# optional hybrid setup
export LOCAL_AIRFLOW=true  # create local airflow venv, not provisioning Cloud Composer
export LOCAL_DBT=true  # create local dbt venv
```

Options for venvs if using hybrid setup:
- if `sqlite3` system library is too old "sqlite C library version too old (< 3.15.0)":
  - Download and update `sqlite3` binary: https://www.sqlite.org/download.html
  - Use a `conda` env: `BASE_CONDA_ENV=`
```bash
# Alternative 1: venv based on python distribution (change as needed)
export BASE_PYTHON=python3.8

# Alternative 2: venv based on conda env python distribution (change as needed)
export BASE_CONDA_ENV=base
```

Initialize environment using single script to:
- initialize local Python venvs if using hybrid setup
- provision cloud resources using Terraform with local storage backend
- generate a dbt BigQuery connection service account JSON file at `DBT_GCP_CREDENTIALS_FILE` location (see base variables)
- generate a service account JSON file at `ORCHESTRATOR_GCP_CREDENTIALS_FILE` location (see base variables) only if `LOCAL_AIRFLOW=true`
- build container images either locally or using Cloud Build + Cloud Artifacts
- upload DAGs to Composer if using cloud orchestrator
- generate `.env` enviroment file with all relevant environment variables used in this repo
```bash
gcloud config set project $GCP_PROJECT_ID
chmod +x ./init-env.sh

# running all steps
RUN_ALL=true ./init-env.sh

# running individual steps
INIT_VENVS=true ./init-env.sh
APPLY_TERRAFORM=true ./init-env.sh
UPDATE_DBT_CREDENTIALS_FILE=true ./init-env.sh
UPDATE_ORCHESTRATOR_CREDENTIALS_FILE=true ./init-env.sh
BUILD_CONTAINER_IMAGES=true ./init-env.sh
UPLOAD_COMPOSER_DAGS=true ./init-env.sh

# Note: .env environment variable is updated in all script runs
```

## Cloud

Cloud Composer:
- Follow instructions [orchestration/airflow/README.md](./orchestration/airflow/README.md)

Cloud dbt:
- Fork repository to your GitHub account: https://github.com/hdt94/dtc-de-project/fork
- Create a dbt project: https://cloud.getdbt.com/
- Setup dbt project subdirectory to: `datawarehouse/dbt/trips`
- Setup BigQuery connection using the service account JSON file previously generated at `DBT_GCP_CREDENTIALS_FILE` location (see base variables): https://docs.getdbt.com/docs/quickstarts/dbt-cloud/bigquery#connect-dbt-cloud-to-bigquery
- Setup repository using Git Clone option: git@github.com:YOUR_GITHUB_USERNAME/dtc-de-project.git
- Add dbt deploy key to your repository: https://docs.getdbt.com/docs/cloud/git/import-a-project-by-git-url#github
- Follow instructions [datawarehouse/dbt/trips/README.md](./datawarehouse/dbt/trips/README.md)

## Local

Local Airflow:
- WARNING: standalone mode is for development only, do not use it in production.
- Enable environment:
  ```bash
  set -a; source .env; set +a;
  source venvs/venv-airflow/bin/activate
  airflow standalone
  ```
- Follow instructions  [orchestration/airflow/README.md](./orchestration/airflow/README.md)

Local dbt:
- Enable environment:
  ```bash
  set -a; source .env; set +a;
  source venvs/venv-dbt/bin/activate
  cd datawarehouse/dbt/trips
  ```
- Follow instructions [datawarehouse/dbt/trips/README.md](./datawarehouse/dbt/trips/README.md)
