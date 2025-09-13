WITH latest_snapshot AS (
  SELECT COUNT(*) as snapshot_count
  FROM `data-prd-adhoc.credit_risk_adhoc.intern_loan_offer_daily_snapshot`
  WHERE business_date = (SELECT MAX(business_date) FROM `data-prd-adhoc.credit_risk_adhoc.intern_loan_offer_daily_snapshot`)
),
current_table AS (
  SELECT COUNT(*) as current_count
  FROM `data-prd-adhoc.credit_risk_adhoc.intern_loan_offer_current`
)
SELECT
  s.snapshot_count,
  c.current_count,
  CASE
    WHEN s.snapshot_count = c.current_count THEN 'MATCH'
    ELSE 'DIFFERENT'
  END as comparison
FROM latest_snapshot s, current_table c;

-------------------------------------- Task 2

SELECT
  DATE(created_at) as offer_date,
  COUNT(*) as offers_count,
  COUNT(DISTINCT customer_id) as unique_customers
FROM `data-prd-adhoc.credit_risk_adhoc.intern_loan_offer_current`
WHERE DATE(created_at) IN ('2025-08-25', '2025-07-25')
GROUP BY DATE(created_at)
ORDER BY offer_date;

----------------------

SELECT
  COUNT(*) as total_lfs_customers,
  MIN(customer_start_date) as earliest_startdate,
  MAX(customer_start_date) as latest_startdate
FROM `data-prd-adhoc.credit_risk_adhoc.intern_data_mart_customer`
WHERE customer_source = 'LFS'
AND business_date = '2025-08-25'
LIMIT 5;

-----------------------

SELECT
  business_date,
  COUNT(*) as total_customers,
  COUNT(CASE WHEN customer_source = 'LFS' THEN 1 END) as lfs_customers
FROM `data-prd-adhoc.credit_risk_adhoc.intern_data_mart_customer`
WHERE business_date >= '2025-08-20'
GROUP BY business_date
ORDER BY business_date DESC
LIMIT 10;

----------------------

SELECT
  customer_source,
  COUNT(*) as customers,
  MIN(customer_start_date) as earliest_start,
  MAX(customer_start_date) as latest_start,
  MIN(business_date) as earliest_business_date,
  MAX(business_date) as latest_business_date
FROM `data-prd-adhoc.credit_risk_adhoc.intern_data_mart_customer`
WHERE customer_source = 'LFS'
GROUP BY customer_source;

------------------------

SELECT
  COUNT(DISTINCT c.customer_id) as lfs_customers_offered_aug25,
  MIN(c.customer_start_date) as earliest_startdate,
  MAX(c.customer_start_date) as latest_startdate
FROM `data-prd-adhoc.credit_risk_adhoc.intern_loan_offer_current` o
JOIN `data-prd-adhoc.credit_risk_adhoc.intern_data_mart_customer` c
  ON o.customer_id = c.customer_id
WHERE DATE(o.created_at) = '2025-08-25'
  AND c.business_date = '2025-08-31'  -- tanggal paling deket
  AND c.customer_source = 'LFS';

-------------------------

SELECT
  COUNT(DISTINCT c.customer_id) as lfs_customers_offered_jul25,
  MIN(c.customer_start_date) as earliest_startdate,
  MAX(c.customer_start_date) as latest_startdate
FROM `data-prd-adhoc.credit_risk_adhoc.intern_loan_offer_current` o
JOIN `data-prd-adhoc.credit_risk_adhoc.intern_data_mart_customer` c
  ON o.customer_id = c.customer_id
WHERE DATE(o.created_at) = '2025-07-25'
  AND c.business_date = '2025-08-31'
  AND c.customer_source = 'LFS';

------------------------------------ Task 3

SELECT
  partner_id,
  product_code,
  COUNT(*) as applications,
  COUNT(CASE WHEN status IN ('ACTIVATED', 'Approve') THEN 1 END) as approved
FROM `data-prd-adhoc.credit_risk_adhoc.intern_loan_application`
GROUP BY partner_id, product_code
ORDER BY applications DESC
LIMIT 10;

-------------------------

SELECT
  DATE(loan_application_created_at) as application_date,
  COUNT(*) as applications
FROM `data-prd-adhoc.credit_risk_adhoc.intern_loan_application`
WHERE DATE(loan_application_created_at) BETWEEN '2025-08-01' AND '2025-09-30'
GROUP BY DATE(loan_application_created_at)
ORDER BY application_date DESC
LIMIT 10;

