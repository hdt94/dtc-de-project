"""
Extract trips parquet files from TCL and load them to Google Cloud Storage

DAG supports both scheduled DagRun and manual parameterized DagRun.

Dynamic tasks are created based on list-like parameters: `years` and `vehicle_types`

Parameters:
- `data_bucket_name: string`: destination data bucket. This can be defined as:
    - DAG parameter (takes precedence)
    - Airflow variable (fallback in case no parameter is set)
- `vehicle_types: [string]`: optional
- `years: [int]`: optional


"""

import datetime as dt

from airflow import DAG
from airflow.decorators import task
from airflow.models.param import Param


CLOUD_RUN_REQUIREMENT = "google-cloud-run==0.7.1"
VEHICLE_TYPES = [
    "fhv",
    "fhvhv",
    "green",
    "yellow",
]


@task.virtualenv(
    task_id="extract_load_trips_from_tlc_to_gs_single_task",
    requirements=[CLOUD_RUN_REQUIREMENT],
    system_site_packages=False,
)
def extract_load(bucket_name, image, parent, vehicle_type, year, data_interval_end=None, run_id=None):
    """
    Cloud Run Job to extract and load based on scheduled DagRun:
        extract_load(bucket_name, image, parent, vehicle_type)
    This call will raise error if URL is not found.

    Cloud Run Job to extract and load based on explicit year parameter:
        extract_load(bucket_name, , image, parent, vehicle_type, year)
    This call will print not found URLs.
    """
    import re
    from google.cloud import run_v2

    assert bucket_name is not None, "bucket_name is required"
    assert image is not None, "image is required"
    assert parent is not None, "parent is required"

    run_id = re.sub("[_:T+]", "-", run_id).replace("--", "-")
    job_id = f"extract-load-trips-{run_id}"

    if year is None:
        conditional_args = [
            "--year", str(data_interval_end.year),
            "--month", str(data_interval_end.month),
            "--raise-if-any-not-found"
        ]
    else:
        conditional_args = [
            "--year", str(year),
        ]

    container = run_v2.Container(
        image=image,
        command=["python3"],
        args=[
            "-O", "-m", "dtc_de.extract_load.extract_load_trips_from_tlc_to_gs",
            "--bucket-name", bucket_name,
            "--vehicle-type", vehicle_type,
            *conditional_args
        ],
        resources=run_v2.ResourceRequirements(
            limits={
                "cpu": "2",
                "memory": "4Gi",
            }
        )
    )

    job = run_v2.Job()
    job.template.template.containers = [container]
    job.template.template.max_retries = 0

    print("Creating job on Cloud Run...")
    client = run_v2.JobsClient()
    res = client.create_job(job=job, job_id=job_id, parent=parent).result()
    if res.terminal_condition.state is not run_v2.Condition.State.CONDITION_SUCCEEDED:
        raise ValueError("Job state after creation is not CONDITION_SUCCEEDED")

    job_name = res.name
    print(f"Cloud Run Job name: {job_name}")

    print("Running job...")
    res = client.run_job(name=job_name).result()
    if (res.succeeded_count == 0) and (res.failed_count > 0):
        raise RuntimeError("job run failed")

    print("Deleting job...")
    client.delete_job(name=job_name).result()

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
    "cloud_run_jobs_parent": Param(default=None, type=["string", "null"]),
    "data_bucket_name": Param(default=None, type=["string", "null"]),
    "vehicle_types": Param(
        default=None,
        type=["array", "null"],
        items={"enum": VEHICLE_TYPES, "type": "string"},
    ),
    "years": Param(default=None, type=["array", "null"], items={"type": "integer"}),
}

with DAG(
    dag_id="extract_load_trips_from_tlc_to_gs_single_task",
    catchup=False,
    params=params,
    render_template_as_native_obj=True,
    schedule="@monthly",
    start_date=dt.datetime(2023, 4, 4),
) as dag:
    partials = dict(
        bucket_name="{{ params.data_bucket_name or var.value.get('data_bucket_name', None) }}",
        image="{{ var.value.docker_image_extract_load_trips_from_tlc_to_gs }}",
        parent="{{ params.cloud_run_jobs_parent or var.value.get('cloud_run_jobs_parent', None) }}",
    )
    expands = dict(
        vehicle_type=get_param(
            "{{ params.vehicle_types }}",
            ["green", "yellow"],
        ),
        year=get_param("{{ params.years }}", [None]),
    )

    extract_load.partial(**partials).expand(**expands)
