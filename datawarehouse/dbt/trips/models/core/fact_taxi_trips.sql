{{ config(
    materialized='table',
    partition_by={
      "field": "pickup_datetime",
      "data_type": "timestamp",
      "granularity": "day"
    }
) }}

WITH green_trips AS (
    SELECT *,
        'Green' AS service_type 
    FROM {{ ref('stg_green_trips') }}
),
yellow_trips AS (
    SELECT *,
        'Yellow' AS service_type 
    FROM {{ ref('stg_yellow_trips') }}
),
trips AS (
    SELECT * FROM green_trips
    UNION ALL
    SELECT * FROM yellow_trips
),
zones AS (
    SELECT * FROM {{ ref('dim_zones') }}
    where borough != 'Unknown'
)
SELECT 
    trips.tripid,
    trips.vendorid,
    trips.service_type,
    trips.ratecodeid,
    trips.pickup_locationid,
    pickup_zone.borough AS pickup_borough,
    pickup_zone.zone AS pickup_zone,
    trips.dropoff_locationid,
    dropoff_zone.borough AS dropoff_borough,
    dropoff_zone.zone AS dropoff_zone, 
    trips.pickup_datetime,
    trips.dropoff_datetime,
    trips.store_and_fwd_flag,
    trips.passenger_count,
    trips.trip_distance,
    trips.trip_type,
    trips.fare_amount,
    trips.extra,
    trips.mta_tax,
    trips.tip_amount,
    trips.tolls_amount,
    trips.ehail_fee,
    trips.improvement_surcharge,
    trips.total_amount,
    trips.payment_type,
    trips.payment_type_description,
    trips.congestion_surcharge
FROM trips
INNER JOIN zones AS pickup_zone
ON trips.pickup_locationid = pickup_zone.locationid
INNER JOIN zones AS dropoff_zone
ON trips.dropoff_locationid = dropoff_zone.locationid
