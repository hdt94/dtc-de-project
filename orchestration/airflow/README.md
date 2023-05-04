Notes:
- Data bucket name may be overriden as DAG parameter.
- Default data bucket set as Airflow variable through `AIRFLOW_VAR_DATA_BUCKET_NAME` environment variable cannot be modified from UI, as Airflow variables defined as environment variables are not visible from Airflow UI. Read https://airflow.apache.org/docs/apache-airflow/stable/howto/variable.html#storing-variables-in-environment-variables
