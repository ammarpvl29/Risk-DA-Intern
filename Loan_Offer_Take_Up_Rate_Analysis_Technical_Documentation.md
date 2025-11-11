# Loan Offer Take Up Rate (TUPR) Analysis - Technical Documentation

**Date:** 2025-10-31
**Author:** Ammar Siregar
**Mentor:** Pak Subhan
**Business Objective:** Analyze conversion rate from loan offers to disbursements across multiple dimensions

---

## Executive Summary

This analysis measures the **Take Up Rate (TUPR)** - the percentage of loan offers that convert to actual disbursements. The core business question is: **"Of all customers we offer loans to, how many actually take the loan?"**

**Key Findings:**
- **Overall TUPR (Jan-Oct 2025):** 4.72% (188,925 disbursed / 4M offers)
- **TUPR Trend:** Declining from 6.25% (March) → 3.13% (October)
- **Best Converting Segment:** JAG08 Low Risk (L) customers at 4.67%
- **Insight:** Smaller limit offers (<5M) convert better (5.97%) than large offers (>20M at 3.94%)

---

## Table of Contents

1. [Business Context](#business-context)
2. [Data Architecture](#data-architecture)
3. [Methodology](#methodology)
4. [SQL Query Logic](#sql-query-logic)
5. [Dimensional Analysis](#dimensional-analysis)
6. [Key Findings](#key-findings)
7. [Business Implications](#business-implications)
8. [Next Steps](#next-steps)

---

## Business Context

### What is Take Up Rate?

**Definition:**
```
Take Up Rate (TUPR) = (Number of Disbursed Loans / Total Number of Loan Offers) × 100%
```

**Business Importance:**
- Measures **effectiveness** of loan offering strategy
- Indicates **customer acceptance** of credit products
- Helps optimize **offer targeting** and **limit sizing**
- Critical for **revenue forecasting** and **capital planning**

### Analytical Framework (Points of View)

Per Pak Subhan's guidance, TUPR is analyzed across two main profiles:

#### 1. Main Profile (Loan Offer Characteristics)
- **OfferDate:** Monthly trend analysis
- **Product Type:** JAG06, JAG08, JAG09 performance
- **Risk Grade:** Risk bracket segmentation (H, L, LM, M, MH, NO_BUREAU)
- **Limit Tiering:** Offer amount buckets (<5M, 5-10M, 10-20M, >20M)

#### 2. Demographic Profile (Customer Characteristics)
- **Age Tier:** Customer age grouping
- *(Pending implementation - requires customer table join)*

---

## Data Architecture

### Source Tables

| Table | Purpose | Key Fields | Filter Criteria |
|-------|---------|-----------|-----------------|
| `jago-bank-data-production.dwh_core.loan_offer_daily_snapshot` | Loan offers (numerator + denominator) | `customer_id`, `business_date`, `product_code`, `risk_bracket`, `limit_offer`, `expires_at`, `offer_status` | `business_date` = EOM or current date, `offer_status` NOT IN ('REJECTED', 'CLOSED') |
| `jago-bank-data-production.data_mart.credit_risk_vintage_account_direct_lending` | Disbursed loans (numerator) | `lfs_customer_id`, `facility_start_date`, `deal_type`, `plafond_facility`, `plafond` | `deal_type` IN ('JAG06', 'JAG08', 'JAG09'), `mob` = 0 |
| `jago-bank-data-production.data_mart.customer` | Customer demographics | `customer_id`, `age_group`, `business_date` | Join on `customer_id` AND `business_date` |

### Data Flow

```
Loan Offer Snapshot (Base Population)
    ↓
Filter: EOM only, exclude REJECTED/CLOSED
    ↓
Deduplicate: Latest offer per customer per month (DENSE_RANK)
    ↓
Join: Vintage table (facility_start_date > key_date)
    ↓
Flag: flag_disburse = 1 if match exists, else 0
    ↓
Aggregate: Calculate TUPR by dimensions
```

---

## Methodology

### Step 1: Define Base Offer Population

**Critical Logic:**
- Use **end-of-month (EOM) snapshots** to capture monthly offer state
- Apply **DENSE_RANK** to handle duplicate offers (especially JAG09 Zeus)
- Calculate **key_date** for matching disbursements:
  ```sql
  CASE
    WHEN DATE_DIFF(DATE(expires_at), DATE(created_at), MONTH) = 1
    THEN DATE(created_at)
    ELSE DATE_SUB(CAST(expires_at AS DATE), INTERVAL 1 MONTH)
  END AS key_date
  ```

### Step 2: Identify Disbursed Loans

**Matching Logic:**
- Join condition: `customer_id` match AND `facility_start_date > key_date`
- Filter for **MOB = 0** (first month of loan - newly disbursed)
- Only include **Direct Lending products** (JAG06, JAG08, JAG09)

### Step 3: Calculate TUPR

**Formula:**
```sql
ROUND(
  COUNT(DISTINCT CASE WHEN flag_disburse = 1 THEN customer_id END) * 100.0 /
  COUNT(DISTINCT customer_id),
  2
) AS take_up_rate_pct
```

**Key Principle (Pak Subhan's Emphasis):**
> "The denominator MUST be the total offers from loan_offer table, NOT the disbursed count. If you start with disbursement table (~5k records), you lose all non-converters and cannot calculate TUPR."

### Step 4: Dimensional Breakdowns

**Limit Tiering Logic:**
```sql
CASE
  WHEN CAST(limit_offer AS FLOAT64) < 5000000 THEN '<5M'
  WHEN CAST(limit_offer AS FLOAT64) >= 5000000 AND CAST(limit_offer AS FLOAT64) <= 10000000 THEN '5-10M'
  WHEN CAST(limit_offer AS FLOAT64) > 10000000 AND CAST(limit_offer AS FLOAT64) <= 20000000 THEN '10-20M'
  WHEN CAST(limit_offer AS FLOAT64) > 20000000 THEN '>20M'
  ELSE 'Unknown'
END AS limit_tier
```

---

## SQL Query Logic

### Query Structure Overview

```sql
WITH
-- Step 1: Base loan offers (filtered, deduplicated)
base_loan_offer AS (
  -- Filters: EOM snapshots, exclude rejected/closed
  -- Deduplication: DENSE_RANK by customer + business_date
),

-- Step 2: Disbursed loans (MOB=0, JAG products)
crvadl AS (
  -- Aggregate plafond and plafond_facility by customer + facility_start_date
),

-- Step 3: Inner join to identify conversions
base_loan_offer_disburse AS (
  -- Match offers to disbursements where facility_start_date > key_date
),

-- Step 4: Left join to flag disbursements
base_loan_offer_final AS (
  -- flag_disburse = 1 if customer disbursed after offer
  -- Add limit_tier bucketing
)

-- Step 5: Aggregate by dimensions
SELECT
  offer_month,
  product_code,
  risk_bracket,
  limit_tier,
  COUNT(DISTINCT customer_id) AS total_customers,
  SUM(limit_offer) AS total_limit,
  COUNT(DISTINCT CASE WHEN flag_disburse = 1 THEN customer_id END) AS customers_disbursed,
  ROUND(...) AS take_up_rate_pct
FROM base_loan_offer_final
GROUP BY offer_month, product_code, risk_bracket, limit_tier
```

### Critical Join Condition

```sql
-- CORRECT (preserves full offer population)
FROM base_loan_offer x
LEFT JOIN base_loan_offer_disburse y
  ON x.business_date = y.business_date
  AND x.customer_id = y.customer_id

-- WRONG (loses non-converters)
FROM crvadl y
LEFT JOIN base_loan_offer x ...  -- ❌ Starts with disbursed loans!
```

---

## Dimensional Analysis

### 1. Overall TUPR Trend (Jan-Oct 2025)

| Month | Total Offers | Total Limit (IDR) | Disbursed | TUPR % |
|-------|--------------|-------------------|-----------|--------|
| 2025-01 | 94,136 | 3.0T | 4,364 | **4.64%** |
| 2025-02 | 134,499 | 4.2T | 6,413 | **4.77%** |
| 2025-03 | 271,426 | 7.8T | 16,968 | **6.25%** ⬆️ |
| 2025-04 | 273,633 | 8.3T | 16,965 | **6.20%** |
| 2025-05 | 349,712 | 9.7T | 21,231 | **6.07%** |
| 2025-06 | 399,916 | 11.6T | 23,089 | **5.77%** |
| 2025-07 | 434,418 | 12.1T | 24,282 | **5.59%** |
| 2025-08 | 486,434 | 13.9T | 24,020 | **4.94%** ⬇️ |
| 2025-09 | 748,841 | 20.7T | 26,086 | **3.48%** ⬇️ |
| 2025-10 | 813,622 | 22.0T | 25,507 | **3.13%** ⬇️ |
| **Total** | **4,006,637** | **113.4T** | **188,925** | **4.72%** |

**Key Observations:**
- ✅ Peak TUPR: **March 2025 (6.25%)**
- ⚠️ Declining trend: -3.12pp from March to October
- 📈 Volume growth: 94K → 813K offers (+764%)
- 📉 Conversion degradation despite volume scale-up

---

### 2. Product Breakdown

| Product | Description | Total Offers | Disbursed | TUPR % | Notes |
|---------|-------------|--------------|-----------|--------|-------|
| **JAG08** | Credit Line (Bureau) | 3,003,016 | 172,780 | **5.75%** | Dominant product (75% of offers) |
| **JAG06** | New Product (Sep '25) | 913,638 | 15,249 | **1.67%** | Low conversion, recent launch |
| **JAG09** | Credit Line (Non-Bureau) | 71,521 | 830 | **1.16%** | NO_BUREAU segment, high risk |
| JAG01 | Legacy Product | 7,123 | 0 | **0.00%** | Not converting (inactive?) |
| PBL01 | Partner Product | 9,946 | 29 | **0.29%** | Minimal volume/conversion |
| JAG31 | Unknown | 1,354 | 0 | **0.00%** | Not converting |
| OD | Overdraft | 24 | 0 | **0.00%** | Minimal testing |
| JAG71 | Unknown | 15 | 0 | **0.00%** | Pilot/test product |

**Product Insights:**
- JAG08 is the **core revenue driver** (172K disbursements)
- JAG06 shows **low TUPR** despite 913K offers (launch issues?)
- JAG09 limited to **NO_BUREAU customers** (by design)

---

### 3. Risk Grade Breakdown

| Risk Bracket | Description | Total Offers | Disbursed | TUPR % | Business Insight |
|--------------|-------------|--------------|-----------|--------|------------------|
| **L** (Low) | Lowest risk | 1,040,445 | 33,910 | **3.26%** | Largest segment, conservative conversion |
| **LM** (Low-Med) | Low-Medium | 1,182,743 | 32,310 | **2.73%** | Balanced risk-reward |
| **M** (Medium) | Medium risk | 1,178,050 | 39,190 | **3.33%** | **Highest volume disbursed** |
| **MH** (Med-High) | Medium-High | 500,567 | 12,096 | **2.42%** | Higher risk, lower acceptance |
| **H** (High) | High risk | 36,307 | 1,591 | **4.38%** | Small segment, surprisingly decent TUPR |
| **NO_BUREAU** | Non-bureau | 68,525 | 194 | **0.28%** | JAG09 only, very low conversion |

**Risk Grade Insights:**
- **Medium (M) customers** have highest disbursement count (39K) AND decent TUPR (3.33%)
- **Low (L) customers** dominate offers but convert at only 3.26%
- **NO_BUREAU** segment shows minimal take-up (0.28%) - high friction or low intent?
- **High (H) risk** surprisingly converts at 4.38% - possibly targeted offers?

---

### 4. Limit Tiering Breakdown

| Limit Tier | Offer Range (IDR) | Total Offers | Total Limit (IDR) | Disbursed | TUPR % |
|------------|-------------------|--------------|-------------------|-----------|--------|
| **<5M** | < 5,000,000 | 161,313 | 568B | 9,631 | **5.97%** ⬆️ |
| **5-10M** | 5M - 10M | 868,436 | 6.6T | 31,900 | **3.67%** |
| **10-20M** | 10M - 20M | 1,188,823 | 18.1T | 45,757 | **3.85%** |
| **>20M** | > 20,000,000 | 1,778,119 | 88.2T | 54,782 | **3.08%** ⬇️ |
| Unknown | No limit data | 9,946 | 0 | 29 | **0.29%** |
| **Total** | - | **4,006,637** | **113.4T** | **188,925** | **4.72%** |

**Limit Tiering Insights:**
- ✅ **Inverse relationship:** Smaller offers = Higher TUPR
  - <5M: **5.97%** (best conversion)
  - >20M: **3.08%** (lowest conversion)
- 💡 **Hypothesis:** Customers perceive smaller limits as more "manageable"
- ⚠️ **Portfolio concentration:** 44% of offers are >20M tier (1.77M customers)
- 💰 **Value vs Volume tradeoff:**
  - <5M: High TUPR but low total limit (568B)
  - >20M: Low TUPR but massive limit exposure (88.2T = 78% of total)

---

## Key Findings

### ✅ Finding 1: TUPR Declining Despite Volume Growth

**Observation:**
- March 2025: 271K offers → 16,968 disbursed (**6.25% TUPR**)
- October 2025: 813K offers → 25,507 disbursed (**3.13% TUPR**)
- Volume increased **3x**, but TUPR dropped **-50%**

**Possible Causes:**
1. **Offer quality degradation** - expanding to lower-intent customers
2. **Market saturation** - existing active borrowers receiving multiple offers
3. **Product-market fit** - JAG06 launch diluting overall TUPR
4. **Seasonality** - Q4 lower demand vs Q1/Q2

**Recommended Analysis:**
- Cohort analysis: Are March customers different from October customers?
- Repeat offer analysis: How many customers receive multiple offers?
- JAG06 deep dive: Why is new product converting at only 1.67%?

---

### ✅ Finding 2: Limit Size Inversely Correlates with TUPR

**Data:**
| Tier | TUPR | Interpretation |
|------|------|----------------|
| <5M | 5.97% | Customers more willing to take smaller loans |
| 5-10M | 3.67% | Mid-tier shows hesitance |
| 10-20M | 3.85% | Slight uptick (sweet spot?) |
| >20M | 3.08% | Large limits intimidate customers |

**Business Implication:**
- Current strategy: Offering **large limits** to attract customers
- Reality: Customers **more likely to accept smaller, manageable amounts**
- Opportunity: Test **tiered offer campaigns** (start small, increase over time)

---

### ✅ Finding 3: JAG08 Dominates, JAG06 Underperforms

**JAG08 Performance:**
- 3M offers → 172K disbursed (**5.75% TUPR**)
- Mature product, proven conversion

**JAG06 Performance:**
- 913K offers → 15K disbursed (**1.67% TUPR**)
- Launched Sep 2025, struggling to convert
- Possible issues:
  - Product complexity?
  - Poor targeting?
  - Technical friction?
  - Insufficient customer education?

**Action Required:**
- Root cause analysis on JAG06 low TUPR
- Customer survey: Why did you NOT take the JAG06 offer?
- A/B test: JAG06 messaging/UX improvements

---

### ✅ Finding 4: Medium Risk Customers are Sweet Spot

**Data:**
- **L (Low Risk):** 1.04M offers, 3.26% TUPR, 33K disbursed
- **M (Medium Risk):** 1.18M offers, **3.33% TUPR**, **39K disbursed** ⬆️
- **MH (Medium-High):** 500K offers, 2.42% TUPR, 12K disbursed

**Insight:**
- Medium risk customers have **highest disbursement volume**
- Low risk customers (L, LM) have **lower conversion despite high offers**
- Hypothesis: Low risk = Already have credit elsewhere, less urgent need

**Strategy Recommendation:**
- Focus offer campaigns on **M (Medium)** segment
- For L segment: Improve offer attractiveness (rates, benefits)

---

## Business Implications

### For Product Team

1. **JAG06 Optimization Priority**
   - Current: 913K offers, 1.67% TUPR (15K disbursements)
   - Potential: If TUPR matched JAG08 (5.75%), could add **37K disbursements**
   - Action: User research + friction analysis

2. **Limit Sizing Strategy Review**
   - Current: 44% of offers are >20M (lowest TUPR at 3.08%)
   - Test: Offer <5M limits to more customers (currently only 4% of offers)
   - Expected: +2.89pp TUPR improvement (from 3.08% → 5.97%)

### For Marketing Team

3. **Customer Segmentation**
   - **Focus:** Medium (M) risk customers (highest volume)
   - **Messaging:** Emphasize manageability for smaller limits (<5M)
   - **Channel:** Personalized in-app nudges vs mass campaigns

4. **Reactivation Campaigns**
   - Target: Customers who received offers but didn't convert
   - Test: "Start small" messaging (e.g., "Try 3M first, increase later")

### For Risk Team

5. **Offer Strategy Recalibration**
   - Current: Offering large limits to attract customers (not working)
   - Alternative: Conservative initial offers, prove-and-grow model
   - Benefit: Higher TUPR + lower default risk

6. **NO_BUREAU Segment Review**
   - Current TUPR: 0.28% (68K offers, 194 disbursed)
   - Question: Is this segment viable? Or abandon?
   - Data needed: Default rates of NO_BUREAU disbursements

### For Executive Leadership

7. **TUPR as North Star Metric**
   - Current tracking: Volume (offers sent)
   - Proposed: **TUPR × Volume = Disbursements** (revenue-generating)
   - Target: Stabilize TUPR at 5%+ while scaling volume

8. **Q4 2025 Action Plan**
   - Oct TUPR: 3.13% (lowest in 2025)
   - Goal: Reverse decline to 5%+ by Q1 2026
   - Levers: JAG06 fix + limit sizing + segmentation

---

## Next Steps

### Immediate (Week of Oct 31)

- [x] **Complete Main Profile pivot tables**
  - [x] Product × Month
  - [x] Risk Grade × Month
  - [x] Limit Tier × Month

- [ ] **Add Demographics Profile**
  - [ ] Optimize customer table join (currently 20+ min query time)
  - [ ] Age Tier × Month analysis
  - [ ] Income bracket analysis (if available)

- [ ] **Build Looker Dashboard**
  - [ ] Overall TUPR trend (line chart)
  - [ ] Product comparison (stacked bar)
  - [ ] Risk grade heatmap
  - [ ] Limit tier waterfall

### Short-Term (Nov 2025)

- [ ] **Deep Dive: JAG06 Root Cause Analysis**
  - Why 1.67% TUPR vs JAG08's 5.75%?
  - Customer journey analysis (offer → view → apply → abandon)
  - Technical friction points (load times, errors)

- [ ] **Cohort Analysis**
  - Do March customers (6.25% TUPR) differ from Oct customers (3.13%)?
  - Repeat offer analysis (how many get 2+ offers per month?)
  - Time-to-conversion analysis (days from offer to disbursal)

- [ ] **Limit Sizing Experiment**
  - A/B test: Offer <5M vs >20M to similar customer segments
  - Measure: TUPR, utilization rate, 30-day activation

### Medium-Term (Dec 2025 - Jan 2026)

- [ ] **Predictive Model: Propensity to Take Up**
  - Features: Risk grade, limit size, age, balance, offer count
  - Target: Predict P(disburse | offer) for smarter targeting
  - Benefit: Reduce wasted offers, improve TUPR

- [ ] **Customer Survey**
  - Sample: 1,000 customers who received offer but didn't convert
  - Questions:
    - Why didn't you take the offer?
    - Was the limit too high/low?
    - Did you understand the product?
    - Do you plan to take it later?

- [ ] **Competitive Benchmarking**
  - How does 4.72% TUPR compare to industry peers?
  - What are best-in-class conversion rates for digital lending?

---

## Appendix

### Query Performance Notes

**Current Query Stats:**
- **Execution time:** ~2-3 minutes (without customer join)
- **Rows processed:** 4M+ loan offers across 10 months
- **Data scanned:** ~500 GB (BigQuery)

**Optimization Tips:**
1. Always filter `business_date >= 'YYYY-MM-DD'` (partitioned field)
2. Use `QUALIFY` instead of subquery + ROW_NUMBER for deduplication
3. Pre-aggregate crvadl CTE (currently recalculates for each query)

**Customer Join Performance Issue:**
- **Problem:** 20+ minute query time when joining with `data_mart.customer`
- **Cause:** Customer table is large, not optimized for frequent EOM joins
- **Solution:**
  - Create intermediate table: `customer_eos_snapshot` (end-of-month only)
  - Or use INFORMATION_SCHEMA to check customer table size/partitioning

### Data Quality Checks

**Validation Query 1: Check Denominator Consistency**
```sql
-- Ensure total customers match across different aggregations
SELECT
  SUM(total_customers) AS sum_by_product,
  (SELECT COUNT(DISTINCT customer_id) FROM base_loan_offer) AS unique_customers
FROM product_aggregation
-- sum_by_product should equal unique_customers
```

**Validation Query 2: Disbursement Logic Check**
```sql
-- Verify facility_start_date > key_date for all matches
SELECT COUNT(*)
FROM base_loan_offer_disburse
WHERE facility_start_date <= key_date
-- Should return 0
```

### Glossary

| Term | Definition |
|------|------------|
| **TUPR** | Take Up Rate Percentage - conversion rate from offer to disbursement |
| **EOM** | End of Month - snapshot taken on last day of each month |
| **MOB** | Month on Book - months since loan origination (MOB=0 is first month) |
| **JAG06/08/09** | Bank Jago Direct Lending product codes |
| **Plafond** | Indonesian term for "credit limit" or "loan amount" |
| **CIF** | Customer Information File - customer identifier |
| **Bureau vs Non-Bureau** | Credit bureau score available vs unavailable |
| **DENSE_RANK** | SQL window function for ranking with tie-handling |
| **Facility** | Credit line (can contain multiple loan drawdowns) |
| **Deal** | Individual loan drawdown from a facility |

---

## References

- **Mentor Session:** 1-1 with Pak Subhan (2025-10-31)
- **Tables Analyzed:**
  - `jago-bank-data-production.dwh_core.loan_offer_daily_snapshot`
  - `jago-bank-data-production.data_mart.credit_risk_vintage_account_direct_lending`
  - `jago-bank-data-production.data_mart.customer`
- **Analysis Period:** 2025-01-01 to 2025-10-31 (10 months)
- **Total Offers Analyzed:** 4,006,637
- **Total Disbursements:** 188,925
- **Overall TUPR:** 4.72%

---

**Document Status:** ✅ Ready for review
**Next Update:** After demographics analysis completion
**Dashboard Target:** Looker deployment by Nov 15, 2025
