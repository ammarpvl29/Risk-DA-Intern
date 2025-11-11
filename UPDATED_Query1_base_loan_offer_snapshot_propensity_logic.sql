CREATE OR REPLACE TABLE `data-prd-adhoc.temp_ammar.base_loan_offer_snapshot` AS

WITH offer_raw AS (
  SELECT
    business_date,
    customer_id,
    created_at,
    updated_at,
    agreement_agreed_at,
    expires_at,
    product_code,
    offer_status,
    risk_bracket,
    overdraft_initial_facility_limit,
    installment_initial_facility_limit,
    COALESCE(installment_initial_facility_limit, overdraft_initial_facility_limit) AS limit_offer,

    CASE
      WHEN DATE_DIFF(DATE(expires_at), DATE(created_at), MONTH) = 1
      THEN DATE(created_at)
      ELSE DATE_SUB(CAST(expires_at AS DATE), INTERVAL 1 MONTH)
    END AS key_date,

    LAST_DAY(DATE_SUB(CAST(expires_at AS DATE), INTERVAL 1 MONTH)) AS loan_start_date

  FROM `jago-bank-data-production.dwh_core.loan_offer_daily_snapshot`
  WHERE business_date BETWEEN DATE '2025-01-01' AND CURRENT_DATE()
    AND (
      business_date = LAST_DAY(business_date)
      OR business_date = CURRENT_DATE()
    )
    AND offer_status = 'ENABLED'
    AND LAST_DAY(CAST(expires_at AS DATE), MONTH) >= LAST_DAY(business_date, MONTH)
    AND (LAST_DAY(DATE(agreement_agreed_at), MONTH) >= business_date OR DATE(agreement_agreed_at) IS NULL)
),

offer_deduped AS (
  SELECT * FROM offer_raw
  QUALIFY DENSE_RANK() OVER (
    PARTITION BY customer_id, business_date
    ORDER BY created_at DESC, updated_at DESC
  ) = 1
)

SELECT
  business_date,
  customer_id,
  created_at,
  updated_at,
  agreement_agreed_at,
  loan_start_date,
  key_date,
  product_code,
  offer_status,
  risk_bracket,
  overdraft_initial_facility_limit,
  installment_initial_facility_limit,
  limit_offer,
  
  CASE
    WHEN LAST_DAY(DATE(created_at), MONTH) < business_date THEN 'carry over'
    ELSE 'new'
  END AS source,

  CASE
    WHEN LAST_DAY(DATE(created_at), MONTH) < business_date THEN 1
    ELSE 0
  END AS is_carry_over_offer,

  CASE
    WHEN LAST_DAY(DATE(created_at), MONTH) >= business_date THEN 1
    ELSE 0
  END AS is_new_offer

FROM offer_deduped;