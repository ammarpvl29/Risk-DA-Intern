-- Validation Query: Check Propensity Score Counts for Sept & Oct 2025
-- Compare with Stephanie's output:
-- New offers Sept: 460,333 | Oct: 94,700
-- Carry-overs Sept: 124,976 | Oct: 499,363

WITH latest_offers AS (
  SELECT
    DATE(business_date) AS business_date,
    customer_id,
    DATE(created_at) AS created_at,
    DATE(expires_at) AS expires_at,
    agreement_agreed_at,

    -- Carry-over logic: created in previous month(s)
    CASE
      WHEN LAST_DAY(DATE(created_at), MONTH) < business_date THEN 1
      ELSE 0
    END AS is_carry_over_offer,

    -- New offer logic: created in same month as business_date
    CASE
      WHEN LAST_DAY(DATE(created_at), MONTH) >= business_date THEN 1
      ELSE 0
    END AS is_new_offer

  FROM `jago-bank-data-production.dwh_core.loan_offer_daily_snapshot`
  WHERE
    business_date IN ('2025-09-30', '2025-10-31')
    AND LAST_DAY(CAST(expires_at AS DATE), MONTH) >= LAST_DAY(business_date, MONTH)
    AND offer_status NOT LIKE 'BLOCKED'
    AND (LAST_DAY(DATE(agreement_agreed_at), MONTH) >= business_date OR DATE(agreement_agreed_at) IS NULL)

  QUALIFY DENSE_RANK() OVER (
    PARTITION BY customer_id, business_date
    ORDER BY created_at DESC, expires_at DESC
  ) = 1
),

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
  FROM `jago-bank-data-production.data_mart.customer` c
  INNER JOIN latest_offers lo
    ON c.customer_id = lo.customer_id
    AND c.business_date = lo.business_date
  WHERE
    c.business_date IN ('2025-09-30', '2025-10-31')
    AND c.customer_source = 'LFS'
),

facilities_customer AS (
  SELECT
    mlf.business_date,
    c.id_number,
    c.customer_id,
    mlf.start_date
  FROM `jago-bank-data-production.data_mart.customer` c
  INNER JOIN `jago-bank-data-production.one_reporting_views.master_loan_facility_report` mlf
    ON mlf.cif = c.customer_id
    AND mlf.business_date = c.business_date
  WHERE
    c.business_date IN ('2025-09-30', '2025-10-31')
    AND c.customer_source = 'LP'
    AND mlf.business_date IN ('2025-09-30', '2025-10-31')
    AND mlf.facility_type LIKE '%FJDL%'

  QUALIFY DENSE_RANK() OVER(
    PARTITION BY c.id_number, c.business_date
    ORDER BY mlf.start_date DESC
  ) = 1
),

final_main AS (
  SELECT
    x.business_date,
    x.id_number,
    x.customer_id,
    x.expires_at,
    x.created_at,
    x.agreement_agreed_at,
    x.is_carry_over_offer,
    x.is_new_offer,
    y.start_date,
    CASE WHEN y.business_date IS NOT NULL THEN 1 ELSE 0 END AS flag_has_facility,
    CASE
      WHEN y.start_date >= DATE(x.created_at)
        AND y.start_date <= DATE(x.expires_at)
      THEN 1
      ELSE 0
    END AS flag_takeup
  FROM latest_offers_customer x
  LEFT JOIN facilities_customer y
    ON x.business_date = y.business_date
    AND x.id_number = y.id_number
),

final_filtered AS (
  SELECT
    fm.*
  FROM final_main fm
  WHERE fm.id_number NOT IN (
    SELECT id_number
    FROM final_main
    WHERE flag_has_facility = 1 AND flag_takeup = 0
  )
),

final_deduped AS (
  SELECT *
  FROM final_filtered
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY business_date, id_number, customer_id
    ORDER BY created_at DESC, expires_at DESC
  ) = 1
)

-- Summary counts by month and offer type
SELECT
  FORMAT_DATE('%Y-%m', business_date) AS month,
  CASE
    WHEN is_new_offer = 1 THEN 'New Offer'
    WHEN is_carry_over_offer = 1 THEN 'Carry Over'
    ELSE 'Unknown'
  END AS offer_type,
  COUNT(DISTINCT customer_id) AS customer_count,
  COUNT(DISTINCT CASE WHEN flag_takeup = 1 THEN customer_id END) AS customers_disbursed,
  ROUND(
    COUNT(DISTINCT CASE WHEN flag_takeup = 1 THEN customer_id END) * 100.0 /
    NULLIF(COUNT(DISTINCT customer_id), 0),
    2
  ) AS take_up_rate_pct
FROM final_deduped
GROUP BY 1, 2
ORDER BY 1 DESC, 2;

-- Detail breakdown
-- UNION ALL
--
-- SELECT
--   business_date,
--   is_new_offer,
--   is_carry_over_offer,
--   COUNT(DISTINCT customer_id) AS customer_count
-- FROM final_deduped
-- GROUP BY 1, 2, 3
-- ORDER BY 1 DESC, 2 DESC;
