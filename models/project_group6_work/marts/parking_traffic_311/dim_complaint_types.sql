-- CIS 9440 Group 6 - Milestone 4
-- Complaint type dimension for NYPD parking/traffic-related 311 requests
-- Grain: one row per distinct (complaint_type, descriptor) combination

WITH stg_311 AS (

    SELECT *
    FROM {{ ref('stg_311_requests') }}

),

distinct_complaint_types AS (

    SELECT DISTINCT
        complaint_type,
        descriptor

    FROM stg_311

    WHERE complaint_type IS NOT NULL

),

dim_complaint_type AS (

    SELECT
        {{ dbt_utils.generate_surrogate_key([
            'complaint_type',
            'descriptor'
        ]) }} AS complaint_type_key,

        complaint_type,
        descriptor

    FROM distinct_complaint_types

)

SELECT * FROM dim_complaint_type