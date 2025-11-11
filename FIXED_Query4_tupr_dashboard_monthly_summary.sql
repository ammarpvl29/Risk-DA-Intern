CREATE OR REPLACE TABLE `data-prd-adhoc.credit_risk_adhoc.tupr_dashboard_monthly_summary` AS

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
    ROUND(y.plafond / y.plafond_facility, 2) AS util_first
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
GROUP BY 1, 2, 3, 4, 5
ORDER BY 1 DESC, 3, 5;