# TUPR Dashboard - Campaign Segmentation Integration

**Document Type:** Technical Wiki Entry - Feature Addition
**Project:** Digital Lending Analytics - Campaign Segmentation Bridge
**Author:** Ammar Siregar (Risk Data Analyst Intern)
**Mentor:** Pak Subhan (Credit Risk Team)
**Date Created:** 2025-11-06
**Last Updated:** 2025-11-06
**Status:** ✅ In Development
**Parent Documentation:** TUPR_Dashboard_Complete_Technical_Wiki_20251106.md
**Related RFC:** [RFC] Propensity Loan Take Up 2025

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Business Context](#business-context)
3. [Technical Requirements](#technical-requirements)
4. [Data Source Analysis](#data-source-analysis)
5. [Implementation Design](#implementation-design)
6. [Query 2.5: Campaign Bridge](#query-25-campaign-bridge)
7. [Updated Pipeline](#updated-pipeline)
8. [Dashboard Integration](#dashboard-integration)
9. [Validation & Quality Checks](#validation--quality-checks)
10. [Troubleshooting Guide](#troubleshooting-guide)
11. [References](#references)

---

## Executive Summary

### Purpose

This document describes the integration of **campaign segmentation data** into the existing TUPR (Take-Up Rate) Dashboard, enabling analysis of loan offer conversion rates by marketing campaign type.

### What Changed

**Before:**
- Dashboard showed TUPR by Source (New vs Carry-Over), Product, Risk Grade, Limit Tier
- No visibility into which campaign segment customers belonged to

**After:**
- Dashboard shows TUPR by **Campaign Segment** (BAU, CT, Weekly)
- Ability to compare test campaigns (CT) vs normal campaigns (BAU)
- Support for deep-dive into specific test categories

### Business Impact

This addition enables the Product team to answer:
1. **"Do test campaigns have better take-up rates than normal campaigns?"**
2. **"Which specific test campaign performs best?"**
3. **"Should we scale up a successful test campaign?"**

### Key Stakeholders

| Team | Use Case |
|------|----------|
| **Product Team** | Measure A/B test effectiveness, decide which campaigns to scale |
| **Marketing Team** | Optimize campaign targeting and messaging |
| **Risk Team** | Monitor if high-conversion campaigns have acceptable risk profiles |
| **Executive Leadership** | ROI analysis of marketing spend |

---

## Business Context

### The Underwriting Waterfall

**Mentor's Explanation (Nov 4, 2025):**

Not all Jago customers receive loan offers. The 500K+ monthly offer base is the result of a rigorous **"underwriting waterfall"**:

```
15,000,000  Total Jago Customers
    ↓       Filter 1: Indonesian citizenship
14,500,000
    ↓       Filter 2: Non-Syariah
10,000,000
    ↓       Filter 3: Age requirements
 8,500,000
    ↓       Filter 4: Income verification
 6,000,000
    ↓       Filter 5: Credit bureau check
 2,000,000
    ↓       Filter 6: Behavioral scores
   541,000  ✅ Passed Underwriting Waterfall
```

**This 541K is the "daging" (meat) of the operation** - customers deemed creditworthy and eligible for loan offers.

---

### Campaign Segmentation

Once customers pass the waterfall, they are split into **campaign segments** for A/B testing:

#### **Segment 1: BAU (Business As Usual)**
- **Volume:** ~500,000 customers (90-95%)
- **Purpose:** Baseline/control group
- **Strategy:** Standard offer terms, normal marketing
- **Expected TUPR:** 1-2%

#### **Segment 2: CT (Credit Test)**
- **Volume:** ~40,000 customers (5-10%)
- **Purpose:** Experimental campaigns
- **Strategy:** Test different:
  - Offer amounts (higher/lower limits)
  - Interest rates
  - Marketing messages
  - Customer segments (demographics, behavior)
- **Expected TUPR:** Varies (could be 0.5% or 5%)

**Example Test Categories:**
- Test 1: "Young professionals (age 25-35)"
- Test 2: "High-income earners (>50M/month)"
- Test 3: "E-commerce frequent users"

#### **Segment 3: Weekly**
- **Volume:** ~1,000 customers (<1%)
- **Purpose:** Rapid iteration tests
- **Strategy:** Very small experiments, quick validation
- **Expected TUPR:** Highly variable

---

### The Three-Model Framework

**Mentor's Analogy (Nov 4, 2025):**

This dashboard represents **Model Type 2: Propensity Modeling**

```
┌─────────────────────────────────────────────────────┐
│ Model Type 1: PREDICTION                            │
│ ├─ Example: Insurance Price Prediction (your thesis)│
│ ├─ Predicts: Continuous value                       │
│ └─ Output: Price, score, amount                     │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ Model Type 2: PROPENSITY ← THIS DASHBOARD           │
│ ├─ Example: Loan Take-Up Rate                       │
│ ├─ Predicts: Probability of action (%)              │
│ └─ Output: Conversion rate, percent sales           │
└─────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│ Model Type 3: CREDIT SCORING (Next Phase)           │
│ ├─ Example: Delinquency Risk, Churn                 │
│ ├─ Predicts: Default probability, bad rate          │
│ └─ Output: Risk score, DPD 30+/90+ rate             │
└─────────────────────────────────────────────────────┘
```

**Key Insight from Mentor:**
> "Product team may celebrate if Test 2 has 5% TUPR vs Normal 2% ('Wih, take up rate gua naik!'). But Risk team must check: if Test 2 has 20% bad rate vs Normal 1%, that's a disaster. Stop immediately ('Tutup, tutup. Gila.')."

**This dashboard measures STEP 1 (Propensity). Next phase will add STEP 2 (Credit Scoring/Collection).**

---

## Technical Requirements

### Functional Requirements

| Requirement | Description | Priority |
|-------------|-------------|----------|
| **FR-1** | Join offer data with underwriting waterfall (campaign segment) | P0 - Critical |
| **FR-2** | Add Campaign Segment dimension (BAU, CT, Weekly) | P0 - Critical |
| **FR-3** | Add Campaign Category dimension (Test 1, Test 2, etc.) | P1 - High |
| **FR-4** | Ensure no duplication of customers | P0 - Critical |
| **FR-5** | Handle "Unknown" segment for unmatched customers | P1 - High |
| **FR-6** | Maintain backward compatibility with existing dimensions | P0 - Critical |

### Non-Functional Requirements

| Requirement | Description | Target |
|-------------|-------------|--------|
| **NFR-1** | Query execution time | <15 minutes (entire pipeline) |
| **NFR-2** | Data freshness | Daily (match existing TUPR refresh) |
| **NFR-3** | Data quality | >95% of offers matched to campaign |
| **NFR-4** | Dashboard responsiveness | <5 seconds (after data load) |

---

## Data Source Analysis

### Source Table: dl_whitelist

**Location:** `data-prd-adhoc.dl_whitelist_checkers.*`

The campaign segmentation data comes from **three separate tables**, representing different underwriting paths:

#### **Table 1: dl_wl_final_whitelist_raw_history (BAU)**
```sql
`data-prd-adhoc.dl_whitelist_checkers.dl_wl_final_whitelist_raw_history`
```

**Purpose:** Standard underwriting path (Business As Usual)

**Key Fields:**
- `business_date`: Date of underwriting decision
- `customer_id`: Unique customer identifier
- `waterfall_failure_step`: Stage where customer stopped (or '99. Passed')
- `flag_offer_upload`: Whether offer was uploaded ('Yes'/'No')
- `risk_group`: Risk grade from underwriting (HCI model)
- `ews_calibrated_scores_bin`: Early Warning System score

**Volume:** ~1.7M records (Jan-Oct 2025)

#### **Table 2: dl_wl_final_whitelist_credit_test_raw_history (CT)**
```sql
`data-prd-adhoc.dl_whitelist_checkers.dl_wl_final_whitelist_credit_test_raw_history`
```

**Purpose:** Experimental campaign underwriting

**Additional Fields:**
- `category`: Specific test name (e.g., "Test 1", "Test 2")

**Volume:** ~874K records (Jan-Oct 2025)

#### **Table 3: dl_wl_final_whitelist_weekly_raw_history (Weekly)**
```sql
`data-prd-adhoc.dl_whitelist_checkers.dl_wl_final_whitelist_weekly_raw_history`
```

**Purpose:** Rapid iteration tests

**Volume:** ~77 records (Jan-Oct 2025)

---

### Data Quality Analysis

**Query to validate source tables:**
```sql
SELECT
  'BAU' as segment,
  COUNT(*) as total_records,
  COUNT(DISTINCT customer_id) as unique_customers,
  COUNTIF(waterfall_failure_step = '99. Passed Underwriting Waterfall') as passed,
  COUNTIF(flag_offer_upload = 'Yes') as offer_uploaded
FROM `data-prd-adhoc.dl_whitelist_checkers.dl_wl_final_whitelist_raw_history`
WHERE business_date >= '2025-01-01'

UNION ALL

SELECT
  'CT' as segment,
  COUNT(*) as total_records,
  COUNT(DISTINCT customer_id) as unique_customers,
  COUNTIF(waterfall_failure_step = '99. Passed Underwriting Waterfall') as passed,
  COUNTIF(flag_offer_upload = 'Yes') as offer_uploaded
FROM `data-prd-adhoc.dl_whitelist_checkers.dl_wl_final_whitelist_credit_test_raw_history`
WHERE business_date >= '2025-01-01'

UNION ALL

SELECT
  'Weekly' as segment,
  COUNT(*) as total_records,
  COUNT(DISTINCT customer_id) as unique_customers,
  COUNTIF(waterfall_failure_step = '99. Passed Underwriting Waterfall') as passed,
  COUNTIF(flag_offer_upload = 'Yes') as offer_uploaded
FROM `data-prd-adhoc.dl_whitelist_checkers.dl_wl_final_whitelist_weekly_raw_history`
WHERE business_date >= '2025-01-01';
```

**Expected Result (Jan-Oct 2025):**
```
segment | total_records | unique_customers | passed    | offer_uploaded
--------|---------------|------------------|-----------|----------------
BAU     | 1,679,528     | ~800K            | ~500K     | ~500K
CT      | 873,956       | ~400K            | ~200K     | ~200K
Weekly  | 77            | ~50              | ~30       | ~30
```

---

### Join Key Analysis

**Challenge:** How to match `loan_offer_daily_snapshot` with `dl_whitelist`?

#### **Option 1: Match on business_date (CURRENT IMPLEMENTATION)**
```sql
ON x.customer_id = y.customer_id
AND x.business_date = y.business_date
```

**Pros:**
- Direct match - fast execution
- Both tables have business_date

**Cons:**
- Mismatch when key_date != business_date
- Some offers may not match (timing issues)

#### **Option 2: Match on key_date month (ALTERNATIVE)**
```sql
ON x.customer_id = y.customer_id
AND LAST_DAY(x.key_date) = LAST_DAY(y.business_date)
```

**Pros:**
- Consistent with month-based grouping
- Better alignment with offer effective date

**Cons:**
- Slightly slower (date functions)

**Decision:** Use **Option 1** initially for simplicity. Monitor "Unknown" rate and switch to Option 2 if >20% unmatched.

---

## Implementation Design

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│              EXISTING PIPELINE (Before)                     │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│ Query 1: base_loan_offer_snapshot                           │
│ └─ NEW + CARRY-OVER classification                          │
└──────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│ Query 2: base_loan_offer_with_demo                          │
│ └─ Add demographics (age_tier)                              │
└──────────────────────────────────────────────────────────────┘
                           │
                           ▼
          ┌────────────────┴────────────────┐
          │                                  │
┌─────────▼─────────┐            ┌──────────▼──────────┐
│ Query 3:          │            │ Query 4:            │
│ Final Dataset     │            │ Monthly Summary     │
│ (Dimensional)     │            │ (KPI Boxes)         │
└───────────────────┘            └─────────────────────┘
          │                                  │
          └────────────────┬─────────────────┘
                           ▼
                   Looker Dashboard


┌─────────────────────────────────────────────────────────────┐
│              NEW PIPELINE (After Campaign Addition)         │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│ Query 1: base_loan_offer_snapshot                           │
│ └─ NEW + CARRY-OVER classification                          │
└──────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│ Query 2: base_loan_offer_with_demo                          │
│ └─ Add demographics (age_tier)                              │
└──────────────────────────────────────────────────────────────┘
                           │
                           ▼
┌──────────────────────────────────────────────────────────────┐
│ ✨ Query 2.5: base_loan_offer_with_campaign (NEW!)          │
│ ├─ JOIN with dl_whitelist (BAU/CT/Weekly)                   │
│ ├─ Add campaign_segment dimension                           │
│ ├─ Add campaign_category dimension                          │
│ └─ Deduplicate (one segment per customer)                   │
└──────────────────────────────────────────────────────────────┘
                           │
                           ▼
          ┌────────────────┴────────────────┐
          │                                  │
┌─────────▼─────────┐            ┌──────────▼──────────┐
│ Query 3:          │            │ Query 4:            │
│ Final Dataset     │            │ Monthly Summary     │
│ (+ Campaign Dims) │            │ (+ Campaign Dims)   │
└───────────────────┘            └─────────────────────┘
          │                                  │
          └────────────────┬─────────────────┘
                           ▼
          Looker Dashboard (+ Campaign Filters & Pivots)
```

---

### Data Flow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│ loan_offer_daily_snapshot (dwh_core)                        │
│ ├─ 577,681 Oct offers                                       │
│ └─ Fields: customer_id, business_date, product_code         │
└─────────────────────────────────────────────────────────────┘
                           │
                           │ Query 1 + Query 2
                           ▼
┌─────────────────────────────────────────────────────────────┐
│ base_loan_offer_with_demo (temp_ammar)                      │
│ ├─ 553,528 Oct offers (after demographic join)             │
│ └─ Fields: customer_id, business_date, key_date, source     │
└─────────────────────────────────────────────────────────────┘
                           │
                           │ Query 2.5 (LEFT JOIN)
                           │
          ┌────────────────┴────────────────┐
          │                                  │
┌─────────▼─────────┐            ┌──────────▼──────────┐
│ dl_whitelist      │            │ base_loan_offer_    │
│ (credit_risk)     │  JOIN      │ with_demo           │
│ 2.5M records      │◄───────────│ 553K offers         │
│ (BAU/CT/Weekly)   │            │                     │
└───────────────────┘            └─────────────────────┘
          │
          │ Filter: Passed Waterfall + Offer Uploaded
          │ Dedupe: One segment per customer (priority: BAU > CT > Weekly)
          │
          ▼
┌─────────────────────────────────────────────────────────────┐
│ base_loan_offer_with_campaign (credit_risk_adhoc)          │
│ ├─ 553,528 Oct offers (same count, new dimensions)         │
│ ├─ New Fields:                                              │
│ │   ├─ campaign_segment (BAU/CT/Weekly/Unknown)            │
│ │   ├─ campaign_category (Test 1, Test 2, etc.)            │
│ │   ├─ ews_calibrated_scores_bin                           │
│ │   └─ risk_group_hci                                      │
│ └─ Match Rate: ~85-90% (10-15% "Unknown")                  │
└─────────────────────────────────────────────────────────────┘
```

---

## Query 2.5: Campaign Bridge

### File Information

**File:** `Query2.5_add_campaign_segmentation.sql`
**Output Table:** `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign`
**Runtime:** ~8-12 minutes
**Dependencies:** Query 2 output (`base_loan_offer_with_demo`)

---

### SQL Implementation

```sql
CREATE OR REPLACE TABLE `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign` AS

-- ============================================================================
-- STEP 1: Extract BAU Campaign Data
-- ============================================================================
WITH bau_segment AS (
  SELECT
    x.business_date,
    x.customer_id,
    'BAU' AS is_ct,
    'BAU' as ct_category,
    x.ews_calibrated_scores_bin,
    x.risk_group as risk_group_hci,
    1 AS rnk  -- Priority 1 (highest)
  FROM `data-prd-adhoc.dl_whitelist_checkers.dl_wl_final_whitelist_raw_history` x
  LEFT JOIN `data-prd-adhoc.dl_whitelist_checkers.dl_wl_final_whitelist_credit_test_raw_history` y
    ON x.customer_id = y.customer_id
    AND x.business_date = y.business_date
  WHERE
    x.business_date >= '2025-01-01'
    AND x.waterfall_failure_step = '99. Passed Underwriting Waterfall'
    AND x.flag_offer_upload = 'Yes'
    -- ✅ Exclude customers who also passed CT waterfall (they belong to CT, not BAU)
    AND (y.customer_id IS NULL
         OR (y.customer_id IS NOT NULL
             AND y.waterfall_failure_step NOT LIKE '99. Passed Underwriting Waterfall'))
),

-- ============================================================================
-- STEP 2: Extract CT (Credit Test) Campaign Data
-- ============================================================================
ct_segment AS (
  SELECT
    business_date,
    customer_id,
    'CT' AS is_ct,
    category as ct_category,
    ews_calibrated_scores_bin,
    risk_group as risk_group_hci,
    2 AS rnk  -- Priority 2
  FROM `data-prd-adhoc.dl_whitelist_checkers.dl_wl_final_whitelist_credit_test_raw_history`
  WHERE
    business_date >= '2025-01-01'
    AND waterfall_failure_step = '99. Passed Underwriting Waterfall'
    AND flag_offer_upload = 'Yes'
),

-- ============================================================================
-- STEP 3: Extract Weekly Campaign Data
-- ============================================================================
weekly_segment AS (
  SELECT
    business_date,
    customer_id,
    'Weekly' AS is_ct,
    category as ct_category,
    NULL as ews_calibrated_scores_bin,
    risk_group as risk_group_hci,
    3 AS rnk  -- Priority 3 (lowest)
  FROM `data-prd-adhoc.dl_whitelist_checkers.dl_wl_final_whitelist_weekly_raw_history`
  WHERE
    business_date >= '2025-01-01'
    AND waterfall_failure_step = '99. Passed Underwriting Waterfall'
    AND flag_offer_upload = 'Yes'
),

-- ============================================================================
-- STEP 4: Combine All Segments
-- ============================================================================
dl_whitelist AS (
  SELECT * FROM bau_segment
  UNION ALL
  SELECT * FROM ct_segment
  UNION ALL
  SELECT * FROM weekly_segment
),

-- ============================================================================
-- STEP 5: Deduplicate (One Segment Per Customer)
-- ============================================================================
dl_whitelist_deduped AS (
  SELECT * FROM dl_whitelist
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY customer_id, business_date
    ORDER BY rnk ASC  -- ✅ Priority: BAU (1) > CT (2) > Weekly (3)
  ) = 1
)

-- ============================================================================
-- STEP 6: Join with Offer Data
-- ============================================================================
SELECT
  x.*,  -- All existing fields from base_loan_offer_with_demo
  COALESCE(y.is_ct, 'Unknown') AS campaign_segment,
  COALESCE(y.ct_category, 'Unknown') AS campaign_category,
  y.ews_calibrated_scores_bin,
  y.risk_group_hci
FROM `data-prd-adhoc.temp_ammar.base_loan_offer_with_demo` x
LEFT JOIN dl_whitelist_deduped y
  ON x.customer_id = y.customer_id
  AND x.business_date = y.business_date;
```

---

### Logic Explanation

#### **STEP 1: BAU Segment Extraction**

**Key Logic:**
```sql
LEFT JOIN credit_test_table y
WHERE (y.customer_id IS NULL
       OR y.waterfall_failure_step NOT LIKE '99. Passed Underwriting Waterfall')
```

**Why This Matters:**
- Some customers appear in BOTH `raw_history` (BAU table) and `credit_test` (CT table)
- If a customer passed BOTH waterfalls, they belong to **CT** (test group), not BAU
- This LEFT JOIN + filter ensures BAU only contains "pure BAU" customers

**Example:**
```
Customer A:
- Appears in raw_history: Passed ✅
- Appears in credit_test: Passed ✅
→ Classification: CT (not BAU)

Customer B:
- Appears in raw_history: Passed ✅
- Appears in credit_test: Failed ❌
→ Classification: BAU
```

---

#### **STEP 5: Deduplication Logic**

**Priority Ranking:**
```sql
ORDER BY rnk ASC  -- BAU (1) > CT (2) > Weekly (3)
```

**Why Prioritize BAU?**
- BAU is the largest, most stable segment
- If a customer somehow qualifies for multiple segments, BAU is the "default"
- CT and Weekly are opt-in/targeted segments

**Edge Case Handling:**
- Customer in BAU + CT → Keep CT (test group)
- Customer in CT + Weekly → Keep CT (larger test)
- Customer in all three → Keep BAU (safest default)

---

#### **STEP 6: LEFT JOIN Behavior**

**Match Outcome:**
```sql
COALESCE(y.is_ct, 'Unknown') AS campaign_segment
```

| Scenario | Output | Frequency |
|----------|--------|-----------|
| **Match found in BAU** | campaign_segment = 'BAU' | ~70-80% |
| **Match found in CT** | campaign_segment = 'CT' | ~10-15% |
| **Match found in Weekly** | campaign_segment = 'Weekly' | <1% |
| **No match** | campaign_segment = 'Unknown' | ~10-15% |

**Reasons for "Unknown":**
1. Offer created before underwriting completed (timing mismatch)
2. Customer in `loan_offer_daily_snapshot` but not in `dl_whitelist` (data sync issue)
3. Test/dev data
4. Offer status changed after snapshot (e.g., blocked post-creation)

---

### Output Schema

| Column | Type | Source | Description | Example |
|--------|------|--------|-------------|---------|
| `business_date` | DATE | Query 2 | Snapshot date | 2025-10-31 |
| `customer_id` | STRING | Query 2 | Customer ID | XXWJ9ZF0CB |
| `key_date` | DATE | Query 2 | Offer effective date | 2025-10-05 |
| `source` | STRING | Query 2 | NEW vs CARRY-OVER | new, carry over |
| `product_code` | STRING | Query 2 | Loan product | JAG06, JAG08, JAG09 |
| `risk_bracket` | STRING | Query 2 | Risk grade | L, LM, M, MH, H |
| `age_tier` | STRING | Query 2 | Age bracket | 26-30, 31-35 |
| `limit_offer` | FLOAT | Query 2 | Offered limit (IDR) | 15000000.0 |
| **`campaign_segment`** | STRING | **Query 2.5** | **Campaign type** | **BAU, CT, Weekly, Unknown** |
| **`campaign_category`** | STRING | **Query 2.5** | **Test name** | **Test 1, Test 2, BAU** |
| **`ews_calibrated_scores_bin`** | STRING | **Query 2.5** | **EWS risk score** | **Low, Medium, High** |
| **`risk_group_hci`** | STRING | **Query 2.5** | **Underwriting risk** | **L, LM, M, MH, H** |

---

### Validation Queries

#### **Validation 1: No Duplicates**
```sql
SELECT
  customer_id,
  business_date,
  COUNT(*) as row_count
FROM `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign`
WHERE business_date = '2025-10-31'
GROUP BY customer_id, business_date
HAVING COUNT(*) > 1
ORDER BY row_count DESC;
```

**Expected:** No rows (0 duplicates)

---

#### **Validation 2: Campaign Segment Distribution**
```sql
SELECT
  campaign_segment,
  COUNT(DISTINCT customer_id) as customers,
  ROUND(COUNT(DISTINCT customer_id) * 100.0 / SUM(COUNT(DISTINCT customer_id)) OVER(), 1) as pct
FROM `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign`
WHERE business_date = '2025-10-31'
GROUP BY campaign_segment
ORDER BY customers DESC;
```

**Expected:**
```
campaign_segment | customers | pct
-----------------|-----------|-----
BAU              | 380,000   | 68.7%
Unknown          | 85,000    | 15.4%
CT               | 88,000    | 15.9%
Weekly           | 528       | 0.1%
```

---

#### **Validation 3: Row Count Conservation**
```sql
SELECT
  'Query 2 Output' as stage,
  COUNT(*) as total_rows,
  COUNT(DISTINCT customer_id) as unique_customers
FROM `data-prd-adhoc.temp_ammar.base_loan_offer_with_demo`
WHERE business_date = '2025-10-31'

UNION ALL

SELECT
  'Query 2.5 Output' as stage,
  COUNT(*) as total_rows,
  COUNT(DISTINCT customer_id) as unique_customers
FROM `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign`
WHERE business_date = '2025-10-31';
```

**Expected:**
```
stage             | total_rows | unique_customers
------------------|------------|------------------
Query 2 Output    | 553,528    | 553,528
Query 2.5 Output  | 553,528    | 553,528  ← Must match!
```

---

## Updated Pipeline

### Query 3 Changes (Final Dataset)

**File:** `FIXED_Query3_tupr_dashboard_final_dataset.sql`

**Change 1: Update Source Reference**
```sql
-- OLD:
WITH base_loan_offer AS (
  SELECT * FROM `data-prd-adhoc.temp_ammar.base_loan_offer_with_demo`
  WHERE business_date >= '2025-01-01'
),

-- NEW:
WITH base_loan_offer AS (
  SELECT * FROM `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign`
  WHERE business_date >= '2025-01-01'
),
```

**Change 2: Add Campaign Dimensions to SELECT**
```sql
SELECT
  FORMAT_DATE('%Y-%m', key_date) AS offer_month,

  -- Existing dimensions
  source,
  source_sorted,

  -- ✨ NEW: Campaign dimensions
  campaign_segment,
  CASE
    WHEN campaign_segment = 'BAU' THEN '1.BAU'
    WHEN campaign_segment = 'CT' THEN '2.CT'
    WHEN campaign_segment = 'Weekly' THEN '3.Weekly'
    ELSE '4.Unknown'
  END AS campaign_segment_sorted,

  campaign_category,

  -- Other dimensions (product, risk, limit)
  product_code,
  product_code_sorted,
  ...

FROM base_loan_offer_final
WHERE key_date < DATE_TRUNC(CURRENT_DATE(), MONTH)
  AND key_date >= '2025-01-01'
GROUP BY 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12  -- ✨ Added positions 4, 5, 6
ORDER BY 1 DESC, 3, 5, 7, 9, 11;
```

**Impact:**
- Row count per month increases from ~1,000 to ~3,000 (3x campaign segments × existing dimensions)

---

### Query 4 Changes (Monthly Summary)

**File:** `FIXED_Query4_tupr_dashboard_monthly_summary.sql`

**Change 1: Update Source Reference** (same as Query 3)

**Change 2: Add Campaign Segment to SELECT**
```sql
SELECT
  FORMAT_DATE('%Y-%m', key_date) AS offer_month,

  -- Existing dimensions
  source,
  source_sorted,

  -- ✨ NEW: Campaign segment (NOT campaign_category)
  campaign_segment,
  CASE
    WHEN campaign_segment = 'BAU' THEN '1.BAU'
    WHEN campaign_segment = 'CT' THEN '2.CT'
    WHEN campaign_segment = 'Weekly' THEN '3.Weekly'
    ELSE '4.Unknown'
  END AS campaign_segment_sorted,

  -- Metrics
  COUNT(DISTINCT customer_id) AS total_customers,
  ...

FROM base_loan_offer_final
WHERE key_date < DATE_TRUNC(CURRENT_DATE(), MONTH)
  AND key_date >= '2025-01-01'
GROUP BY 1, 2, 3, 4, 5  -- ✨ Added positions 4, 5
ORDER BY 1 DESC, 3, 5;
```

**Why NOT include campaign_category?**
- Query 4 is for KPI boxes (high-level aggregation)
- campaign_category is too granular (would create 10+ rows per month)
- Campaign_category deep-dive should use Query 3 (detailed dataset)

**Impact:**
- October 2025: 2 rows (new + carry over) → 6-8 rows (2 × 3-4 campaign segments)

---

## Dashboard Integration

### LookML View Updates

#### **View 1: tupr_dashboard_final_dataset.view**

**Add campaign dimensions:**
```lkml
dimension: campaign_segment {
  type: string
  sql: ${TABLE}.campaign_segment ;;
  order_by_field: campaign_segment_sorted
  description: "Campaign segmentation: BAU (normal), CT (test), Weekly (rapid test)"
}

dimension: campaign_segment_sorted {
  type: string
  sql: ${TABLE}.campaign_segment_sorted ;;
  hidden: yes
}

dimension: campaign_category {
  type: string
  sql: ${TABLE}.campaign_category ;;
  description: "Specific test name for CT segment (e.g., Test 1, Test 2)"
}

dimension: ews_calibrated_scores_bin {
  type: string
  sql: ${TABLE}.ews_calibrated_scores_bin ;;
  description: "Early Warning System risk score bin"
}

dimension: risk_group_hci {
  type: string
  sql: ${TABLE}.risk_group_hci ;;
  description: "Risk group from underwriting (HCI model)"
}
```

---

#### **View 2: tupr_dashboard_monthly_summary.view**

**Add campaign segment dimension:**
```lkml
dimension: campaign_segment {
  type: string
  sql: ${TABLE}.campaign_segment ;;
  order_by_field: campaign_segment_sorted
  description: "Campaign segmentation: BAU (normal), CT (test), Weekly (rapid test)"
}

dimension: campaign_segment_sorted {
  type: string
  sql: ${TABLE}.campaign_segment_sorted ;;
  hidden: yes
}

-- ❌ Do NOT add campaign_category to this view (not in Query 4)
```

---

### Dashboard Layout Updates

#### **Section 1: Filters (Top)**

**Add Filter 4: Campaign Segment**
- **Type:** Dropdown (multi-select)
- **Options:** BAU, CT, Weekly, Unknown
- **Default:** All selected
- **Purpose:** Filter entire dashboard by campaign type

**Configuration in Dashboard:**
```json
{
  "name": "Campaign Segment",
  "field": "tupr_dashboard_final_dataset.campaign_segment",
  "type": "field_filter",
  "default_value": "",
  "allow_multiple_values": true
}
```

---

#### **Section 2: New Pivot - TUPR by Campaign Segment**

**Title:** "TUPR by Campaign Segment"
**Position:** After KPI boxes, before existing pivots

**Configuration:**
- **View:** `tupr_dashboard_final_dataset`
- **Visualization:** Pivot Table
- **Rows:** `Offer Month`
- **Columns:** `Campaign Segment`
- **Values:**
  - `Total Customers`
  - `Customers Disbursed`
  - `Take Up Rate Pct By Customer`
  - `Total Limit`

**Expected Output (October 2025):**
```
Offer Month | BAU         | CT          | Weekly    | Unknown
            | #Cust | TUPR | #Cust | TUPR | #Cust | TUPR | #Cust | TUPR
------------|-------|------|-------|------|-------|------|-------|-----
2025-10     |368K   | 0.9% | 124K  | 0.3% | 0     | 0%   | 61K   | 1.8%
2025-09     |287K   | 1.4% | 213K  | 0.8% | 0     | 0%   | 97K   | 0.3%
```

---

#### **Section 3: New Pivot - TUPR by Campaign Category (CT Deep Dive)**

**Title:** "TUPR by Campaign Category (CT Tests)"
**Position:** Below Campaign Segment pivot

**Configuration:**
- **View:** `tupr_dashboard_final_dataset`
- **Visualization:** Pivot Table
- **Filter:** `campaign_segment = 'CT'` (show only CT segment)
- **Rows:** `Offer Month`
- **Columns:** `Campaign Category`
- **Values:**
  - `Total Customers`
  - `Take Up Rate Pct By Customer`

**Expected Output (October 2025):**
```
Offer Month | Test 1      | Test 2      | Test 3      | Control
            | #Cust | TUPR | #Cust | TUPR | #Cust | TUPR | #Cust | TUPR
------------|-------|------|-------|------|-------|------|-------|-----
2025-10     | 45K   | 0.4% | 38K   | 0.2% | 23K   | 0.5% | 18K   | 0.2%
2025-09     | 89K   | 1.0% | 67K   | 0.6% | 34K   | 0.9% | 23K   | 0.5%
```

---

## Validation & Quality Checks

### Data Quality Metrics

| Metric | Target | Measurement | Status |
|--------|--------|-------------|--------|
| **Match Rate** | >85% | % offers with campaign_segment != 'Unknown' | ✅ Monitor |
| **BAU Dominance** | 70-85% | % offers in BAU segment | ✅ Expected |
| **CT Volume** | 10-20% | % offers in CT segment | ✅ Expected |
| **Weekly Volume** | <1% | % offers in Weekly segment | ✅ Expected |
| **No Duplicates** | 0 | Customers with >1 row per business_date | ✅ Critical |
| **Row Conservation** | 100% | Query 2.5 output = Query 2 input | ✅ Critical |

---

### Monthly Validation Checklist

**Run this query on the 1st of each month:**
```sql
-- Campaign Segmentation Quality Report
WITH monthly_stats AS (
  SELECT
    FORMAT_DATE('%Y-%m', business_date) as month,
    campaign_segment,
    COUNT(DISTINCT customer_id) as customers,
    COUNT(*) as total_rows
  FROM `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign`
  WHERE business_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 3 MONTH)
  GROUP BY 1, 2
)
SELECT
  month,
  campaign_segment,
  customers,
  total_rows,
  ROUND(customers * 100.0 / SUM(customers) OVER (PARTITION BY month), 1) as pct_of_month
FROM monthly_stats
ORDER BY month DESC, customers DESC;
```

**Expected Patterns:**
- BAU: 70-85% consistently
- CT: 10-20% (may spike during campaign months)
- Unknown: <15% (investigate if >20%)
- Weekly: <1% (may be 0 in some months)

---

### Troubleshooting Common Issues

#### **Issue 1: High "Unknown" Rate (>20%)**

**Symptom:** More than 20% of offers have campaign_segment = 'Unknown'

**Possible Causes:**
1. Timing mismatch: Offer created before underwriting completed
2. Missing data in dl_whitelist tables
3. JOIN condition not matching correctly

**Diagnostic Query:**
```sql
-- Check when offers were created vs business_date
SELECT
  business_date,
  DATE(created_at) as created_date,
  COUNTIF(campaign_segment = 'Unknown') as unknown_count,
  COUNT(*) as total_count,
  ROUND(COUNTIF(campaign_segment = 'Unknown') * 100.0 / COUNT(*), 1) as unknown_pct
FROM `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign`
WHERE business_date >= '2025-10-01'
GROUP BY 1, 2
HAVING unknown_pct > 20
ORDER BY 1 DESC, 2 DESC;
```

**Fix:** Consider switching JOIN condition from `business_date` to `LAST_DAY(key_date)`.

---

#### **Issue 2: Customer Count Inflation**

**Symptom:** Total customers after Query 2.5 is higher than Query 2

**Cause:** Duplicate records from JOIN (customer appears in multiple campaign segments)

**Diagnostic Query:**
```sql
-- Find customers with multiple campaign segments
SELECT
  customer_id,
  business_date,
  STRING_AGG(DISTINCT campaign_segment) as segments,
  COUNT(*) as row_count
FROM `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign`
WHERE business_date = '2025-10-31'
GROUP BY customer_id, business_date
HAVING COUNT(*) > 1
LIMIT 20;
```

**Fix:** Ensure Query 2.5 has proper deduplication with `QUALIFY ROW_NUMBER()`.

---

#### **Issue 3: Campaign Category NULL for CT Segment**

**Symptom:** Some CT customers have campaign_category = 'Unknown' or NULL

**Cause:** Missing `category` field in `dl_wl_final_whitelist_credit_test_raw_history`

**Diagnostic Query:**
```sql
SELECT
  campaign_segment,
  campaign_category,
  COUNT(DISTINCT customer_id) as customers
FROM `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign`
WHERE business_date = '2025-10-31'
  AND campaign_segment = 'CT'
GROUP BY 1, 2
ORDER BY 3 DESC;
```

**Fix:** Acceptable if <5% of CT segment. If >10%, investigate data quality in source table.

---

## References

### Parent Documentation

- **TUPR Dashboard Complete Technical Wiki:** `TUPR_Dashboard_Complete_Technical_Wiki_20251106.md`
- **Propensity Model Feature Analysis:** `Propensity_Model_Feature_Analysis_Knowledge_Base.md`

### Source Code

| File | Purpose | Location |
|------|---------|----------|
| **Query 2.5** | Campaign segmentation bridge | Query2.5_add_campaign_segmentation.sql |
| **Updated Query 3** | Final dataset (with campaign dims) | FIXED_Query3_tupr_dashboard_final_dataset.sql |
| **Updated Query 4** | Monthly summary (with campaign dims) | FIXED_Query4_tupr_dashboard_monthly_summary.sql |

### Related Tables

| Table | Schema | Purpose |
|-------|--------|---------|
| **dl_wl_final_whitelist_raw_history** | dl_whitelist_checkers | BAU campaign data |
| **dl_wl_final_whitelist_credit_test_raw_history** | dl_whitelist_checkers | CT campaign data |
| **dl_wl_final_whitelist_weekly_raw_history** | dl_whitelist_checkers | Weekly campaign data |

---

## Glossary

| Term | Definition |
|------|------------|
| **BAU** | Business As Usual - normal campaign, control group (~70-85% of offers) |
| **CT** | Credit Test - experimental campaigns, test group (~10-20% of offers) |
| **Weekly** | Rapid iteration tests - very small experiments (<1% of offers) |
| **Campaign Segment** | High-level grouping: BAU, CT, Weekly |
| **Campaign Category** | Specific test name within CT (e.g., "Test 1", "Test 2") |
| **Underwriting Waterfall** | Multi-stage filtering process to identify creditworthy customers |
| **dl_whitelist** | Combined table of customers who passed underwriting |
| **Passed Waterfall** | waterfall_failure_step = '99. Passed Underwriting Waterfall' |
| **Unknown Segment** | Offers that don't match any campaign segment (data quality issue) |
| **rnk** | Priority ranking for deduplication (1=BAU, 2=CT, 3=Weekly) |
| **EWS** | Early Warning System - risk monitoring for existing customers |
| **HCI** | Risk scoring model used in underwriting |

---

## Change Log

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2025-11-06 | 1.0 | Initial campaign segmentation integration | Ammar Siregar |

---

## Contact & Support

**Document Owner:** Ammar Siregar (Risk Data Analyst Intern)
**Mentor:** Pak Subhan (Credit Risk Team)
**Dashboard URL:** https://bankjago.cloud.looker.com/dashboards/461
**Data Location:** `data-prd-adhoc.credit_risk_adhoc.*`

For questions or feedback, contact via Jago internal Slack: `#credit-risk-analytics`

---

**Last Updated:** 2025-11-06
**Status:** ✅ In Development
**Next Milestone:** Production deployment after validation
