-- ============================================================================
-- VALIDATION QUERIES FOR NOV 6, 2025 UPDATES
-- Run these AFTER executing updated Query 2.5, Query 3, and Query 4
-- ============================================================================

-- ============================================================================
-- VALIDATION 1: Check KPI Discrepancy
-- Expected: Should match the pivot totals (4,715 for Oct 2025)
-- ============================================================================
SELECT
  '1. Monthly Summary Table Check' as validation,
  offer_month,
  source,
  campaign_segment,
  total_customers,
  customers_disbursed,
  total_limit
FROM `data-prd-adhoc.credit_risk_adhoc.tupr_dashboard_monthly_summary`
WHERE offer_month = '2025-10'
ORDER BY source, campaign_segment;

-- Expected: Should have ~8 rows (2 sources × 4-5 campaign segments)
-- Sum of customers_disbursed should = 4,715 (not 34,630!)

-- ============================================================================
-- VALIDATION 2: Check COALESCE Effectiveness
-- How many "Unknown" were filled by looking back at previous months?
-- ============================================================================
SELECT
  'Before COALESCE' as version,
  campaign_segment,
  COUNT(DISTINCT customer_id) as customers
FROM `data-prd-adhoc.temp_ammar.base_loan_offer_with_campaign_OLD`  -- Old version
WHERE business_date = '2025-10-31'
GROUP BY campaign_segment

UNION ALL

SELECT
  'After COALESCE' as version,
  campaign_segment,
  COUNT(DISTINCT customer_id) as customers
FROM `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign`  -- New version
WHERE business_date = '2025-10-31'
GROUP BY campaign_segment
ORDER BY 1, 2;

-- Expected: "Unknown" count should DECREASE after COALESCE
-- New categories "Open Market" and "Employee and Partner Payroll" should appear

-- ============================================================================
-- VALIDATION 3: Check Unknown Split (JAG09 vs Others)
-- ============================================================================
SELECT
  'After Unknown Split' as validation,
  campaign_segment,
  product_code,
  COUNT(DISTINCT customer_id) as customers,
  ROUND(COUNT(DISTINCT customer_id) * 100.0 / SUM(COUNT(DISTINCT customer_id)) OVER(), 2) as pct
FROM `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign`
WHERE business_date = '2025-10-31'
  AND campaign_segment IN ('Open Market', 'Employee and Partner Payroll', 'Unknown')
GROUP BY campaign_segment, product_code
ORDER BY campaign_segment, product_code;

-- Expected:
-- "Open Market" should have ONLY JAG09
-- "Employee and Partner Payroll" should have JAG06, JAG08 (NOT JAG09)
-- "Unknown" should be minimal or zero

-- ============================================================================
-- VALIDATION 4: Check Campaign Segment Distribution (Full Breakdown)
-- ============================================================================
SELECT
  'Campaign Segment Distribution (Oct 2025)' as validation,
  campaign_segment,
  COUNT(DISTINCT customer_id) as customers,
  ROUND(COUNT(DISTINCT customer_id) * 100.0 / SUM(COUNT(DISTINCT customer_id)) OVER(), 2) as pct,
  COUNT(DISTINCT CASE WHEN source = 'new' THEN customer_id END) as new_customers,
  COUNT(DISTINCT CASE WHEN source = 'carry over' THEN customer_id END) as carry_over_customers
FROM `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign`
WHERE business_date = '2025-10-31'
GROUP BY campaign_segment
ORDER BY customers DESC;

-- Expected Order (after sorting):
-- 1. BAU (largest, 70-80%)
-- 2. CT (10-20%)
-- 3. Weekly (<1%)
-- 4. Open Market (new category from JAG09 Unknown)
-- 5. Employee and Partner Payroll (new category from other Unknown)
-- 6. Unknown (should be minimal after COALESCE)

-- ============================================================================
-- VALIDATION 5: Check NULL CT Values
-- Investigate why CT category might be NULL
-- ============================================================================
SELECT
  'NULL CT Investigation' as validation,
  campaign_segment,
  campaign_category,
  COUNT(DISTINCT customer_id) as customers
FROM `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign`
WHERE business_date = '2025-10-31'
  AND campaign_segment = 'CT'
GROUP BY campaign_segment, campaign_category
ORDER BY customers DESC;

-- Expected:
-- Most CT should have a category (Test 1, Test 2, etc.)
-- If many have NULL or 'Unknown', check the dl_whitelist_credit_test table

-- ============================================================================
-- VALIDATION 6: Row Count Conservation Check
-- Ensure no data loss across the pipeline
-- ============================================================================
SELECT
  'Row Count Check' as validation,
  'Query 2 Output' as stage,
  COUNT(*) as total_rows,
  COUNT(DISTINCT customer_id) as unique_customers
FROM `data-prd-adhoc.temp_ammar.base_loan_offer_with_demo`
WHERE business_date = '2025-10-31'

UNION ALL

