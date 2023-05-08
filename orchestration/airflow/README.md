# Up and running

List Docker operator images built on environment initialization (check [repo root README](/README.md)) to confirm availability:
```bash
# Using local setup
docker images list | grep grep extract_load_trips_from_tlc_to_gs
```

Set Docker operator image on orchestrator instance:
```bash
# Using local setup
IMAGE=extract_load_trips_from_tlc_to_gs:latest
airflow variables set docker_image_extract_load_trips_from_tlc_to_gs $IMAGE
```

Example DAG configuration:
```json
{
    "data_bucket_name": null,
    "vehicle_types": ["green", "yellow"],
    "years": [2019, 2020, 2021, 2022]
}
```

Notes:
- Data bucket name may be overriden as DAG parameter.
- Default data bucket set as Airflow variable through `AIRFLOW_VAR_DATA_BUCKET_NAME` environment variable cannot be modified from UI, as Airflow variables defined as environment variables are not visible from Airflow UI. Read https://airflow.apache.org/docs/apache-airflow/stable/howto/variable.html#storing-variables-in-environment-variables
