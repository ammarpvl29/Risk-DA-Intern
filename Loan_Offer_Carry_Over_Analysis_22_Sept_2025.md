# 📊 Loan Offer Carry-Over & Anomaly Analysis

**Analysis Date**: September 22, 2025
**Analyst**: Risk DA Intern
**Status**: ✅ **COMPLETED & ACTIONABLE**

---

## 🎯 **Executive Summary**

This document summarizes the investigation into the composition of the active loan offer population, a critical preparatory step for the **Propensity Loan Take Up 2025** project. The analysis began with a broad exploration and concluded by producing two distinct, final queries that correspond to two strategic business goals.

### **Key Findings**:
-   **"Carry-Over" Cohort Discovery**: A large population of customers exists whose active loan offers were created in months prior to the analysis month. This "carry-over" group is **5 times larger** than the group of customers who received new offers.
-   **Data Anomalies Explained**: The large size of the carry-over group is explained by two data characteristics: some offers have very long initial durations (15+ months), and more importantly, offer expiration dates can be extended over time.
-   **Strategic Choice Defined**: The analysis concluded that the core task is not to find one "correct" answer, but to frame a strategic choice for stakeholders: should the propensity model target **new offers** or **all active offers**?

---

## 🔬 **Phase 1: Initial Exploration & Discovery**

The analysis began with a broad query to understand the entire population of customers with an active offer on a given month-end. This initial exploration yielded the most critical insight of the analysis.

#### **Exploratory Query**
```sql
-- This query provides the widest possible view of all active offers
WITH offer AS (
  SELECT
    business_date,
    CASE WHEN last_day(date(created_at), month) < business_date THEN 'yes' ELSE 'no' END AS check
  FROM `jago-bank-data-production.dwh_core.loan_offer_daily_snapshot`
  WHERE
    business_date IN ('2025-08-31')
    AND last_day(CAST(expires_at AS date), month) >= last_day(business_date, month)
    AND offer_status NOT LIKE 'BLOCKED'
    AND (last_day(date(agreement_agreed_at), month) >= business_date OR date(agreement_agreed_at) IS NULL)
  QUALIFY DENSE_RANK() OVER (PARTITION BY business_date, customer_id ORDER BY created_at DESC, expires_at DESC) = 1
)
SELECT
  business_date,
  COUNT(*) AS total_active_offers,
  COUNTIF(check = 'no') AS new_offers,
  COUNTIF(check = 'yes') AS carry_over_offers
FROM offer
GROUP BY business_date;
```

#### **Key Finding: The Scale of the Carry-Over Problem**
The query revealed that the 'carry-over' cohort is the dominant group, making it the central point of ambiguity for the propensity model.

| business_date | total_active_offers | new_offers | carry_over_offers |
| :--- | :--- | :--- | :--- |
| 2025-08-31 | **336,775** | 53,103 | **283,672** |


---

## 🚀 **Phase 2: Final Deliverables for Strategic Decision**

After a full analysis, including investigating data anomalies and refining the cohort (filtering for LFS customers), the investigation concluded by producing two final, complete queries. These queries correspond to the two distinct strategic goals identified, and are the primary deliverable for discussion with stakeholders.

### **Query for Goal A: New Offer Performance**
This query answers: "What is the monthly performance of **new offers** for our LFS customers?" It deliberately excludes the 'carry-over' cohort to get a clean metric for new campaigns.

