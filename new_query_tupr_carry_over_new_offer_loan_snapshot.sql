-- CREATE OR REPLACE TABLE `data-prd-adhoc.temp_ammar.base_loan_offer_snapshot` AS
with loan_offer_base as (
SELECT DISTINCT
  'new' as source,
  business_date,
  customer_id,
  created_at,
  updated_at,
  agreement_agreed_at,
  LAST_DAY(DATE_SUB(CAST(y.expires_at AS DATE), INTERVAL 1 MONTH)) AS loan_start_date,
  CASE
    WHEN DATE_DIFF(DATE(expires_at), DATE(created_at), MONTH) = 1
    THEN DATE(created_at)
    ELSE DATE_SUB(CAST(expires_at AS DATE), INTERVAL 1 MONTH)
  END AS key_date,
  product_code,
  offer_status,
  risk_bracket,
  overdraft_initial_facility_limit,
  installment_initial_facility_limit,
  COALESCE(installment_initial_facility_limit, overdraft_initial_facility_limit) AS limit_offer
FROM `jago-bank-data-production.dwh_core.loan_offer_daily_snapshot` y
WHERE business_date BETWEEN DATE '2025-01-01' AND CURRENT_DATE()
  AND (
    business_date = LAST_DAY(business_date)
    OR business_date = CURRENT_DATE()
  )
  -- 
  -- and agreement_agreed_at <= created_at
  and created_at between '2025-10-01' and '2025-10-31'
  and last_day (date(created_at)) = last_day (date(business_date))
  AND offer_status = 'ENABLED'
QUALIFY DENSE_RANK() OVER (
  PARTITION BY customer_id, business_date
  ORDER BY created_at DESC, updated_at DESC
) = 1

UNION ALL

SELECT DISTINCT
  'carry over' AS source,
  business_date,
  customer_id,
  created_at,
  updated_at,
  agreement_agreed_at,
  LAST_DAY(DATE_SUB(CAST(y.expires_at AS DATE), INTERVAL 1 MONTH)) AS loan_start_date,
  CASE
    WHEN DATE_DIFF(DATE(expires_at), DATE(created_at), MONTH) = 1
    THEN DATE(created_at)
    ELSE DATE_SUB(CAST(expires_at AS DATE), INTERVAL 1 MONTH)
  END AS key_date,
  product_code,
  offer_status,
  risk_bracket,
  overdraft_initial_facility_limit,
  installment_initial_facility_limit,
  COALESCE(installment_initial_facility_limit, overdraft_initial_facility_limit) AS limit_offer
FROM `jago-bank-data-production.dwh_core.loan_offer_daily_snapshot` y
WHERE business_date BETWEEN DATE '2025-01-01' AND CURRENT_DATE()
  AND (
    business_date = LAST_DAY(business_date)
    OR business_date = CURRENT_DATE()
  )
  -- 
  -- and agreement_agreed_at <= created_at
  and updated_at between '2025-10-01' and '2025-10-31'
  and last_day (date(updated_at)) = last_day (date(business_date))
  and last_day (date(created_at)) != last_day (date(business_date))
  AND offer_status = 'ENABLED'
QUALIFY DENSE_RANK() OVER (
  PARTITION BY customer_id, business_date
  ORDER BY created_at DESC, updated_at DESC
) = 1
)