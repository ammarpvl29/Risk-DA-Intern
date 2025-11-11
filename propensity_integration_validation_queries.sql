-- ============================================================================
-- PROPENSITY SCORE INTEGRATION VALIDATION QUERIES
-- Purpose: Validate propensity score tables and integration with TUPR dashboard
-- Date: November 7, 2025
-- ============================================================================
--
-- Tables to validate:
-- 1. iter5_propensity_scores_combined (dev + oot)
-- 2. iter6_propensity_scores_combined (dev + oot)
-- 3. propensity_scores_all_iterations (master table)
--
-- TUPR Pipeline Reference:
-- Query 1 → base_loan_offer_snapshot (NEW/CARRY-OVER classification)
-- Query 2 → base_loan_offer_with_demo (demographics)
-- Query 2.5 → base_loan_offer_with_campaign (campaign segmentation with COALESCE)
-- Query 3 → tupr_dashboard_final_dataset (dimensional aggregation)
-- Query 4 → tupr_dashboard_monthly_summary (monthly summary KPI)
--
-- ============================================================================

-- ============================================================================
-- VALIDATION 1: Table Structure and Row Counts
-- Verify all 3 tables exist and have expected structure
-- ============================================================================
SELECT
  '1. Iter5 Table Check' as validation,
  COUNT(*) as total_rows,
  COUNT(DISTINCT customer_id) as unique_customers,
  COUNT(DISTINCT appid) as unique_appids,
  COUNT(DISTINCT business_date) as unique_dates,
  COUNT(DISTINCT scores_bin) as unique_bins,
  MIN(business_date) as min_date,
  MAX(business_date) as max_date
FROM `data-prd-adhoc.credit_risk_adhoc.iter5_propensity_scores_combined`

UNION ALL

SELECT
  '1. Iter6 Table Check' as validation,
  COUNT(*) as total_rows,
  COUNT(DISTINCT customer_id) as unique_customers,
  COUNT(DISTINCT appid) as unique_appids,
  COUNT(DISTINCT business_date) as unique_dates,
  COUNT(DISTINCT scores_bin) as unique_bins,
  MIN(business_date) as min_date,
  MAX(business_date) as max_date
FROM `data-prd-adhoc.credit_risk_adhoc.iter6_propensity_scores_combined`

UNION ALL

SELECT
  '1. All Iterations Table Check' as validation,
  COUNT(*) as total_rows,
  COUNT(DISTINCT customer_id) as unique_customers,
  COUNT(DISTINCT appid) as unique_appids,
  COUNT(DISTINCT business_date) as unique_dates,
  COUNT(DISTINCT scores_bin) as unique_bins,
  MIN(business_date) as min_date,
  MAX(business_date) as max_date
FROM `data-prd-adhoc.credit_risk_adhoc.propensity_scores_all_iterations`;

-- Expected:
-- - iter5 + iter6 row count should roughly equal all_iterations (if UNION ALL)
-- - unique_bins should = 10 (0-9)
-- - Date ranges should be March-October 2025

-- ============================================================================
-- VALIDATION 2: Score Distribution (Decile Check)
-- Verify propensity scores are properly distributed across bins
-- ============================================================================
SELECT
  '2. Iter5 Score Distribution' as validation,
  scores_bin,
  COUNT(*) as customers,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as pct,
  MIN(business_date) as first_date,
  MAX(business_date) as last_date
FROM `data-prd-adhoc.credit_risk_adhoc.iter5_propensity_scores_combined`
GROUP BY scores_bin
ORDER BY scores_bin;

