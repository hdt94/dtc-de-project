"""
Extract trips parquet files from TCL and load them to Google Cloud Storage

DAG supports both scheduled DagRun and manual parameterized DagRun.

Dynamic tasks are created based on list-like parameters: `years` and `vehicle_types`

Parameters:
- `cloud_batch_parent: str`: location parent for Cloud Batch jobs. This can be defined as:
    - DAG parameter (takes precedence)
    - Airflow variable (fallback in case no parameter is set)
- `data_bucket_name: str`: destination data bucket. This can be defined as:
    - DAG parameter (takes precedence)
    - Airflow variable (fallback in case no parameter is set)
- `vehicle_types: [string]`: optional
- `years: [int]`: optional
"""

import datetime as dt

from airflow import DAG
from airflow.decorators import task
from airflow.models.param import Param


CLOUD_BATCH_REQUIREMENT = "google-cloud-batch==0.10.0"
VEHICLE_TYPES = [
    "fhv",
    "fhvhv",
    "green",
    "yellow",
]


@task.virtualenv(
    requirements=[CLOUD_BATCH_REQUIREMENT],
    system_site_packages=False,
)
def check_job_state(job_name):
    """
    TODO
    create a deferrable operator/sensor as time.sleep() is not optimal
    """
    import time
    from google.cloud import batch_v1

    (FAILED, SUCCEEDED) = (
        batch_v1.JobStatus.State.FAILED,
        batch_v1.JobStatus.State.SUCCEEDED,
    )

    event_to_str = lambda e: str(e).replace('\n', ', ')

    client = batch_v1.BatchServiceClient()
    job = client.get_job(name=job_name)
    num_events = len(job.status.status_events)
    while job.status.state not in [FAILED, SUCCEEDED]:
        if num_events < len(job.status.status_events):
            for event in job.status.status_events[num_events:]:
                print(f"Batch job status event: {event_to_str(event)}")

            num_events = len(job.status.status_events)

        time.sleep(10)
        job = client.get_job(name=job.name)

    event = job.status.status_events[-1]
    print(f"Batch job last status event: {event_to_str(event)}")
    if job.status.state == FAILED:
        raise RuntimeError(f"Job failed: {job_name}")


@task.virtualenv(
    requirements=[CLOUD_BATCH_REQUIREMENT],
    system_site_packages=False,
)
def create_extract_load_batch_job(
    bucket_name,
    image,
    parent,
    vehicle_type,
    year=None,
    data_interval_end=None,
    run_id=None,
):
    """
    Create Cloud Batch job to extract and load based on scheduled DagRun:
        create_extract_load_batch_job(bucket_name, image, parent, vehicle_type)
    This call will raise error if URL is not found.

    Create Cloud Batch job to extract and load based on explicit year parameter:
        create_extract_load_batch_job(bucket_name, image, parent, vehicle_type, year)
    This call will print not found URLs.
    """
    import re
    from google.cloud import batch_v1

    assert bucket_name is not None, "bucket_name is required"
    assert image is not None, "image is required"
    assert parent is not None, "parent is required"

    run_id = re.sub("[_:T+]", "-", run_id).replace("--", "-")
    job_id = f"extract-load-trips-batch-{run_id}"

    if year is None:
        conditional_args = [
            "--year",
            str(data_interval_end.year),
            "--month",
            str(data_interval_end.month),
            "--raise-if-any-not-found",
        ]
    else:
        conditional_args = [
            "--year",
            str(year),
        ]

    container = batch_v1.Runnable.Container({
        "image_uri": image,
        "entrypoint": "python3",
        "commands": [
            "-O", "-m", "dtc_de.extract_load.extract_load_trips_from_tlc_to_gs",
            "--bucket-name", bucket_name,
            "--vehicle-type", vehicle_type,
            *conditional_args,
        ],
    })
    job = batch_v1.Job({
        "task_groups": [
            {
                "task_spec": {
                    "runnables": [{"container": container}],
                    "compute_resource": {"cpu_milli": 2000, "memory_mib": 16},
                    "max_retry_count": 0,
                }
            }
        ],
        "allocation_policy": {
            "instances": [{"policy": {"machine_type": "e2-standard-2"}}]
        },
        "logs_policy": {"destination": "CLOUD_LOGGING"},
    })

    print("Creating job on Cloud Batch...")
    client = batch_v1.BatchServiceClient()
    res = client.create_job(
        job=job,
        job_id=job_id,
        parent=parent,
    )

    job_name = res.name
    print(f"Cloud Batch job name: {job_name}")

    return job_name


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
    "cloud_batch_parent": Param(default=None, type=["string", "null"]),
    "data_bucket_name": Param(default=None, type=["string", "null"]),
    "vehicle_types": Param(
        default=None,
        type=["array", "null"],
        items={"enum": VEHICLE_TYPES, "type": "string"},
    ),
    "years": Param(default=None, type=["array", "null"], items={"type": "integer"}),
}

with DAG(
    dag_id="extract_load_trips_from_tlc_to_gs_batch_job",
    catchup=False,
    params=params,
    render_template_as_native_obj=True,
    schedule="@monthly",
    start_date=dt.datetime(2023, 4, 4),
) as dag:
    partials = dict(
        bucket_name="{{ params.data_bucket_name or var.value.get('data_bucket_name', None) }}",
        image="{{ var.value.docker_image_extract_load_trips_from_tlc_to_gs }}",
        parent="{{ params.cloud_batch_parent or var.value.get('cloud_batch_parent', None) }}",
    )
    expands = dict(
        vehicle_type=get_param(
            "{{ params.vehicle_types }}",
            ["green", "yellow"],
        ),
        year=get_param("{{ params.years }}", [None]),
    )

    job_names = create_extract_load_batch_job.partial(**partials).expand(**expands)
    check_job_state.expand(job_name=job_names)
