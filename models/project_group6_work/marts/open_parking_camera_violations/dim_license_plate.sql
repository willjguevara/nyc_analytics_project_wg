WITH stg_open_camera AS (

    SELECT *
    FROM {{ ref('stg_open_camera_violations') }}

),

distinct_license_plates AS (

    SELECT DISTINCT
        state,
        license_type

    FROM stg_open_camera

    WHERE license_type IS NOT NULL and state is not null

),

dim_license_types AS (

    SELECT
        {{ dbt_utils.generate_surrogate_key([
            'state',
            'license_type'
        ]) }} AS license_key,

        state,
        license_type

    FROM distinct_license_plates

)

SELECT * FROM dim_license_types