-- Expected: Each bin should have ~10% of customers (since it's decile-based)
-- Bins 8-9 (high propensity) might have slightly fewer customers

SELECT
  '2. Iter6 Score Distribution' as validation,
  scores_bin,
  COUNT(*) as customers,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as pct,
  MIN(business_date) as first_date,
  MAX(business_date) as last_date
FROM `data-prd-adhoc.credit_risk_adhoc.iter6_propensity_scores_combined`
GROUP BY scores_bin
ORDER BY scores_bin;

-- ============================================================================
-- VALIDATION 3: Primary Key Uniqueness
-- Verify no duplicates in primary keys
-- ============================================================================
SELECT
  '3. Iter5 Primary Key Check' as validation,
  COUNT(*) as total_rows,
  COUNT(DISTINCT CONCAT(customer_id, '|', appid, '|', business_date)) as unique_keys,
  COUNT(*) - COUNT(DISTINCT CONCAT(customer_id, '|', appid, '|', business_date)) as duplicates
FROM `data-prd-adhoc.credit_risk_adhoc.iter5_propensity_scores_combined`

UNION ALL

SELECT
  '3. Iter6 Primary Key Check' as validation,
  COUNT(*) as total_rows,
  COUNT(DISTINCT CONCAT(customer_id, '|', appid, '|', business_date)) as unique_keys,
  COUNT(*) - COUNT(DISTINCT CONCAT(customer_id, '|', appid, '|', business_date)) as duplicates
FROM `data-prd-adhoc.credit_risk_adhoc.iter6_propensity_scores_combined`;

-- Expected: duplicates = 0 for both tables

-- ============================================================================
-- VALIDATION 4: Join Test with TUPR Base (Query 2.5 Output)
-- Test joining propensity scores with base_loan_offer_with_campaign
-- ============================================================================
WITH tupr_base AS (
  SELECT
    business_date,
    customer_id,
    source,
    campaign_segment,
    campaign_category,
    product_code,
    risk_bracket,
    limit_offer
  FROM `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign`
  WHERE business_date >= '2025-03-01' -- Propensity model training period
    AND business_date <= '2025-10-31'
)
SELECT
  '4. Join Test: TUPR Base + Iter5 Propensity' as validation,
  FORMAT_DATE('%Y-%m', t.business_date) as offer_month,
  COUNT(DISTINCT t.customer_id) as tupr_customers,
  COUNT(DISTINCT CASE WHEN p.customer_id IS NOT NULL THEN t.customer_id END) as customers_with_propensity,
  COUNT(DISTINCT CASE WHEN p.customer_id IS NULL THEN t.customer_id END) as customers_without_propensity,
  ROUND(
    COUNT(DISTINCT CASE WHEN p.customer_id IS NOT NULL THEN t.customer_id END) * 100.0 /
    NULLIF(COUNT(DISTINCT t.customer_id), 0),
    2
  ) as match_rate_pct
FROM tupr_base t
LEFT JOIN `data-prd-adhoc.credit_risk_adhoc.iter5_propensity_scores_combined` p
  ON t.customer_id = p.customer_id
  AND FORMAT_DATE('%Y-%m-%d', t.business_date) = p.business_date
GROUP BY offer_month
ORDER BY offer_month;

-- Expected: Match rate will vary by month
-- - High match rate (70-90%) for March-August 2025 (training period)
-- - Lower match rate for September-October 2025 (OOT period)

-- ============================================================================
-- VALIDATION 5: Score Distribution by Campaign Segment
-- Analyze propensity scores across different campaign segments
-- ============================================================================
WITH tupr_with_propensity AS (
  SELECT
    t.business_date,
    t.customer_id,
    t.source,
    t.campaign_segment,
    t.product_code,
    p.scores_bin as propensity_bin
  FROM `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign` t
  LEFT JOIN `data-prd-adhoc.credit_risk_adhoc.iter5_propensity_scores_combined` p
    ON t.customer_id = p.customer_id
    AND FORMAT_DATE('%Y-%m-%d', t.business_date) = p.business_date
  WHERE t.business_date >= '2025-03-01'
    AND t.business_date <= '2025-10-31'
)
SELECT
  '5. Propensity Distribution by Campaign Segment' as validation,
  campaign_segment,
  propensity_bin,
  COUNT(DISTINCT customer_id) as customers,
  ROUND(COUNT(DISTINCT customer_id) * 100.0 / SUM(COUNT(DISTINCT customer_id)) OVER(PARTITION BY campaign_segment), 2) as pct_within_segment
FROM tupr_with_propensity
WHERE propensity_bin IS NOT NULL
GROUP BY campaign_segment, propensity_bin
ORDER BY campaign_segment, propensity_bin;

-- Expected:
-- - BAU segment should have majority of propensity scores
-- - CT segment might have different distribution (higher propensity)
-- - Open Market might show different patterns

-- ============================================================================
-- VALIDATION 6: Propensity vs TUPR Correlation
-- Check if higher propensity scores correlate with higher take-up rates
-- ============================================================================
WITH tupr_base AS (
  SELECT
    t.business_date,
    t.customer_id,
    t.source,
    t.campaign_segment,
    t.key_date,
    t.limit_offer,
    p.scores_bin as propensity_bin
  FROM `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign` t
  LEFT JOIN `data-prd-adhoc.credit_risk_adhoc.iter5_propensity_scores_combined` p
    ON t.customer_id = p.customer_id
    AND FORMAT_DATE('%Y-%m-%d', t.business_date) = p.business_date
  WHERE t.business_date >= '2025-03-01'
    AND t.business_date < DATE_TRUNC(CURRENT_DATE(), MONTH)
    AND p.scores_bin IS NOT NULL
),
crvadl AS (
  SELECT DISTINCT
    lfs_customer_id AS customer_id,
    facility_start_date
  FROM `jago-bank-data-production.data_mart.credit_risk_vintage_account_direct_lending`
  WHERE business_date >= '2025-03-01'
    AND deal_type IN ('JAG06', 'JAG08', 'JAG09')
    AND facility_start_date >= '2025-03-01'
    AND mob = 0
),
tupr_with_disburse AS (
  SELECT
    t.*,
    CASE WHEN d.facility_start_date IS NOT NULL THEN 1 ELSE 0 END AS flag_disburse
  FROM tupr_base t
  LEFT JOIN crvadl d
    ON t.customer_id = d.customer_id
    AND d.facility_start_date > t.key_date
    AND FORMAT_DATE('%Y-%m', d.facility_start_date) = FORMAT_DATE('%Y-%m', t.key_date)
)
SELECT
  '6. Propensity vs TUPR Correlation' as validation,
  propensity_bin,
  COUNT(DISTINCT customer_id) as total_customers,
  COUNT(DISTINCT CASE WHEN flag_disburse = 1 THEN customer_id END) as customers_disbursed,
  ROUND(
    COUNT(DISTINCT CASE WHEN flag_disburse = 1 THEN customer_id END) * 100.0 /
    NULLIF(COUNT(DISTINCT customer_id), 0),
    2
  ) as tupr_pct
FROM tupr_with_disburse
GROUP BY propensity_bin
ORDER BY propensity_bin;

-- Expected: TUPR% should INCREASE as propensity_bin increases
-- Bin 9 (highest propensity) should have highest TUPR%
-- This validates the model is working correctly

-- ============================================================================
-- VALIDATION 7: Coverage by Source (New vs Carry-Over)
-- Check propensity score coverage for new vs carry-over offers
-- ============================================================================
WITH tupr_with_propensity AS (
  SELECT
    t.business_date,
    t.customer_id,
    t.source,
    t.campaign_segment,
    p.scores_bin as propensity_bin
  FROM `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign` t
  LEFT JOIN `data-prd-adhoc.credit_risk_adhoc.iter5_propensity_scores_combined` p
    ON t.customer_id = p.customer_id
    AND FORMAT_DATE('%Y-%m-%d', t.business_date) = p.business_date
  WHERE t.business_date >= '2025-03-01'
    AND t.business_date <= '2025-10-31'
)
SELECT
  '7. Propensity Coverage by Source' as validation,
  FORMAT_DATE('%Y-%m', business_date) as offer_month,
  source,
  COUNT(DISTINCT customer_id) as total_customers,
  COUNT(DISTINCT CASE WHEN propensity_bin IS NOT NULL THEN customer_id END) as customers_with_score,
  COUNT(DISTINCT CASE WHEN propensity_bin IS NULL THEN customer_id END) as customers_without_score,
  ROUND(
    COUNT(DISTINCT CASE WHEN propensity_bin IS NOT NULL THEN customer_id END) * 100.0 /
    NULLIF(COUNT(DISTINCT customer_id), 0),
    2
  ) as coverage_pct
FROM tupr_with_propensity
GROUP BY offer_month, source
ORDER BY offer_month, source;

-- Expected:
-- - "new" offers might have lower coverage (newly offered customers)
-- - "carry over" offers might have higher coverage (customers seen in previous months)

-- ============================================================================
-- VALIDATION 8: Monthly Trend Analysis
-- Track propensity score distribution over time
-- ============================================================================
SELECT
  '8. Monthly Propensity Trend (Iter5)' as validation,
  FORMAT_DATE('%Y-%m', PARSE_DATE('%Y-%m-%d', business_date)) as score_month,
  scores_bin,
  COUNT(*) as customers,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY FORMAT_DATE('%Y-%m', PARSE_DATE('%Y-%m-%d', business_date))), 2) as pct_within_month
