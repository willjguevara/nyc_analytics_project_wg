WITH source AS (
    SELECT *
    FROM {{ source('raw', 'source_open_parking_project') }}
), -- Easier to refer to the dbt reference to a long table name

cleaned AS (
    SELECT
        -- Get all columns from source, except ones we're transforming below
        * EXCEPT (
            summons_number,
            issue_date,
            judgment_entry_date,
            violation_time,
            violation,
            fine_amount,
            penalty_amount,
            interest_amount,
            reduction_amount,
            payment_amount, 
            amount_due, 
            violation_status,
            plate,
            state,
            license_type,
            violation,
            precinct,
            county,
            issuing_agency
        ),

        -- Identifiers
        CAST(summons_number AS STRING) AS summons_number,

        -- Date/Time
        SAFE_CAST(issue_date AS TIMESTAMP) AS issue_date,
        SAFE_CAST(judgment_entry_date AS TIMESTAMP) AS judgment_entry_date,
        TRIM(CAST(violation_time AS STRING)) AS violation_time,

        -- Request details
        TRIM(CAST(issuing_agency AS STRING)) AS agency_name,
        TRIM(CAST(plate AS STRING)) AS plate,

        -- Location
        TRIM(CAST(precinct AS STRING)) AS police_precinct,
        TRIM(CAST(state AS STRING)) AS state,

        -- Standardize borough names
        CASE
            WHEN UPPER(TRIM(county))
                IN ('MANHATTAN', 'NEW YORK COUNTY')
                THEN 'Manhattan'
            WHEN UPPER(TRIM(county))
                IN ('BRONX', 'THE BRONX')
                THEN 'Bronx'
            WHEN UPPER(TRIM(county))
                IN ('BROOKLYN', 'KINGS COUNTY')
                THEN 'Brooklyn'
            WHEN UPPER(TRIM(county))
                IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY')
                THEN 'Queens'
            WHEN UPPER(TRIM(county))
                IN ('STATEN ISLAND', 'RICHMOND COUNTY')
                THEN 'Staten Island'
            ELSE 'UNKNOWN or CITYWIDE'
        END AS borough,

        --amounts
        CAST(amount_due as NUMERIC) AS amount_due,
        CAST(fine_amount as NUMERIC) AS fine_amount,
        CAST(interest_amount as NUMERIC) AS interest_amount,
        CAST(payment_amount as NUMERIC) AS payment_amount,
        CAST(penalty_amount as NUMERIC) AS penalty_amount,
        CAST(reduction_amount as NUMERIC) AS reduction_amount,

        --violation details
        TRIM(CAST(violation AS STRING)) AS type_of_violation,
        TRIM(CAST(violation_status AS STRING)) AS violation_status,

        -- Metadata
        CURRENT_TIMESTAMP() AS _stg_loaded_at

    FROM source

    -- Filters: NYPD requests in the four selected complaint types
    WHERE UPPER(TRIM(issuing_agency)) = 'POLICE DEPARTMENT'
      AND summons_number IS NOT NULL
      AND issue_date IS NOT NULL

    -- Deduplicate
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY summons_number
        ORDER BY issue_date DESC
    ) = 1
)

SELECT * FROM cleaned