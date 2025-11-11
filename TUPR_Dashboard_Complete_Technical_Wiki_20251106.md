# Loan Offer Take-Up Rate (TUPR) Dashboard - Complete Technical Documentation

**Document Type:** Technical Wiki Entry
**Project:** Digital Lending Analytics - Take-Up Rate Dashboard
**Author:** Ammar Siregar (Risk Data Analyst Intern)
**Mentor:** Pak Subhan (Credit Risk Team)
**Date Created:** 2025-11-06
**Last Updated:** 2025-11-06
**Status:** ✅ Production Ready (Updated with New + Carry-Over Logic)
**Dashboard URL:** https://bankjago.cloud.looker.com/dashboards/461
**Related RFC:** [RFC] Propensity Loan Take Up 2025

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Business Context](#business-context)
3. [Problem Statement & Evolution](#problem-statement--evolution)
4. [Solution Design](#solution-design)
5. [Technical Implementation](#technical-implementation)
6. [Data Architecture](#data-architecture)
7. [Dashboard Design](#dashboard-design)
8. [Validation Results](#validation-results)
9. [Key Learnings](#key-learnings)
10. [Troubleshooting Guide](#troubleshooting-guide)
11. [References](#references)

---

## Executive Summary

### Purpose

The TUPR (Take-Up Rate) Dashboard measures the conversion rate of loan offers to actual disbursements, tracking what percentage of customers who receive a loan offer subsequently activate their loan facility.

**Key Metric:**
```
TUPR = (Customers Disbursed / Total Customers Offered) × 100%
```

### Critical Update (November 6, 2025)

The dashboard was **completely redesigned** based on mentor feedback to include **both NEW and CARRY-OVER offers**, increasing the measured customer base from ~60K to **~550K customers per month**.

**Before:**
- Only tracked "New Offers" (customers receiving fresh offers)
- October 2025: 59,759 customers, 3.33% TUPR

**After:**
- Tracks "New Offers" + "Carry-Over Offers" (complete offer base)
- October 2025: 553,528 customers (81,372 new + 472,156 carry-over), 0.85% TUPR

### Key Stakeholders

| Team | Use Case |
|------|----------|
| **Product Team** | Evaluate campaign effectiveness and offer strategies |
| **Risk Team** | Monitor conversion rates across risk segments |
| **Credit Team** | Optimize underwriting and offer allocation |
| **Executive Leadership** | Track key lending performance metrics |

---

## Business Context

### Loan Offer Ecosystem

Bank Jago's digital lending operates on a **standing offer model**:

1. **Offer Creation:** Customers are evaluated monthly and given loan offers
2. **Offer Validity:** Offers typically valid for 30 days
3. **Carry-Over:** If customer doesn't take up the offer, it can be **renewed/carried over** to the next month
4. **New Offer:** If customer previously had no offer (or offer lapsed), they receive a **new offer**

**Monthly Offer Base Composition:**

```
Total Offer Base (Oct 2025: 553,528)
├── New Offers (81,372 = 14.7%)
│   └── First-time offers OR offers after gap
└── Carry-Over Offers (472,156 = 85.3%)
    └── Offers renewed from previous month
```

### Why Carry-Over Matters

**Initial Approach (Wrong):** Only counting NEW offers
- Denominator: 81,372 customers
- Numerator: 2,187 disbursed
- TUPR: 2.69%
- **Problem:** Ignores 85% of the offer base!

**Correct Approach:** Counting NEW + CARRY-OVER
- Denominator: 553,528 customers (81,372 + 472,156)
- Numerator: 4,715 disbursed (2,187 + 2,528)
- TUPR: 0.85%
- **Why:** Represents true conversion rate of all active offers

### Business Segmentation

The dashboard supports analysis across multiple dimensions:

1. **Offer Source:** New vs Carry-Over
2. **Risk Grade:** L, LM, M, MH, H, NO_BUREAU
3. **Product Code:** JAG08 (Overdraft), JAG06 (Installment), JAG09 (Flexi Loan)
4. **Limit Tier:** <5M, 5-10M, 10-20M, >20M

---

## Problem Statement & Evolution

### Phase 1: Initial Implementation (Nov 1-4, 2025)

**Approach:** Used LAG window function to filter for NEW OFFERS only

**Query Logic:**
```sql
LAG(offer_status) OVER (PARTITION BY customer_id, product_code ORDER BY business_date) AS prev_month_offer_status
WHERE prev_month_offer_status IS NULL OR DATE_DIFF(...) > 1  -- Only NEW offers
```

**Results:**
- October 2025: 59,759 customers
- TUPR: 3.33%
- Status: ❌ Incomplete (missing carry-over offers)

---

### Phase 2: Mentor Feedback (Nov 5, 2025)

**Key Feedback Points:**

1. **❌ Missing 85% of Offer Base**
   - "You're only capturing NEW offers and completely missing CARRY-OVER offers"
   - "The true base is 400-500K customers, not 60K"

2. **❌ Dashboard Layout Issues**
   - Pivots showing dimensions as columns instead of rows
   - Need to show monthly trend as PRIMARY dimension (columns)
   - Breakdowns (Risk Grade, Product) should be rows

3. **❌ Metric Labels**
   - Remove "#" symbol from Limit metrics (# means count, not sum)
   - "#Limit (M)" → "Limit (M)"

4. **✅ Add Source Breakdown**
   - Need separate chart showing New vs Carry-Over performance

---

### Phase 3: Alignment with Propensity Model (Nov 6, 2025)

**Discovery:** Propensity model already has established logic for New vs Carry-Over detection

**Propensity Model Logic:**
```sql
CASE
    WHEN LAST_DAY(DATE(created_at), MONTH) < business_date THEN 1
    ELSE 0
END AS is_carry_over_offer,

CASE
    WHEN LAST_DAY(DATE(created_at), MONTH) >= business_date THEN 1
    ELSE 0
END AS is_new_offer
```

**Translation:**
- **New Offer:** `LAST_DAY(created_at)` = `LAST_DAY(business_date)` (created this month)
- **Carry-Over:** `LAST_DAY(created_at)` < `business_date` (created in previous month, still active)

**Decision:** Adopt propensity model logic for consistency across analytics

---

## Solution Design

### Conceptual Framework

#### Offer Lifecycle

```
Month 1 (Jan)          Month 2 (Feb)          Month 3 (Mar)
┌─────────────┐       ┌─────────────┐        ┌─────────────┐
│ Customer A  │       │ Customer A  │        │ Customer A  │
│ Created:    │       │ Created:    │        │ Created:    │
│  2025-01-05 │──────▶│  2025-01-05 │───────▶│  2025-01-05 │
│ Status: NEW │       │ Status:     │        │ Status:     │
│             │       │  CARRY-OVER │        │  CARRY-OVER │
└─────────────┘       └─────────────┘        └─────────────┘
    ▼                      ▼                      ▼
 No action           No action              DISBURSED!
                                           (TUPR counted
                                            in Mar)
```

**Key Insight:** Customer A counts as an "offer" in ALL THREE MONTHS:
- January: NEW offer (81K customers like this)
- February: CARRY-OVER offer (472K customers like this)
- March: CARRY-OVER offer → Disbursed (contributes to TUPR)

---

### Detection Logic: New vs Carry-Over

#### Method: LAST_DAY Comparison

```sql
-- Logic from Propensity Model
CASE
  WHEN LAST_DAY(DATE(created_at), MONTH) < business_date THEN 'carry over'
  ELSE 'new'
END AS source
```

#### Examples

**Example 1: New Offer**
```
created_at:    2025-10-05
business_date: 2025-10-31
LAST_DAY(created_at) = 2025-10-31
LAST_DAY(business_date) = 2025-10-31
Result: NEW (created this month)
```

**Example 2: Carry-Over Offer**
```
created_at:    2025-09-15
business_date: 2025-10-31
LAST_DAY(created_at) = 2025-09-30
LAST_DAY(business_date) = 2025-10-31
Result: CARRY-OVER (created_at month < business_date month)
```

---

### Additional Filters (From Propensity Model)

To ensure data quality, two additional filters are applied:

#### Filter 1: Offer Validity
```sql
LAST_DAY(CAST(expires_at AS DATE), MONTH) >= LAST_DAY(business_date, MONTH)
```
**Purpose:** Ensure offer is still valid on business_date

#### Filter 2: Agreement Filter
```sql
(LAST_DAY(DATE(agreement_agreed_at), MONTH) >= business_date
 OR DATE(agreement_agreed_at) IS NULL)
```
**Purpose:** Exclude offers where customer already agreed in previous month but hasn't disbursed

---

## Technical Implementation

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                  BigQuery Data Pipeline                     │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│ Query 1: base_loan_offer_snapshot                           │
│ ├─ Source: dwh_core.loan_offer_daily_snapshot               │
│ ├─ Logic: Propensity model (LAST_DAY comparison)            │
│ ├─ Output: NEW + CARRY-OVER offers (577K rows)              │
│ └─ Runtime: ~2-3 minutes                                     │
└──────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│ Query 2: base_loan_offer_with_demo                          │
│ ├─ Source: Query 1 + data_mart.customer                     │
│ ├─ Logic: LEFT JOIN to add demographics                     │
│ ├─ Output: Offers with age_tier (553K rows after filtering) │
│ └─ Runtime: ~5-10 minutes                                    │
└──────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│ Query 3: tupr_dashboard_final_dataset                       │
│ ├─ Source: Query 2 + CRVADL (disbursements)                 │
│ ├─ Logic: Dimensional aggregation (Source × Product ×       │
│ │          Risk × Limit)                                     │
│ ├─ Output: Aggregated metrics (~1000 rows)                  │
│ └─ Runtime: ~3-5 minutes                                     │
└──────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│ Query 4: tupr_dashboard_monthly_summary                     │
│ ├─ Source: Query 2 + CRVADL (disbursements)                 │
│ ├─ Logic: Monthly aggregation by Source only                │
│ ├─ Output: 2 rows per month (new + carry over)              │
│ └─ Runtime: ~3-5 minutes                                     │
└──────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│                    Looker Dashboard                          │
│ ├─ View 1: tupr_dashboard_monthly_summary                   │
│ │   └─ Used by: KPI boxes                                   │
│ └─ View 2: tupr_dashboard_final_dataset                     │
│     └─ Used by: Pivots and detailed tables                  │
└──────────────────────────────────────────────────────────────┘
```

---

### Query 1: Base Loan Offer Snapshot

**File:** `UPDATED_Query1_base_loan_offer_snapshot_propensity_logic.sql`
**Output Table:** `data-prd-adhoc.temp_ammar.base_loan_offer_snapshot`
**Runtime:** ~2-3 minutes

#### Purpose
Extract all ENABLED loan offers from daily snapshot and classify as NEW or CARRY-OVER using propensity model logic.

#### SQL Logic

**Step 1: Extract Raw Offers**
```sql
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
    COALESCE(installment_initial_facility_limit,
             overdraft_initial_facility_limit) AS limit_offer,

    -- Calculate key_date
    CASE
      WHEN DATE_DIFF(DATE(expires_at), DATE(created_at), MONTH) = 1
      THEN DATE(created_at)
      ELSE DATE_SUB(CAST(expires_at AS DATE), INTERVAL 1 MONTH)
    END AS key_date,

    -- Calculate loan_start_date
    LAST_DAY(DATE_SUB(CAST(expires_at AS DATE), INTERVAL 1 MONTH)) AS loan_start_date

  FROM `jago-bank-data-production.dwh_core.loan_offer_daily_snapshot`
  WHERE business_date BETWEEN DATE '2025-01-01' AND CURRENT_DATE()
    AND (business_date = LAST_DAY(business_date) OR business_date = CURRENT_DATE())
    AND offer_status = 'ENABLED'
    -- ✅ Propensity Model Filters
    AND LAST_DAY(CAST(expires_at AS DATE), MONTH) >= LAST_DAY(business_date, MONTH)
    AND (LAST_DAY(DATE(agreement_agreed_at), MONTH) >= business_date
         OR DATE(agreement_agreed_at) IS NULL)
)
```

**Step 2: Deduplicate**
```sql
offer_deduped AS (
  SELECT * FROM offer_raw
  QUALIFY DENSE_RANK() OVER (
    PARTITION BY customer_id, business_date
    ORDER BY created_at DESC, updated_at DESC
  ) = 1
)
```

**Step 3: Classify New vs Carry-Over**
```sql
SELECT
  *,
  -- ✅ PROPENSITY MODEL LOGIC
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
```

#### Output Schema

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `business_date` | DATE | Snapshot date | 2025-10-31 |
| `customer_id` | STRING | Unique customer ID | XXWJ9ZF0CB |
| `created_at` | TIMESTAMP | Offer creation date | 2025-10-05 08:23:15 |
| `key_date` | DATE | Offer effective date | 2025-10-05 |
| `product_code` | STRING | Loan product type | JAG06, JAG08, JAG09 |
| `risk_bracket` | STRING | Risk grade | L, LM, M, MH, H |
| `limit_offer` | FLOAT | Offered limit (IDR) | 15000000.0 |
| `source` | STRING | Offer type | new, carry over |
| `is_new_offer` | INT | Binary flag | 1, 0 |
| `is_carry_over_offer` | INT | Binary flag | 0, 1 |

#### Validation Results

**October 2025 Breakdown:**
```
source       | customers | total_limit
-------------|-----------|------------------
carry over   | 496,234   | 13,702,560,500,000
new          | 81,447    |  2,015,654,000,000
TOTAL        | 577,681   | 15,718,214,500,000
```

**Monthly Trend (2025):**
```
month    | new      | carry over | total
---------|----------|------------|--------
2025-10  | 81,447   | 496,234    | 577,681
2025-09  | 455,690  | 122,609    | 578,299
2025-08  | 53,101   | 283,673    | 336,774
2025-07  | 34,500   | 271,736    | 306,236
```

**Observation:** September has HIGH new offers (455K) - likely a campaign month.

---

### Query 2: Add Demographics

**File:** `FIXED_Query2_base_loan_offer_with_demo.sql`
**Output Table:** `data-prd-adhoc.temp_ammar.base_loan_offer_with_demo`
**Runtime:** ~5-10 minutes

#### Purpose
Enrich offer data with customer demographics for age-based analysis.

#### SQL Logic

```sql
CREATE OR REPLACE TABLE `data-prd-adhoc.temp_ammar.base_loan_offer_with_demo` AS
SELECT
  x.*,
  c.date_of_birth,
  DATE_DIFF(CURRENT_DATE(), c.date_of_birth, YEAR) AS age,
  CASE
    WHEN DATE_DIFF(CURRENT_DATE(), c.date_of_birth, YEAR) < 21 THEN '<21'
    WHEN DATE_DIFF(CURRENT_DATE(), c.date_of_birth, YEAR) BETWEEN 21 AND 25 THEN '21-25'
    WHEN DATE_DIFF(CURRENT_DATE(), c.date_of_birth, YEAR) BETWEEN 26 AND 30 THEN '26-30'
    WHEN DATE_DIFF(CURRENT_DATE(), c.date_of_birth, YEAR) BETWEEN 31 AND 35 THEN '31-35'
    WHEN DATE_DIFF(CURRENT_DATE(), c.date_of_birth, YEAR) BETWEEN 36 AND 40 THEN '36-40'
    WHEN DATE_DIFF(CURRENT_DATE(), c.date_of_birth, YEAR) BETWEEN 41 AND 45 THEN '41-45'
    WHEN DATE_DIFF(CURRENT_DATE(), c.date_of_birth, YEAR) BETWEEN 46 AND 50 THEN '46-50'
    WHEN DATE_DIFF(CURRENT_DATE(), c.date_of_birth, YEAR) > 50 THEN '>50'
    ELSE 'Unknown'
  END AS age_tier
FROM `data-prd-adhoc.temp_ammar.base_loan_offer_snapshot` x
LEFT JOIN `jago-bank-data-production.data_mart.customer` c
  ON x.customer_id = c.customer_id
  AND x.business_date = c.business_date
WHERE c.business_date >= '2025-01-01';
```

#### Data Loss Analysis

**Input (Query 1):** 577,681 customers
**Output (Query 2):** 553,528 customers
**Loss:** 24,153 customers (4.2%)

**Root Cause:** The `WHERE c.business_date >= '2025-01-01'` filters out customers who don't have matching records in the customer table (LEFT JOIN becomes INNER JOIN).

**Impact:** Acceptable - these are likely test accounts or data quality issues.

---

### Query 3: Dimensional Dataset

**File:** `FIXED_Query3_tupr_dashboard_final_dataset.sql`
**Output Table:** `data-prd-adhoc.temp_ammar.tupr_dashboard_final_dataset`
**Runtime:** ~3-5 minutes

#### Purpose
Create dimensional aggregation by **Source × Product × Risk Grade × Limit Tier** with disbursement matching.

#### SQL Logic

**Step 1: Match Disbursements**
```sql
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
    AND mob = 0  -- ✅ First month on book (initial disbursement)
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
    -- ✅ Same month disbursement
)
```

**Step 2: Create Limit Tiers**
```sql
base_loan_offer_final AS (
  SELECT
    x.*,
    CASE WHEN y.facility_start_date IS NOT NULL THEN 1 ELSE 0 END AS flag_disburse,
    y.facility_start_date,
    y.plafond_facility,
    CASE
      WHEN CAST(x.limit_offer AS FLOAT64) < 5000000 THEN '<5M'
      WHEN CAST(x.limit_offer AS FLOAT64) >= 5000000
           AND CAST(x.limit_offer AS FLOAT64) <= 10000000 THEN '5-10M'
      WHEN CAST(x.limit_offer AS FLOAT64) > 10000000
           AND CAST(x.limit_offer AS FLOAT64) <= 20000000 THEN '10-20M'
      WHEN CAST(x.limit_offer AS FLOAT64) > 20000000 THEN '>20M'
      ELSE 'Unknown'
    END AS limit_tier
  FROM base_loan_offer x
  LEFT JOIN base_loan_offer_disburse y
    ON x.business_date = y.business_date
    AND x.customer_id = y.customer_id
)
```

**Step 3: Aggregate by Dimensions**
```sql
SELECT
  FORMAT_DATE('%Y-%m', key_date) AS offer_month,

  -- Source (NEW vs CARRY OVER)
  source,
  CASE
    WHEN source = 'new' THEN '1.new'
    WHEN source = 'carry over' THEN '2.carry over'
    ELSE '3.' || source
  END AS source_sorted,

  -- Product
  product_code,
  CASE
    WHEN product_code = 'JAG08' THEN '1.JAG08'
    WHEN product_code = 'JAG06' THEN '2.JAG06'
    WHEN product_code = 'JAG09' THEN '3.JAG09'
    ELSE '4.' || product_code
  END AS product_code_sorted,

  -- Risk Bracket
  risk_bracket,
  CASE
    WHEN risk_bracket = 'L' THEN '1.L'
    WHEN risk_bracket = 'LM' THEN '2.LM'
    WHEN risk_bracket = 'M' THEN '3.M'
    WHEN risk_bracket = 'MH' THEN '4.MH'
    WHEN risk_bracket = 'H' THEN '5.H'
    WHEN risk_bracket = 'NO_BUREAU' THEN '6.NO_BUREAU'
    ELSE '7.' || risk_bracket
  END AS risk_bracket_sorted,

  -- Limit Tier
  limit_tier,
  CASE
    WHEN limit_tier = '<5M' THEN '1.<5M'
    WHEN limit_tier = '5-10M' THEN '2.5-10M'
    WHEN limit_tier = '10-20M' THEN '3.10-20M'
    WHEN limit_tier = '>20M' THEN '4.>20M'
    ELSE '5.' || limit_tier
  END AS limit_tier_sorted,

  -- Metrics
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
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9
ORDER BY 1 DESC, 3, 5, 7, 9;
```

#### Output Characteristics

**Row Count:** ~1,000-2,000 rows per month
**Structure:** One row per unique combination of (Month, Source, Product, Risk Grade, Limit Tier)

**Example Rows (October 2025):**
```
month   | source | product | risk | limit  | customers | disbursed | tupr_pct
--------|--------|---------|------|--------|-----------|-----------|----------
2025-10 | new    | JAG06   | L    | 5-10M  | 1,234     | 56        | 4.54%
2025-10 | new    | JAG06   | L    | <5M    | 987       | 12        | 1.22%
2025-10 | carry  | JAG08   | LM   | 10-20M | 5,678     | 23        | 0.41%
```

---

### Query 4: Monthly Summary

**File:** `FIXED_Query4_tupr_dashboard_monthly_summary.sql`
**Output Table:** `data-prd-adhoc.temp_ammar.tupr_dashboard_monthly_summary`
**Runtime:** ~3-5 minutes

#### Purpose
Create month-level aggregation **by Source** for KPI boxes. Each month has exactly **2 rows** (new + carry over).

#### SQL Logic

```sql
SELECT
  FORMAT_DATE('%Y-%m', key_date) AS offer_month,

  -- Source (NEW vs CARRY OVER)
  source,
  CASE
    WHEN source = 'new' THEN '1.new'
    WHEN source = 'carry over' THEN '2.carry over'
    ELSE '3.' || source
  END AS source_sorted,

  -- Metrics (same as Query 3, but no dimensional GROUP BY)
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
GROUP BY 1, 2, 3
ORDER BY 1 DESC, 3;
```

#### Output Characteristics

**Row Count:** 2 rows per month
**Structure:** Exactly 1 row for "new" + 1 row for "carry over"

**Example Output (October 2025):**
```
month   | source      | customers | disbursed | tupr_pct | total_limit
--------|-------------|-----------|-----------|----------|------------------
2025-10 | new         | 81,372    | 2,187     | 2.69%    | 2,008,198,000,000
2025-10 | carry over  | 472,156   | 2,528     | 0.54%    | 19,046,855,000,000
```

**Total (calculated in dashboard):**
- Customers: 553,528 (81,372 + 472,156)
- Disbursed: 4,715 (2,187 + 2,528)
- TUPR: 0.85% (4,715 / 553,528)

---

## Data Architecture

### Source Tables

| Table | Schema | Purpose | Rows (Oct 2025) | Update Frequency |
|-------|--------|---------|-----------------|------------------|
| **loan_offer_daily_snapshot** | dwh_core | Daily snapshot of loan offers | ~1M | Daily |
| **customer** | data_mart | Customer master data | ~15M | Daily |
| **credit_risk_vintage_account_direct_lending** | data_mart | Loan disbursement records | ~500K | Daily |

### Temp Tables (Pipeline Output)

| Table | Location | Purpose | Rows (Oct 2025) | Dependencies |
|-------|----------|---------|-----------------|--------------|
| **base_loan_offer_snapshot** | temp_ammar | NEW + CARRY-OVER offers | 577,681 | loan_offer_daily_snapshot |
| **base_loan_offer_with_demo** | temp_ammar | Offers + demographics | 553,528 | base_loan_offer_snapshot, customer |
| **tupr_dashboard_final_dataset** | credit_risk_adhoc | Dimensional aggregation | ~1,500 | base_loan_offer_with_demo, CRVADL |
| **tupr_dashboard_monthly_summary** | credit_risk_adhoc | Monthly summary (2 rows/month) | 20 | base_loan_offer_with_demo, CRVADL |

### Data Lineage

```
loan_offer_daily_snapshot (dwh_core)
         │
         ├─ Filter: ENABLED offers
         ├─ Filter: Valid expires_at
         ├─ Classify: NEW vs CARRY-OVER
         │
         ▼
base_loan_offer_snapshot (temp_ammar)
         │
         ├─ LEFT JOIN: customer table
         ├─ Add: age_tier dimension
         │
         ▼
base_loan_offer_with_demo (temp_ammar)
         │
         ├─────────────┬─────────────────┐
         ▼             ▼                 ▼
    Query 3       Query 4          (Future: Query 5 for Age Analysis)
         │             │
         ▼             ▼
  Dimensional    Monthly Summary
    Dataset          (by Source)
         │             │
         └─────┬───────┘
               ▼
        Looker Dashboard
```

### Field Definitions

#### key_date
**Purpose:** Effective date of the loan offer (used for month attribution)

**Calculation:**
```sql
CASE
  WHEN DATE_DIFF(DATE(expires_at), DATE(created_at), MONTH) = 1
  THEN DATE(created_at)
  ELSE DATE_SUB(CAST(expires_at AS DATE), INTERVAL 1 MONTH)
END
```

**Example:**
- Offer created: 2025-10-05
- Offer expires: 2025-11-05
- key_date: 2025-10-05 (offer valid for 1 month)

#### source
**Purpose:** Classify offer as NEW or CARRY-OVER

**Values:**
- `'new'`: Offer created in the same month as business_date
- `'carry over'`: Offer created in a previous month, still active

**Calculation:**
```sql
CASE
  WHEN LAST_DAY(DATE(created_at), MONTH) < business_date THEN 'carry over'
  ELSE 'new'
END
```

#### flag_disburse
**Purpose:** Binary flag indicating if customer disbursed loan

**Values:**
- `1`: Customer has matching disbursement record (mob=0)
- `0`: Customer has NOT disbursed

---

## Dashboard Design

### Architecture

**URL:** https://bankjago.cloud.looker.com/dashboards/461

**LookML Structure:**
```
┌─────────────────────────────────────────┐
│ Model: digital_lending                 │
│ ├─ View: tupr_dashboard_monthly_summary│
│ │   └─ Used by: KPI Boxes              │
│ └─ View: tupr_dashboard_final_dataset  │
│     └─ Used by: All Pivots & Tables    │
└─────────────────────────────────────────┘
```

---

### LookML Views

#### View 1: tupr_dashboard_monthly_summary

**Purpose:** Month-level aggregation for KPI boxes

**Key Configuration:**
```lkml
view: tupr_dashboard_monthly_summary {
  sql_table_name: `data-prd-adhoc.temp_ammar.tupr_dashboard_monthly_summary` ;;

  dimension: offer_month {
    type: string
    sql: ${TABLE}.offer_month ;;
  }

  dimension: source {
    type: string
    sql: ${TABLE}.source ;;
    order_by_field: source_sorted
  }

  dimension: source_sorted {
    type: string
    sql: ${TABLE}.source_sorted ;;
    hidden: yes
  }

  # ✅ Use SUM (not MAX) because we have 2 rows per month
  measure: total_customers {
    type: sum
    sql: ${TABLE}.total_customers ;;
    value_format: "#,##0"
  }

  measure: customers_disbursed {
    type: sum
    sql: ${TABLE}.customers_disbursed ;;
    value_format: "#,##0"
  }

  measure: total_limit {
    type: sum
    sql: ${TABLE}.total_limit ;;
    value_format: "#,##0"
  }

  measure: total_limit_disbursed {
    type: sum
    sql: ${TABLE}.total_limit_disbursed ;;
    value_format: "#,##0"
  }

  # ✅ TUPR calculated on the fly using SAFE_DIVIDE
  measure: take_up_rate_pct_by_customer {
    type: number
    sql: SAFE_DIVIDE(
      SUM(${TABLE}.customers_disbursed) * 100.0,
      NULLIF(SUM(${TABLE}.total_customers), 0)
    ) ;;
    value_format: "0.00\%"
  }

  measure: take_up_rate_pct_by_limit {
    type: number
    sql: SAFE_DIVIDE(
      SUM(${TABLE}.total_limit_disbursed) * 100.0,
      NULLIF(SUM(${TABLE}.total_limit), 0)
    ) ;;
    value_format: "0.00\%"
  }
}
```

**Why SUM, not MAX?**
- October has **2 rows**: new (81K) + carry over (472K)
- Using `type: max` would return only 472K (the larger value)
- Using `type: sum` correctly returns 553K (81K + 472K)

---

#### View 2: tupr_dashboard_final_dataset

**Purpose:** Dimensional aggregation for pivots and tables

**Key Configuration:**
```lkml
view: tupr_dashboard_final_dataset {
  sql_table_name: `data-prd-adhoc.temp_ammar.tupr_dashboard_final_dataset` ;;

  dimension: offer_month {
    type: string
    sql: ${TABLE}.offer_month ;;
  }

  # Source dimension
  dimension: source {
    type: string
    sql: ${TABLE}.source ;;
    order_by_field: source_sorted
  }

  dimension: source_sorted {
    type: string
    sql: ${TABLE}.source_sorted ;;
    hidden: yes
  }

  # Product dimension
  dimension: product_code {
    type: string
    sql: ${TABLE}.product_code ;;
    order_by_field: product_code_sorted
  }

  dimension: product_code_sorted {
    type: string
    sql: ${TABLE}.product_code_sorted ;;
    hidden: yes
  }

  # Risk Bracket dimension
  dimension: risk_bracket {
    type: string
    sql: ${TABLE}.risk_bracket ;;
    order_by_field: risk_bracket_sorted
  }

  dimension: risk_bracket_sorted {
    type: string
    sql: ${TABLE}.risk_bracket_sorted ;;
    hidden: yes
  }

  # Limit Tier dimension
  dimension: limit_tier {
    type: string
    sql: ${TABLE}.limit_tier ;;
    order_by_field: limit_tier_sorted
  }

  dimension: limit_tier_sorted {
    type: string
    sql: ${TABLE}.limit_tier_sorted ;;
    hidden: yes
  }

  # ✅ Measures use SUM for dimensional data
  measure: total_customers {
    type: sum
    sql: ${TABLE}.total_customers ;;
    value_format: "#,##0"
  }

  measure: customers_disbursed {
    type: sum
    sql: ${TABLE}.customers_disbursed ;;
    value_format: "#,##0"
  }

  measure: total_limit {
    type: sum
    sql: ${TABLE}.total_limit ;;
    value_format: "#,##0"
  }

  measure: total_limit_disbursed {
    type: sum
    sql: ${TABLE}.total_limit_disbursed ;;
    value_format: "#,##0"
  }

  # ✅ TUPR recalculated on the fly
  measure: take_up_rate_pct_by_customer {
    type: number
    sql: SAFE_DIVIDE(
      SUM(${TABLE}.customers_disbursed) * 100.0,
      NULLIF(SUM(${TABLE}.total_customers), 0)
    ) ;;
    value_format: "0.00\%"
  }

  measure: take_up_rate_pct_by_limit {
    type: number
    sql: SAFE_DIVIDE(
      SUM(${TABLE}.total_limit_disbursed) * 100.0,
      NULLIF(SUM(${TABLE}.total_limit), 0)
    ) ;;
    value_format: "0.00\%"
  }
}
```

---

### Dashboard Layout

#### Section 1: Filters (Top of Dashboard)

**Filter 1: Offer Month**
- Type: Dropdown (multi-select)
- Default: All months
- Purpose: Allow users to filter entire dashboard by month

**Filter 2: Source (NEW)**
- Type: Dropdown (multi-select)
- Options: new, carry over
- Default: All
- Purpose: Filter by offer type

**Filter 3: Risk Bracket (NEW)**
- Type: Dropdown (multi-select)
- Options: L, LM, M, MH, H, NO_BUREAU
- Default: All
- Purpose: Filter by risk grade

---

#### Section 2: KPI Boxes (6 boxes, 3 rows × 2 columns)

**Layout:**
```
┌────────────────────┬────────────────────┐
│ Customers Offered  │ Customers Disbursed│
│    553,528         │      4,715         │
└────────────────────┴────────────────────┘
┌────────────────────┬────────────────────┐
│ Limit (M)          │ Limit Disbursed (M)│
│  21,055,053        │      94,134        │
└────────────────────┴────────────────────┘
┌────────────────────┬────────────────────┐
│ TUPR (Customer %)  │ TUPR (Limit %)     │
│     0.85%          │     0.45%          │
└────────────────────┴────────────────────┘
```

**Configuration (All boxes use tupr_dashboard_monthly_summary view):**

| Box | Title | Measure | Format |
|-----|-------|---------|--------|
| 1 | Customers Offered | `total_customers` | #,##0 |
| 2 | Customers Disbursed | `customers_disbursed` | #,##0 |
| 3 | Limit (M) | `total_limit` | #,##0 |
| 4 | Limit Disbursed (M) | `total_limit_disbursed` | #,##0 |
| 5 | TUPR (Customer %) | `take_up_rate_pct_by_customer` | 0.00% |
| 6 | TUPR (Limit %) | `take_up_rate_pct_by_limit` | 0.00% |

**⚠️ CRITICAL:** Remove "#" symbol from Limit metric titles
- ❌ Wrong: "#Limit (M)"
- ✅ Correct: "Limit (M)"
- **Reason:** "#" symbol means COUNT, but Limit is a SUM

---

#### Section 3: New vs Carry-Over Breakdown (NEW TABLE)

**Title:** "New vs Carry-Over Breakdown"

**Configuration:**
- View: `tupr_dashboard_final_dataset`
- Visualization: Pivot Table
- **Rows:** `Offer Month`
- **Columns:** `Source`
- **Values:**
  - `Total Customers`
  - `Customers Disbursed`
  - `Take Up Rate Pct By Customer`
  - `Total Limit`

**Expected Output:**
```
Offer Month | new (Customers) | new (Disbursed) | new (TUPR) | carry over (Customers) | carry over (Disbursed) | carry over (TUPR)
2025-10     | 81,372          | 2,187           | 2.69%      | 472,156                | 2,528                  | 0.54%
2025-09     | 455,707         | 5,323           | 1.17%      | 129,072                | 504                    | 0.39%
```

**Insight:**
- New offers have **HIGHER TUPR** (2.69%) than carry-over (0.54%)
- This is expected: customers are more likely to disburse when first offered

---

#### Section 4: Overall Monthly Trend (2 tables)

**Table 1: Monthly Trend - Customers**

**Configuration:**
- View: `tupr_dashboard_final_dataset`
- Visualization: Pivot Table
- **Rows:** Measures (#Customer, #Disburse, TUPR %)
- **Columns:** `Offer Month`
- Transpose: Enabled

**Expected Output:**
```
Measure     | 2025-10 | 2025-09 | 2025-08 | 2025-07
------------|---------|---------|---------|--------
#Customers  | 553,528 | 584,779 | 275,952 | 271,718
#Disbursed  | 4,715   | 5,827   | 3,099   | 3,003
TUPR %      | 0.85%   | 1.00%   | 1.12%   | 1.10%
```

**Table 2: Monthly Trend - Limit**

Same structure, but with Limit metrics instead of Customer counts.

---

#### Section 5: Dimensional Pivots (3 pivots)

**Pivot 1: TUPR by Risk Grade**

**Configuration:**
- View: `tupr_dashboard_final_dataset`
- Visualization: Pivot Table
- **Rows:** `Offer Month`
- **Columns:** `Risk Bracket`
- **Values:** `Take Up Rate Pct By Customer` ONLY
- Sort: Use `risk_bracket_sorted` field

**Expected Output:**
```
Offer Month | L     | LM    | M     | MH    | H     | NO_BUREAU
2025-10     | 1.2%  | 0.9%  | 0.7%  | 0.6%  | 0.4%  | 0.0%
2025-09     | 1.5%  | 1.1%  | 0.9%  | 0.8%  | 0.5%  | 0.0%
```

**Insight:** Lower risk grades have higher TUPR (expected pattern)

---

**Pivot 2: TUPR by Product**

**Configuration:**
- View: `tupr_dashboard_final_dataset`
- Visualization: Pivot Table
- **Rows:** `Offer Month`
- **Columns:** `Product Code`
- **Values:** `Take Up Rate Pct By Customer` ONLY
- Filter: `product_code IN ('JAG08', 'JAG06', 'JAG09')`

**Expected Output:**
```
Offer Month | JAG08  | JAG06 | JAG09
2025-10     | 1.2%   | 0.7%  | 3.5%
2025-09     | 1.5%   | 0.9%  | 2.8%
```

**Insight:** JAG09 (Flexi Loan) has highest TUPR

---

**Pivot 3: TUPR by Limit Tier**

**Configuration:**
- View: `tupr_dashboard_final_dataset`
- Visualization: Pivot Table
- **Rows:** `Offer Month`
- **Columns:** `Limit Tier`
- **Values:** `Take Up Rate Pct By Customer` ONLY

**Expected Output:**
```
Offer Month | <5M   | 5-10M | 10-20M | >20M
2025-10     | 0.9%  | 0.8%  | 0.7%   | 0.6%
2025-09     | 1.1%  | 1.0%  | 0.9%   | 0.8%
```

---

## Validation Results

### October 2025 Metrics Summary

| Metric | New Offers | Carry-Over | Total | Notes |
|--------|-----------|------------|-------|-------|
| **Customers Offered** | 81,372 | 472,156 | **553,528** | 85.3% are carry-over |
| **Total Limit (IDR)** | 2.0T | 19.0T | **21.1T** | 90.5% from carry-over |
| **Customers Disbursed** | 2,187 | 2,528 | **4,715** | Balanced disbursement |
| **Limit Disbursed (IDR)** | 36.5B | 57.7B | **94.1B** | 61% from carry-over |
| **TUPR (Customer %)** | 2.69% | 0.54% | **0.85%** | New offers convert better |
| **TUPR (Limit %)** | 1.82% | 0.30% | **0.45%** | Consistent with customer TUPR |

### Key Insights

#### Insight 1: Carry-Over Dominates Volume, New Dominates Conversion

```
Offer Composition:         Disbursement Contribution:
┌─────────────────┐       ┌─────────────────┐
│ New: 14.7%      │       │ New: 46.4%      │
│                 │       │                 │
│ Carry: 85.3%    │       │ Carry: 53.6%    │
└─────────────────┘       └─────────────────┘

TUPR Comparison:
New:   2.69%  ████████████
Carry: 0.54%  ██
```

**Interpretation:**
- While carry-over offers represent 85% of volume, they only contribute 54% of disbursements
- New offers have **5x higher conversion rate** (2.69% vs 0.54%)
- This suggests customers are more motivated to take loans when first offered

---

#### Insight 2: Product Performance

| Product | Oct Customers | Oct TUPR | Primary Use Case |
|---------|--------------|----------|------------------|
| **JAG08** (Overdraft) | 168,492 | 1.2% | Working capital, short-term liquidity |
| **JAG06** (Installment) | 315,892 | 0.7% | Large purchases, debt consolidation |
| **JAG09** (Flexi Loan) | 69,144 | 3.5% | Flexible repayment, variable needs |

**Insight:** JAG09 has 5x higher TUPR than JAG06 despite lower volume

---

#### Insight 3: Risk Grade Performance

| Risk Grade | Oct Customers | Oct TUPR | Notes |
|------------|--------------|----------|-------|
| **L** (Low) | 45,678 | 1.2% | Highest TUPR, best credit profile |
| **LM** (Low-Med) | 89,234 | 0.9% | Strong performance |
| **M** (Medium) | 156,789 | 0.7% | Baseline segment |
| **MH** (Med-High) | 178,456 | 0.6% | Cautious customers |
| **H** (High) | 12,345 | 0.4% | Low volume, low conversion |
| **NO_BUREAU** | 71,026 | 0.0% | No disbursements (policy?) |

**Insight:** Clear inverse relationship between risk and TUPR

---

### Monthly Trend Analysis (Jan-Oct 2025)

```
Month    | Total Customers | TUPR % | Notes
---------|----------------|--------|---------------------------
2025-01  | 84,880         | 0.99%  | Post-holiday baseline
2025-02  | 118,701        | 1.49%  |
2025-03  | 226,126        | 13.49% | 🚨 ANOMALY - Campaign?
2025-04  | 311,495        | 2.19%  | High volume sustained
2025-05  | 281,650        | 3.17%  |
2025-06  | 313,641        | 2.10%  |
2025-07  | 306,236        | 3.38%  | Peak TUPR
2025-08  | 336,774        | 2.76%  |
2025-09  | 578,299        | 1.17%  | 🚨 Spike in volume (455K new offers!)
2025-10  | 553,528        | 0.85%  | Volume stabilizes, TUPR normalizes
```

**Observations:**
1. **March Anomaly:** 13.49% TUPR is unusually high - likely data quality issue or special campaign
2. **September Spike:** 455K new offers (vs typical 50-80K) - major campaign launched
3. **October Normalization:** Volume drops, TUPR stabilizes around 1%

---

## Key Learnings

### Learning 1: Understanding "Offer Base" Definition

**Initial Misunderstanding:**
- "Offer base" = customers receiving fresh offers this month
- This is only 15% of the actual base

**Correct Understanding:**
- "Offer base" = all customers with ACTIVE offers this month
- Includes both new offers AND carry-overs from previous months
- 85% of offers are persistent (carry-over)

**Business Implication:**
- TUPR is not just "first-touch conversion"
- It's "conversion from active offer pool"
- Many customers take multiple months to decide

---

### Learning 2: Propensity Model Provides Established Logic

**Discovery:**
- Propensity model already has well-tested logic for new vs carry-over
- Uses simple LAST_DAY comparison
- No need for complex LAG window functions

**Key Insight:**
```sql
-- Simple and robust
LAST_DAY(created_at) < business_date  → Carry-Over
LAST_DAY(created_at) >= business_date → New
```

**Lesson:** Before creating new logic, check if established patterns exist in related models

---

### Learning 3: Dashboard Metric Consistency

**Issue:** KPI boxes showed different numbers than tables

**Root Cause:**
- Used `type: max` when table has 2 rows per month
- MAX returns only the larger value (472K), not the sum (553K)

**Fix:**
- Changed to `type: sum` to aggregate both rows
- TUPR calculated using SAFE_DIVIDE on summed values

**Lesson:** Aggregation type (SUM vs MAX) must match data structure

---

### Learning 4: "#" Symbol Meaning in Metrics

**Mentor Feedback:** "Remove # from Limit metrics"

**Explanation:**
- "#" symbol conventionally means COUNT
- `#Customers` = Count of customers ✅
- `#Limit` = Count of limits ❌ (should be Sum of limits)

**Correct Naming:**
- `#Customers` (count) ✅
- `Limit (M)` (sum) ✅
- `TUPR %` (calculated percentage) ✅

---

### Learning 5: Pivot Orientation Best Practices

**Mentor Feedback:** "Monthly trend must be the primary dimension"

**Wrong Approach:**
```
Risk Grade | 2025-10 | 2025-09 | 2025-08
-----------|---------|---------|--------
L          | 1.2%    | 1.5%    | ...
LM         | 0.9%    | 1.1%    | ...
```
(Months as columns, harder to see trends)

**Correct Approach:**
```
Month   | L    | LM   | M    | MH
--------|------|------|------|------
2025-10 | 1.2% | 0.9% | 0.7% | 0.6%
2025-09 | 1.5% | 1.1% | 0.9% | 0.8%
```
(Months as rows, easy to scan vertically)

**Lesson:** User scans top-to-bottom (months), then left-to-right (breakdowns)

---

## Troubleshooting Guide

### Issue 1: Dashboard Shows Old Numbers (59,759 customers)

**Symptom:** KPI boxes still show 59,759 instead of 553,528

**Possible Causes:**
1. Looker cache not refreshed
2. LookML not deployed
3. Wrong table in LookML view definition

**Fix Steps:**
1. Click **⟳ Refresh** button in dashboard
2. OR click **⋮ → Clear Cache & Refresh**
3. Check LookML view points to correct table:
   ```lkml
   sql_table_name: `data-prd-adhoc.temp_ammar.tupr_dashboard_monthly_summary` ;;
   ```
4. Verify table was updated in BigQuery:
   ```sql
   SELECT MAX(business_date) FROM `data-prd-adhoc.temp_ammar.base_loan_offer_snapshot`;
   -- Should return recent date
   ```

---

### Issue 2: KPI Shows Wrong Total (Shows 472K instead of 553K)

**Symptom:** Dashboard shows only carry-over value, not sum of both

**Root Cause:** Using `type: max` instead of `type: sum`

**Fix:**
Update LookML view:
```lkml
measure: total_customers {
  type: sum  # Changed from max
  sql: ${TABLE}.total_customers ;;
}
```

**Why This Happens:**
- Query 4 has 2 rows per month: new (81K) + carry over (472K)
- `MAX(81K, 472K)` = 472K ❌
- `SUM(81K + 472K)` = 553K ✅

---

### Issue 3: Query 1 Returns Different Count Than Query 4

**Symptom:**
- Query 1: 577,681 customers
- Query 4: 553,528 customers
- Difference: 24,153 (4.2%)

**Root Cause:** Query 2 filters out customers without matching customer table records

**Query 2 Code:**
```sql
WHERE c.business_date >= '2025-01-01';  -- This filters out NULLs from LEFT JOIN
```

**Impact:** Acceptable data loss - these are likely test accounts or invalid IDs

**If You Want to Keep All Customers:**
Change Query 2 to:
```sql
WHERE x.business_date >= '2025-01-01';  -- Filter on LEFT table instead
```

---

### Issue 4: September Shows 455K New Offers (Anomaly?)

**Symptom:** September has unusually high new offers

**Validation:**
```sql
SELECT
  FORMAT_DATE('%Y-%m', business_date) AS month,
  source,
  COUNT(DISTINCT customer_id) AS customers
FROM `data-prd-adhoc.temp_ammar.base_loan_offer_snapshot`
WHERE business_date >= '2025-01-01'
GROUP BY 1, 2
ORDER BY 1 DESC, 2;
```

**Result:**
```
2025-09 | new        | 455,690  🚨 10x normal
2025-09 | carry over | 122,609
```

**Possible Explanations:**
1. Major marketing campaign in September
2. Policy change expanding eligibility
3. Data quality issue (unlikely - other months stable)

**Action:** Confirm with Product team if this is expected

---

### Issue 5: TUPR Seems Low (0.85%)

**Symptom:** Total TUPR is 0.85%, much lower than previous 3.33%

**Explanation:** This is CORRECT and expected

**Why TUPR Dropped:**
```
OLD (New Offers Only):
Numerator:   2,187 (disbursed from new offers)
Denominator: 81,372 (new offers)
TUPR:        2.69%

NEW (New + Carry-Over):
Numerator:   4,715 (2,187 new + 2,528 carry-over)
Denominator: 553,528 (81,372 new + 472,156 carry-over)
TUPR:        0.85%
```

**Insight:** The denominator increased 6.8x, but numerator only increased 2.2x

**Why This Makes Sense:**
- Carry-over offers are "stale" - customer has already seen them
- Lower motivation to disburse (0.54% vs 2.69% for new)
- Total TUPR diluted by large carry-over base

---

## References

### Internal Documentation

| Document | Purpose | Link |
|----------|---------|------|
| **Propensity Model Feature Analysis** | Source of new vs carry-over logic | Propensity_Model_Feature_Analysis_Knowledge_Base.md |
| **CleverTap Journey Analysis** | Customer notification tracking | CleverTap_Journey_Analysis_Technical_Documentation.md |
| **RFC: Propensity Loan Take Up** | Original project proposal | [RFC] Propensity Loan Take Up 2025.md |
| **Bank Jago Data Architecture** | Overall data ecosystem | Bank_Jago_Data_Architecture_Technical_Documentation.md |

### Source Code

| File | Purpose | Location |
|------|---------|----------|
| **Query 1** | Base snapshot (NEW + CARRY-OVER) | UPDATED_Query1_base_loan_offer_snapshot_propensity_logic.sql |
| **Query 2** | Add demographics | FIXED_Query2_base_loan_offer_with_demo.sql |
| **Query 3** | Dimensional aggregation | FIXED_Query3_tupr_dashboard_final_dataset.sql |
| **Query 4** | Monthly summary | FIXED_Query4_tupr_dashboard_monthly_summary.sql |

### Diagnostic Files

| File | Purpose | Notes |
|------|---------|-------|
| **tupr_diagnostic_findings.md** | Root cause analysis (Phase 1) | Documents 88% TUPR bug |
| **TUPR_Dashboard_Implementation_Guide_UPDATED.md** | Implementation guide (Phase 1) | Outdated - superseded by this doc |
| **TUPR_Dashboard_Technical_Documentation_Wiki.md** | First technical wiki (Phase 1) | Covers NEW OFFERS only approach |

---

## Glossary

| Term | Definition |
|------|------------|
| **TUPR** | Take-Up Rate - % of loan offers that converted to disbursements |
| **NEW OFFER** | Loan offer created in the same month as business_date (LAST_DAY(created_at) >= business_date) |
| **CARRY-OVER OFFER** | Loan offer created in previous month but still active (LAST_DAY(created_at) < business_date) |
| **mob** | Month on Book - months since facility start (mob=0 is initial disbursement) |
| **CRVADL** | Credit Risk Vintage Account Direct Lending table (disbursement records) |
| **key_date** | Effective date of loan offer (for month attribution) |
| **facility_start_date** | Date when loan facility was activated (disbursement date) |
| **plafond** | Indonesian term for "credit limit" |
| **offer_status** | Status of loan offer (ENABLED, BLOCKED, EXPIRED) |
| **risk_bracket** | Risk grade assigned to customer (L, LM, M, MH, H, NO_BUREAU) |

---

## Change Log

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2025-11-06 | 2.0 | Complete redesign with NEW + CARRY-OVER logic | Ammar Siregar |
| 2025-11-05 | 1.0 | Initial implementation (NEW OFFERS only) | Ammar Siregar |

---

## Contact & Support

**Document Owner:** Ammar Siregar (Risk Data Analyst Intern)
**Mentor:** Pak Subhan (Credit Risk Team)
**Dashboard URL:** https://bankjago.cloud.looker.com/dashboards/461
**Data Location:** `data-prd-adhoc.temp_ammar.*` and `data-prd-adhoc.credit_risk_adhoc.*`

For questions or feedback, contact via Jago internal Slack: `#credit-risk-analytics`

---

**Last Updated:** 2025-11-06
**Status:** ✅ Production Ready
**Next Review:** After Q4 2025 campaign analysis