SELECT
  'Row Count Check' as validation,
  'Query 2.5 Output' as stage,
  COUNT(*) as total_rows,
  COUNT(DISTINCT customer_id) as unique_customers
FROM `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign`
WHERE business_date = '2025-10-31'

UNION ALL

SELECT
  'Row Count Check' as validation,
  'Query 4 Output (Sum)' as stage,
  SUM(total_customers) as total_rows,
  SUM(total_customers) as unique_customers
FROM `data-prd-adhoc.credit_risk_adhoc.tupr_dashboard_monthly_summary`
WHERE offer_month = '2025-10';

-- Expected: All three should show ~553,528 customers (same count)

-- ============================================================================
-- VALIDATION 7: Check Disbursement Matching
-- Verify the 4,715 disbursed number is consistent
-- ============================================================================
SELECT
  'Disbursement Consistency Check' as validation,
  offer_month,
  SUM(total_customers) as total_customers,
  SUM(customers_disbursed) as total_disbursed,
  ROUND(SUM(customers_disbursed) * 100.0 / SUM(total_customers), 2) as tupr_pct
FROM `data-prd-adhoc.credit_risk_adhoc.tupr_dashboard_monthly_summary`
WHERE offer_month = '2025-10'
GROUP BY offer_month;

-- Expected: total_disbursed = 4,715 (NOT 34,630)

-- ============================================================================
-- VALIDATION 8: Test COALESCE Lookback Logic
-- See which month provided the data for each customer
-- ============================================================================
WITH offers AS (
  SELECT
    x.customer_id,
    x.business_date,
    x.product_code,
    e0.is_ct as current_month,
    e1.is_ct as prev_month,
    e2.is_ct as next_month,
    e3.is_ct as two_months_back,
    COALESCE(e0.is_ct, e1.is_ct, e2.is_ct, e3.is_ct) as final_segment
  FROM `data-prd-adhoc.temp_ammar.base_loan_offer_with_demo` x
  LEFT JOIN (
    SELECT customer_id, business_date, 'BAU' AS is_ct FROM `data-prd-adhoc.dl_whitelist_checkers.dl_wl_final_whitelist_raw_history`
    WHERE business_date >= '2025-01-01' AND waterfall_failure_step = '99. Passed Underwriting Waterfall'
  ) e0 ON x.customer_id = e0.customer_id AND LAST_DAY(x.business_date) = LAST_DAY(DATE(e0.business_date))
  LEFT JOIN (
    SELECT customer_id, business_date, 'BAU' AS is_ct FROM `data-prd-adhoc.dl_whitelist_checkers.dl_wl_final_whitelist_raw_history`
    WHERE business_date >= '2025-01-01' AND waterfall_failure_step = '99. Passed Underwriting Waterfall'
  ) e1 ON x.customer_id = e1.customer_id AND LAST_DAY(DATE_SUB(x.business_date, INTERVAL 1 MONTH)) = LAST_DAY(DATE(e1.business_date))
  LEFT JOIN (
    SELECT customer_id, business_date, 'BAU' AS is_ct FROM `data-prd-adhoc.dl_whitelist_checkers.dl_wl_final_whitelist_raw_history`
    WHERE business_date >= '2025-01-01' AND waterfall_failure_step = '99. Passed Underwriting Waterfall'
  ) e2 ON x.customer_id = e2.customer_id AND LAST_DAY(DATE_ADD(x.business_date, INTERVAL 1 MONTH)) = LAST_DAY(DATE(e2.business_date))
  LEFT JOIN (
    SELECT customer_id, business_date, 'BAU' AS is_ct FROM `data-prd-adhoc.dl_whitelist_checkers.dl_wl_final_whitelist_raw_history`
    WHERE business_date >= '2025-01-01' AND waterfall_failure_step = '99. Passed Underwriting Waterfall'
  ) e3 ON x.customer_id = e3.customer_id AND LAST_DAY(DATE_SUB(x.business_date, INTERVAL 2 MONTH)) = LAST_DAY(DATE(e3.business_date))
  WHERE x.business_date = '2025-10-31'
)
SELECT
  'COALESCE Source Analysis' as validation,
  CASE
    WHEN current_month IS NOT NULL THEN 'Found in Current Month'
    WHEN prev_month IS NOT NULL THEN 'Found in Previous Month (-1)'
    WHEN next_month IS NOT NULL THEN 'Found in Next Month (+1)'
    WHEN two_months_back IS NOT NULL THEN 'Found in 2 Months Back (-2)'
    ELSE 'Not Found (remains NULL)'
  END AS data_source,
  COUNT(DISTINCT customer_id) as customers,
  ROUND(COUNT(DISTINCT customer_id) * 100.0 / SUM(COUNT(DISTINCT customer_id)) OVER(), 2) as pct
FROM offers
GROUP BY data_source
ORDER BY customers DESC;

-- Expected:
-- Most should be "Found in Current Month"
-- Some should be filled by "-1" or "-2" lookback
-- Fewer should remain "Not Found"
