CREATE OR REPLACE TABLE `data-prd-adhoc.temp_ammar.ammar_customer_loan_details` AS

WITH
latest_offers AS (
SELECT
	CASE
	WHEN date(created_at) IN('2025-03-27', '2025-03-26') THEN DATE('2025-04-30') 
	ELSE date(business_date)
	END AS business_date,
	customer_id,
	date(expires_at) as expires_at,
	agreement_agreed_at,
	CASE
	WHEN date(created_at) IN('2025-03-27', '2025-03-26') THEN DATE('2025-04-05') 
	ELSE date(created_at)
	END AS created_at,
	CASE 
		WHEN last_day(date(created_at), month) < business_date THEN 1 
		ELSE 0 
	END AS is_carry_over_offer,
	CASE 
		WHEN last_day(date(created_at), month) >= business_date THEN 1 
		ELSE 0 
	END AS is_new_offer
FROM jago-bank-data-production.dwh_core.loan_offer_daily_snapshot
WHERE
	business_date IN ('2025-08-31', '2025-07-31', '2025-06-30', '2025-05-31', '2025-03-31', '2025-02-28', '2025-01-31')
	AND last_day(cast(expires_at as date), month) >= last_day(business_date, month)
	AND offer_status NOT LIKE 'BLOCKED'
	AND (last_day(date(agreement_agreed_at), month) >= business_date OR date(agreement_agreed_at) IS NULL)
QUALIFY DENSE_RANK() OVER (PARTITION BY customer_id, business_date ORDER BY created_at DESC, expires_at DESC) = 1
)
,
latest_offers_customer AS (
  SELECT
	  c.business_date,
	  c.id_number,
	  c.customer_id,
	  lo.expires_at,
	  lo.created_at,
	  lo.agreement_agreed_at,
	  lo.is_carry_over_offer,
	  lo.is_new_offer
  FROM jago-bank-data-production.data_mart.customer c
  INNER JOIN latest_offers lo ON c.customer_id = lo.customer_id AND c.business_date = lo.business_date
  WHERE c.business_date IN ('2025-08-31', '2025-07-31', '2025-06-30', '2025-05-31', '2025-03-31', '2025-02-28',
'2025-01-31')
	  AND c.customer_source = 'LFS'
),
facilities_customer AS
(
  SELECT
	  mlf.business_date,
	  c.id_number,
	  c.customer_id,
	  mlf.status,
	  mlf.cif,
	  mlf.facility_reference,
	  mlf.tanggal_pk_awal,
	  mlf.plafond,
	  mlf.unused_amount,
	  mlf.start_date,
	  mlf.maturity_date
  FROM jago-bank-data-production.data_mart.customer c
  INNER JOIN jago-bank-data-production.one_reporting_views.master_loan_facility_report mlf
  ON mlf.cif = c.customer_id AND mlf.business_date = c.business_date
  WHERE c.business_date IN ('2025-08-31', '2025-07-31', '2025-06-30', '2025-05-31', '2025-03-31', '2025-02-28',
'2025-01-31')
	  AND c.customer_source = 'LP'
	  AND mlf.business_date IN ('2025-08-31', '2025-07-31', '2025-06-30', '2025-05-31', '2025-03-31', '2025-02-28',
'2025-01-31')
	  AND mlf.facility_type LIKE '%FJDL%'
  QUALIFY DENSE_RANK() OVER(PARTITION BY c.id_number, c.business_date ORDER BY mlf.start_date DESC) = 1
),
final_main AS
(
  SELECT 
    x.business_date,
    x.id_number,
    x.customer_id,
    x.expires_at,
    x.created_at,
    x.agreement_agreed_at,
    x.is_carry_over_offer,
    x.is_new_offer,
    y.status,
    y.cif,
    y.facility_reference,
    y.tanggal_pk_awal,
    y.plafond,
    y.unused_amount,
    y.start_date,
    y.maturity_date,
    CASE WHEN y.business_date is not null THEN 1 ELSE 0 END AS flag_has_facility,
    CASE WHEN y.start_date >= DATE(x.created_at) AND y.start_date <= DATE(x.expires_at)
    THEN 1 ELSE 0 END AS flag_takeup,
    1 as all_offer
  FROM latest_offers_customer x
  LEFT JOIN facilities_customer y
  ON x.business_date = y.business_date AND x.id_number = y.id_number
),
offer_aprl AS (
    SELECT 
        CASE
          WHEN date(created_at) IN('2025-03-27', '2025-03-26') THEN DATE('2025-04-30') 
          ELSE date(business_date)
        END AS business_date,
        customer_id,
        date(expires_at) as expires_at,
        agreement_agreed_at,
        CASE
          WHEN date(created_at) IN('2025-03-27', '2025-03-26') THEN DATE('2025-04-05') 
          ELSE date(created_at)
        END AS created_at
    FROM jago-bank-data-production.dwh_core.loan_offer_daily_snapshot
    WHERE business_date='2025-04-30'
      AND last_day(cast(expires_at as date), month) >= last_day(business_date, month)
      AND offer_status NOT LIKE 'BLOCKED'
      AND (last_day(date(agreement_agreed_at), month) >= business_date OR date(agreement_agreed_at) IS NULL)
), 
latest_offers_aprl AS (
  SELECT 
      business_date,
      customer_id,
      expires_at,
      created_at,
      agreement_agreed_at,
      CASE 
        WHEN last_day(date(created_at), month) < business_date THEN 1 
        ELSE 0 
      END AS is_carry_over_offer,
      CASE 
        WHEN last_day(date(created_at), month) >= business_date THEN 1 
        ELSE 0 
      END AS is_new_offer
  FROM offer_aprl
  WHERE business_date='2025-04-30'
  AND last_day(cast(expires_at as date), month) >= last_day(business_date, month)
  AND (last_day(date(agreement_agreed_at), month) >= business_date OR date(agreement_agreed_at) IS NULL)
  QUALIFY DENSE_RANK() OVER (PARTITION BY customer_id ORDER BY created_at DESC, expires_at DESC) = 1
),
latest_offers_customer_aprl AS (
    SELECT
        c.business_date,
        c.id_number,
        c.customer_id,
        lo.expires_at,
        lo.created_at,
        lo.agreement_agreed_at,
        lo.is_carry_over_offer,
        lo.is_new_offer
    FROM jago-bank-data-production.data_mart.customer c
    INNER JOIN latest_offers_aprl lo ON c.customer_id = lo.customer_id
    WHERE c.business_date = '2025-04-30'
        AND c.customer_source = 'LFS'
),
facilities_customer_aprl AS 
(
    SELECT
        mlf.business_date,
        c.id_number,
        c.customer_id,
        mlf.status,
        mlf.cif,
        mlf.facility_reference,
        mlf.tanggal_pk_awal,
        mlf.plafond,
        mlf.unused_amount,
        mlf.start_date,
        mlf.maturity_date
    FROM jago-bank-data-production.data_mart.customer c
    INNER JOIN jago-bank-data-production.one_reporting_views.master_loan_facility_report mlf
    ON mlf.cif = c.customer_id
    WHERE c.business_date = '2025-04-30'
        AND c.customer_source = 'LP'
        AND mlf.business_date = '2025-04-30'
        AND mlf.facility_type LIKE '%FJDL%'
    QUALIFY DENSE_RANK() OVER(PARTITION BY c.id_number ORDER BY mlf.start_date DESC) = 1
),
final_aprl AS
(
    SELECT 
      x.business_date,
      x.id_number,
      x.customer_id,
      x.expires_at,
      x.created_at,
      x.agreement_agreed_at,
      x.is_carry_over_offer,
      x.is_new_offer,
      y.status,
      y.cif,
      y.facility_reference,
      y.tanggal_pk_awal,
      y.plafond,
      y.unused_amount,
      y.start_date,
      y.maturity_date,
      CASE WHEN y.business_date is not null THEN 1 ELSE 0 END AS flag_has_facility,
      CASE WHEN y.start_date >= DATE(x.created_at) AND y.start_date <= DATE(x.expires_at) 
      THEN 1 ELSE 0 END AS flag_takeup,
      1 as all_offer
    FROM latest_offers_customer_aprl x 
    LEFT JOIN facilities_customer_aprl y
    ON x.business_date = y.business_date AND x.id_number = y.id_number
)
,
all_customers_history AS (
  SELECT DISTINCT id_number, business_date
  FROM final_main
  
  UNION DISTINCT
  
  SELECT DISTINCT id_number, business_date  
  FROM final_aprl
),
customer_classification AS (
  SELECT 
    fm.id_number,
    fm.business_date,
    fm.created_at,
    fm.is_new_offer,
    fm.is_carry_over_offer
  FROM (
    SELECT id_number, business_date, created_at, is_new_offer, is_carry_over_offer FROM final_main
    UNION ALL
    SELECT id_number, business_date, created_at, is_new_offer, is_carry_over_offer FROM final_aprl
  ) fm
),
final_main_with_classification AS (
  SELECT 
    fm.*
  FROM final_main fm
  WHERE fm.id_number NOT IN (SELECT id_number FROM final_main WHERE flag_has_facility=1 AND flag_takeup=0)
),
final_aprl_with_classification AS (
  SELECT 
    fa.*
  FROM final_aprl fa
  WHERE fa.id_number NOT IN (SELECT id_number FROM final_aprl WHERE flag_has_facility=1 AND flag_takeup=0)
)

SELECT * FROM (
  SELECT *,
    ROW_NUMBER() OVER (PARTITION BY business_date, id_number, customer_id ORDER BY created_at DESC, expires_at DESC) as rn
  FROM (
    SELECT * FROM final_main_with_classification
    
    UNION ALL
    
    SELECT * FROM final_aprl_with_classification
    WHERE business_date = '2025-04-30'
  )
)
WHERE rn = 1
ORDER BY business_date DESC, id_number;