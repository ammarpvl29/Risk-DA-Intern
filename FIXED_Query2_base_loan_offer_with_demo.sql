-- ============================================================================
-- Query 2: Base Loan Offer with Demographics
-- Purpose: Join new offers with customer demographics for age tier analysis
-- Depends on: Query 1 (base_loan_offer_snapshot must be created first)
-- ============================================================================

CREATE OR REPLACE TABLE `data-prd-adhoc.temp_ammar.base_loan_offer_with_demo` AS
SELECT
  x.*,
  c.date_of_birth,
  DATE_DIFF(CURRENT_DATE(), c.date_of_birth, YEAR) AS age,
  CASE
    WHEN DATE_DIFF(CURRENT_DATE(), c.date_of_birth, YEAR) < 21 THEN '<21'
    WHEN DATE_DIFF(CURRENT_DATE(), c.date_of_birth, YEAR) BETWEEN 21 AND 25 THEN '21-25'
    WHEN DATE_DIFF(CURRENT_DATE(), c.date_of_birth, YEAR) BETWEEN 26 AND 30 THEN '26-30'
    WHEN DATE_DIFF(CURRENT_DATE(), c.date_of_birth, YEAR) BETWEEN 31 AND 35 THEN '31-35'
    WHEN DATE_DIFF(CURRENT_DATE(), c.date_of_birth, YEAR) BETWEEN 36 AND 40 THEN '36-40'
    WHEN DATE_DIFF(CURRENT_DATE(), c.date_of_birth, YEAR) BETWEEN 41 AND 45 THEN '41-45'
    WHEN DATE_DIFF(CURRENT_DATE(), c.date_of_birth, YEAR) BETWEEN 46 AND 50 THEN '46-50'
    WHEN DATE_DIFF(CURRENT_DATE(), c.date_of_birth, YEAR) > 50 THEN '>50'
    ELSE 'Unknown'
  END AS age_tier
FROM `data-prd-adhoc.temp_ammar.base_loan_offer_snapshot` x
LEFT JOIN `jago-bank-data-production.data_mart.customer` c
  ON x.customer_id = c.customer_id
  AND x.business_date = c.business_date
WHERE c.business_date >= '2025-01-01';

-- Note: This query takes 5-10 minutes due to customer table size
-- Expected result: Same row count as Query 1, now with age demographics
