"""
Extract trips parquet files from TCL and load them to Google Cloud Storage

DAG supports both scheduled DagRun and manual parameterized DagRun.

Dynamic tasks are created based on list-like parameters: `years` and `vehicle_types`

Parameters:
- `data_bucket_name: string`: destination data bucket. This can be defined as:
    - DAG parameter (takes precedence)
    - Airflow variable (fallback in case no parameter is set)
- `years: [int]`: optional
- `vehicle_types: [string]`: optional
"""

import datetime as dt

from airflow import DAG
from airflow.decorators import task
from airflow.models.param import Param


VEHICLE_TYPES = [
    "fhv",
    "fhvhv",
    "green",
    "yellow",
]


@task.docker(
    task_id="extract_load_trips_from_tlc_to_gs",
    image="{{ var.value.docker_image_extract_load_trips_from_tlc_to_gs }}",
    retry_delay=dt.timedelta(weeks=1),
)
def extract_load(bucket_name, vehicle_type, year, data_interval_end=None):
    """
    Extract and load based on scheduled DagRun:
        extract_load(bucket_name, vehicle_type)
    This call will raise error if URL is not found.

    Extract and load based on explicit year parameter:
        extract_load(bucket_name, vehicle_type, year)
    This call will print not found URLs.
    """
    from dtc_de.extract_load import extract_load_trips_from_tlc_to_gs

    if year is None:
        extract_load_trips_from_tlc_to_gs.main(
            bucket_name=bucket_name,
            vehicle_type=vehicle_type,
            year=data_interval_end.year,
            month=data_interval_end.month,
            raise_if_any_not_found=True,
        )
    else:
        extract_load_trips_from_tlc_to_gs.main(
            bucket_name=bucket_name,
            vehicle_type=vehicle_type,
            year=year,
            raise_if_any_not_found=False,
        )


@task
def get_param(param_value, default_value):
    """
    Get param list value or default list value.
    This is required for Operator.expand() call to work.
    """
    if param_value is None:
        return default_value

    return param_value


params = {
    "data_bucket_name": Param(default=None, type=["string", "null"]),
    "vehicle_types": Param(
        default=None,
        type=["array", "null"],
        items={"enum": VEHICLE_TYPES, "type": "string"},
    ),
    "years": Param(default=None, type=["array", "null"], items={"type": "integer"}),
}

with DAG(
    dag_id="extract_load_trips_from_tlc_to_gs",
    catchup=False,
    params=params,
    render_template_as_native_obj=True,
    schedule="@monthly",
    start_date=dt.datetime(2023, 4, 4),
) as dag:
    partials = dict(
        bucket_name="{{ params.data_bucket_name or var.value.get('data_bucket_name', None) }}",
    )
    expands = dict(
        vehicle_type=get_param(
            "{{ params.vehicle_types }}",
            ["green", "yellow"],
        ),
        year=get_param("{{ params.years }}", [None]),
    )
    extract_load.partial(**partials).expand(**expands)