-------------------------

SELECT
  MIN(DATE(loan_application_created_at)) as earliest_date,
  MAX(DATE(loan_application_created_at)) as latest_date,
  COUNT(*) as total_applications
FROM `data-prd-adhoc.credit_risk_adhoc.intern_loan_application`;

-------------------------

SELECT
  partner_id,
  product_code,
  loan_application_source,
  applications
FROM (
  SELECT
    partner_id,
    product_code,
    loan_application_source,
    COUNT(*) as applications
  FROM `data-prd-adhoc.credit_risk_adhoc.intern_loan_application`
  GROUP BY partner_id, product_code, loan_application_source
)
WHERE partner_id LIKE '%JAD%'
    OR product_code LIKE '%JAD%'
    OR loan_application_source LIKE '%JAD%'
ORDER BY applications DESC;

-------------------------

SELECT COUNT(*) as applications_2025
FROM `data-prd-adhoc.credit_risk_adhoc.intern_loan_application`
WHERE DATE(loan_application_created_at) >= '2025-01-01';

------------------------

SELECT COUNT(*) as jad_applications
FROM `data-prd-adhoc.credit_risk_adhoc.intern_loan_application`
WHERE partner_id LIKE '%JAD%'
    OR product_code LIKE '%JAD%'
    OR loan_application_source LIKE '%JAD%';

-------------------------

SELECT
  'Date Range' as description,
  MIN(DATE(loan_application_created_at)) as earliest_date,
  MAX(DATE(loan_application_created_at)) as latest_date,
  COUNT(*) as total_applications,
  COUNT(CASE WHEN DATE(loan_application_created_at) >= '2025-01-01' THEN 1 END) as applications_2025
FROM `data-prd-adhoc.credit_risk_adhoc.intern_loan_application`;

-------------------------------------- Task 4

SELECT
  DealType,
  COUNT(*) as facility_count
FROM `data-prd-adhoc.credit_risk_adhoc.intern_MasterLoanFacility`
GROUP BY DealType
ORDER BY facility_count DESC
LIMIT 10;

---------------------------

SELECT
  DealType,
  COUNT(*) as facility_count
FROM `data-prd-adhoc.credit_risk_adhoc.intern_MasterLoanFacility`
WHERE DealType LIKE '%JAG%'
GROUP BY DealType
ORDER BY facility_count DESC;

---------------------------

WITH aug25_customers AS (
  SELECT DISTINCT c.id_number
  FROM `data-prd-adhoc.credit_risk_adhoc.intern_loan_offer_current` o
  JOIN `data-prd-adhoc.credit_risk_adhoc.intern_data_mart_customer` c
    ON o.customer_id = c.customer_id
  WHERE DATE(o.created_at) = '2025-08-25'
    AND c.business_date = '2025-08-31'
    AND c.customer_source = 'LFS'
)
SELECT
  COUNT(DISTINCT m.CIF) as customers_with_jag_facilities,
  SUM(CASE WHEN m.DealType LIKE 'JAG%' THEN 1 ELSE 0 END) as total_jag_facilities
FROM `data-prd-adhoc.credit_risk_adhoc.intern_MasterLoanFacility` m
JOIN `data-prd-adhoc.credit_risk_adhoc.intern_data_mart_customer` c
  ON m.CIF = c.customer_cif
JOIN aug25_customers a25 ON c.id_number = a25.id_number
WHERE m.DealType LIKE 'JAG%';

-----------------------

SELECT
  COUNT(DISTINCT c.customer_cif) as customers_in_both_tables
FROM `data-prd-adhoc.credit_risk_adhoc.intern_data_mart_customer` c
JOIN `data-prd-adhoc.credit_risk_adhoc.intern_MasterLoanFacility` m
  ON c.customer_cif = m.CIF
WHERE c.business_date = '2025-08-31'
  AND m.DealType LIKE 'JAG%'
LIMIT 10;

----------------------

SELECT
  customer_cif,
  customer_source,
  COUNT(*) as count
FROM `data-prd-adhoc.credit_risk_adhoc.intern_data_mart_customer`
WHERE business_date = '2025-08-31'
  AND customer_cif IS NOT NULL
GROUP BY customer_cif, customer_source
ORDER BY count DESC
LIMIT 5;

----------------------

SELECT
  CIF,
  DealType,
  COUNT(*) as count
