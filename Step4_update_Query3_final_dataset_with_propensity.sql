-- ============================================================================
-- STEP 4: Update Query 3 - Add Propensity Dimensions to Final Dataset
-- ============================================================================
-- Purpose: Add propensity_score_bin to tupr_dashboard_final_dataset
-- Author: Ammar Siregar
-- Date: 2025-11-10
-- Base File: FIXED_Query3_tupr_dashboard_final_dataset.sql
-- ============================================================================

CREATE OR REPLACE TABLE `data-prd-adhoc.credit_risk_adhoc.tupr_dashboard_final_dataset` AS

WITH base_loan_offer AS (
  SELECT * FROM `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign`
  WHERE business_date >= '2025-01-01'
),

crvadl AS (
  SELECT DISTINCT
    lfs_customer_id AS customer_id,
    deal_type,
    facility_start_date,
    MAX(plafond_facility) AS plafond_facility,
    SUM(plafond) AS plafond,
    SUM(outstanding_balance * -1) AS OS
  FROM `jago-bank-data-production.data_mart.credit_risk_vintage_account_direct_lending`
  WHERE business_date >= '2025-01-01'
    AND deal_type IN ('JAG06', 'JAG08', 'JAG09')
    AND facility_start_date >= '2025-01-01'
    AND mob = 0
  GROUP BY customer_id, deal_type, facility_start_date
),

base_loan_offer_disburse AS (
  SELECT
    x.*,
    y.* EXCEPT(customer_id)
  FROM base_loan_offer x
  INNER JOIN crvadl y
    ON x.customer_id = y.customer_id
    AND y.facility_start_date > x.key_date
    AND FORMAT_DATE('%Y-%m', y.facility_start_date) = FORMAT_DATE('%Y-%m', x.key_date)
),

base_loan_offer_final AS (
  SELECT
    x.*,
    CASE WHEN y.facility_start_date IS NOT NULL THEN 1 ELSE 0 END AS flag_disburse,
    y.facility_start_date,
    y.plafond_facility,
    y.plafond,
    ROUND(y.plafond / y.plafond_facility, 2) AS util_first,
    CASE
      WHEN CAST(x.limit_offer AS FLOAT64) < 5000000 THEN '<5M'
      WHEN CAST(x.limit_offer AS FLOAT64) >= 5000000 AND CAST(x.limit_offer AS FLOAT64) <= 10000000 THEN '5-10M'
      WHEN CAST(x.limit_offer AS FLOAT64) > 10000000 AND CAST(x.limit_offer AS FLOAT64) <= 20000000 THEN '10-20M'
      WHEN CAST(x.limit_offer AS FLOAT64) > 20000000 THEN '>20M'
      ELSE 'Unknown'
    END AS limit_tier
  FROM base_loan_offer x
  LEFT JOIN base_loan_offer_disburse y
    ON x.business_date = y.business_date
    AND x.customer_id = y.customer_id
)

