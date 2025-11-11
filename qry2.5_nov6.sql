CREATE OR REPLACE TABLE `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign` AS

WITH dl_whitelist AS (
  -- BAU
  SELECT
    x.business_date,
    x.customer_id,
    'BAU' AS is_ct,
    'BAU' as ct_category,
    x.ews_calibrated_scores_bin,
    x.risk_group as risk_group_hci,
    1 AS rnk
  FROM `data-prd-adhoc.dl_whitelist_checkers.dl_wl_final_whitelist_raw_history` x
  LEFT JOIN
`data-prd-adhoc.dl_whitelist_checkers.dl_wl_final_whitelist_credit_test_raw_history` y
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

  -- CT
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
)

SELECT
  x.*,
  COALESCE(y.is_ct, 'Unknown') AS campaign_segment,
  COALESCE(y.ct_category, 'Unknown') AS campaign_category,
  y.ews_calibrated_scores_bin,
  y.risk_group_hci
FROM `data-prd-adhoc.temp_ammar.base_loan_offer_with_demo` x
LEFT JOIN dl_whitelist_deduped y
  ON x.customer_id = y.customer_id
  -- tambahin filter pakai coalesce untuk bandingin bulan sebelumnya
  AND LAST_DAY(CAST(x.key_date AS DATE)) = LAST_DAY(CAST(y.business_date AS DATE))