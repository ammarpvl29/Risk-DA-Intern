-- ============================================================================
-- STEP 2: Validate Unified Propensity Score Table
-- ============================================================================
-- Purpose: Verify data quality and coverage after Step 1
-- Author: Ammar Siregar
-- Date: 2025-11-10
-- ============================================================================

-- ============================================================================
-- Validation 1: Monthly Count Summary
-- ============================================================================
-- Expected Results:
-- 2025-01 to 2025-08: From iter5/iter6
-- 2025-09: new=460,332, carryover=124,976 (validated ✓)
-- 2025-10: new=94,700, carryover=499,363 (validated ✓)
-- 2025-11: From latest run
-- ============================================================================

SELECT
  FORMAT_DATE('%Y-%m', period) AS month,
  source,
  model_iteration,
  COUNT(DISTINCT customer_id) AS customer_count,
  COUNT(DISTINCT CASE WHEN flag_takeup = 1 THEN customer_id END) AS customers_disbursed,
  ROUND(
    COUNT(DISTINCT CASE WHEN flag_takeup = 1 THEN customer_id END) * 100.0 /
    NULLIF(COUNT(DISTINCT customer_id), 0),
    2
  ) AS take_up_rate_pct
FROM `data-prd-adhoc.credit_risk_adhoc.propensity_scores_unified_jan_nov`
GROUP BY 1, 2, 3
ORDER BY 1 DESC, 2, 3;

-- ✅ CHECK: Sept new should be ~460,332
-- ✅ CHECK: Sept carryover should be ~124,976
-- ✅ CHECK: Oct new should be ~94,700
-- ✅ CHECK: Oct carryover should be ~499,363

-- ============================================================================
-- Validation 2: Propensity Score Distribution by Month
-- ============================================================================
-- Expected: Each bin should have ~10% of customers (±3%)
-- Red Flag: Any bin with >20% or <5% indicates scoring issue
-- ============================================================================

SELECT
  FORMAT_DATE('%Y-%m', period) AS month,
  source,
  propensity_score_bin,
  COUNT(DISTINCT customer_id) AS customers,
  ROUND(
    COUNT(DISTINCT customer_id) * 100.0 /
    SUM(COUNT(DISTINCT customer_id)) OVER (PARTITION BY FORMAT_DATE('%Y-%m', period), source),
    2
  ) AS pct_of_month
FROM `data-prd-adhoc.credit_risk_adhoc.propensity_scores_unified_jan_nov`
GROUP BY 1, 2, 3
ORDER BY 1 DESC, 2, 3;

-- ✅ CHECK: Each bin should be 8-12% within each month/source combination
-- ⚠️ WARNING: If bin distribution is skewed, contact Stephanie

-- ============================================================================
-- Validation 3: Take-Up Rate Monotonicity Check
-- ============================================================================
-- CRITICAL: Confirm propensity bins correlate with take-up rate
-- Expected: Bin 0 < Bin 1 < ... < Bin 9 (monotonic increase)
-- ============================================================================

SELECT
  source,
  propensity_score_bin,
  COUNT(DISTINCT customer_id) AS total_customers,
  COUNT(DISTINCT CASE WHEN flag_takeup = 1 THEN customer_id END) AS customers_disbursed,
  ROUND(
    COUNT(DISTINCT CASE WHEN flag_takeup = 1 THEN customer_id END) * 100.0 /
    NULLIF(COUNT(DISTINCT customer_id), 0),
    2
  ) AS take_up_rate_pct
FROM `data-prd-adhoc.credit_risk_adhoc.propensity_scores_unified_jan_nov`
GROUP BY 1, 2
ORDER BY 1, 2;

-- ✅ CHECK: Take-up rate should INCREASE from Bin 0 to Bin 9
-- 🚨 RED FLAG: If Bin 3 > Bin 7, model is NOT working correctly

-- Expected Pattern:
-- new,        0,  ???, ???, 0.15%  ← Lowest
-- new,        1,  ???, ???, 0.50%
-- new,        2,  ???, ???, 0.70%
-- ...
-- new,        8,  ???, ???, 5.00%
-- new,        9,  ???, ???, 10.80% ← Highest

-- ============================================================================
-- Validation 4: Check for Duplicate Primary Keys
-- ============================================================================
-- Expected: 0 duplicates
-- If duplicates exist, use QUALIFY in Step 1 to deduplicate
-- ============================================================================