FROM `data-prd-adhoc.credit_risk_adhoc.iter5_propensity_scores_combined`
GROUP BY score_month, scores_bin
ORDER BY score_month, scores_bin;

-- Expected: Distribution should be relatively stable across months (each bin ~10%)
-- If distribution shifts significantly, may indicate model drift or data quality issues

-- ============================================================================
-- VALIDATION 9: Product Code Distribution with Propensity
-- Analyze propensity scores by product type
-- ============================================================================
WITH tupr_with_propensity AS (
  SELECT
    t.business_date,
    t.customer_id,
    t.product_code,
    t.campaign_segment,
    p.scores_bin as propensity_bin
  FROM `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign` t
  LEFT JOIN `data-prd-adhoc.credit_risk_adhoc.iter5_propensity_scores_combined` p
    ON t.customer_id = p.customer_id
    AND FORMAT_DATE('%Y-%m-%d', t.business_date) = p.business_date
  WHERE t.business_date >= '2025-03-01'
    AND t.business_date <= '2025-10-31'
)
SELECT
  '9. Propensity Distribution by Product Code' as validation,
  product_code,
  propensity_bin,
  COUNT(DISTINCT customer_id) as customers,
  ROUND(COUNT(DISTINCT customer_id) * 100.0 / SUM(COUNT(DISTINCT customer_id)) OVER(PARTITION BY product_code), 2) as pct_within_product
