"""
Extract trips parquet files from TCL and load them to Google Cloud Storage

Configuration:
- `data_bucket_name: string`: destination data bucket. This can be defined as:
    - DAG parameter (takes precedence)
    - Airflow variable (fallback in case no parameter is set)
- `year: int`: optional
- `vehicle_type: string`: optional
"""

import datetime as dt

from airflow import DAG
from airflow.decorators import task
from airflow.models.param import Param

from dtc_de.utils.requirements import read_module_requirements


VEHICLE_TYPES = [
    "fhv",
    "fhvhv",
    "green",
    "yellow",
]

with DAG(
    dag_id="extract_load_trips_from_tlc_to_gs",
    catchup=False,
    description=__doc__,
    params={
        "data_bucket_name": Param(default=None, type=["string", "null"]),
        "vehicle_type": Param(default="green", enum=VEHICLE_TYPES, type="string"),
        "year": Param(default=None, type=["integer", "null"]),
    },
    render_template_as_native_obj=True,
    schedule=None,
    start_date=dt.datetime(2023, 4, 4),
) as dag:

    @task.virtualenv(
        task_id="extract_load_trips_from_tlc_to_gs",
        requirements=read_module_requirements(
            "dtc_de.extract_load",
            "extract_load_trips_from_tlc_to_gs.requirements.txt",
        ),
        system_site_packages=False,
    )
    def extract_load(bucket_name, vehicle_type, year):
        from dtc_de.extract_load import extract_load_trips_from_tlc_to_gs

        extract_load_trips_from_tlc_to_gs.main(
            bucket_name=bucket_name,
            vehicle_type=vehicle_type,
            year=year,
        )

    extract_load(
        bucket_name="{{ params.data_bucket_name or var.value.get('data_bucket_name', None) }}",
        vehicle_type="{{ params.vehicle_type }}",
        year="{{ params.year }}",
    )
