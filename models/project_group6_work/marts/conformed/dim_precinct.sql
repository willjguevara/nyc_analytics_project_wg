WITH stg_open_camera AS (

    SELECT *
    FROM {{ ref('stg_open_camera_violations') }}
),

stg_311_requests AS (
    SELECT * FROM {{ ref('stg_311_requests') }}

),

all_locations AS (

    SELECT DISTINCT
        borough,
        SAFE_CAST(TRIM(REPLACE(police_precinct, 'Precinct', '')) AS INT64) AS police_precinct
    FROM stg_311_requests
    WHERE borough IS NOT NULL
    AND UPPER(borough) != 'UNSPECIFIED'
    AND SAFE_CAST(TRIM(REPLACE(police_precinct, 'Precinct', '')) AS INT64) IS NOT NULL

    UNION DISTINCT

    SELECT DISTINCT
        borough,
        SAFE_CAST(police_precinct AS INT) AS police_precinct
    FROM stg_open_camera
    WHERE borough IS NOT NULL
       OR police_precinct IS NOT NULL

),

dim_precinct AS (

    SELECT
        {{ dbt_utils.generate_surrogate_key([
            'borough',
            'police_precinct'
        ]) }} AS precinct_key,
        borough,
        police_precinct

    FROM all_locations

)

SELECT * FROM dim_precinct

