{{ config(
    materialized='table',
    partition_by={
      "field": "pickup_datetime",
      "data_type": "timestamp",
      "granularity": "day"
    }    
) }}

WITH dim_zones AS (
    SELECT * FROM {{ ref('dim_zones') }}
    WHERE borough != 'Unknown'
)
SELECT 
    trips.tripid,
    trips.affiliated_base_number,
    trips.dispatching_base_num,

    -- trip info
    trips.sr_flag,

    trips.pickup_locationid,
    pickup_zone.borough AS pickup_borough, 
    pickup_zone.zone AS pickup_zone, 

    trips.dropoff_locationid,
    dropoff_zone.borough AS dropoff_borough, 
    dropoff_zone.zone AS dropoff_zone,  

    trips.pickup_datetime,
    trips.dropoff_datetime

FROM {{ ref('stg_fhv_trips') }} AS trips
INNER JOIN dim_zones AS pickup_zone
ON trips.pickup_locationid = pickup_zone.locationid
INNER JOIN dim_zones AS dropoff_zone
ON trips.dropoff_locationid = dropoff_zone.locationid
