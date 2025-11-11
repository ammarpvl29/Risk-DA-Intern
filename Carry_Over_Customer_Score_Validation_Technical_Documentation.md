# Carry-Over Customer Score Validation - Technical Documentation

## Document Information

**Project**: Propensity Model Iteration 4 & 5 Validation on Carry-Over Customers
**Analyst**: Ammar Siregar (Risk Data Analyst Intern)
**Data Scientist**: Stephanie
**Mentor**: Pak Subhan
**Date**: 2025-10-06
**Task**: Validate if EWS propensity scores trained on "new offer" customers generalize to "carry-over" customers

---

## Executive Summary

This document describes the technical implementation of carry-over customer score validation. The core objective is to test whether propensity scores generated for "new offer" customers can effectively predict behavior when those same customers receive "carry-over" offers in subsequent months.

**Key Question**: If a customer received a "new offer" in March with a propensity score, does that score still predict their behavior when they receive a "carry-over" offer in April, May, or later months?

---

## Business Context

### Customer Offer Types

**New Offer Customers**:
- Fresh loan offers in the current month
- Smaller cohort (~70,000 customers)
- Model training primarily based on this segment

**Carry-Over Customers**:
- Offers from previous months, refreshed via whitelist mechanism
- Much larger cohort (5x new offers, ~358,000 unique customers)
- Can receive multiple carry-over offers across different months

### Validation Objective

Ensure the propensity model (built on "new offer" segment) maintains predictive power on the "carry-over" segment, which represents the majority of the customer base.

---

## Data Infrastructure

### Source Tables

#### 1. Base Customer Loan Details
**Table**: `data-prd-adhoc.temp_ammar.ammar_customer_loan_details`

**Key Fields**:
- `customer_id` - Unique customer identifier
- `business_date` - Business period (month-end date)
- `created_at` - Offer creation timestamp
- `is_carry_over_offer` - Flag (1 = carry-over, 0 = new offer)
- `is_new_offer` - Flag (1 = new offer, 0 = carry-over)
- `flag_takeup` - Target variable (1 = loan disbursed, 0 = not taken up)
- `expires_at` - Offer expiration date
- `plafond` - Loan limit amount

**Schema**: `data-prd-adhoc.temp_ammar.ammar_customer_loan_details.csv`

#### 2. EWS Propensity Score Tables
**Tables** (Created as part of this task):
- `data-prd-adhoc.temp_ammar.ammar_iter4_dev_scores`
- `data-prd-adhoc.temp_ammar.ammar_iter4_oot_scores`
- `data-prd-adhoc.temp_ammar.ammar_iter5_dev_scores`
- `data-prd-adhoc.temp_ammar.ammar_iter5_oot_scores`

**Key Fields**:
- `customer_id` - Links to base table
- `offer_date` - Score reference date (DATE format from period)
- `period` - Original period string (YYYY-MM-DD format)
- `scores_bin` - Propensity score bins (0-9, where 9 = highest propensity)
- `calibrated_score_bin` - EWS risk score bins (10 ranges, risk of DEFAULT)
- `flag_takeup` - Actual take-up outcome
- `split_tagging` - Dataset split ('train', 'test', 'oot')
- `scores` - Raw propensity score
- `calibrated_score` - Raw EWS risk score

**Source Data**:
- Iteration 4 (Non-Bureau): `ammar_df_scores_20251001_nonbureau`, `ammar_df_scores_oot_20251001_nonbureau`
- Iteration 5 (Bureau Enhanced): `ammar_df_scores_20251001_bureau_1m`, `ammar_df_scores_oot_20251001_bureau_1m`

---

## Technical Implementation

### Phase 1: Physical Table Creation

#### Purpose
Create permanent customer-level score tables (not aggregated) to enable temporal joining with carry-over customers.

#### Query Pattern

