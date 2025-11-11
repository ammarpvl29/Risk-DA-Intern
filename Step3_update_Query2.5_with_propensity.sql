-- ============================================================================
-- STEP 3: Update Query 2.5 - Add Propensity Score Join
-- ============================================================================
-- Purpose: Modify base_loan_offer_with_campaign to include propensity scores
-- Author: Ammar Siregar
-- Date: 2025-11-10
-- Base File: Query2.5_add_campaign_segmentation_UPDATED.sql
-- ============================================================================

CREATE OR REPLACE TABLE `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign` AS

WITH dl_whitelist AS (
  -- BAU (Business As Usual)
  SELECT
    x.business_date,
    x.customer_id,
    'BAU' AS is_ct,
    'BAU' as ct_category,
    x.ews_calibrated_scores_bin,
    x.risk_group as risk_group_hci,
    1 AS rnk
  FROM `data-prd-adhoc.dl_whitelist_checkers.dl_wl_final_whitelist_raw_history` x
  LEFT JOIN `data-prd-adhoc.dl_whitelist_checkers.dl_wl_final_whitelist_credit_test_raw_history` y
    ON x.customer_id = y.customer_id
    AND x.business_date = y.business_date
  WHERE
    x.business_date >= '2025-01-01'
    AND x.waterfall_failure_step = '99. Passed Underwriting Waterfall'
    AND x.flag_offer_upload = 'Yes'
    AND (y.customer_id IS NULL
         OR (y.customer_id IS NOT NULL
             AND y.waterfall_failure_step NOT LIKE '99. Passed Underwriting Waterfall'))

  UNION ALL

  -- CT (Credit Test)
  SELECT
    business_date,
    customer_id,
    'CT' AS is_ct,
    category as ct_category,
    ews_calibrated_scores_bin,
    risk_group as risk_group_hci,
    2 AS rnk
  FROM `data-prd-adhoc.dl_whitelist_checkers.dl_wl_final_whitelist_credit_test_raw_history`
  WHERE
    business_date >= '2025-01-01'
    AND waterfall_failure_step = '99. Passed Underwriting Waterfall'
    AND flag_offer_upload = 'Yes'

  UNION ALL

  -- Weekly
  SELECT
    business_date,
    customer_id,
    'Weekly' AS is_ct,
    category as ct_category,
    NULL as ews_calibrated_scores_bin,
    risk_group as risk_group_hci,
    3 AS rnk
  FROM `data-prd-adhoc.dl_whitelist_checkers.dl_wl_final_whitelist_weekly_raw_history`
  WHERE
    business_date >= '2025-01-01'
    AND waterfall_failure_step = '99. Passed Underwriting Waterfall'
    AND flag_offer_upload = 'Yes'
),

dl_whitelist_deduped AS (
  SELECT * FROM dl_whitelist
  QUALIFY ROW_NUMBER() OVER (PARTITION BY customer_id, business_date ORDER BY rnk ASC) = 1
),

-- ============================================================================
-- NEW CTE: Propensity Scores
-- ============================================================================
propensity_scores AS (
  SELECT
    customer_id,
    period AS offer_date,
    source,
    propensity_score,
    propensity_score_bin,
    model_iteration
  FROM `data-prd-adhoc.credit_risk_adhoc.propensity_scores_unified_jan_nov`
),
-- ============================================================================

