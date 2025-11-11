CREATE OR REPLACE TABLE `data-prd-adhoc.temp_ammar.collection_analysis_aug_sept_2025_customers` AS (
WITH
base AS
(
  SELECT DISTINCT
      id_number,
      lfs_customer_id,
      facility_reference,
      deal_reference,
      mob,
      deal_type,
      facility_start_date,
      first_due_date,
      1 AS cust,
      SUM(plafond) AS plafond,
      MAX(EXTRACT(DAY FROM maturity_date)) AS day_maturity,
      MAX(EXTRACT(DAY FROM first_due_date)) AS day_first_due
  FROM `jago-bank-data-production.data_mart.credit_risk_vintage_account_direct_lending`
  WHERE business_date >= '2024-10-31'
  AND deal_type IN ('JAG06', 'JAG08')
  AND facility_start_date > '2024-10-01'
  AND mob = 0
  AND FORMAT_DATE('%Y%m', start_date) = FORMAT_DATE('%Y%m', facility_start_date)
  AND facility_start_date <= '2025-10-31'
  GROUP BY 1,2,3,4,5,6,7,8
),

bs AS
(
  SELECT DATE('2025-01-31') AS base, * FROM
`data-prd-adhoc.credit_risk_adhoc.base_logic_bibit_stockbit_20241231`
  UNION ALL
  SELECT DATE('2025-02-28') AS base, * FROM
`data-prd-adhoc.credit_risk_adhoc.base_logic_bibit_stockbit_20250131`
  UNION ALL
  SELECT DATE('2025-03-31') AS base, * FROM
`data-prd-adhoc.credit_risk_adhoc.base_logic_bibit_stockbit_20250228`
  UNION ALL
  SELECT DATE('2025-04-30') AS base, * FROM
`data-prd-adhoc.credit_risk_adhoc.base_logic_bibit_stockbit_20250331`
  UNION ALL
  SELECT DATE('2025-05-31') AS base, * FROM
`data-prd-adhoc.credit_risk_adhoc.base_logic_bibit_stockbit_20250430`
  UNION ALL
  SELECT DATE('2025-06-30') AS base, * FROM
`data-prd-adhoc.credit_risk_adhoc.base_logic_bibit_stockbit_20250531`
  UNION ALL
  SELECT DATE('2025-07-31') AS base, * FROM
`data-prd-adhoc.credit_risk_adhoc.base_logic_bibit_stockbit_20250630`
  UNION ALL
  SELECT DATE('2025-08-31') AS base, * FROM
`data-prd-adhoc.credit_risk_adhoc.base_logic_bibit_stockbit_20250731`
  UNION ALL
  SELECT DATE('2025-09-30') AS base, * FROM
`data-prd-adhoc.credit_risk_adhoc.base_logic_bibit_stockbit_20250831`
),

flag_bs AS
(
  SELECT
      base.*,
      bs.partner_final,
      CASE WHEN bs.customer_id IS NOT NULL THEN 1 ELSE 0 END AS flag_bibit
  FROM base
  LEFT JOIN bs ON base.lfs_customer_id = bs.customer_id
              AND bs.base = LAST_DAY(base.facility_start_date)
),

performance AS
(
  SELECT
      business_date,
      lfs_customer_id,
    facility_reference,
      mob,
    deal_type,
    facility_start_date,
      -- MAX(acct_3dpd_max) AS fpd_dpd3_mob1_act,
      -- SUM(balance_30dpd_max) AS fpd_dpd3_mom1_bal
    acct_3dpd_max
  FROM `jago-bank-data-production.data_mart.credit_risk_vintage_account_direct_lending`
  WHERE business_date >= '2024-10-31'
  AND deal_type IN ('JAG06', 'JAG08')
  AND facility_start_date > '2024-10-01'
  AND mob = 1
  AND FORMAT_DATE('%Y%m', start_date) = FORMAT_DATE('%Y%m', facility_start_date)
  AND facility_start_date <= '2025-10-31'
  GROUP BY 1,2,3,4,5,6,7
),

scoring_ews AS
(
  SELECT * FROM
`data-prd-adhoc.dl_whitelist_checkers.credit_risk_vintage_account_direct_lending_ews_score`
),

scoring_hci AS
(
  SELECT DISTINCT lfs_customer_id, risk_group_hci
  FROM `data-prd-adhoc.dl_whitelist_checkers.credit_risk_vintage_account_direct_lending_hci_score`
),

device AS
(
  SELECT DISTINCT business_date, customer_id, score, created_at, external_id
  FROM `jago-bank-data-production.risk_datamart.device`
  WHERE business_date IS NOT NULL
),

scoring_td AS
(
  SELECT DISTINCT
      x.lfs_customer_id,
      y.external_id,
      y.score AS score_TD
  FROM flag_bs x
  LEFT JOIN device y ON x.lfs_customer_id = y.customer_id
                  AND CAST(y.business_date AS DATE) <= x.facility_start_date
  QUALIFY DENSE_RANK() OVER (PARTITION BY x.lfs_customer_id ORDER BY y.business_date DESC, y.created_at
DESC, external_id DESC) = 1
)

SELECT
  x.id_number,
  x.lfs_customer_id,
  x.facility_reference,
  x.deal_reference,
  x.facility_start_date,
  x.first_due_date,
  x.day_maturity,
  x.day_first_due,
  x.deal_type,
  x.plafond,
  x.partner_final,
  x.flag_bibit,

  FORMAT_DATE('%Y-%m', x.facility_start_date) AS cohort_month,
  CASE
      WHEN LAST_DAY(x.facility_start_date) = '2025-08-31' THEN 'August 2025'
      WHEN LAST_DAY(x.facility_start_date) = '2025-09-30' THEN 'September 2025'
      ELSE 'Other'
  END AS cohort_name,

  y.business_date,
  y.mob,
  COALESCE(y.fpd_dpd3_mob1_act, 0) AS fpd_dpd3_mob1_act,
  COALESCE(y.fpd_dpd3_mom1_bal, 0) AS fpd_dpd3_mom1_bal,

  CASE
      WHEN COALESCE(y.fpd_dpd3_mob1_act, 0) = 1 THEN 1
      ELSE 0
  END AS flag_bad_customer,
  CASE
      WHEN COALESCE(y.fpd_dpd3_mob1_act, 0) = 0 THEN 1
      ELSE 0
  END AS flag_good_customer,

  z1.calibrated_scores AS ews_calibrated_scores,
  z2.risk_group_hci,
  z3.score_TD

FROM flag_bs x
LEFT JOIN performance y ON x.lfs_customer_id = y.lfs_customer_id
  AND x.facility_reference = y.facility_reference
LEFT JOIN scoring_ews z1 ON x.lfs_customer_id = z1.lfs_customer_id
LEFT JOIN scoring_hci z2 ON x.lfs_customer_id = z2.lfs_customer_id
LEFT JOIN scoring_td z3 ON x.lfs_customer_id = z3.lfs_customer_id
WHERE LAST_DAY(x.facility_start_date) IN ('2025-08-31', '2025-09-30')
AND x.day_maturity < 11
);