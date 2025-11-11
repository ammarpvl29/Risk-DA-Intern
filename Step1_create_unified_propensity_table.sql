-- ============================================================================
-- STEP 1: Create Unified Propensity Score Table (Jan-Nov 2025)
-- ============================================================================
-- Purpose: Combine iter5, iter6 (Jan-Aug) with new tables (Sept-Nov)
-- Author: Ammar Siregar
-- Date: 2025-11-10
-- ============================================================================

CREATE OR REPLACE TABLE `data-prd-adhoc.credit_risk_adhoc.propensity_scores_unified_jan_nov` AS

WITH

-- ============================================================================
-- Part A: ITER 5 - New Offers (Jan-Aug 2025)
-- ============================================================================
iter5_new_offers AS (
  SELECT
    SPLIT(primary_key, '|')[OFFSET(0)] AS customer_id,
    SPLIT(primary_key, '|')[OFFSET(1)] AS appid,
    DATE(SPLIT(primary_key, '|')[OFFSET(2)]) AS period,
    'new' AS source,
    'iter5' AS model_iteration,
    split_tagging,
    flag_takeup,
    scores AS propensity_score,
    CAST(scores_bin AS INT64) AS propensity_score_bin
  FROM `data-prd-adhoc.credit_risk_adhoc.ammar_df_scores_20251001_bureau_1m`
  WHERE split_tagging IN ('train', 'test')
    AND primary_key IS NOT NULL

  UNION ALL

  SELECT
    SPLIT(primary_key, '|')[OFFSET(0)] AS customer_id,
    SPLIT(primary_key, '|')[OFFSET(1)] AS appid,
    DATE(SPLIT(primary_key, '|')[OFFSET(2)]) AS period,
    'new' AS source,
    'iter5' AS model_iteration,
    split_tagging,
    flag_takeup,
    scores AS propensity_score,
    CAST(scores_bin AS INT64) AS propensity_score_bin
  FROM `data-prd-adhoc.credit_risk_adhoc.ammar_df_scores_oot_20251001_bureau_1m`
  WHERE split_tagging = 'oot'
    AND primary_key IS NOT NULL
),

-- ============================================================================
-- Part B: ITER 6 - Carry-Overs (Jan-Aug 2025)
-- ============================================================================
iter6_carryovers AS (
  SELECT
    SPLIT(primary_key, '|')[OFFSET(0)] AS customer_id,
    SPLIT(primary_key, '|')[OFFSET(1)] AS appid,
    DATE(SPLIT(primary_key, '|')[OFFSET(2)]) AS period,
    'carry over' AS source,
    'iter6' AS model_iteration,
    split_tagging,
    flag_takeup,
    scores AS propensity_score,
    CAST(scores_bin AS INT64) AS propensity_score_bin
  FROM `data-prd-adhoc.credit_risk_adhoc.ammar_df_scores_20251011_carryover`
  WHERE split_tagging IN ('train', 'test')
    AND primary_key IS NOT NULL

  UNION ALL

  SELECT
    SPLIT(primary_key, '|')[OFFSET(0)] AS customer_id,
    SPLIT(primary_key, '|')[OFFSET(1)] AS appid,
    DATE(SPLIT(primary_key, '|')[OFFSET(2)]) AS period,
    'carry over' AS source,
    'iter6' AS model_iteration,
    split_tagging,
    flag_takeup,
    scores AS propensity_score,
    CAST(scores_bin AS INT64) AS propensity_score_bin
  FROM `data-prd-adhoc.credit_risk_adhoc.ammar_df_scores_oot_20251011_carryover`
  WHERE split_tagging = 'oot'
    AND primary_key IS NOT NULL
),

-- ============================================================================
-- Part C: NEW TABLES - September 2025
-- ============================================================================
sept_2025 AS (
  SELECT
    SPLIT(primary_key, '|')[OFFSET(0)] AS customer_id,
    SPLIT(primary_key, '|')[OFFSET(1)] AS appid,
    DATE(SPLIT(primary_key, '|')[OFFSET(2)]) AS period,
    'new' AS source,
    'iter7_sept' AS model_iteration,
    'production' AS split_tagging,  -- New tables don't have split_tagging
    flag_takeup,
    scores AS propensity_score,
    CAST(scores_bin AS INT64) AS propensity_score_bin
  FROM `data-prd-adhoc.dl_whitelist_checkers.df_scores_newoffers_20250930`
  WHERE primary_key IS NOT NULL

  UNION ALL

  SELECT
    SPLIT(primary_key, '|')[OFFSET(0)] AS customer_id,
    SPLIT(primary_key, '|')[OFFSET(1)] AS appid,
    DATE(SPLIT(primary_key, '|')[OFFSET(2)]) AS period,
    'carry over' AS source,
    'iter8_sept' AS model_iteration,
    'production' AS split_tagging,
    flag_takeup,
    scores AS propensity_score,
    CAST(scores_bin AS INT64) AS propensity_score_bin
  FROM `data-prd-adhoc.dl_whitelist_checkers.df_scores_carryovers_20250930`
  WHERE primary_key IS NOT NULL
),

