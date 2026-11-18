-- Grain: one row per 311 service request handled by NYPD (one row per unique_key).
-- Built from stg_311_requests (already deduped on unique_key).
--
-- KEY RULES (the dims MUST build their keys with the exact same expressions):
--   complaint_type_key = MD5 hash of complaint_type | descriptor
--   location_key       = MD5 hash of incident_zip | borough
--   agency_key         = MD5 hash of agency_name (same rule as issuing_agency_key in the parking fact)
--   precinct_key       = MD5 hash of precinct number (leading zeros stripped, same as the parking fact)
--   *_date_key         = 'YYYYMMDD', or '-1' if missing (closed_date_key is '-1' for open requests)
--   created_time_key   = 2-digit hour '00'-'23', or '-1' if missing
--
-- MEASURES:
--   days_to_close      = whole days from created to closed; NULL for open requests
--                        and for bad data where closed_date < created_date

-- Grain: one row per 311 service request handled by NYPD (one row per unique_key).
-- Built from stg_311_requests (already deduped on unique_key).
--
-- KEY RULES (the dims MUST build their keys with the exact same expressions):
--   complaint_type_key = MD5 hash of complaint_type | descriptor
--   location_key       = MD5 hash of incident_zip | borough
--   agency_key         = MD5 hash of agency_name (same rule as issuing_agency_key in the parking fact)
--   precinct_key       = MD5 hash of precinct number (leading zeros stripped, same as the parking fact)
--   *_date_key         = 'YYYYMMDD', or '-1' if missing (closed_date_key is '-1' for open requests)
--   created_time_key   = 2-digit hour '00'-'23', or '-1' if missing
--
-- MEASURES:
--   days_to_close      = whole days from created to closed; NULL for open requests
--                        and for bad data where closed_date < created_date

WITH stg AS (
    SELECT * FROM {{ ref('stg_311_requests') }}
),

prepped AS (
    SELECT
        *,
        -- '019' -> '19'; blanks/0/non-numeric -> 'UNKNOWN'
        COALESCE(
            CAST(NULLIF(SAFE_CAST(REGEXP_EXTRACT(CAST(police_precinct AS STRING), r'(\d+)') AS INT64), 0) AS STRING),
            'UNKNOWN'
        ) AS precinct_clean
    FROM stg
)

SELECT
    -- Surrogate key
    TO_HEX(MD5(CAST(unique_key AS STRING)))                       AS complaint_fact_key,

    -- Degenerate dimension / attributes
    unique_key,
    channel_type,
    status                                                        AS request_status,
    vehicle_type,

    -- Measure
    CASE
        WHEN closed_date IS NOT NULL AND DATE(closed_date) >= DATE(created_date)
            THEN DATE_DIFF(DATE(closed_date), DATE(created_date), DAY)
    END                                                           AS days_to_close,

    -- Foreign keys
    TO_HEX(MD5(CONCAT(
        COALESCE(UPPER(complaint_type), 'UNKNOWN'), '|',
        COALESCE(UPPER(descriptor), 'UNKNOWN')
    )))                                                           AS complaint_type_key,

    TO_HEX(MD5(CONCAT(
        COALESCE(CAST(incident_zip AS STRING), 'UNKNOWN'), '|',
        COALESCE(UPPER(borough), 'UNKNOWN')
    )))                                                           AS location_key,

    TO_HEX(MD5(COALESCE(UPPER(agency_name), 'UNKNOWN')))          AS agency_key,

    TO_HEX(MD5(precinct_clean))                                   AS precinct_key,

    COALESCE(FORMAT_DATE('%Y%m%d', DATE(created_date)), '-1')     AS created_date_key,
    COALESCE(FORMAT_DATE('%Y%m%d', DATE(closed_date)), '-1')      AS closed_date_key,

    COALESCE(LPAD(CAST(EXTRACT(HOUR FROM created_date) AS STRING), 2, '0'), '-1') AS created_time_key

FROM prepped