```sql
CREATE OR REPLACE TABLE `data-prd-adhoc.temp_ammar.ammar_iter5_dev_scores` AS
WITH
model_scores_split AS
(
  SELECT
    SPLIT(primary_key, '|')[OFFSET(0)] AS customer_id,
    SPLIT(primary_key, '|')[OFFSET(1)] AS appid,
    SPLIT(primary_key, '|')[OFFSET(2)] AS period,
    flag_takeup,
    split_tagging,
    scores,
    scores_bin
  FROM `data-prd-adhoc.credit_risk_adhoc.ammar_df_scores_20251001_bureau_1m`
  WHERE split_tagging IN ('train', 'test') and primary_key is not null
)
,
joined_data AS
(
  select x.*,y.cbas_created_date,y.calibrated_score_bin,y.calibrated_score
  from model_scores_split x
  left join `jago-bank-data-production.datascience_digital_lending.ews_inferences_monthly` y
  on x.customer_id = y.customer_id_lfs
  and LAST_DAY(date(cbas_created_date)) <= LAST_DAY(DATE_SUB(date(period), INTERVAL 1 MONTH))
  where cbas_created_month > '2024-01-01'
),
joined_data_summary
as
(
  select * from joined_data
  qualify DENSE_RANK() OVER (PARTITION BY customer_id,period ORDER BY LAST_DAY(date(cbas_created_date)) DESC,calibrated_score ASC,appid ASC)=1
),
join_data_null
as
(
  select  x.*
  from model_scores_split x left join joined_data y
  on x.customer_id=y.customer_id
  where y.customer_id is null
),
join_data_null1 AS
(
  select x.*,y.cbas_created_date,y.calibrated_score_bin,y.calibrated_score
  from join_data_null x
  left join `jago-bank-data-production.datascience_digital_lending.ews_inferences_monthly` y
  on x.customer_id = y.customer_id_lfs
  and LAST_DAY(date(cbas_created_date)) = LAST_DAY(date(period))
  where cbas_created_month > '2024-01-01'
),
gabungan
as
(
  select *, 2 as sources1 from join_data_null1
  union all
  select *, 1 as sources1 from joined_data_summary
),
gabungan_summary
as
(
  select *
  from gabungan
  qualify DENSE_RANK() OVER (PARTITION BY customer_id,period ORDER BY sources1 asc)=1
)
-- CRITICAL: Keep customer-level data (no GROUP BY)
select
  customer_id,
  appid,
  DATE(period) as offer_date,  -- period is already YYYY-MM-DD format
  period,
  split_tagging,
  scores_bin,
  calibrated_score_bin,
  flag_takeup,
  scores,
  calibrated_score
from gabungan_summary;
```

#### Key Technical Details

**Period Format Handling**:
```sql
-- WRONG: PARSE_DATE('%Y%m%d', period) -- Causes "Failed to parse" error
-- CORRECT: DATE(period) -- Period is already 'YYYY-MM-DD' format
```