SELECT
  FORMAT_DATE('%Y-%m', key_date) AS offer_month,

  source,
  CASE
    WHEN source = 'new' THEN '1.new'
    WHEN source = 'carry over' THEN '2.carry over'
    ELSE '3.' || source
  END AS source_sorted,

  campaign_segment,
  CASE
    WHEN campaign_segment = 'BAU' THEN '1.BAU'
    WHEN campaign_segment = 'CT' THEN '2.CT'
    WHEN campaign_segment = 'Weekly' THEN '3.Weekly'
    WHEN campaign_segment = 'Open Market' THEN '4.Open Market'
    WHEN campaign_segment = 'Employee and Partner Payroll' THEN '5.Employee and Partner Payroll'
    ELSE '6.Unknown'
  END AS campaign_segment_sorted,

  campaign_category,
  CASE
    WHEN campaign_category = 'BAU' THEN '1.BAU'
    WHEN campaign_category LIKE 'CT %' THEN '2.' || campaign_category
    WHEN campaign_category = 'Weekly' THEN '3.Weekly'
    WHEN campaign_category = 'Open Market' THEN '4.Open Market'
    WHEN campaign_category = 'Employee and Partner Payroll' THEN '5.Employee and Partner Payroll'
    ELSE '6.Unknown'
  END AS campaign_category_sorted,

  product_code,
  CASE
    WHEN product_code = 'JAG08' THEN '1.JAG08'
    WHEN product_code = 'JAG06' THEN '2.JAG06'
    WHEN product_code = 'JAG09' THEN '3.JAG09'
    ELSE '4.' || product_code
  END AS product_code_sorted,

  risk_bracket,
  CASE
    WHEN risk_bracket = 'L' THEN '1.L'
    WHEN risk_bracket = 'LM' THEN '2.LM'
    WHEN risk_bracket = 'M' THEN '3.M'
    WHEN risk_bracket = 'MH' THEN '4.MH'
    WHEN risk_bracket = 'H' THEN '5.H'
    WHEN risk_bracket = 'NO_BUREAU' THEN '6.NO_BUREAU'
    ELSE '7.' || risk_bracket
  END AS risk_bracket_sorted,

  limit_tier,
  CASE
    WHEN limit_tier = '<5M' THEN '1.<5M'
    WHEN limit_tier = '5-10M' THEN '2.5-10M'
    WHEN limit_tier = '10-20M' THEN '3.10-20M'
    WHEN limit_tier = '>20M' THEN '4.>20M'
    ELSE '5.' || limit_tier
  END AS limit_tier_sorted,

  -- ========================================================================
  -- NEW: Propensity Score Dimensions
  -- ========================================================================
  propensity_score_bin,
  CASE
    WHEN propensity_score_bin = 0 THEN '00.Bin 0'
    WHEN propensity_score_bin = 1 THEN '01.Bin 1'
    WHEN propensity_score_bin = 2 THEN '02.Bin 2'
    WHEN propensity_score_bin = 3 THEN '03.Bin 3'
    WHEN propensity_score_bin = 4 THEN '04.Bin 4'
    WHEN propensity_score_bin = 5 THEN '05.Bin 5'
    WHEN propensity_score_bin = 6 THEN '06.Bin 6'
    WHEN propensity_score_bin = 7 THEN '07.Bin 7'
    WHEN propensity_score_bin = 8 THEN '08.Bin 8'
    WHEN propensity_score_bin = 9 THEN '09.Bin 9'
    WHEN propensity_score_bin IS NULL THEN '99.No Score'
    ELSE '10.Unknown'
  END AS propensity_score_bin_sorted,

  -- Grouped propensity tier for simplified analysis
  CASE
    WHEN propensity_score_bin IN (0, 1, 2) THEN 'Low (0-2)'
    WHEN propensity_score_bin IN (3, 4, 5, 6) THEN 'Medium (3-6)'
    WHEN propensity_score_bin IN (7, 8, 9) THEN 'High (7-9)'
    WHEN propensity_score_bin IS NULL THEN 'No Score'
    ELSE 'Unknown'
  END AS propensity_tier,

  CASE
    WHEN propensity_score_bin IN (0, 1, 2) THEN '1.Low (0-2)'
    WHEN propensity_score_bin IN (3, 4, 5, 6) THEN '2.Medium (3-6)'
    WHEN propensity_score_bin IN (7, 8, 9) THEN '3.High (7-9)'
    WHEN propensity_score_bin IS NULL THEN '4.No Score'
    ELSE '5.Unknown'
  END AS propensity_tier_sorted,
  -- ========================================================================

  COUNT(DISTINCT customer_id) AS total_customers,
  ROUND(SUM(CAST(limit_offer AS FLOAT64)), 0) AS total_limit,
  COUNT(DISTINCT CASE WHEN flag_disburse = 1 THEN customer_id END) AS customers_disbursed,
  ROUND(SUM(CASE WHEN flag_disburse = 1 THEN CAST(limit_offer AS FLOAT64) ELSE 0 END), 0) AS total_limit_disbursed,
  ROUND(
    COUNT(DISTINCT CASE WHEN flag_disburse = 1 THEN customer_id END) * 100.0 /
    NULLIF(COUNT(DISTINCT customer_id), 0),
    2
  ) AS take_up_rate_pct_by_customer,
  ROUND(
    SUM(CASE WHEN flag_disburse = 1 THEN CAST(limit_offer AS FLOAT64) ELSE 0 END) * 100.0 /
    NULLIF(SUM(CAST(limit_offer AS FLOAT64)), 0),
    2
  ) AS take_up_rate_pct_by_limit

FROM base_loan_offer_final
WHERE key_date < DATE_TRUNC(CURRENT_DATE(), MONTH)
  AND key_date >= '2025-01-01'

-- ========================================================================
-- UPDATED GROUP BY: Add positions 14, 15, 16, 17 for propensity fields
-- ========================================================================
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17

ORDER BY 1 DESC, 3, 5, 7, 9, 11, 13, 15, 17;

-- ============================================================================
-- Expected Output Schema:
-- ============================================================================
-- All existing fields PLUS:
-- + propensity_score_bin (INT64, NULL if no match)
-- + propensity_score_bin_sorted (STRING for Looker ordering)
-- + propensity_tier (STRING: Low/Medium/High/No Score)
-- + propensity_tier_sorted (STRING for Looker ordering)
-- ============================================================================

-- ============================================================================
-- POST-EXECUTION VALIDATION
-- ============================================================================
-- Run this query to validate propensity integration:
--
-- SELECT
--   offer_month,
--   source,
--   propensity_tier,
--   SUM(total_customers) AS customers,
--   ROUND(
--     SUM(customers_disbursed) * 100.0 / NULLIF(SUM(total_customers), 0),
--     2
--   ) AS tupr_pct
-- FROM `data-prd-adhoc.credit_risk_adhoc.tupr_dashboard_final_dataset`
-- WHERE offer_month >= '2025-09'  -- Months with validated propensity data
-- GROUP BY 1, 2, 3
-- ORDER BY 1 DESC, 2, 4;
--
-- Expected Pattern:
-- 2025-09, new, High (7-9),    ???,  8-12%   ← Highest TUPR
-- 2025-09, new, Medium (3-6),  ???,  2-4%
-- 2025-09, new, Low (0-2),     ???,  0.5-1%  ← Lowest TUPR
-- ============================================================================
