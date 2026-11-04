WITH source AS (
   SELECT * FROM {{ source('raw', 'source_nyc_dob_job_apps') }}
), -- Easier to refer to the dbt reference to a long name table this way

cleaned AS (
   SELECT
       -- Get all columns from source, except ones we're transforming below
       -- To do cleaning on them or explicitly cast them as types just in case
       * EXCEPT (
           job_filing_number, 
           filing_status,
           house_no, 
           street_name,
           borough, 
           block, 
           lot,
           community_board, 
           current_status_date, 
           first_permit_date, 
           signoff_date,  
           initial_cost, 
           total_construction_floor_area,
           sprinkler_work_type,
           plumbing_work_type, 
           postcode, 
           nta, 
           latitude, 
           longitude,
           zip
       ),

       -- Identifiers
       CAST(job_filing_number AS STRING) AS request_id,

       -- Date/Time
       CAST(current_status_date AS TIMESTAMP) AS current_status_date,
       CAST(first_permit_date AS TIMESTAMP) AS first_permit_date,
       CAST(signoff_date AS TIMESTAMP) AS signoff_date,

       -- Request details
       CAST(sprinkler_work_type AS STRING) AS sprinkler_work_type,
       CAST(plumbing_work_type AS STRING) AS plumbing_work_type,
       CAST(initial_cost AS DECIMAL) AS initial_cost,
       CAST(total_construction_floor_area AS DECIMAL) AS total_construction_square_footage,
		CASE
           WHEN filing_status like '%Intent to Revoke%' THEN 'Intent to Revoke'
           WHEN filing_status like '%Objections%' THEN 'Objections'
           WHEN filing_status like '%On Hold%' THEN 'On Hold'
           WHEN filing_status like '%OnHold%' THEN 'On Hold'
           WHEN filing_status like '%Objections%' THEN 'Objections'
           WHEN filing_status like '%Loft Board%' THEN 'Objections'
           WHEN filing_status like '%Pending%' THEN 'Pending'
           WHEN filing_status like '%Permit Entire%' THEN 'Permit Entire'
           WHEN filing_status like '%Intent to Revoke%' THEN 'Intent to Revoke'
           ELSE filing_status
       END AS filing_status,

       -- Location - clean zip code, handling several common zip code data problems
       CASE
           WHEN UPPER(TRIM(CAST(postcode AS STRING))) IN ('N/A', 'NA') THEN NULL
           WHEN UPPER(TRIM(CAST(postcode AS STRING))) = 'ANONYMOUS' THEN 'Anonymous'
           WHEN LENGTH(CAST(postcode AS STRING)) = 5 THEN CAST(postcode AS STRING)
           WHEN LENGTH(CAST(postcode AS STRING)) = 9 THEN CAST(postcode AS STRING)
           WHEN LENGTH(CAST(postcode AS STRING)) = 10
               AND REGEXP_CONTAINS(CAST(postcode AS STRING), r'^\d{5}-\d{4}')
           THEN CAST(postcode AS STRING)
           ELSE NULL
       END AS zip,

       -- Location - standardized borough, just in case
       CASE
           WHEN UPPER(TRIM(borough)) IN ('MANHATTAN', 'NEW YORK COUNTY') THEN 'Manhattan'
           WHEN UPPER(TRIM(borough)) IN ('BRONX', 'THE BRONX') THEN 'Bronx'
           WHEN UPPER(TRIM(borough)) IN ('BROOKLYN', 'KINGS COUNTY') THEN 'Brooklyn'
           WHEN UPPER(TRIM(borough)) IN ('QUEENS', 'QUEEN', 'QUEENS COUNTY') THEN 'Queens'
           WHEN UPPER(TRIM(borough)) IN ('STATEN ISLAND', 'RICHMOND COUNTY') THEN 'Staten Island'
           ELSE 'UNKNOWN'
       END AS borough,

       CAST(house_no AS STRING) AS house_no,
       CAST(street_name AS STRING) AS street_name,
       CAST(block AS STRING) AS block,
       CAST(lot AS STRING) AS lot,
       CAST(community_board AS STRING) AS community_board,
       CAST(latitude AS DECIMAL) AS latitude,
       CAST(longitude AS DECIMAL) AS longitude,
       CAST(nta AS STRING) AS neighborhood,

       -- Metadata
       CURRENT_TIMESTAMP() AS _stg_loaded_at

   FROM source

   -- Filters
   WHERE job_filing_number IS NOT NULL
   AND signoff_date IS NOT NULL
   AND borough IS NOT NULL
   AND nta IS NOT NULL
   AND postcode IS NOT NULL

   -- Deduplicate
   QUALIFY ROW_NUMBER() OVER (PARTITION BY job_filing_number ORDER BY current_status_date DESC) = 1
)

SELECT * FROM cleaned