FROM tupr_with_propensity
WHERE propensity_bin IS NOT NULL
GROUP BY product_code, propensity_bin
ORDER BY product_code, propensity_bin;

-- Expected:
-- - JAG08 (Installment) might have different propensity distribution than JAG06 (Overdraft)
-- - JAG09 (Open Market) might show distinct patterns

-- ============================================================================
-- VALIDATION 10: NULL Analysis - Why No Propensity Score?
-- Investigate customers without propensity scores
-- ============================================================================
WITH tupr_without_propensity AS (
  SELECT
    t.business_date,
    t.customer_id,
    t.source,
    t.campaign_segment,
    t.product_code,
    t.risk_bracket
  FROM `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign` t
  LEFT JOIN `data-prd-adhoc.credit_risk_adhoc.iter5_propensity_scores_combined` p
    ON t.customer_id = p.customer_id
    AND FORMAT_DATE('%Y-%m-%d', t.business_date) = p.business_date
  WHERE t.business_date >= '2025-03-01'
    AND t.business_date <= '2025-10-31'
    AND p.customer_id IS NULL
)
SELECT
  '10. Customers Without Propensity Score' as validation,
  FORMAT_DATE('%Y-%m', business_date) as offer_month,
  campaign_segment,
  source,
  COUNT(DISTINCT customer_id) as customers_without_score,
  ROUND(COUNT(DISTINCT customer_id) * 100.0 / SUM(COUNT(DISTINCT customer_id)) OVER(), 2) as pct
FROM tupr_without_propensity
GROUP BY offer_month, campaign_segment, source
ORDER BY offer_month, campaign_segment, source;

-- Expected:
-- - Customers outside training period (before March or after August 2025 dev period)
-- - Newly offered customers in current month (if model not yet run)
-- - Open Market segment might have more NULLs (not in training data)

-- ============================================================================
-- VALIDATION 11: Iter5 vs Iter6 Comparison
-- Compare score distributions between iterations
-- ============================================================================
WITH combined_scores AS (
  SELECT
    'Iter5' as iteration,
    customer_id,
    business_date,
    scores_bin
  FROM `data-prd-adhoc.credit_risk_adhoc.iter5_propensity_scores_combined`

  UNION ALL

  SELECT
    'Iter6' as iteration,
    customer_id,
    business_date,
    scores_bin
  FROM `data-prd-adhoc.credit_risk_adhoc.iter6_propensity_scores_combined`
)
SELECT
  '11. Iter5 vs Iter6 Score Distribution' as validation,
  iteration,
  scores_bin,
  COUNT(*) as customers,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(PARTITION BY iteration), 2) as pct_within_iteration
FROM combined_scores
GROUP BY iteration, scores_bin
ORDER BY iteration, scores_bin;

-- Expected: Distributions should be similar but not identical
-- Iter6 might have refinements that shift some customers between bins