FROM `data-prd-adhoc.credit_risk_adhoc.intern_MasterLoanFacility`
WHERE DealType LIKE 'JAG%'
  AND CIF IS NOT NULL
GROUP BY CIF, DealType
ORDER BY count DESC
LIMIT 5;

-----------------------

SELECT
  c.id_number,
  c.customer_cif,
  c.customer_id,
  o.created_at
FROM `data-prd-adhoc.credit_risk_adhoc.intern_loan_offer_current` o
JOIN `data-prd-adhoc.credit_risk_adhoc.intern_data_mart_customer` c
  ON o.customer_id = c.customer_id
WHERE DATE(o.created_at) = '2025-08-25'
  AND c.business_date = '2025-08-31'
  AND c.customer_source = 'LFS';

-----------------------

SELECT
  CIF,
  DealType,
  Outstanding,
  StartDate,
  COUNT(*) as facilities
FROM `data-prd-adhoc.credit_risk_adhoc.intern_MasterLoanFacility`
WHERE CIF IN ('8a85410c85a665e30185ab2a82485eee', '8a85488278cef4940178d45a4da241b8')
  AND DealType LIKE 'JAG%'
GROUP BY CIF, DealType, Outstanding, StartDate;

------------------------------------- Task 5

SELECT
  DealType,
  COUNT(*) as facilities,
  AVG(Plafond) as avg_limit,
  AVG(Outstanding) as avg_outstanding,
  MIN(StartDate) as earliest_start,
  MAX(StartDate) as latest_start,
  COUNT(CASE WHEN Outstanding > 0 THEN 1 END) as active_facilities
FROM `data-prd-adhoc.credit_risk_adhoc.intern_MasterLoanFacility`
WHERE DealType LIKE 'JAG%'
GROUP BY DealType
ORDER BY facilities DESC;

------------------------

SELECT
  DealType,
  Plafond as limit_value,
  Outstanding as outstanding_value,
  StartDate,
  MaturityDate,
  Status
FROM `data-prd-adhoc.credit_risk_adhoc.intern_MasterLoanFacility`
WHERE DealType = 'JAG08'
ORDER BY StartDate DESC
LIMIT 5;

----------------------

SELECT
  DealType,
  StartDate,
  MaturityDate,
  DATE_DIFF(MaturityDate, StartDate, DAY) as tenor_days,
  ROUND(DATE_DIFF(MaturityDate, StartDate, DAY) / 30.0, 1) as tenor_months,
  Plafond,
  Outstanding,
  Status
FROM `data-prd-adhoc.credit_risk_adhoc.intern_MasterLoanFacility`
WHERE DealType = 'JAG08'
ORDER BY StartDate DESC
LIMIT 5;

------------------------

SELECT * FROM `data-prd-adhoc.credit_risk_adhoc.intern_MasterLoanFacility` limit 10;

---------------------------------------------- Task 6

SELECT
  COUNT(*) as total_facilities,
  COUNT(DISTINCT CIF) as unique_customers,
  MIN(BusinessDate) as earliest_date,
  MAX(BusinessDate) as latest_date
FROM `data-prd-adhoc.credit_risk_adhoc.intern_StgLoanFacility`;

-----------------------------

SELECT
  DealType,
  COUNT(*) as facility_count
FROM `data-prd-adhoc.credit_risk_adhoc.intern_StgLoanFacility`
GROUP BY DealType
ORDER BY facility_count DESC
LIMIT 10;

----------------------------

SELECT
  DealType,
  COUNT(*) as facility_count
FROM `data-prd-adhoc.credit_risk_adhoc.intern_StgLoanFacility`
WHERE DealType LIKE '%JAG%'
GROUP BY DealType
ORDER BY facility_count DESC;

-----------------------------

SELECT
  'MasterLoanFacility' as table_name,
  COUNT(*) as total_records,
  0 as records_with_interest_rate,
  NULL as avg_interest_rate,
  'TIDAK ADA FIELD INTERESTRATE' as notes
FROM `data-prd-adhoc.credit_risk_adhoc.intern_MasterLoanFacility`

UNION ALL

SELECT
  'StgLoanFacility' as table_name,
  COUNT(*) as total_records,
  COUNT(InterestRate) as records_with_interest_rate,
  ROUND(AVG(InterestRate), 2) as avg_interest_rate,
  'ADA FIELD INTERESTRATE' as notes
FROM `data-prd-adhoc.credit_risk_adhoc.intern_StgLoanFacility`;