**EWS Score Joining Logic** (from mentor's pattern):
1. **Standard Logic**: Get EWS score from previous month
   - `LAST_DAY(cbas_created_date) <= LAST_DAY(DATE_SUB(period, INTERVAL 1 MONTH))`
2. **Fallback Logic**: Use same month score if previous month not available
   - `LAST_DAY(cbas_created_date) = LAST_DAY(period)`
3. **Union with Priority**: Prefer standard logic (`sources1=1` over `sources1=2`)

**Table Output**: Customer-level records (NOT aggregated) to preserve granularity for temporal joins

---

### Phase 2: Carry-Over Customer Score Validation

#### Core Logic

**Join Condition**: Match carry-over customers with their historical "new offer" scores where:
1. Customer ID matches
2. Score offer_date < Carry-over business_date (historical scores only)
3. Use most recent available score within time window

#### Complete Query

```sql
-- Carry-Over Customer Score Validation Query
-- Tests if "new offer" scores predict "carry-over" behavior

WITH carry_over_base AS (
  SELECT
    customer_id,
    created_at as carry_over_offer_date,
    business_date as period,
    flag_takeup as actual_takeup,
    expires_at,
    plafond
  FROM `data-prd-adhoc.temp_ammar.ammar_customer_loan_details`
  WHERE is_carry_over_offer = 1
),

-- Standard logic: Get scores from PREVIOUS month
carry_over_with_scores_standard AS (
  SELECT
    co.customer_id,
    co.carry_over_offer_date,
    co.period,
    co.actual_takeup,
    s.offer_date as score_reference_date,
    s.scores_bin,
    s.calibrated_score_bin,
    s.scores,
    s.calibrated_score,
    s.split_tagging
  FROM carry_over_base co
  LEFT JOIN `data-prd-adhoc.temp_ammar.ammar_iter5_dev_scores` s
    ON co.customer_id = s.customer_id
    AND LAST_DAY(s.offer_date) <= LAST_DAY(DATE_SUB(co.period, INTERVAL 1 MONTH))
  QUALIFY DENSE_RANK() OVER (
    PARTITION BY co.customer_id, co.period
    ORDER BY LAST_DAY(s.offer_date) DESC, s.calibrated_score ASC
  ) = 1
),

-- Find customers with no match from standard logic
carry_over_null AS (
  SELECT co.*
  FROM carry_over_base co
  LEFT JOIN carry_over_with_scores_standard s
    ON co.customer_id = s.customer_id AND co.period = s.period
  WHERE s.customer_id IS NULL
),

-- Fallback logic: Use SAME month scores for unmatched customers
carry_over_with_scores_fallback AS (
  SELECT
    co.customer_id,
    co.carry_over_offer_date,
    co.period,
    co.actual_takeup,
    s.offer_date as score_reference_date,
    s.scores_bin,
    s.calibrated_score_bin,
    s.scores,
    s.calibrated_score,
    s.split_tagging
  FROM carry_over_null co
  LEFT JOIN `data-prd-adhoc.temp_ammar.ammar_iter5_dev_scores` s
    ON co.customer_id = s.customer_id
    AND LAST_DAY(s.offer_date) = LAST_DAY(co.period)
  QUALIFY DENSE_RANK() OVER (
    PARTITION BY co.customer_id, co.period
    ORDER BY LAST_DAY(s.offer_date) DESC, s.calibrated_score ASC
  ) = 1
),

-- Combine both sources (prioritize standard logic)
gabungan AS (
  SELECT *, 2 as sources1 FROM carry_over_with_scores_fallback
  UNION ALL
  SELECT *, 1 as sources1 FROM carry_over_with_scores_standard
),

-- Deduplicate preferring standard logic
gabungan_summary AS (
  SELECT *
  FROM gabungan
  QUALIFY DENSE_RANK() OVER (
    PARTITION BY customer_id, period
    ORDER BY sources1 ASC
  ) = 1
)

-- Final aggregated output for pivot table
SELECT
  period,
  split_tagging,
  scores_bin,
  calibrated_score_bin,
  actual_takeup as flag_takeup,
  COUNT(DISTINCT customer_id) as count_customer
FROM gabungan_summary
WHERE scores_bin IS NOT NULL  -- Exclude customers without valid scores
GROUP BY period, split_tagging, scores_bin, calibrated_score_bin, actual_takeup
ORDER BY period, split_tagging, scores_bin, calibrated_score_bin, actual_takeup;
```

---

## Query Logic Breakdown

### CTE 1: carry_over_base
**Purpose**: Filter base table for carry-over customers only

**Key Logic**:
- `WHERE is_carry_over_offer = 1`
- `business_date as period` - Critical for matching with score table

### CTE 2: carry_over_with_scores_standard
**Purpose**: Join carry-over customers with historical scores (previous month)

**Join Conditions**:
```sql
ON co.customer_id = s.customer_id
AND LAST_DAY(s.offer_date) <= LAST_DAY(DATE_SUB(co.period, INTERVAL 1 MONTH))
```

**Deduplication Logic**:
```sql
QUALIFY DENSE_RANK() OVER (
  PARTITION BY co.customer_id, co.period
  ORDER BY LAST_DAY(s.offer_date) DESC,  -- Most recent score
           s.calibrated_score ASC          -- Lowest risk if tie
) = 1
```

### CTE 3: carry_over_null
**Purpose**: Identify customers who didn't match in standard logic

**Why NULL matches occur**:
- Carry-over offer before any "new offer" scoring started
- Customer only has same-month scores (no previous month available)

### CTE 4: carry_over_with_scores_fallback
**Purpose**: Apply fallback logic for unmatched customers (same month score)

**Join Condition**:
```sql
AND LAST_DAY(s.offer_date) = LAST_DAY(co.period)
```

### CTE 5: gabungan
**Purpose**: Union standard and fallback results with priority flag

**sources1 Flag**:
- `1` = Standard logic (previous month)
- `2` = Fallback logic (same month)

### CTE 6: gabungan_summary
**Purpose**: Deduplicate, preferring standard logic over fallback

**Final Selection**:
```sql
QUALIFY DENSE_RANK() OVER (
  PARTITION BY customer_id, period
  ORDER BY sources1 ASC  -- Prefer 1 over 2
) = 1
```

---

## Key Findings

### Customer Count Analysis

**Diagnostic Query Results**:
- **iter5_dev unique customers**: 328,823
- **Carry-over unique customers**: 358,029
- **Pivot table total count**: 838,553

### Why Customer Count is Higher in Carry-Over Analysis

**Time-Series Nature**:
- Each unique customer can appear **multiple times** across different months
- Example: Customer A appears in April, May, June, July, August = 5 records

**Sample Customer Frequency**:
```
customer_id         num_carryover_months
1322413435          8
1557516456          8
1794393824          8
```

**Interpretation**:
- 838,553 total records ÷ 358,029 unique customers = **2.3 average appearances per customer**
- This is **expected behavior** - validates score persistence across multiple months
- Tests: "Does March score predict April behavior? May behavior? June behavior?"

**Mentor Guidance**: "Take the other offers too" - confirmed that multiple monthly appearances are intentional for score decay analysis.

---

## Performance Matrix Structure

### Output Columns

```sql
period                    -- Business date (YYYY-MM-DD)
split_tagging             -- 'train' or 'test' from score table
scores_bin                -- Propensity score 0-9 (9 = highest propensity)
calibrated_score_bin      -- EWS risk bin (10 ranges)
flag_takeup               -- Actual take-up (0 or 1)
count_customer            -- Distinct customers in this cell
```

### Pivot Table Dimensions

**Rows**: `scores_bin` (0-9)
**Columns**: `calibrated_score_bin` (10 risk ranges)
**Values**:
- Count of customers
- Take-up rate (%)
- Conditional formatting (red-yellow-green)

### Expected Patterns

**If model generalizes well**:
- scores_bin 9 should show highest take-up rate (~18%)
- scores_bin 0 should show lowest take-up rate (~0.01%)
- Pattern should mirror iter5_dev development performance

**If model fails**:
- Flat take-up rates across all scores_bin
- Discrimination ratio < 10x (vs expected 1,808x for iter5)

---

## Iteration Comparison Framework

### Run Query for All 4 Tables

1. **Iteration 4 Development**: `ammar_iter4_dev_scores`
2. **Iteration 4 OOT**: `ammar_iter4_oot_scores`
3. **Iteration 5 Development**: `ammar_iter5_dev_scores`
4. **Iteration 5 OOT**: `ammar_iter5_oot_scores`

### Comparison Metrics

**Model Performance**:
- Discrimination power (Bin 9 vs Bin 0 ratio)
- Take-up rate progression across bins
- Stability across time periods

**Business Validation**:
- Does iter5 (bureau-enhanced) maintain 1,808x discrimination on carry-over?
- Does iter4 (non-bureau) maintain 73x discrimination on carry-over?
- Are patterns consistent with original dev/OOT datasets?

---

## Common Issues & Troubleshooting

### Issue 1: "Failed to parse input string '2025-04-30'"

**Cause**: Incorrect date parsing function
**Solution**:
```sql
-- WRONG
PARSE_DATE('%Y%m%d', period)

-- CORRECT
DATE(period)  -- period is already 'YYYY-MM-DD' string
```

### Issue 2: NULL scores_bin in first 39 rows

**Cause**: Carry-over customers before scoring period (June 2024 - February 2025)
**Solution**: Filter with `WHERE scores_bin IS NOT NULL`

**Why it happens**:
- Score tables only contain March 2025+ data
- Early carry-over offers have no historical "new offer" score to reference

### Issue 3: Mixing iterations in standard vs fallback

**Cause**: Copy-paste error using iter4 in standard, iter5 in fallback
**Solution**: Ensure both CTEs reference the **same iteration table**

### Issue 4: Aggregated tables instead of customer-level

**Cause**: Using GROUP BY in CREATE TABLE statement
**Solution**: Keep customer-level records (no GROUP BY) for temporal joins

---

## Data Quality Checks

### Validation Queries

```sql
-- 1. Check for duplicate customer-period combinations
SELECT customer_id, period, COUNT(*) as cnt
FROM `data-prd-adhoc.temp_ammar.ammar_iter5_dev_scores`
GROUP BY customer_id, period
HAVING cnt > 1;

-- 2. Verify date ranges
SELECT
  MIN(offer_date) as earliest_score,
  MAX(offer_date) as latest_score
FROM `data-prd-adhoc.temp_ammar.ammar_iter5_dev_scores`;

-- 3. Check score distribution
SELECT
  scores_bin,
  COUNT(*) as customers,
  ROUND(AVG(flag_takeup) * 100, 2) as takeup_pct
FROM `data-prd-adhoc.temp_ammar.ammar_iter5_dev_scores`
GROUP BY scores_bin
ORDER BY scores_bin;
```

---

## Next Steps

### Analysis Tasks

1. **Create Pivot Tables**: Build 4 performance matrices (iter4 dev/oot, iter5 dev/oot)
2. **Compare Discrimination**: Calculate Bin 9 / Bin 0 ratios for carry-over vs original
3. **Time Decay Analysis**: Track score performance degradation over months
4. **Risk Concentration Check**: Ensure high-propensity ≠ high-risk customers

### Presentation to Mentor

**Key Questions to Answer**:
- Does the model maintain predictive power on carry-over customers?
- Is there score decay over time (March score → August behavior)?
- Should we recommend different models for new vs carry-over segments?

---

## Technical References

### Related Documentation
- `Propensity_Model_Iteration_4_5_Analysis_Wiki.md` - Model development details
- `Propensity_Model_Feature_Analysis_Knowledge_Base.md` - Feature validation framework
- `Data_Analysis_Flow_Guide_Bank_Jago.md` - Standard analysis methodology

### SQL Patterns Used
- `SPLIT()` - Parse primary_key composite field
- `LAST_DAY()` - Month-end date normalization
- `DATE_SUB()` - Temporal offset (previous month)
- `DENSE_RANK() with QUALIFY` - Efficient deduplication
- `UNION ALL` with priority flag - Fallback logic pattern

### BigQuery Best Practices
- Customer-level tables before aggregation
- Temporal joins with INTERVAL logic
- NULL handling with fallback CTEs
- Consistent date formatting

---

## Glossary

**Business Date**: Month-end date representing the analysis period
**Carry-Over Offer**: Loan offer refreshed from previous month via whitelist
**New Offer**: Fresh loan offer in current month
**scores_bin**: Propensity to ACCEPT loan (0-9, built by Stephanie)
**calibrated_score_bin**: Risk of DEFAULT (EWS system, 10 ranges)
**split_tagging**: Dataset split identifier ('train', 'test', 'oot')
**sources1**: Priority flag (1=standard logic, 2=fallback logic)
**Take-up Rate**: Percentage of customers who accepted and disbursed loan

---

**Document Version**: 1.0
**Last Updated**: 2025-10-06
**Status**: Active Implementation Phase
**Query Status**: Validated and Production-Ready
