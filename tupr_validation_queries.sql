-- ============================================================================
-- TUPR VALIDATION QUERIES
-- Purpose: Diagnose why TUPR shows 88% after switching to agreement_agreed_at
-- Expected: ~3% TUPR with 813K customers
-- Actual: 88% TUPR with 6K customers
-- ============================================================================

-- Query 1: Check agreement_agreed_at NULL values and date range
-- Purpose: Verify data quality of agreement_agreed_at field
SELECT
  COUNT(*) AS total_records,
  COUNT(agreement_agreed_at) AS non_null_agreement_agreed_at,
  COUNT(*) - COUNT(agreement_agreed_at) AS null_agreement_agreed_at,
  MIN(DATE(agreement_agreed_at)) AS min_agreement_date,
  MAX(DATE(agreement_agreed_at)) AS max_agreement_date,
  MIN(business_date) AS min_business_date,
  MAX(business_date) AS max_business_date
FROM `data-prd-adhoc.temp_ammar.base_loan_offer_snapshot`
WHERE business_date >= '2025-01-01';

-- Query 2: Compare month grouping - business_date vs agreement_agreed_at
-- Purpose: See how customer counts differ between the two date fields
SELECT
  FORMAT_DATE('%Y-%m', business_date) AS month_by_business_date,
  FORMAT_DATE('%Y-%m', DATE(agreement_agreed_at)) AS month_by_agreement_agreed_at,
  COUNT(DISTINCT customer_id) AS customer_count,
  COUNT(*) AS record_count
FROM `data-prd-adhoc.temp_ammar.base_loan_offer_snapshot`
WHERE business_date >= '2025-01-01'
  AND agreement_agreed_at IS NOT NULL
GROUP BY 1, 2
ORDER BY 1, 2;

-- Query 3: Check "same month" filter impact
-- Purpose: How many records have agreement_agreed_at in same month as business_date?
SELECT
  'All Records' AS filter_type,
  COUNT(DISTINCT customer_id) AS customers,
  COUNT(*) AS records
FROM `data-prd-adhoc.temp_ammar.base_loan_offer_snapshot`
WHERE business_date >= '2025-01-01'

UNION ALL

SELECT
  'Same Month: agreement_agreed_at = business_date' AS filter_type,
  COUNT(DISTINCT customer_id) AS customers,
  COUNT(*) AS records
FROM `data-prd-adhoc.temp_ammar.base_loan_offer_snapshot`
WHERE business_date >= '2025-01-01'
  AND FORMAT_DATE('%Y-%m', DATE(agreement_agreed_at)) = FORMAT_DATE('%Y-%m', business_date)

UNION ALL

SELECT
  'October 2025 - business_date' AS filter_type,
  COUNT(DISTINCT customer_id) AS customers,
  COUNT(*) AS records
FROM `data-prd-adhoc.temp_ammar.base_loan_offer_snapshot`
WHERE FORMAT_DATE('%Y-%m', business_date) = '2025-10'

UNION ALL

SELECT
  'October 2025 - agreement_agreed_at' AS filter_type,
  COUNT(DISTINCT customer_id) AS customers,
  COUNT(*) AS records
FROM `data-prd-adhoc.temp_ammar.base_loan_offer_snapshot`
WHERE FORMAT_DATE('%Y-%m', DATE(agreement_agreed_at)) = '2025-10';

-- Query 4: Date difference analysis between business_date and agreement_agreed_at
-- Purpose: Understand the time lag between these two dates
SELECT
  DATE_DIFF(business_date, DATE(agreement_agreed_at), DAY) AS days_diff,
  COUNT(DISTINCT customer_id) AS customers,
  COUNT(*) AS records
FROM `data-prd-adhoc.temp_ammar.base_loan_offer_snapshot`
WHERE business_date >= '2025-01-01'
  AND agreement_agreed_at IS NOT NULL
GROUP BY 1
ORDER BY 1;

-- Query 5: October detailed breakdown - offers using business_date
-- Purpose: See what the "correct" October population looks like
SELECT
  COUNT(DISTINCT customer_id) AS total_customers,
  COUNT(DISTINCT CASE WHEN agreement_agreed_at IS NOT NULL THEN customer_id END) AS customers_with_agreement_date,
  COUNT(DISTINCT CASE
    WHEN FORMAT_DATE('%Y-%m', DATE(agreement_agreed_at)) = '2025-10'
    THEN customer_id
  END) AS customers_with_oct_agreement
FROM `data-prd-adhoc.temp_ammar.base_loan_offer_snapshot`
WHERE FORMAT_DATE('%Y-%m', business_date) = '2025-10';

-- Query 6: Disbursement matching logic check
-- Purpose: Verify join logic between offers and disbursements
WITH oct_offers AS (
  SELECT DISTINCT
    customer_id,
    business_date,
    agreement_agreed_at,
    key_date,
    product_code,
    limit_offer
  FROM `data-prd-adhoc.temp_ammar.base_loan_offer_snapshot`
  WHERE FORMAT_DATE('%Y-%m', business_date) = '2025-10'
),

oct_disbursements AS (
  SELECT DISTINCT
    lfs_customer_id AS customer_id,
    deal_type,
    facility_start_date
  FROM `jago-bank-data-production.data_mart.credit_risk_vintage_account_direct_lending`
  WHERE deal_type IN ('JAG06', 'JAG08', 'JAG09')
    AND facility_start_date >= '2025-01-01'
    AND mob = 0
)

SELECT
  'Total October Offers' AS metric,
  COUNT(DISTINCT o.customer_id) AS customers
FROM oct_offers o

UNION ALL

SELECT
  'Matched with Disbursement (any month)' AS metric,
  COUNT(DISTINCT o.customer_id) AS customers
FROM oct_offers o
INNER JOIN oct_disbursements d
  ON o.customer_id = d.customer_id
  AND d.facility_start_date > o.key_date

UNION ALL

SELECT
  'Matched with Disbursement (same month as business_date)' AS metric,
  COUNT(DISTINCT o.customer_id) AS customers
FROM oct_offers o
INNER JOIN oct_disbursements d
  ON o.customer_id = d.customer_id
  AND d.facility_start_date > o.key_date
  AND FORMAT_DATE('%Y-%m', d.facility_start_date) = FORMAT_DATE('%Y-%m', o.business_date)

UNION ALL

SELECT
  'Matched with Disbursement (same month as agreement_agreed_at)' AS metric,
  COUNT(DISTINCT o.customer_id) AS customers
FROM oct_offers o
INNER JOIN oct_disbursements d
  ON o.customer_id = d.customer_id
  AND d.facility_start_date > o.key_date
  AND FORMAT_DATE('%Y-%m', d.facility_start_date) = FORMAT_DATE('%Y-%m', DATE(o.agreement_agreed_at))
  AND FORMAT_DATE('%Y-%m', DATE(o.agreement_agreed_at)) = FORMAT_DATE('%Y-%m', o.business_date);

-- Query 7: Sample records to inspect actual dates
-- Purpose: Look at actual examples to understand the data
SELECT
  customer_id,
  business_date,
  DATE(agreement_agreed_at) AS agreement_date,
  key_date,
  product_code,
  offer_status,
  CAST(limit_offer AS FLOAT64) AS limit_offer,
  DATE_DIFF(business_date, DATE(agreement_agreed_at), DAY) AS days_between_business_and_agreement
FROM `data-prd-adhoc.temp_ammar.base_loan_offer_snapshot`
WHERE FORMAT_DATE('%Y-%m', business_date) = '2025-10'
ORDER BY RAND()
LIMIT 20;