offers_with_campaign AS (
  SELECT
    x.*,
    COALESCE(
      e0.is_ct,
      e1.is_ct,
      e2.is_ct,
      e3.is_ct
    ) AS campaign_segment_raw,

    COALESCE(
      e0.ct_category,
      e1.ct_category,
      e2.ct_category,
      e3.ct_category
    ) AS campaign_category_raw,

    COALESCE(
      e0.ews_calibrated_scores_bin,
      e1.ews_calibrated_scores_bin,
      e2.ews_calibrated_scores_bin,
      e3.ews_calibrated_scores_bin
    ) AS ews_calibrated_scores_bin,

    COALESCE(
      e0.risk_group_hci,
      e1.risk_group_hci,
      e2.risk_group_hci,
      e3.risk_group_hci
    ) AS risk_group_hci,

    -- ========================================================================
    -- NEW: Propensity Score Fields
    -- ========================================================================
    p.propensity_score,
    p.propensity_score_bin,
    p.model_iteration AS propensity_model_iteration
    -- ========================================================================

  FROM `data-prd-adhoc.temp_ammar.base_loan_offer_with_demo` x

  -- Existing whitelist joins (e0, e1, e2, e3)
  LEFT JOIN dl_whitelist_deduped e0
    ON x.customer_id = e0.customer_id
    AND LAST_DAY(x.business_date) = LAST_DAY(DATE(e0.business_date))

  LEFT JOIN dl_whitelist_deduped e1
    ON x.customer_id = e1.customer_id
    AND LAST_DAY(DATE_SUB(x.business_date, INTERVAL 1 MONTH)) = LAST_DAY(DATE(e1.business_date))

  LEFT JOIN dl_whitelist_deduped e2
    ON x.customer_id = e2.customer_id
    AND LAST_DAY(DATE_ADD(x.business_date, INTERVAL 1 MONTH)) = LAST_DAY(DATE(e2.business_date))

  LEFT JOIN dl_whitelist_deduped e3
    ON x.customer_id = e3.customer_id
    AND LAST_DAY(DATE_SUB(x.business_date, INTERVAL 2 MONTH)) = LAST_DAY(DATE(e3.business_date))

  -- ========================================================================
  -- NEW: Propensity Score Join
  -- ========================================================================
  LEFT JOIN propensity_scores p
    ON x.customer_id = p.customer_id
    AND LAST_DAY(x.business_date) = LAST_DAY(p.offer_date)
    AND x.source = p.source  -- Match 'new' or 'carry over'
  -- ========================================================================
)

SELECT
  *,

  CASE
    WHEN campaign_segment_raw IS NOT NULL THEN campaign_segment_raw
    WHEN campaign_segment_raw IS NULL AND product_code = 'JAG09' THEN 'Open Market'
    WHEN campaign_segment_raw IS NULL AND product_code != 'JAG09' THEN 'Employee and Partner Payroll'
    ELSE 'Unknown'
  END AS campaign_segment,

  CASE
    WHEN campaign_category_raw IS NOT NULL THEN campaign_category_raw
    WHEN campaign_category_raw IS NULL AND product_code = 'JAG09' THEN 'Open Market'
    WHEN campaign_category_raw IS NULL AND product_code != 'JAG09' THEN 'Employee and Partner Payroll'
    ELSE 'Unknown'
  END AS campaign_category

FROM offers_with_campaign;

-- ============================================================================
-- Expected Output Schema:
-- ============================================================================
-- All existing fields from base_loan_offer_with_demo
-- + campaign_segment_raw, campaign_segment
-- + campaign_category_raw, campaign_category
-- + ews_calibrated_scores_bin
-- + risk_group_hci
-- + propensity_score (FLOAT, NULL if no match)
-- + propensity_score_bin (INT64, NULL if no match)
-- + propensity_model_iteration (STRING, NULL if no match)
-- ============================================================================

-- ============================================================================
-- VALIDATION QUERY (Run after table creation)
-- ============================================================================
-- Check propensity score join coverage by month:
--
-- SELECT
--   FORMAT_DATE('%Y-%m', business_date) AS month,
--   source,
--   COUNT(DISTINCT customer_id) AS total_customers,
--   COUNT(DISTINCT CASE WHEN propensity_score_bin IS NOT NULL THEN customer_id END) AS with_propensity,
--   ROUND(
--     COUNT(DISTINCT CASE WHEN propensity_score_bin IS NOT NULL THEN customer_id END) * 100.0 /
--     NULLIF(COUNT(DISTINCT customer_id), 0),
--     2
--   ) AS coverage_pct
-- FROM `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign`
-- WHERE business_date >= '2025-01-01'
-- GROUP BY 1, 2
-- ORDER BY 1 DESC, 2;
--
-- Expected: Coverage_pct should be HIGH (>80%) for all months Jan-Nov 2025
-- ============================================================================
