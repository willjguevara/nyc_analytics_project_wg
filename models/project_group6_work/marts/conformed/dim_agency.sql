WITH stg_open_camera AS (

    SELECT *
    FROM {{ ref('stg_open_camera_violations') }}
),

stg_311_requests AS (
    SELECT * FROM {{ ref('stg_311_requests') }}

),

all_agencies AS (

    SELECT DISTINCT
        agency_name
    FROM stg_311_requests
    WHERE agency_name IS NOT NULL

    UNION DISTINCT

    SELECT DISTINCT
        agency_name
    FROM stg_open_camera
    WHERE agency_name IS NOT NULL

),

standardized_agencies AS (

    SELECT DISTINCT
        CASE
            WHEN agency_name = 'New York City Police Department'
                THEN 'POLICE DEPARTMENT'
            ELSE TRIM(agency_name)
        END AS agency_name
    FROM all_agencies

),

dim_agency AS (

    SELECT
        {{ dbt_utils.generate_surrogate_key([
            'agency_name',
        ]) }} AS agency_key,
        agency_name
    FROM standardized_agencies

)

SELECT * FROM dim_agency