WITH stg_open_camera AS (

    SELECT *
    FROM {{ ref('stg_open_camera_violations') }}

),

stg_311_requests AS (

    SELECT *
    FROM {{ ref('stg_311_requests') }}

),

-- Collect hours from both staging tables
all_times AS (

    -- Hours from 311 service requests
    SELECT
        EXTRACT(HOUR FROM created_date) AS hour
    FROM stg_311_requests
    WHERE created_date IS NOT NULL

    UNION DISTINCT

    -- Hours from parking violations
    SELECT
        CASE
            WHEN REGEXP_CONTAINS(
                TRIM(violation_time),
                r'^(0[1-9]|1[0-2])[0-5][0-9][AP]$'
            )
            THEN MOD(
                SAFE_CAST(
                    SUBSTR(TRIM(violation_time), 1, 2)
                    AS INT64
                ),
                12
            ) + IF(
                RIGHT(TRIM(violation_time), 1) = 'P',
                12,
                0
            )
            ELSE NULL
        END AS hour
    FROM stg_open_camera
    WHERE violation_time IS NOT NULL

),

all_hours AS (

    SELECT hour
    FROM UNNEST(GENERATE_ARRAY(0, 23)) AS hour

),

distinct_hours AS (

    SELECT hour
    FROM all_times
    WHERE hour IS NOT NULL

    UNION DISTINCT

    SELECT hour
    FROM all_hours

),

time_dimension AS (

    SELECT
        {{ dbt_utils.generate_surrogate_key(['hour']) }} AS time_key,

        hour,

        CASE
            WHEN hour < 12 THEN 'AM'
            ELSE 'PM'
        END AS am_pm,

        CASE
            WHEN hour BETWEEN 5 AND 11 THEN 'Morning'
            WHEN hour BETWEEN 12 AND 16 THEN 'Afternoon'
            WHEN hour BETWEEN 17 AND 20 THEN 'Evening'
            ELSE 'Night'
        END AS time_of_day

    FROM distinct_hours

),

-- Unknown time placeholder
null_placeholder AS (

    SELECT
        '-1' AS time_key,
        CAST(NULL AS INT64) AS hour,
        'Unknown' AS am_pm,
        'Unknown' AS time_of_day

)

SELECT * FROM time_dimension

UNION ALL

SELECT * FROM null_placeholder
