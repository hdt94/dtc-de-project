SELECT
   -- identifiers
    {{ dbt_utils.generate_surrogate_key(['dispatching_base_num', 'pickup_datetime']) }} AS tripid,
    CAST(affiliated_base_number AS STRING) AS  affiliated_base_number,
    CAST(dispatching_base_num AS STRING) AS  dispatching_base_num,
    CAST(dolocationid AS INTEGER) AS dropoff_locationid,
    CAST(pulocationid AS INTEGER) AS  pickup_locationid,

    -- timestamps
    CAST(dropoff_datetime AS TIMESTAMP) AS dropoff_datetime,
    CAST(pickup_datetime AS TIMESTAMP) AS pickup_datetime,

    -- trip info
    CAST(sr_flag AS INTEGER) AS sr_flag

FROM {{ source('staging', 'stg_fhv_trips_raw_external') }}

{% if var('is_test_run', default=true) %}
LIMIT 10
{% endif %}
