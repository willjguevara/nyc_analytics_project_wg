-- CIS 9440 Group 6 - Milestone 4
-- Location dimension for NYPD parking/traffic-related 311 requests
-- Grain: one row per distinct combination of location attributes

WITH stg_311 AS (

    SELECT *
    FROM {{ ref('stg_311_requests') }}

),

all_locations AS (

    SELECT DISTINCT
        location_type,
        incident_address,
        incident_zip,
        street_name,
        city,
        borough

    FROM stg_311

    WHERE location_type IS NOT NULL
       OR incident_address IS NOT NULL
       OR incident_zip IS NOT NULL
       OR street_name IS NOT NULL
       OR city IS NOT NULL
       OR borough IS NOT NULL

),

location_dimension AS (

    SELECT
        {{ dbt_utils.generate_surrogate_key([
            'location_type',
            'incident_address',
            'incident_zip',
            'street_name',
            'city',
            'borough'
        ]) }} AS location_key,

        location_type,
        incident_address,
        incident_zip,
        street_name,
        city,
        borough

    FROM all_locations

),

-- Placeholder row for missing location information
null_placeholder AS (

    SELECT
        '-1' AS location_key,
        CAST(NULL AS STRING) AS location_type,
        CAST(NULL AS STRING) AS incident_address,
        CAST(NULL AS STRING) AS incident_zip,
        CAST(NULL AS STRING) AS street_name,
        CAST(NULL AS STRING) AS city,
        CAST(NULL AS STRING) AS borough

)

SELECT * FROM location_dimension

UNION ALL

SELECT * FROM null_placeholder