-- ============================================================================
-- VALIDATION 12: Check for Score Bin Migration (Iter5 → Iter6)
-- Analyze how many customers changed bins between iterations
-- ============================================================================
WITH iter5_scores AS (
  SELECT
    customer_id,
    business_date,
    scores_bin as iter5_bin
  FROM `data-prd-adhoc.credit_risk_adhoc.iter5_propensity_scores_combined`
),
iter6_scores AS (
  SELECT
    customer_id,
    business_date,
    scores_bin as iter6_bin
  FROM `data-prd-adhoc.credit_risk_adhoc.iter6_propensity_scores_combined`
)
SELECT
  '12. Score Bin Migration (Iter5 → Iter6)' as validation,
  i5.iter5_bin,
  i6.iter6_bin,
  COUNT(*) as customers,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as pct
FROM iter5_scores i5
INNER JOIN iter6_scores i6
  ON i5.customer_id = i6.customer_id
  AND i5.business_date = i6.business_date
GROUP BY i5.iter5_bin, i6.iter6_bin
ORDER BY i5.iter5_bin, i6.iter6_bin;

-- Expected:
-- - Diagonal (same bin) should have highest counts (stable scores)
-- - Off-diagonal shows migrations (score changes)
-- - Large migrations might indicate model instability

-- ============================================================================
-- VALIDATION 13: Integration Test with TUPR Dashboard Final Dataset
-- Test joining with Query 3 output (tupr_dashboard_final_dataset)
-- ============================================================================
WITH tupr_agg AS (
  SELECT
    offer_month,
    source,
    campaign_segment,
    product_code,
    risk_bracket,
    total_customers,
    customers_disbursed,
    take_up_rate_pct_by_customer
  FROM `data-prd-adhoc.credit_risk_adhoc.tupr_dashboard_final_dataset`
  WHERE offer_month >= '2025-03'
    AND offer_month <= '2025-10'
),
tupr_detail AS (
  SELECT
    FORMAT_DATE('%Y-%m', t.business_date) as offer_month,
    t.source,
    t.campaign_segment,
    t.product_code,
    t.risk_bracket,
    t.customer_id,
    p.scores_bin as propensity_bin
  FROM `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign` t
  LEFT JOIN `data-prd-adhoc.credit_risk_adhoc.iter5_propensity_scores_combined` p
    ON t.customer_id = p.customer_id
    AND FORMAT_DATE('%Y-%m-%d', t.business_date) = p.business_date
  WHERE t.business_date >= '2025-03-01'
    AND t.business_date < DATE_TRUNC(CURRENT_DATE(), MONTH)
)
SELECT
  '13. TUPR Dashboard + Propensity Integration Test' as validation,
  a.offer_month,
  a.campaign_segment,
  a.total_customers as tupr_total,
  COUNT(DISTINCT d.customer_id) as detail_total,
  COUNT(DISTINCT CASE WHEN d.propensity_bin IS NOT NULL THEN d.customer_id END) as with_propensity,
  ROUND(
    COUNT(DISTINCT CASE WHEN d.propensity_bin IS NOT NULL THEN d.customer_id END) * 100.0 /
    NULLIF(COUNT(DISTINCT d.customer_id), 0),
    2
  ) as propensity_coverage_pct
FROM tupr_agg a
LEFT JOIN tupr_detail d
  ON a.offer_month = d.offer_month
  AND a.source = d.source
  AND a.campaign_segment = d.campaign_segment
  AND a.product_code = d.product_code
  AND a.risk_bracket = d.risk_bracket
GROUP BY a.offer_month, a.campaign_segment, a.total_customers
ORDER BY a.offer_month, a.campaign_segment;

-- Expected: tupr_total should match detail_total (row conservation check)
-- propensity_coverage_pct shows what % of each segment has scores

