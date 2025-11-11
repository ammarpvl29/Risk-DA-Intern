-- ============================================================================
-- Query 1: Base Loan Offer Snapshot (NEW OFFERS ONLY)
-- Purpose: Create base temp table with new offer detection
-- Filter: Exclude carry-over offers (offers that existed in previous month)
-- ============================================================================

CREATE OR REPLACE TABLE `data-prd-adhoc.temp_ammar.base_loan_offer_snapshot` AS

WITH offer_raw AS (
  SELECT
    business_date,
    customer_id,
    created_at,
    updated_at,  -- ✅ Include for QUALIFY clause
    agreement_agreed_at,
    expires_at,
    product_code,
    offer_status,
    risk_bracket,
    overdraft_initial_facility_limit,
    installment_initial_facility_limit,
    COALESCE(installment_initial_facility_limit, overdraft_initial_facility_limit) AS limit_offer,

    -- Calculate key_date (offer effective date)
    CASE
      WHEN DATE_DIFF(DATE(expires_at), DATE(created_at), MONTH) = 1
      THEN DATE(created_at)
      ELSE DATE_SUB(CAST(expires_at AS DATE), INTERVAL 1 MONTH)
    END AS key_date,

    -- Calculate loan_start_date
    LAST_DAY(DATE_SUB(CAST(expires_at AS DATE), INTERVAL 1 MONTH)) AS loan_start_date

  FROM `jago-bank-data-production.dwh_core.loan_offer_daily_snapshot`
  WHERE business_date BETWEEN DATE '2025-01-01' AND CURRENT_DATE()
    AND (
      business_date = LAST_DAY(business_date)
      OR business_date = CURRENT_DATE()
    )
    AND offer_status = 'ENABLED'
),

-- Deduplicate before carry-over detection
offer_deduped AS (
  SELECT * FROM offer_raw
  QUALIFY DENSE_RANK() OVER (
    PARTITION BY customer_id, business_date
    ORDER BY created_at ASC, updated_at DESC  -- First offer created, latest update
  ) = 1
),

-- Detect carry-over vs new offers
offer_with_flag AS (
  SELECT
    *,
    -- Check: Did this customer have an ENABLED offer last month?
    LAG(offer_status) OVER (
      PARTITION BY customer_id, product_code
      ORDER BY business_date
    ) AS prev_month_offer_status,

    LAG(business_date) OVER (
      PARTITION BY customer_id, product_code
      ORDER BY business_date
    ) AS prev_month_business_date
  FROM offer_deduped
)

-- Final selection: NEW OFFERS ONLY
SELECT
  business_date,
  customer_id,
  created_at,
  agreement_agreed_at,
  loan_start_date,
  key_date,
  product_code,
  offer_status,
  risk_bracket,
  overdraft_initial_facility_limit,
  installment_initial_facility_limit,
  limit_offer,

  -- Flag for reference (optional, can be used in analysis)
  CASE
    WHEN prev_month_offer_status IS NULL THEN 1  -- No previous offer = NEW
    WHEN prev_month_offer_status = 'ENABLED'
      AND DATE_DIFF(business_date, prev_month_business_date, MONTH) = 1
      THEN 0  -- Continuous offer from last month = CARRY-OVER
    ELSE 1  -- Gap in offers = NEW
  END AS is_new_offer

FROM offer_with_flag
WHERE
  -- ✅ FILTER: Keep NEW OFFERS only
  CASE
    WHEN prev_month_offer_status IS NULL THEN 1
    WHEN prev_month_offer_status = 'ENABLED'
      AND DATE_DIFF(business_date, prev_month_business_date, MONTH) = 1
      THEN 0
    ELSE 1
  END = 1;

-- Expected result: Fewer customers than before (carry-overs excluded)
-- Validate: SELECT FORMAT_DATE('%Y-%m', key_date) AS month, COUNT(DISTINCT customer_id) FROM table GROUP BY 1;