SELECT
  customer_id,
  period,
  source,
  COUNT(*) AS duplicate_count
FROM `data-prd-adhoc.credit_risk_adhoc.propensity_scores_unified_jan_nov`
GROUP BY customer_id, period, source
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC
LIMIT 100;

-- ✅ CHECK: This query should return 0 rows
-- ⚠️ WARNING: If duplicates exist, add QUALIFY deduplication in Step 1

-- ============================================================================
-- Validation 5: Data Completeness - Period Coverage
-- ============================================================================
-- Expected: All months from 2025-01 to 2025-11
-- ============================================================================

WITH expected_months AS (
  SELECT month FROM UNNEST([
    '2025-01', '2025-02', '2025-03', '2025-04', '2025-05', '2025-06',
    '2025-07', '2025-08', '2025-09', '2025-10', '2025-11'
  ]) AS month
),

actual_months AS (
  SELECT DISTINCT FORMAT_DATE('%Y-%m', period) AS month
  FROM `data-prd-adhoc.credit_risk_adhoc.propensity_scores_unified_jan_nov`
)

SELECT
  e.month,
  CASE WHEN a.month IS NOT NULL THEN '✅ Present' ELSE '❌ Missing' END AS status
FROM expected_months e
LEFT JOIN actual_months a ON e.month = a.month
ORDER BY e.month;

-- ✅ CHECK: All 11 months should show "✅ Present"
-- ⚠️ WARNING: If any month shows "❌ Missing", check source tables

-- ============================================================================
-- Validation 6: Model Iteration Coverage
-- ============================================================================
-- Verify which model iteration is used for each month
-- ============================================================================

SELECT
  FORMAT_DATE('%Y-%m', period) AS month,
  source,
  model_iteration,
  COUNT(DISTINCT customer_id) AS customers
FROM `data-prd-adhoc.credit_risk_adhoc.propensity_scores_unified_jan_nov`
GROUP BY 1, 2, 3
ORDER BY 1 DESC, 2, 3;

-- Expected:
-- 2025-01 to 2025-08: iter5 (new), iter6 (carry over)
-- 2025-09: iter7_sept (new), iter8_sept (carry over)
-- 2025-10: iter7_oct (new), iter8_oct (carry over)
-- 2025-11: iter7_nov (new), iter8_nov (carry over)

-- ============================================================================
-- Validation 7: Score Range Check
-- ============================================================================
-- Verify raw propensity scores are within valid range [0, 1]
-- ============================================================================

SELECT
  FORMAT_DATE('%Y-%m', period) AS month,
  source,
  MIN(propensity_score) AS min_score,
  ROUND(APPROX_QUANTILES(propensity_score, 100)[OFFSET(25)], 4) AS p25_score,
  ROUND(APPROX_QUANTILES(propensity_score, 100)[OFFSET(50)], 4) AS median_score,
  ROUND(APPROX_QUANTILES(propensity_score, 100)[OFFSET(75)], 4) AS p75_score,
  MAX(propensity_score) AS max_score
FROM `data-prd-adhoc.credit_risk_adhoc.propensity_scores_unified_jan_nov`
GROUP BY 1, 2
ORDER BY 1 DESC, 2;

-- ✅ CHECK: min_score should be >= 0.0
-- ✅ CHECK: max_score should be <= 1.0
-- ⚠️ WARNING: If scores outside [0, 1], check source data

-- ============================================================================
-- SUMMARY VALIDATION CHECKLIST
-- ============================================================================
-- [ ] Validation 1: Sept counts match (460,332 new + 124,976 carryover)
-- [ ] Validation 1: Oct counts match (94,700 new + 499,363 carryover)
-- [ ] Validation 2: Score distribution ~10% per bin (±3%)
-- [ ] Validation 3: Take-up rate increases monotonically (Bin 0 < Bin 9)
-- [ ] Validation 4: No duplicate primary keys
-- [ ] Validation 5: All 11 months present (Jan-Nov 2025)
-- [ ] Validation 6: Correct model iterations per period
-- [ ] Validation 7: Scores within [0, 1] range
-- ============================================================================

-- If all validations pass ✅, proceed to Step 3: Update TUPR Query 2.5
-- If any validation fails ❌, investigate and fix before proceeding