-- ============================================================================
-- VALIDATION 14: High Propensity vs Low Propensity TUPR Comparison
-- Business validation: Do high propensity customers actually convert more?
-- ============================================================================
WITH tupr_base AS (
  SELECT
    t.business_date,
    t.customer_id,
    t.source,
    t.campaign_segment,
    t.key_date,
    t.limit_offer,
    p.scores_bin as propensity_bin,
    CASE
      WHEN p.scores_bin IN (0, 1, 2) THEN 'Low Propensity (0-2)'
      WHEN p.scores_bin IN (3, 4, 5, 6) THEN 'Medium Propensity (3-6)'
      WHEN p.scores_bin IN (7, 8, 9) THEN 'High Propensity (7-9)'
      ELSE 'No Score'
    END AS propensity_tier
  FROM `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign` t
  LEFT JOIN `data-prd-adhoc.credit_risk_adhoc.iter5_propensity_scores_combined` p
    ON t.customer_id = p.customer_id
    AND FORMAT_DATE('%Y-%m-%d', t.business_date) = p.business_date
  WHERE t.business_date >= '2025-03-01'
    AND t.business_date < DATE_TRUNC(CURRENT_DATE(), MONTH)
),
crvadl AS (
  SELECT DISTINCT
    lfs_customer_id AS customer_id,
    facility_start_date
  FROM `jago-bank-data-production.data_mart.credit_risk_vintage_account_direct_lending`
  WHERE business_date >= '2025-03-01'
    AND deal_type IN ('JAG06', 'JAG08', 'JAG09')
    AND facility_start_date >= '2025-03-01'
    AND mob = 0
),
tupr_with_disburse AS (
  SELECT
    t.*,
    CASE WHEN d.facility_start_date IS NOT NULL THEN 1 ELSE 0 END AS flag_disburse
  FROM tupr_base t
  LEFT JOIN crvadl d
    ON t.customer_id = d.customer_id
    AND d.facility_start_date > t.key_date
    AND FORMAT_DATE('%Y-%m', d.facility_start_date) = FORMAT_DATE('%Y-%m', t.key_date)
)
SELECT
  '14. Propensity Tier vs TUPR' as validation,
  propensity_tier,
  campaign_segment,
  COUNT(DISTINCT customer_id) as total_customers,
  COUNT(DISTINCT CASE WHEN flag_disburse = 1 THEN customer_id END) as customers_disbursed,
  ROUND(
    COUNT(DISTINCT CASE WHEN flag_disburse = 1 THEN customer_id END) * 100.0 /
    NULLIF(COUNT(DISTINCT customer_id), 0),
    2
  ) as tupr_pct
FROM tupr_with_disburse
GROUP BY propensity_tier, campaign_segment
ORDER BY
  CASE
    WHEN propensity_tier = 'High Propensity (7-9)' THEN 1
    WHEN propensity_tier = 'Medium Propensity (3-6)' THEN 2
    WHEN propensity_tier = 'Low Propensity (0-2)' THEN 3
    ELSE 4
  END,
  campaign_segment;

-- Expected: TUPR% should be:
-- High Propensity > Medium Propensity > Low Propensity
-- This validates the model's business value

-- ============================================================================
-- VALIDATION 15: Date Format Consistency Check
-- Ensure date formats are compatible for joins
-- ============================================================================
SELECT
  '15. Date Format Check - Propensity Table' as validation,
  business_date as sample_date,
  LENGTH(business_date) as date_length,
  CASE
    WHEN REGEXP_CONTAINS(business_date, r'^\d{4}-\d{2}-\d{2}$') THEN 'Valid Format (YYYY-MM-DD)'
    ELSE 'Invalid Format'
  END AS date_format_status,
  COUNT(*) as row_count
FROM `data-prd-adhoc.credit_risk_adhoc.iter5_propensity_scores_combined`
GROUP BY business_date
ORDER BY business_date DESC
LIMIT 20;

-- Expected: All dates should be 10 characters (YYYY-MM-DD) and match regex
-- This ensures FORMAT_DATE('%Y-%m-%d', TUPR.business_date) will match correctly

-- ============================================================================
-- END OF VALIDATION QUERIES
-- ============================================================================
--
-- Summary Checklist:
-- ✓ V1: Table structure and row counts
-- ✓ V2: Score distribution (decile check)
-- ✓ V3: Primary key uniqueness
-- ✓ V4: Join test with TUPR base (Query 2.5)
-- ✓ V5: Score distribution by campaign segment
-- ✓ V6: Propensity vs TUPR correlation
-- ✓ V7: Coverage by source (new vs carry-over)
-- ✓ V8: Monthly trend analysis
-- ✓ V9: Product code distribution
-- ✓ V10: NULL analysis (missing scores)
-- ✓ V11: Iter5 vs Iter6 comparison
-- ✓ V12: Score bin migration between iterations
-- ✓ V13: Integration test with TUPR dashboard final dataset
-- ✓ V14: High vs low propensity TUPR comparison (business validation)
-- ✓ V15: Date format consistency check
--
-- Run these queries in order. If any validation fails, investigate before
-- proceeding to dashboard integration.
--