-- ============================================================================
-- Part D: NEW TABLES - October 2025
-- ============================================================================
oct_2025 AS (
  SELECT
    SPLIT(primary_key, '|')[OFFSET(0)] AS customer_id,
    SPLIT(primary_key, '|')[OFFSET(1)] AS appid,
    DATE(SPLIT(primary_key, '|')[OFFSET(2)]) AS period,
    'new' AS source,
    'iter7_oct' AS model_iteration,
    'production' AS split_tagging,
    flag_takeup,
    scores AS propensity_score,
    CAST(scores_bin AS INT64) AS propensity_score_bin
  FROM `data-prd-adhoc.dl_whitelist_checkers.df_scores_newoffers_20251031`
  WHERE primary_key IS NOT NULL

  UNION ALL

  SELECT
    SPLIT(primary_key, '|')[OFFSET(0)] AS customer_id,
    SPLIT(primary_key, '|')[OFFSET(1)] AS appid,
    DATE(SPLIT(primary_key, '|')[OFFSET(2)]) AS period,
    'carry over' AS source,
    'iter8_oct' AS model_iteration,
    'production' AS split_tagging,
    flag_takeup,
    scores AS propensity_score,
    CAST(scores_bin AS INT64) AS propensity_score_bin
  FROM `data-prd-adhoc.dl_whitelist_checkers.df_scores_carryovers_20251031`
  WHERE primary_key IS NOT NULL
),

-- ============================================================================
-- Part E: NEW TABLES - November 2025
-- ============================================================================
nov_2025 AS (
  SELECT
    SPLIT(primary_key, '|')[OFFSET(0)] AS customer_id,
    SPLIT(primary_key, '|')[OFFSET(1)] AS appid,
    DATE(SPLIT(primary_key, '|')[OFFSET(2)]) AS period,
    'new' AS source,
    'iter7_nov' AS model_iteration,
    'production' AS split_tagging,
    flag_takeup,
    scores AS propensity_score,
    CAST(scores_bin AS INT64) AS propensity_score_bin
  FROM `data-prd-adhoc.dl_whitelist_checkers.df_scores_newoffers_20251106`
  WHERE primary_key IS NOT NULL

  UNION ALL

  SELECT
    SPLIT(primary_key, '|')[OFFSET(0)] AS customer_id,
    SPLIT(primary_key, '|')[OFFSET(1)] AS appid,
    DATE(SPLIT(primary_key, '|')[OFFSET(2)]) AS period,
    'carry over' AS source,
    'iter8_nov' AS model_iteration,
    'production' AS split_tagging,
    flag_takeup,
    scores AS propensity_score,
    CAST(scores_bin AS INT64) AS propensity_score_bin
  FROM `data-prd-adhoc.dl_whitelist_checkers.df_scores_carryovers_20251106`
  WHERE primary_key IS NOT NULL
)

-- ============================================================================
-- Final Union: Combine All Periods
-- ============================================================================
SELECT * FROM iter5_new_offers
UNION ALL
SELECT * FROM iter6_carryovers
UNION ALL
SELECT * FROM sept_2025
UNION ALL
SELECT * FROM oct_2025
UNION ALL
SELECT * FROM nov_2025

ORDER BY period DESC, source, customer_id;

-- ============================================================================
-- Expected Output Schema:
-- ============================================================================
-- customer_id (STRING)
-- appid (STRING)
-- period (DATE) - Month-end date matching business_date
-- source (STRING) - 'new' or 'carry over'
-- model_iteration (STRING) - 'iter5', 'iter6', 'iter7_sept', etc.
-- split_tagging (STRING) - 'train', 'test', 'oot', or 'production'
-- flag_takeup (INTEGER) - 0 or 1 (from propensity model)
-- propensity_score (FLOAT) - Raw score 0.0-1.0
-- propensity_score_bin (INTEGER) - Decile 0-9
-- ============================================================================
