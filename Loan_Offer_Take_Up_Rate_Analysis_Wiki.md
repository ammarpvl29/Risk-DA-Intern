# Loan Offer Take Up Rate (TUPR) Analysis - Wiki Entry

**Date:** 2025-10-31
**Author:** Ammar Siregar
**Mentor:** Pak Subhan
**Task Type:** Business Analytics - Take Up Rate Dashboard
**Status:** ✅ Completed (Pending Looker deployment)

---

## 📋 Table of Contents

1. [Business Context](#business-context)
2. [Technical Challenge](#technical-challenge)
3. [Implementation Journey](#implementation-journey)
4. [Query Optimization](#query-optimization)
5. [Final Solution](#final-solution)
6. [Key Findings](#key-findings)
7. [Dashboard Design](#dashboard-design)
8. [Lessons Learned](#lessons-learned)
9. [Next Steps](#next-steps)

---

## Business Context

### What is Take Up Rate?

**Definition:**
> Take Up Rate (TUPR) measures the conversion from loan offers to actual disbursements.

**Formula:**
```
TUPR = (Number of Disbursed Loans / Total Number of Loan Offers) × 100%
```

**Business Question:**
> "Of all customers we offer loans to in a given month (e.g., 300,000 people in August), how many of them actually disburse (e.g., 5,000 people)?"

### Why This Matters

**For Business:**
- Measures **effectiveness** of loan offering strategy
- Indicates **customer acceptance** and **product-market fit**
- Helps optimize **offer targeting** and **limit sizing**
- Critical for **revenue forecasting** and **capital planning**

**For Risk Team:**
- Identifies which **risk segments** convert best
- Validates **offer decisioning** logic
- Informs **credit policy** adjustments

**For Product Team:**
- Highlights **product performance** (JAG06 vs JAG08 vs JAG09)
- Reveals **friction points** in customer journey
- Guides **feature prioritization**

---

## Technical Challenge

### The Core Problem

**Mentor's Guidance (Pak Subhan):**
> "Base population (denominator) MUST be total offers from loan_offer_snapshot table. If you start with disbursement table (~5k records), you lose all non-converters and cannot calculate TUPR."

**Technical Requirements:**
1. ✅ Base table: `loan_offer_daily_snapshot` (ALL offers)
2. ✅ Disbursement table: `credit_risk_vintage_account_direct_lending` (MOB=0 loans)
3. ✅ Matching logic: `facility_start_date > key_date`
4. ✅ Deduplication: Handle multiple offers per customer (especially JAG09)
5. ✅ Dimensions: Product, Risk Grade, Limit Tier, Age Tier
6. ✅ Performance: Customer join causing 20+ min query time

### Analytical Framework

**Main Profile (Loan Characteristics):**
- OfferDate (monthly trend)
- Product Type (JAG06, JAG08, JAG09)
- Risk Grade (H, L, LM, M, MH, NO_BUREAU)
- Limit Tiering (<5M, 5-10M, 10-20M, >20M)

**Demographic Profile (Customer Characteristics):**
- Age Tier (<21, 21-25, 26-30, 31-35, 36-40, 41-45, 46-50, >50)

---

## Implementation Journey

### Iteration 1: Basic Exploration

**Objective:** Understand base loan offer data structure

**Query:**
```sql
WITH base_loan_offer AS (
  SELECT
    business_date,
    customer_id,
    product_code,
    COALESCE(installment_initial_facility_limit, overdraft_initial_facility_limit) AS limit_offer
  FROM `jago-bank-data-production.dwh_core.loan_offer_daily_snapshot`
  WHERE business_date BETWEEN DATE '2025-01-01' AND CURRENT_DATE()
    AND (business_date = LAST_DAY(business_date) OR business_date = CURRENT_DATE())
    AND offer_status NOT IN ('REJECTED', 'CLOSED')
  QUALIFY DENSE_RANK() OVER (
    PARTITION BY customer_id, business_date
    ORDER BY agreement_agreed_at DESC, updated_at DESC
  ) = 1
)

SELECT
  FORMAT_DATE('%Y-%m', business_date) AS offer_month,
  COUNT(DISTINCT customer_id) AS total_customers
FROM base_loan_offer
GROUP BY offer_month
ORDER BY offer_month;
```

**Results:**
| Month | Total Customers |
|-------|-----------------|
| 2025-01 | 94,136 |
| 2025-02 | 134,499 |
| 2025-03 | 271,425 |
| ... | ... |
| 2025-10 | 813,962 |

**✅ Validation:** Growth trajectory confirmed (94K → 813K)

---

### Iteration 2: Add Disbursement Logic

**Objective:** Calculate TUPR by matching offers to disbursements

**Key SQL Logic:**
```sql
WITH
base_loan_offer AS (...),

crvadl AS (
  SELECT DISTINCT
    lfs_customer_id AS customer_id,
    facility_start_date,
    MAX(plafond_facility) AS plafond_facility
  FROM `jago-bank-data-production.data_mart.credit_risk_vintage_account_direct_lending`
  WHERE deal_type IN ('JAG06', 'JAG08', 'JAG09')
    AND mob = 0  -- First month = newly disbursed
  GROUP BY customer_id, facility_start_date
),

base_loan_offer_disburse AS (
  SELECT x.*, y.*
  FROM base_loan_offer x
  INNER JOIN crvadl y
    ON x.customer_id = y.customer_id
    AND y.facility_start_date > x.key_date  -- Disbursed AFTER offer
),

base_loan_offer_final AS (
  SELECT
    x.*,
    CASE WHEN y.facility_start_date IS NOT NULL THEN 1 ELSE 0 END AS flag_disburse
  FROM base_loan_offer x
  LEFT JOIN base_loan_offer_disburse y
    ON x.business_date = y.business_date
    AND x.customer_id = y.customer_id
)

SELECT
  COUNT(DISTINCT customer_id) AS total_offered,
  COUNT(DISTINCT CASE WHEN flag_disburse = 1 THEN customer_id END) AS disbursed,
  ROUND(...) AS take_up_rate_pct
FROM base_loan_offer_final;
```

**Results:**
| Month | Offered | Disbursed | TUPR % |
|-------|---------|-----------|--------|
| 2025-01 | 94,136 | 4,364 | 4.64% |
| 2025-08 | 486,433 | 24,020 | 4.94% |
| 2025-10 | 813,962 | 25,508 | 3.13% |

**✅ Validation:** TUPR calculation working correctly

---

### Iteration 3: Add Product Dimension

**Objective:** Break down TUPR by product

**SQL Addition:**
```sql
SELECT
  offer_month,
  product_code,
  COUNT(DISTINCT customer_id) AS total_customers,
  COUNT(DISTINCT CASE WHEN flag_disburse = 1 THEN customer_id END) AS customers_disbursed,
  ROUND(...) AS take_up_rate_pct
FROM base_loan_offer_final
GROUP BY offer_month, product_code
ORDER BY offer_month, product_code;
```

**Key Findings:**
| Product | Total Offers | Disbursed | TUPR % |
|---------|--------------|-----------|--------|
| JAG08 | 3,003,016 | 172,780 | **5.75%** |
| JAG06 | 913,638 | 15,249 | **1.67%** |
| JAG09 | 71,521 | 830 | **1.16%** |
| JAG01 | 7,123 | 0 | **0.00%** |

**🔍 Insight:** JAG08 dominates, JAG06 underperforms despite high volume

---

### Iteration 4: Add Risk Grade Dimension

**Objective:** Understand TUPR by risk bracket

**Results:**
| Risk Bracket | Offers | Disbursed | TUPR % | Insight |
|--------------|--------|-----------|--------|---------|
| L (Low) | 1,040,445 | 33,910 | 3.26% | Largest segment, conservative |
| LM (Low-Med) | 1,182,743 | 32,310 | 2.73% | Balanced |
| **M (Medium)** | **1,178,050** | **39,190** | **3.33%** | **Sweet spot** |
| MH (Med-High) | 500,567 | 12,096 | 2.42% | Higher risk |
| H (High) | 36,307 | 1,591 | 4.38% | Small but converts |
| NO_BUREAU | 68,525 | 194 | 0.28% | Very low conversion |

**🔍 Insight:** Medium risk customers have highest disbursement volume

---

### Iteration 5: Add Limit Tiering

**Mentor's Guidance:**
```
< 5,000,000        → <5M
≥ 5M and ≤ 10M     → 5-10M
> 10M and ≤ 20M    → 10-20M
> 20,000,000       → >20M
```

**SQL Logic:**
```sql
CASE
  WHEN CAST(limit_offer AS FLOAT64) < 5000000 THEN '<5M'
  WHEN CAST(limit_offer AS FLOAT64) >= 5000000 AND CAST(limit_offer AS FLOAT64) <= 10000000 THEN '5-10M'
  WHEN CAST(limit_offer AS FLOAT64) > 10000000 AND CAST(limit_offer AS FLOAT64) <= 20000000 THEN '10-20M'
  WHEN CAST(limit_offer AS FLOAT64) > 20000000 THEN '>20M'
  ELSE 'Unknown'
END AS limit_tier
```

**Results:**
| Limit Tier | Offers | Total Limit (IDR) | Disbursed | TUPR % |
|------------|--------|-------------------|-----------|--------|
| **<5M** | 161,313 | 568B | 9,631 | **5.97%** ⬆️ |
| 5-10M | 868,436 | 6.6T | 31,900 | 3.67% |
| 10-20M | 1,188,823 | 18.1T | 45,757 | 3.85% |
| **>20M** | 1,778,119 | 88.2T | 54,782 | **3.08%** ⬇️ |

**🔍 KEY INSIGHT:** Inverse relationship - smaller limits convert BETTER!

---

### Iteration 6: Add Demographics (Age Tier)

**Challenge:** Customer table join causing 20+ minute query time

**Problem:**
```sql
-- ❌ SLOW: Re-joining customer table in every query
WITH base_loan_offer AS (...),
base_loan_offer_with_demo AS (
  SELECT x.*, c.age_group
  FROM base_loan_offer x
  LEFT JOIN customer c  -- 20+ minutes!
    ON x.customer_id = c.customer_id
    AND x.business_date = c.business_date
)
```

**Solution:** Materialized temp tables (next section)

---

## Query Optimization

### The Performance Problem

**Initial Approach (CTE-based):**
- Query time: **20+ minutes**
- BigQuery data scanned: **~500 GB**
- Root cause: Re-joining massive customer table every query run

### Mentor's Solution: Physical Tables

**Pak Subhan's Guidance:**
> "Make it a physical table, then join with customer table. This way you only pay the join cost once."

### Step 1: Create Base Loan Offer Snapshot

**Purpose:** Materialize filtered and deduplicated loan offers

```sql
CREATE OR REPLACE TABLE `data-prd-adhoc.temp_ammar.base_loan_offer_snapshot` AS
SELECT DISTINCT
  business_date,
  customer_id,
  CASE
    WHEN DATE_DIFF(DATE(expires_at), DATE(created_at), MONTH) = 1
    THEN DATE(created_at)
    ELSE DATE_SUB(CAST(expires_at AS DATE), INTERVAL 1 MONTH)
  END AS key_date,
  product_code,
  offer_status,
  risk_bracket,
  COALESCE(installment_initial_facility_limit, overdraft_initial_facility_limit) AS limit_offer
FROM `jago-bank-data-production.dwh_core.loan_offer_daily_snapshot`
WHERE business_date BETWEEN DATE '2025-01-01' AND CURRENT_DATE()
  AND (business_date = LAST_DAY(business_date) OR business_date = CURRENT_DATE())
  AND offer_status NOT IN ('REJECTED', 'CLOSED')
QUALIFY DENSE_RANK() OVER (
  PARTITION BY customer_id, business_date
  ORDER BY agreement_agreed_at DESC, updated_at DESC
) = 1;
```

**Result:** ~4M rows, saved as physical table

---

### Step 2: Join with Customer Demographics

**Purpose:** Add age_tier to offers (one-time join)

**Age Calculation Logic:**

**Mentor's Clarification:**
> "Use `current_date()` instead of `business_date` for age calculation. `business_date` is just the record state date, not the customer's actual age at that time."

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
  AND x.business_date = c.business_date;
```

**Result:** ~4M rows with demographics, saved as physical table

**⚠️ Important Note:** `age_group` field in customer table is PII, so we use `date_of_birth` to calculate age manually.

---

### Step 3: Fast Main Query

**Purpose:** Use pre-joined temp table for instant queries

```sql
-- ✅ FAST: Reads from temp table (2-3 minutes)
WITH base_loan_offer AS (
  SELECT * FROM `data-prd-adhoc.temp_ammar.base_loan_offer_with_demo`
  WHERE business_date >= '2025-01-01'
),

crvadl AS (...),
base_loan_offer_disburse AS (...),
base_loan_offer_final AS (...)

SELECT ... FROM base_loan_offer_final;
```

**Performance Comparison:**

| Approach | Query Time | Data Scanned | Cost |
|----------|------------|--------------|------|
| **CTE with customer join** | 20+ min | ~500 GB | High |
| **Physical temp tables** | 2-3 min | ~50 GB | Low |
| **Improvement** | **90%** | **90%** | **90%** |

**✅ Benefits:**
- 10x faster query execution
- 10x less data scanned (lower cost)
- Reusable for multiple analyses
- Easier to debug and validate

---

## Final Solution

### Complete SQL Query (Production-Ready)

```sql
-- FINAL TUPR ANALYSIS QUERY
-- Uses materialized temp tables for performance
-- Calculates Take Up Rate across all dimensions

WITH base_loan_offer AS (
  -- Read from pre-joined temp table (FAST!)
  SELECT *
  FROM `data-prd-adhoc.temp_ammar.base_loan_offer_with_demo`
  WHERE business_date >= '2025-01-01'
),

crvadl AS (
  -- Disbursed loans (MOB=0 only)
  SELECT DISTINCT
    lfs_customer_id AS customer_id,
    deal_type,
    facility_start_date,
    MAX(plafond_facility) AS plafond_facility,
    SUM(plafond) AS plafond,
    SUM(outstanding_balance * -1) AS outstanding_balance
  FROM `jago-bank-data-production.data_mart.credit_risk_vintage_account_direct_lending`
  WHERE business_date >= '2025-01-01'
    AND deal_type IN ('JAG06', 'JAG08', 'JAG09')
    AND facility_start_date >= '2025-01-01'
    AND mob = 0  -- Newly disbursed loans
  GROUP BY customer_id, deal_type, facility_start_date
),

base_loan_offer_disburse AS (
  -- Inner join to identify conversions
  SELECT
    x.*,
    y.* EXCEPT(customer_id)
  FROM base_loan_offer x
  INNER JOIN crvadl y
    ON x.customer_id = y.customer_id
    AND y.facility_start_date > x.key_date  -- Disbursed AFTER offer
),

base_loan_offer_final AS (
  -- Left join to flag disbursements
  SELECT
    x.*,
    CASE WHEN y.facility_start_date IS NOT NULL THEN 1 ELSE 0 END AS flag_disburse,
    y.facility_start_date,
    y.plafond_facility,
    y.plafond,
    ROUND(y.plafond / y.plafond_facility, 2) AS util_first,
    -- Limit Tiering
    CASE
      WHEN CAST(x.limit_offer AS FLOAT64) < 5000000 THEN '<5M'
      WHEN CAST(x.limit_offer AS FLOAT64) >= 5000000 AND CAST(x.limit_offer AS FLOAT64) <= 10000000 THEN '5-10M'
      WHEN CAST(x.limit_offer AS FLOAT64) > 10000000 AND CAST(x.limit_offer AS FLOAT64) <= 20000000 THEN '10-20M'
      WHEN CAST(x.limit_offer AS FLOAT64) > 20000000 THEN '>20M'
      ELSE 'Unknown'
    END AS limit_tier
  FROM base_loan_offer x
  LEFT JOIN base_loan_offer_disburse y
    ON x.business_date = y.business_date
    AND x.customer_id = y.customer_id
)

-- Final aggregation with all dimensions
SELECT
  FORMAT_DATE('%Y-%m', business_date) AS offer_month,
  product_code,
  risk_bracket,
  limit_tier,
  age_tier,
  COUNT(DISTINCT customer_id) AS total_customers,
  ROUND(SUM(CAST(limit_offer AS FLOAT64)), 0) AS total_limit,
  COUNT(DISTINCT CASE WHEN flag_disburse = 1 THEN customer_id END) AS customers_disbursed,
  ROUND(
    COUNT(DISTINCT CASE WHEN flag_disburse = 1 THEN customer_id END) * 100.0 /
    COUNT(DISTINCT customer_id),
    2
  ) AS take_up_rate_pct
FROM base_loan_offer_final
GROUP BY offer_month, product_code, risk_bracket, limit_tier, age_tier
ORDER BY offer_month, product_code, risk_bracket, limit_tier, age_tier;
```

### Query Output Schema

| Field | Type | Description | Example |
|-------|------|-------------|---------|
| `offer_month` | STRING | Month of offer (YYYY-MM) | '2025-08' |
| `product_code` | STRING | Loan product | 'JAG08' |
| `risk_bracket` | STRING | Risk grade | 'L', 'M', 'H' |
| `limit_tier` | STRING | Offer amount bucket | '<5M', '>20M' |
| `age_tier` | STRING | Customer age group | '26-30', '31-35' |
| `total_customers` | INTEGER | Total offers sent | 486,433 |
| `total_limit` | NUMERIC | Sum of offered limits (IDR) | 13,892,941,000,000 |
| `customers_disbursed` | INTEGER | Count of disbursements | 24,020 |
| `take_up_rate_pct` | NUMERIC | TUPR percentage | 4.94 |

---

## Key Findings

### 📊 Overall Performance

**Period:** Jan 2025 - Oct 2025 (10 months)

| Metric | Value |
|--------|-------|
| **Total Offers** | 4,006,637 |
| **Total Disbursed** | 188,925 |
| **Overall TUPR** | **4.72%** |
| **Peak TUPR** | 6.25% (March 2025) |
| **Lowest TUPR** | 3.13% (October 2025) |

**Trend:** ⚠️ Declining TUPR despite volume growth

---

### 🔍 Finding 1: TUPR Declining Over Time

**Data:**
| Quarter | Avg TUPR | Volume | Observation |
|---------|----------|--------|-------------|
| Q1 2025 | 5.22% | 500K offers | Peak performance |
| Q2 2025 | 5.81% | 1.1M offers | Maintained high TUPR |
| Q3 2025 | 4.67% | 1.7M offers | Starting to decline |
| Oct 2025 | 3.13% | 813K offers | Significant drop |

**Hypothesis:**
1. **Offer quality degradation** - Expanding to lower-intent customers
2. **Market saturation** - Active borrowers receiving multiple offers
3. **JAG06 dilution** - New product (Sep '25) converting at only 1.67%
4. **Seasonality** - Q4 traditionally lower consumer credit demand

---

### 🔍 Finding 2: Limit Size Inversely Correlates with TUPR

**Data:**
```
<5M:    5.97% TUPR  (smallest limits, HIGHEST conversion)
5-10M:  3.67% TUPR
10-20M: 3.85% TUPR
>20M:   3.08% TUPR  (largest limits, LOWEST conversion)
```

**Business Insight:**
> Customers are more willing to take **smaller, manageable loans** than large credit lines.

**Current Strategy Problem:**
- 44% of offers are >20M tier (1.78M customers)
- But >20M converts at only 3.08%
- Only 4% of offers are <5M (161K customers)
- But <5M converts at 5.97%!

**Opportunity:**
- If we offered more <5M limits instead of >20M
- Potential TUPR gain: **+2.89 percentage points**
- At current volumes: **~23K additional disbursements**

---

### 🔍 Finding 3: JAG08 Dominates, JAG06 Underperforms

**Product Comparison:**

| Product | Launch | Offers | Disbursed | TUPR | Status |
|---------|--------|--------|-----------|------|--------|
| **JAG08** | Legacy | 3.0M | 172K | **5.75%** | ✅ Strong |
| **JAG06** | Sep '25 | 913K | 15K | **1.67%** | ⚠️ Weak |
| **JAG09** | Aug '25 | 71K | 830 | **1.16%** | ⚠️ Niche |

**JAG06 Problem:**
- Launched Sep 2025 with high volume (418K Sep, 495K Oct)
- But converting at only **1.67%** vs JAG08's **5.75%**
- **Potential impact:** If JAG06 matched JAG08 TUPR:
  - Current: 15K disbursements
  - Potential: **52K disbursements** (+37K)
  - **Lost opportunity: 245% increase**

**Possible Causes:**
1. Product complexity or poor UX?
2. Wrong customer targeting?
3. Insufficient customer education?
4. Technical friction in application flow?

**Action Required:** JAG06 deep dive analysis!

---

### 🔍 Finding 4: Medium Risk = Sweet Spot

**Risk Grade Performance:**

| Risk | Offers | Disbursed | TUPR | Ranking |
|------|--------|-----------|------|---------|
| L | 1.04M | 33,910 | 3.26% | #3 |
| LM | 1.18M | 32,310 | 2.73% | #5 |
| **M** | **1.18M** | **39,190** | **3.33%** | **#1** 🏆 |
| MH | 500K | 12,096 | 2.42% | #6 |
| H | 36K | 1,591 | 4.38% | #2 |
| NO_BUREAU | 68K | 194 | 0.28% | #7 |

**Insight:**
- **Medium (M) risk customers** drive highest disbursement volume (39K)
- **Low (L) risk customers** paradoxically have lower TUPR (3.26%)
  - Hypothesis: Already have credit elsewhere, less urgent need
- **High (H) risk** surprisingly converts well (4.38%)
  - Hypothesis: Targeted, limited offers to high-intent customers

**Strategy Implication:**
- **Double down** on Medium (M) segment
- **Investigate** why Low (L) segment underperforms
- **Optimize** NO_BUREAU strategy (0.28% TUPR = essentially failing)

---

### 🔍 Finding 5: NO_BUREAU Segment Not Viable

**Data:**
- 68,525 offers sent (Sep-Oct 2025)
- Only **194 disbursed** (0.28% TUPR)
- Product: JAG09 exclusively

**Economic Reality:**
```
Cost per offer: ~10,000 IDR (SMS, processing, credit check)
Total cost: 68,525 × 10,000 = 685M IDR
Revenue from 194 disbursements: ~[calculation needed]

ROI: Likely NEGATIVE
```

**Strategic Question:**
> Should we continue offering to NO_BUREAU segment, or reallocate resources to higher-converting segments?

---

## Dashboard Design

### Looker Implementation

#### LookML View Definition

**File:** `views/loan_offer_take_up_rate.view.lkml`

```lkml
view: loan_offer_take_up_rate {
  derived_table: {
    sql:
      WITH base_loan_offer AS (
        SELECT * FROM `data-prd-adhoc.temp_ammar.base_loan_offer_with_demo`
        WHERE business_date >= '2025-01-01'
      ),
      -- [Full query from Final Solution section]
    ;;

    datagroup_trigger: daily_refresh
    partition_keys: ["offer_month"]
  }

  # Dimensions
  dimension: offer_month {
    type: string
    sql: ${TABLE}.offer_month ;;
    label: "Offer Month"
  }

  dimension: product_code {
    type: string
    sql: ${TABLE}.product_code ;;
    label: "Product"
  }

  dimension: risk_bracket {
    type: string
    sql: ${TABLE}.risk_bracket ;;
    label: "Risk Grade"
    order_by_field: risk_bracket_sort
  }

  dimension: risk_bracket_sort {
    type: number
    hidden: yes
    sql: CASE
      WHEN ${risk_bracket} = 'L' THEN 1
      WHEN ${risk_bracket} = 'LM' THEN 2
      WHEN ${risk_bracket} = 'M' THEN 3
      WHEN ${risk_bracket} = 'MH' THEN 4
      WHEN ${risk_bracket} = 'H' THEN 5
      WHEN ${risk_bracket} = 'NO_BUREAU' THEN 6
      ELSE 7
    END ;;
  }

  dimension: limit_tier {
    type: string
    sql: ${TABLE}.limit_tier ;;
    label: "Limit Tier"
    order_by_field: limit_tier_sort
  }

  dimension: limit_tier_sort {
    type: number
    hidden: yes
    sql: CASE
      WHEN ${limit_tier} = '<5M' THEN 1
      WHEN ${limit_tier} = '5-10M' THEN 2
      WHEN ${limit_tier} = '10-20M' THEN 3
      WHEN ${limit_tier} = '>20M' THEN 4
      ELSE 5
    END ;;
  }

  dimension: age_tier {
    type: string
    sql: ${TABLE}.age_tier ;;
    label: "Age Tier"
  }

  # Measures
  measure: total_customers {
    type: sum
    sql: ${TABLE}.total_customers ;;
    label: "#Customer"
    value_format_name: decimal_0
  }

  measure: total_limit {
    type: sum
    sql: ${TABLE}.total_limit ;;
    label: "#Limit"
    value_format_name: decimal_0
  }

  measure: customers_disbursed {
    type: sum
    sql: ${TABLE}.customers_disbursed ;;
    label: "#Disburse"
    value_format_name: decimal_0
  }

  measure: take_up_rate_pct {
    type: number
    sql: ${customers_disbursed} * 100.0 / NULLIF(${total_customers}, 0) ;;
    label: "TUPR %"
    value_format_name: percent_2
  }

  measure: avg_limit_per_customer {
    type: number
    sql: ${total_limit} / NULLIF(${total_customers}, 0) ;;
    label: "Avg Limit/Customer"
    value_format_name: decimal_0
  }
}
```

---

### Dashboard Layout

#### Tab 1: Overview

```
┌──────────────────────────────────────────────────────────┐
│  📈 Loan Offer Take Up Rate Analysis                     │
│  Period: Jan 2025 - Oct 2025                            │
└──────────────────────────────────────────────────────────┘

┌─────────────────────────┐ ┌────────────────────────────┐
│  📊 KPI Cards           │ │  📉 TUPR Trend (Line)      │
│  ┌─────────────────┐    │ │                            │
│  │ Total Offers    │    │ │  6.25% ╱╲                  │
│  │  4,006,637      │    │ │       ╱  ╲                 │
│  └─────────────────┘    │ │  4%  ╱    ╲___             │
│  ┌─────────────────┐    │ │     ╱          ╲___        │
│  │ Total Disbursed │    │ │  2%                        │
│  │    188,925      │    │ │  Jan  Mar  May  Jul  Oct   │
│  └─────────────────┘    │ └────────────────────────────┘
│  ┌─────────────────┐    │
│  │ Overall TUPR    │    │
│  │     4.72%       │    │
│  └─────────────────┘    │
└─────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│  📋 Loan Offer Snapshot (Table)                          │
├──────────┬────────────┬──────────────┬──────────┬───────┤
│ Month    │ #Customer  │ #Limit       │#Disburse │ %     │
├──────────┼────────────┼──────────────┼──────────┼───────┤
│ 2025-01  │   94,136   │ 3.0T         │  4,364   │ 4.64% │
│ 2025-02  │  134,499   │ 4.2T         │  6,413   │ 4.77% │
│ 2025-03  │  271,426   │ 7.8T         │ 16,968   │ 6.25% │
│ 2025-04  │  273,633   │ 8.3T         │ 16,965   │ 6.20% │
│ 2025-05  │  349,712   │ 9.7T         │ 21,231   │ 6.07% │
│ 2025-06  │  399,916   │ 11.6T        │ 23,089   │ 5.77% │
│ 2025-07  │  434,418   │ 12.1T        │ 24,282   │ 5.59% │
│ 2025-08  │  486,434   │ 13.9T        │ 24,020   │ 4.94% │
│ 2025-09  │  748,841   │ 20.7T        │ 26,086   │ 3.48% │
│ 2025-10  │  813,622   │ 22.0T        │ 25,507   │ 3.13% │
└──────────┴────────────┴──────────────┴──────────┴───────┘
```

---

#### Tab 2: Main Profile

```
┌──────────────────────────────────────────────────────────┐
│  🎯 Product Performance (Pivot Table)                    │
├─────────┬─────────┬─────────┬─────────┬─────────────────┤
│ Product │ 2025-01 │ 2025-02 │   ...   │    2025-10      │
├─────────┼─────────┼─────────┼─────────┼─────────────────┤
│ JAG08   │ 4.68%   │ 4.84%   │   ...   │    5.98%        │
│ JAG06   │    -    │    -    │   ...   │    1.60%        │
│ JAG09   │    -    │    -    │   ...   │    1.65%        │
└─────────┴─────────┴─────────┴─────────┴─────────────────┘

┌──────────────────────────────────────────────────────────┐
│  🎲 Risk Grade Performance (Pivot Table)                 │
├─────────┬─────────┬─────────┬─────────┬─────────────────┤
│  Risk   │ 2025-01 │ 2025-02 │   ...   │    2025-10      │
├─────────┼─────────┼─────────┼─────────┼─────────────────┤
│    L    │ 3.41%   │ 3.44%   │   ...   │    3.70%        │
│   LM    │ 4.57%   │ 4.65%   │   ...   │    3.39%        │
│    M    │ 5.70%   │ 5.76%   │   ...   │    3.48%        │
│   MH    │ 6.06%   │ 6.60%   │   ...   │    1.84%        │
│    H    │ 0.00%   │11.40%   │   ...   │    0.99%        │
│NO_BUREAU│    -    │    -    │   ...   │    0.00%        │
└─────────┴─────────┴─────────┴─────────┴─────────────────┘

┌──────────────────────────────────────────────────────────┐
│  💰 Limit Tier Performance (Pivot Table)                 │
├─────────┬─────────┬─────────┬─────────┬─────────────────┤
│  Tier   │ 2025-01 │ 2025-02 │   ...   │    2025-10      │
├─────────┼─────────┼─────────┼─────────┼─────────────────┤
│   <5M   │ 1.88%   │ 2.52%   │   ...   │    3.52%        │
│  5-10M  │ 1.94%   │ 2.94%   │   ...   │    6.07%        │
│ 10-20M  │ 1.81%   │ 3.90%   │   ...   │    5.66%        │
│  >20M   │ 1.48%   │ 1.30%   │   ...   │    6.54%        │
└─────────┴─────────┴─────────┴─────────┴─────────────────┘
```

---

#### Tab 3: Demographic Profile

```
┌──────────────────────────────────────────────────────────┐
│  👥 Age Tier Performance (Pivot Table)                   │
├─────────┬─────────┬─────────┬─────────┬─────────────────┤
│ Age Tier│ 2025-01 │ 2025-02 │   ...   │    2025-10      │
├─────────┼─────────┼─────────┼─────────┼─────────────────┤
│   <21   │   ...   │   ...   │   ...   │      ...        │
│  21-25  │   ...   │   ...   │   ...   │      ...        │
│  26-30  │   ...   │   ...   │   ...   │      ...        │
│  31-35  │   ...   │   ...   │   ...   │      ...        │
│  36-40  │   ...   │   ...   │   ...   │      ...        │
│  41-45  │   ...   │   ...   │   ...   │      ...        │
│  46-50  │   ...   │   ...   │   ...   │      ...        │
│   >50   │   ...   │   ...   │   ...   │      ...        │
└─────────┴─────────┴─────────┴─────────┴─────────────────┘

┌──────────────────────────────────────────────────────────┐
│  📊 Age Distribution (Stacked Bar)                       │
│                                                          │
│  100%  ┌────────────────────────────────────────┐       │
│        │         >50         │  46-50  │ 41-45  │       │
│   75%  ├────────────────────────────────────────┤       │
│        │         36-40       │  31-35  │ 26-30  │       │
│   50%  ├────────────────────────────────────────┤       │
│        │         21-25       │   <21   │        │       │
│   25%  ├────────────────────────────────────────┤       │
│        │                                        │       │
│    0%  └────────────────────────────────────────┘       │
│         Jan    Mar    May    Jul    Sep   Oct          │
└──────────────────────────────────────────────────────────┘
```

---

## Lessons Learned

### 1. **Always Start with Business Logic**

**What We Learned:**
> Before writing SQL, understand the business question deeply.

**Example:**
- Initial instinct: Start with disbursement table (smaller, faster)
- Mentor correction: **Must start with offer table** (denominator)
- Why: TUPR = disbursed / **ALL offers** (not just disbursed customers)

**Takeaway:** Wrong base table = wrong metric!

---

### 2. **Iterative Development > Big Bang**

**Approach:**
1. ✅ Simple query first (explore data)
2. ✅ Add complexity gradually (one dimension at a time)
3. ✅ Validate at each step
4. ✅ Document findings as you go

**Benefits:**
- Easier debugging
- Early validation catches errors
- Incremental learning
- Stakeholder visibility throughout

**Anti-pattern:**
❌ Writing one massive query without testing

---

### 3. **Deduplication is Critical**

**Challenge:** Multiple offers per customer per month (especially JAG09)

**Solution:**
```sql
QUALIFY DENSE_RANK() OVER (
  PARTITION BY customer_id, business_date
  ORDER BY agreement_agreed_at DESC, updated_at DESC
) = 1
```

**Why DENSE_RANK vs ROW_NUMBER?**
- Handles ties properly
- More efficient than subquery approach
- Cleaner code with QUALIFY

**Mentor's Guidance:**
> "JAG09 uses Zeus system which allows multiple offers. Always dedupe by latest agreement timestamp."

---

### 4. **Performance Optimization is Not Premature**

**Initial Thought:**
> "Let's get it working first, optimize later"

**Reality:**
- 20+ minute query = **not usable** in production
- Analysts won't wait 20 min per query iteration
- Dashboard refresh = impossible

**Solution: Physical Tables**
- One-time cost: 5 min to create temp tables
- Ongoing benefit: 90% query time reduction
- ROI: Immediate and massive

**Lesson:** If query takes >5 min, materialize intermediate results!

---

### 5. **Date Logic is Tricky**

**Key Date Concepts:**

| Field | Meaning | Use Case |
|-------|---------|----------|
| `business_date` | End-of-month snapshot date | Joining tables at same point in time |
| `key_date` | Offer effective date | Matching offers to disbursements |
| `facility_start_date` | Loan disbursement date | Identifying conversions |
| `created_at` | Offer creation timestamp | Deduplication |
| `expires_at` | Offer expiration | Calculating key_date |

**Critical Join Condition:**
```sql
-- ✅ CORRECT
ON x.customer_id = y.customer_id
   AND x.business_date = y.business_date  -- Same snapshot!

-- ❌ WRONG (missing business_date)
ON x.customer_id = y.customer_id
```

**Why This Matters:**
- Customer attributes change over time
- Must capture "age at time of offer" not "current age"
- business_date ensures temporal consistency

---

### 6. **PII Awareness**

**Issue:** `age_group` field in customer table is PII

**Solution:** Calculate age from `date_of_birth` instead

**Mentor's Clarification:**
> "Use `current_date()` for age calculation. `business_date` is just record state, not actual age at offer time."

**Implementation:**
```sql
DATE_DIFF(CURRENT_DATE(), c.date_of_birth, YEAR) AS age
```

**Learning:** Always check data classification before using fields in analytics!

---

### 7. **Dimension Ordering Matters**

**For Pivot Tables:**
```sql
-- ✅ GOOD: Logical ordering with sort fields
ORDER BY
  CASE
    WHEN limit_tier = '<5M' THEN 1
    WHEN limit_tier = '5-10M' THEN 2
    WHEN limit_tier = '10-20M' THEN 3
    WHEN limit_tier = '>20M' THEN 4
  END
```

**Why:**
- Alphabetical sorting: '<5M' comes after '>20M' (wrong!)
- Logical sorting: '<5M' → '5-10M' → '10-20M' → '>20M' (right!)

**Looker Implementation:**
```lkml
dimension: limit_tier_sort {
  type: number
  hidden: yes  -- Don't show to users
  sql: CASE ... END ;;
}

dimension: limit_tier {
  order_by_field: limit_tier_sort  -- Use hidden sort field
}
```

---

## Next Steps

### Immediate (Week of Oct 31 - Nov 7)

- [x] **Complete SQL query with demographics**
  - [x] Create temp tables for performance
  - [x] Validate age_tier calculation
  - [x] Test query execution time (<5 min)

- [ ] **Build Looker Dashboard**
  - [ ] Create LookML view definition
  - [ ] Add to model and test
  - [ ] Build dashboard tiles (all 3 tabs)
  - [ ] Add filters (date range, product)
  - [ ] Share draft with Pak Subhan

- [ ] **Validate Findings with Business**
  - [ ] Present TUPR trends to Risk team
  - [ ] Discuss JAG06 underperformance
  - [ ] Align on limit sizing strategy

---

### Short-Term (Nov 2025)

- [ ] **JAG06 Root Cause Analysis**
  - [ ] Customer journey mapping (offer → view → apply → drop-off)
  - [ ] Technical friction analysis (load times, errors)
  - [ ] Compare JAG06 vs JAG08 offer characteristics
  - [ ] Survey: Why didn't customers take JAG06?

- [ ] **Cohort Analysis**
  - [ ] Do March cohorts (6.25% TUPR) differ from Oct cohorts (3.13%)?
  - [ ] Repeat offer analysis (customers receiving multiple offers)
  - [ ] Time-to-conversion distribution

- [ ] **Limit Sizing Experiment**
  - [ ] A/B test: <5M vs >20M offers to similar segments
  - [ ] Measure: TUPR, utilization rate, 30-day activation
  - [ ] Duration: 2 weeks minimum

---

### Medium-Term (Dec 2025 - Jan 2026)

- [ ] **Predictive Model: Propensity to Take Up**
  - [ ] Features: Risk grade, limit size, age, balance, offer count, product
  - [ ] Target: Probability of disburse given offer
  - [ ] Benefit: Smarter targeting, reduce wasted offers

- [ ] **Customer Segmentation**
  - [ ] Cluster customers by TUPR propensity
  - [ ] Tailor offer strategy by segment
  - [ ] Personalized messaging and limits

- [ ] **NO_BUREAU Strategy Review**
  - [ ] Cost-benefit analysis (0.28% TUPR = viable?)
  - [ ] Explore alternative products for non-bureau segment
  - [ ] Decision: Continue, pivot, or exit?

---

### Long-Term (Q1 2026)

- [ ] **TUPR as North Star Metric**
  - [ ] Set team OKR: TUPR target 5%+ by Q1 2026
  - [ ] Weekly TUPR monitoring dashboard
  - [ ] Alert system for TUPR drops

- [ ] **Automated Reporting**
  - [ ] Daily TUPR refresh in Looker
  - [ ] Weekly email digest to stakeholders
  - [ ] Monthly executive summary

- [ ] **Competitive Benchmarking**
  - [ ] Industry research: What's best-in-class TUPR?
  - [ ] Gap analysis vs competitors
  - [ ] Strategic roadmap to close gap

---

## References

### Data Sources

| Table | Purpose | Key Fields | Update Frequency |
|-------|---------|-----------|------------------|
| `jago-bank-data-production.dwh_core.loan_offer_daily_snapshot` | Loan offers (base population) | `customer_id`, `business_date`, `product_code`, `risk_bracket`, `limit_offer`, `expires_at` | Daily (EOM snapshots) |
| `jago-bank-data-production.data_mart.credit_risk_vintage_account_direct_lending` | Disbursed loans | `lfs_customer_id`, `facility_start_date`, `deal_type`, `plafond_facility`, `mob` | Daily |
| `jago-bank-data-production.data_mart.customer` | Customer demographics | `customer_id`, `business_date`, `date_of_birth` | Daily |
| `data-prd-adhoc.temp_ammar.base_loan_offer_snapshot` | Materialized offers (temp) | All offer fields | Created 2025-10-31 |
| `data-prd-adhoc.temp_ammar.base_loan_offer_with_demo` | Offers + demographics (temp) | All offer fields + `age_tier` | Created 2025-10-31 |

### Mentor Sessions

- **Session Date:** 2025-10-31
- **Duration:** ~2 hours
- **Topics Covered:**
  1. TUPR business logic and calculation methodology
  2. Dimensional analysis framework (Main Profile + Demographics)
  3. Query optimization using physical tables
  4. Dashboard layout and Looker implementation
  5. Age calculation clarification (current_date vs business_date)

### Key Mentor Quotes

> "The denominator MUST be the total offers. If you start with disbursement table, you lose all non-converters."

> "Make it a physical table first, then join with customer. This way you only pay the join cost once."

> "JAG09 uses Zeus which allows multiple offers per customer. Always dedupe by latest agreement."

> "Use current_date() for age, not business_date. business_date is just the record state date."

---

## Appendix

### Glossary

| Term | Definition | Example |
|------|------------|---------|
| **TUPR** | Take Up Rate Percentage - conversion rate from offer to disbursement | 4.72% |
| **EOM** | End of Month - snapshot taken on last day of each month | 2025-08-31 |
| **MOB** | Month on Book - months since loan origination (MOB=0 = newly disbursed) | 0, 1, 2, ... |
| **JAG06/08/09** | Bank Jago Direct Lending product codes | JAG08 = Credit Line |
| **Plafond** | Indonesian term for "credit limit" or "loan amount" | 3,000,000 IDR |
| **Bureau vs Non-Bureau** | Credit bureau score available vs unavailable | Bureau = SLIK data available |
| **DENSE_RANK** | SQL window function for ranking with tie-handling | Deduplicate offers |
| **Facility** | Credit line (can contain multiple loan drawdowns) | FacilityRef: DKJ335 |
| **Deal** | Individual loan drawdown from a facility | DealRef: 87608032791884 |
| **key_date** | Effective offer date used for disbursement matching | Calculated from expires_at |
| **PII** | Personally Identifiable Information (restricted fields) | age_group, name, ID |

### SQL Patterns Used

**1. Deduplication with QUALIFY:**
```sql
QUALIFY DENSE_RANK() OVER (
  PARTITION BY customer_id, business_date
  ORDER BY agreement_agreed_at DESC
) = 1
```

**2. Conditional Aggregation:**
```sql
COUNT(DISTINCT CASE WHEN flag_disburse = 1 THEN customer_id END) AS disbursed
```

**3. Percentage Calculation:**
```sql
ROUND(
  COUNT(DISTINCT CASE WHEN flag_disburse = 1 THEN customer_id END) * 100.0 /
  NULLIF(COUNT(DISTINCT customer_id), 0),
  2
) AS take_up_rate_pct
```

**4. Date Bucketing:**
```sql
FORMAT_DATE('%Y-%m', business_date) AS offer_month
```

**5. Tiering with CASE:**
```sql
CASE
  WHEN value < threshold1 THEN 'Tier1'
  WHEN value BETWEEN threshold1 AND threshold2 THEN 'Tier2'
  ELSE 'Tier3'
END AS tier
```

---

### Data Quality Checks

**Check 1: Denominator Consistency**
```sql
-- Verify total customers match across aggregations
SELECT
  SUM(total_customers) AS sum_by_dimensions,
  (SELECT COUNT(DISTINCT customer_id) FROM base_loan_offer) AS unique_base
-- Should be equal
```

**Check 2: Disbursement Logic**
```sql
-- Verify all disbursements happened AFTER offer
SELECT COUNT(*)
FROM base_loan_offer_disburse
WHERE facility_start_date <= key_date
-- Should return 0
```

**Check 3: Age Tier Distribution**
```sql
-- Check for NULLs or Unknown age tiers
SELECT
  age_tier,
  COUNT(*) AS count
FROM base_loan_offer_with_demo
GROUP BY age_tier
ORDER BY count DESC
```

**Check 4: Duplicate Detection**
```sql
-- Ensure no duplicate customer_id per business_date
SELECT
  business_date,
  customer_id,
  COUNT(*) AS row_count
FROM base_loan_offer_snapshot
GROUP BY business_date, customer_id
HAVING COUNT(*) > 1
-- Should return 0 rows
```

---

## Document Metadata

| Field | Value |
|-------|-------|
| **Document Type** | Technical Wiki Entry |
| **Author** | Ammar Siregar (Risk DA Intern) |
| **Mentor** | Pak Subhan |
| **Created Date** | 2025-10-31 |
| **Last Updated** | 2025-10-31 |
| **Status** | ✅ Complete |
| **Review Status** | Pending Pak Subhan review |
| **Related Documents** | `Loan_Master_Staging_Architecture_Technical_Wiki.md` |
| **GitHub Commit** | [To be added] |
| **Looker Dashboard** | [To be deployed] |

---

**End of Wiki Entry**

*This document serves as a complete technical reference for the Loan Offer Take Up Rate analysis, capturing business context, implementation journey, key findings, and actionable next steps.*