```sql
-- Goal A: New Offers Only
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
END AS created_at
FROM jago-bank-data-production.dwh_core.loan_offer_daily_snapshot
WHERE
business_date IN ('2025-08-31', '2025-07-31', '2025-06-30', '2025-05-31', '2025-03-31', '2025-02-28',
'2025-01-31')
and (agreement_agreed_at >= created_at or agreement_agreed_at is null)
and FORMAT_DATE('%Y%m', date(created_at))=FORMAT_DATE('%Y%m', date(business_date))
QUALIFY DENSE_RANK() OVER (PARTITION BY customer_id, business_date ORDER BY expires_at DESC, created_at DESC) = 1
)
,
latest_offers_customer AS (
  SELECT c.business_date, c.id_number, lo.* except(business_date)
  FROM jago-bank-data-production.data_mart.customer c
  INNER JOIN latest_offers lo ON c.customer_id = lo.customer_id AND c.business_date = lo.business_date
  WHERE c.business_date IN ('2025-08-31', '2025-07-31', '2025-06-30', '2025-05-31', '2025-03-31', '2025-02-28',
'2025-01-31')
  AND c.customer_source = 'LFS'
),
facilities_customer AS
(
  SELECT mlf.business_date, c.id_number, mlf.start_date
  FROM jago-bank-data-production.data_mart.customer c
  INNER JOIN `jago-bank-data-production.one_reporting_views.master_loan_facility_report` mlf
  ON mlf.cif = c.customer_id AND mlf.business_date = c.business_date
  WHERE c.business_date IN ('2025-08-31', '2025-07-31', '2025-06-30', '2025-05-31', '2025-03-31', '2025-02-28',
'2025-01-31')
  AND c.customer_source = 'LP'
  AND mlf.business_date IN ('2025-08-31', '2025-07-31', '2025-06-30', '2025-05-31', '2025-03-31', '2025-02-28',
'2025-01-31')
  AND mlf.facility_type LIKE '%FJDL%'
  QUALIFY DENSE_RANK() OVER(PARTITION BY c.id_number, c.business_date ORDER BY mlf.start_date DESC) = 1
),
final as
(
  select x.business_date, x.created_at, x.expires_at, y.start_date, x.id_number
  from latest_offers_customer x
  left join facilities_customer y
  on x.business_date=y.business_date and x.id_number=y.id_number
),
final_base1 as (
select
  final.business_date,
  COUNT(*) as total_offers,
  COUNTIF(start_date IS NOT NULL) as total_disbursed,
  COUNTIF(start_date >= created_at AND start_date <= expires_at) as total_takeup
from final
where id_number not in (select id_number from final where start_date IS NOT NULL and (start_date < created_at OR start_date > expires_at))
GROUP BY business_date
)
,
-- April Anomaly Handling Block
offer_aprl as (
    SELECT 
        CASE WHEN date(created_at) IN('2025-03-27', '2025-03-26') THEN DATE('2025-04-30') ELSE date(business_date) END AS business_date,
        customer_id, date(expires_at) as expires_at, agreement_agreed_at,
        CASE WHEN date(created_at) IN('2025-03-27', '2025-03-26') THEN DATE('2025-04-05') ELSE date(created_at) END AS created_at
    FROM jago-bank-data-production.dwh_core.loan_offer_daily_snapshot
    WHERE business_date='2025-04-30'
) 
, 
latest_offers_aprl AS (
  SELECT business_date, customer_id, expires_at, created_at, agreement_agreed_at
  FROM offer_aprl
  WHERE business_date='2025-04-30'
  and (DATE(agreement_agreed_at) >= DATE(created_at) or agreement_agreed_at is null)
  and FORMAT_DATE('%Y%m', date(created_at))=FORMAT_DATE('%Y%m', date(business_date))
  QUALIFY DENSE_RANK() OVER (PARTITION BY customer_id ORDER BY expires_at DESC, created_at DESC) = 1
)
,
latest_offers_customer_aprl AS (
    SELECT c.business_date, c.id_number, lo.* except(business_date)
    FROM jago-bank-data-production.data_mart.customer c
    INNER JOIN latest_offers_aprl lo ON c.customer_id = lo.customer_id
    WHERE c.business_date = '2025-04-30' AND c.customer_source = 'LFS'
),
facilities_customer_aprl AS 
(
    SELECT mlf.business_date, c.id_number, mlf.start_date
    FROM  jago-bank-data-production.data_mart.customer c
    INNER JOIN jago-bank-data-production.one_reporting_views.master_loan_facility_report mlf ON mlf.cif = c.customer_id
    WHERE c.business_date = '2025-04-30' AND c.customer_source = 'LP' AND mlf.business_date = '2025-04-30' AND mlf.facility_type LIKE '%FJDL%'
    QUALIFY DENSE_RANK() OVER(PARTITION BY c.id_number ORDER BY mlf.start_date DESC) = 1
),
final_aprl as
(
    select x.business_date, x.created_at, x.expires_at, y.start_date, x.id_number
    from latest_offers_customer_aprl x 
    left join facilities_customer_aprl y on x.business_date=y.business_date and x.id_number=y.id_number
),
final_base2 as (
select 
    final_aprl.business_date,
    COUNT(*) as total_offers,
    COUNTIF(start_date IS NOT NULL) as total_disbursed,
    COUNTIF(start_date >= created_at AND start_date <= expires_at) as total_takeup
from final_aprl
where id_number not in (select id_number from final_aprl where start_date IS NOT NULL and (start_date < created_at OR start_date > expires_at))
GROUP BY business_date
)
-- Final combination of both data blocks
select business_date, total_offers, total_disbursed, total_takeup from final_base1
UNION ALL
select business_date, total_offers, total_disbursed, total_takeup from final_base2;
```

### **Query for Goal B: All Active Offer Performance**
This query answers: "What is the monthly performance of **all active offers** (new and carry-over) for our LFS customers?" It is identical to the query above, but with the critical `FORMAT_DATE` filter commented out.

```sql
-- Goal B: All Active Offers (New + Carry-Over)
-- The only difference is commenting out the FORMAT_DATE filter in the two latest_offers CTEs

-- In latest_offers CTE:
-- and FORMAT_DATE('%Y%m', date(created_at))=FORMAT_DATE('%Y%m', date(business_date))

-- In latest_offers_aprl CTE:
-- and FORMAT_DATE('%Y%m', date(created_at))=FORMAT_DATE('%Y%m', date(business_date))
```

---

## 🏷️ **Tags**

`#data-validation` `#data-anomaly` `#loan-offers` `#propensity-model` `#business-questions` `#data-lineage` `#reporting`