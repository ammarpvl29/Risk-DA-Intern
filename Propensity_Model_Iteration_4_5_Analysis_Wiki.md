# Propensity Model Iteration 4 & 5 Analysis - Technical Wiki

## Table of Contents
- [Overview](#overview)
- [Model Versions](#model-versions)
- [Data Architecture](#data-architecture)
- [Query Implementation](#query-implementation)
- [Pivot Table Analysis](#pivot-table-analysis)
- [Key Findings](#key-findings)
- [Comparison Framework](#comparison-framework)
- [References](#references)

---

## Overview

**Project Name**: Propensity Loan Take-Up Model - Iteration 4 & 5 Validation
**Date**: 2025-10-04
**Analyst**: Ammar Siregar (Risk Data Analyst Intern)
**Data Scientist**: Stephanie Dioquino
**Stakeholders**: Kak Akka, Kak Fang, Bang Subhan (Mentors)

### Purpose
Validate and compare two model iterations to support final model selection for production deployment:
- **Iteration 4**: Non-Bureau Model (Internal Jago data only)
- **Iteration 5**: Bureau 1M Model (Internal + SLIK credit bureau data)

### Analysis Scope
- Train dataset validation (historical data)
- OOT (Out-of-Time) validation (July-August 2025 unseen data)
- Pivot table analysis for business stakeholder review
- Performance comparison: Internal-only vs Bureau-enhanced models

---

## Model Versions

### Iteration 4: Non-Bureau Model

**Feature Set**: 15 features (Internal Jago data only)

**Key Features**:
- `fundingbalance_active_min_1month`: Minimum funding balance in last month
- `devicemanufacture_latest`: Latest device manufacturer
- `fundingbalance_active_avg_12months`: Average funding balance over 12 months
- `dailyeventdays_allevent_11pmto5am_count_6months`: Late-night activity patterns
- `transactionamt_interbanktransfer_in_pct25_12months`: Interbank transfer percentiles
- `adbdiff_active_*`: Average daily balance differences

**Model Philosophy**: Can we predict loan take-up using **only internal behavioral data** without external credit bureau information?

**Business Value**:
- Faster scoring (no SLIK API dependency)
- Works for customers without credit history
- Lower operational cost

---

### Iteration 5: Bureau 1M Model

**Feature Set**: 38 features (Internal + SLIK credit bureau data)

**Additional Bureau Features**:
- `slikbalance_unsecurednoncreditcard_avg`: Average unsecured non-credit card debt (SLIK)
- `slikplafond_*`: Credit limits from other institutions
- `mob_multiguna_allcondition_min`: Months on books for multi-purpose loans
- `maturity_rate`: Loan maturity rate across institutions
- `plafond_*`: Plafond/limit features from credit bureau
- `installment_*`: Installment payment patterns
- `flags_*`: Credit behavior flags (e.g., high interest rate loans, top 10 banks)

**Model Philosophy**: Does adding **external credit bureau data** improve prediction accuracy enough to justify additional complexity?

**Business Value**:
- More comprehensive risk assessment
- Captures cross-institutional behavior
- Potentially better separation between high/low propensity

---

## Data Architecture

### Source Tables

#### Model Output Tables (Stephanie's Models)

**Iteration 4 - Non-Bureau**:
- Training: `data-prd-adhoc.credit_risk_adhoc.ammar_df_scores_20251001_nonbureau`
- OOT: `data-prd-adhoc.credit_risk_adhoc.ammar_df_scores_oot_20251001_nonbureau`

**Iteration 5 - Bureau 1M**:
- Training: `data-prd-adhoc.credit_risk_adhoc.ammar_df_scores_20251001_bureau_1m`
- OOT: `data-prd-adhoc.credit_risk_adhoc.ammar_df_scores_oot_20251001_bureau_1m`

**Common Schema**:
```
primary_key (STRING): "customer_id|appid|period" composite key
flag_takeup (INTEGER): 1 = took loan, 0 = did not take loan
split_tagging (STRING): "train", "test", or "valid"
scores (FLOAT): Model propensity score (0-1)
scores_bin (INTEGER): Decile bin (0-9, where 9 = highest propensity)
[Feature columns...]
```

#### EWS Calibrated Scores Table

**Table**: `data-prd-adhoc.credit_risk_adhoc.ammar_ews_score`

**Schema**:
```
lfs_customer_id (STRING): Customer identifier
appid (INTEGER): Application ID
facility_start_date (DATE): Loan facility start date
calibrated_scores (FLOAT): EWS calibrated risk score
calibrated_scores_bin (STRING): Calibrated score decile bin
```

**Purpose**: Provides calibrated risk scores for cross-validation with propensity scores

**Join Key**: `lfs_customer_id + appid` (requires primary_key splitting)

---

### Data Quality Considerations

**From Iteration 1 Learnings**:
1. **NULL Primary Keys**: ~2,000 records with NULL primary_key (from cbas_customer_level non-matches)
   - **Handling**: Filter out with `WHERE primary_key IS NOT NULL`

2. **EWS Duplicates**: Some customers have multiple EWS records for same appid
   - **Handling**: Deduplicate using `ROW_NUMBER() OVER (PARTITION BY lfs_customer_id, appid ORDER BY facility_start_date DESC)`

3. **Primary Key Format**: Composite key requires SPLIT function
   - **Format**: `"customer_id|appid|period"`
   - **Example**: `"V18SR0DP41|25011400123456|2025-06-30"`

---

## Query Implementation

### Base Query Pattern (Applied to All 4 Datasets)

```sql
-- Template: Model Iteration Analysis with EWS Calibrated Scores
-- Adapt for: Iter4_Train, Iter4_OOT, Iter5_Train, Iter5_OOT

WITH
-- Step 1: Split primary_key into components
model_scores_split AS (
  SELECT
    primary_key,
    SPLIT(primary_key, '|')[OFFSET(0)] AS customer_id,
    SPLIT(primary_key, '|')[OFFSET(1)] AS appid,
    SPLIT(primary_key, '|')[OFFSET(2)] AS period,
    flag_takeup,
    split_tagging,
    scores,
    scores_bin
  FROM `data-prd-adhoc.credit_risk_adhoc.ammar_df_scores_20251001_nonbureau`
  WHERE split_tagging = 'train'  -- Change based on dataset
),

-- Step 2: Deduplicate EWS scores
ews_dedup AS (
  SELECT
    lfs_customer_id,
    appid,
    calibrated_scores_bin,
    calibrated_scores
  FROM `data-prd-adhoc.credit_risk_adhoc.ammar_ews_score`
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY lfs_customer_id, appid
    ORDER BY facility_start_date DESC
  ) = 1
),

-- Step 3: Join model scores with EWS calibrated scores
joined_data AS (
  SELECT
    ms.*,
    ews.calibrated_scores_bin,
    ews.calibrated_scores
  FROM model_scores_split ms
  LEFT JOIN ews_dedup ews
    ON ms.customer_id = ews.lfs_customer_id
    AND CAST(ms.appid AS INT64) = ews.appid
)

-- Step 4: Aggregate for pivot table analysis
SELECT
  calibrated_scores_bin,
  scores_bin,
  split_tagging,
  flag_takeup,
  period,
  COUNT(*) AS count
FROM joined_data
WHERE primary_key IS NOT NULL
GROUP BY
  calibrated_scores_bin,
  scores_bin,
  split_tagging,
  flag_takeup,
  period
ORDER BY period, calibrated_scores_bin, scores_bin, flag_takeup;
```

---

### Query Variants

#### Iteration 4 - Non-Bureau Training
```sql
-- Table: ammar_df_scores_20251001_nonbureau
-- Filter: split_tagging = 'train'
```

#### Iteration 4 - Non-Bureau OOT
```sql
-- Table: ammar_df_scores_oot_20251001_nonbureau
-- Note: OOT tables don't have split_tagging column
-- Add: split_tagging AS 'OOT' in SELECT
```

#### Iteration 5 - Bureau 1M Training
```sql
-- Table: ammar_df_scores_20251001_bureau_1m
-- Filter: split_tagging = 'train'
```

#### Iteration 5 - Bureau 1M OOT
```sql
-- Table: ammar_df_scores_oot_20251001_bureau_1m
-- Note: OOT tables don't have split_tagging column
-- Add: split_tagging AS 'OOT' in SELECT
```

---

## Pivot Table Analysis

### Workflow

1. **Run Query** → BigQuery (no CSV download for security)
2. **Copy Results** → Paste into Google Sheets
3. **Create Pivot Tables** → Multiple views for different insights

---

### Pivot Table 1: scores_bin × flag_takeup

**Purpose**: Validate model discriminatory power

**Configuration**:
- **Rows**: `scores_bin` (0-9)
- **Columns**: `flag_takeup` (0, 1)
- **Values**:
  - `SUM of count`
  - `% of Grand Total` (right-click → Show Values As → % of Grand Total)

**Expected Output** (Iteration 4 Example):
```
SUM of count    flag_takeup
scores_bin    0           1         Grand Total   Takeup Rate
0             41,738      65        41,803        0.16%
1             35,909      138       36,047        0.38%
2             28,660      163       28,823        0.57%
3             27,096      270       27,366        0.99%
4             29,457      437       29,894        1.46%
5             25,279      544       25,823        2.11%
6             22,162      703       22,865        3.07%
7             24,959      1,234     26,193        4.71%
8             21,693      3,388     25,081        13.51%
9             [TBD]       [TBD]     [TBD]         [TBD]
Grand Total   256,953     6,942     263,895       2.63%
```

**Key Metrics to Extract**:
- Overall take-up rate: `2.63%`
- Bin 9 take-up rate: `[Calculate from data]`
- Bin 0 take-up rate: `0.16%`
- Separation ratio: `Bin 9 / Bin 0`

---

### Pivot Table 2: scores_bin × period

**Purpose**: Check model stability across time periods

**Configuration**:
- **Rows**: `scores_bin` (0-9)
- **Columns**: `period` (2025-01-31, 2025-02-28, etc.)
- **Values**: `SUM of count`

**Expected Pattern**: Relatively even distribution across periods (no sudden spikes/drops indicating data issues)

---

### Pivot Table 3: calibrated_scores_bin Distribution

**Purpose**: Validate EWS calibrated score balance

**Configuration**:
- **Rows**: `calibrated_scores_bin`
- **Values**:
  - `SUM of count`
  - `% of Grand Total`

**Expected Output**:
```
calibrated_score_bin    SUM of count    % of Total
(-inf, 496]             [TBD]           ~3-5%
(496, 671]              [TBD]           ~15-17%
(671, 734]              [TBD]           ~11-13%
(734, 765]              [TBD]           ~9-11%
(765, 786]              [TBD]           ~10-12%
(786, 801]              [TBD]           ~10-12%
(801, 812]              [TBD]           ~10-12%
(812, 821]              [TBD]           ~10-12%
(821, 827]              [TBD]           ~8-10%
(827, inf]              [TBD]           ~7-9%
Grand Total             [TBD]           100.00%
```

**Health Check**: No single bin should dominate (>30% of total)

---

### Pivot Table 4: scores_bin × calibrated_scores_bin (Counts)

**Purpose**: Cross-validation between propensity and risk scores

**Configuration**:
- **Rows**: `scores_bin` (Propensity)
- **Columns**: `calibrated_scores_bin` (Risk)
- **Values**: `SUM of count`

**Analysis**: Look for correlations or divergences between propensity and risk

---

### Pivot Table 5: scores_bin × calibrated_scores_bin (Takeup Rates)

**Purpose**: Identify high-propensity, low-risk customer segments

**Configuration**:
- **Rows**: `scores_bin`
- **Columns**: `calibrated_scores_bin`
- **Values**: `SUM of count` where `flag_takeup = 1`
- **Show Values As**: `% of column total`

**Expected Pattern** (Iteration 1 reference):
```
scores_bin  Low Risk   Mid Risk   High Risk
0           0.00%      0.01%      0.03%
1           0.11%      0.07%      0.12%
...
9           21.49%     17.31%     13.02%
```

**Business Insight**: Bin 9 customers show high take-up regardless of risk level, but concentration decreases in high-risk bins (healthy pattern)

---

## Key Findings

### Iteration 4 - Non-Bureau Model

**Training Data Performance**:
- Total Records: `263,895`
- Overall Take-up Rate: `2.63%`
- Bin 9 Take-up Rate: `[TBD after analysis]`
- Bin 0 Take-up Rate: `0.16%`
- Separation Ratio: `[TBD] x`

**Distribution Assessment**:
- ✅ Progressive increase from Bin 0 → Bin 9
- ✅ Well-distributed across bins (no extreme concentrations)
- ✅ Matches Iteration 1 pattern (good consistency)

**OOT Validation**:
- [TBD after running OOT query]
- Expected: Similar separation ratio to training (validates model stability)

---

### Iteration 5 - Bureau 1M Model

**Training Data Performance**:
- Total Records: `[TBD]`
- Overall Take-up Rate: `[TBD]%`
- Bin 9 Take-up Rate: `[TBD]%`
- Bin 0 Take-up Rate: `[TBD]%`
- Separation Ratio: `[TBD] x`

**Hypothesis**:
- Should show **better separation** than Iteration 4 due to bureau features
- Trade-off: More features = higher complexity, potential overfitting risk

**OOT Validation**:
- [TBD after running OOT query]
- **Critical test**: Does bureau model maintain performance on unseen data?

---

## Comparison Framework

### Model Selection Criteria

| Criterion | Weight | Iteration 4 (Non-Bureau) | Iteration 5 (Bureau 1M) |
|-----------|--------|--------------------------|-------------------------|
| **Train Performance** | 25% | [AUC/Gini from Stephanie] | [AUC/Gini from Stephanie] |
| **OOT Performance** | 35% | [TBD] | [TBD] |
| **Business Usability** | 20% | High (no SLIK dependency) | Medium (SLIK API required) |
| **Operational Cost** | 10% | Low | Medium-High |
| **Feature Availability** | 10% | 100% (internal only) | ~85% (SLIK coverage) |

### Expected Trade-offs

**Iteration 4 Advantages**:
- ✅ Faster scoring (no external API calls)
- ✅ Works for all customers (no SLIK data requirement)
- ✅ Lower operational cost
- ✅ Simpler model (easier to explain/maintain)

**Iteration 5 Advantages**:
- ✅ More comprehensive risk view (cross-institutional behavior)
- ✅ Potentially better separation (more predictive features)
- ✅ Validates customer creditworthiness externally

**Decision Framework**:
- If **Iteration 4 OOT performance ≥ 90% of Iteration 5 OOT performance** → Choose Iteration 4 (simplicity wins)
- If **Iteration 5 significantly outperforms** → Justify additional complexity

---

## Validation Checklist

Before presenting to business stakeholders:

### Data Quality
- [ ] No NULL primary keys in analysis (filtered out)
- [ ] EWS scores properly deduplicated (no double-counting)
- [ ] Total record counts match Stephanie's reports
- [ ] All periods represented in dataset

### Model Performance
- [ ] Clear separation between Bin 0 and Bin 9
- [ ] Progressive increase in take-up rate across bins
- [ ] OOT performance comparable to training (no overfitting)
- [ ] Stable performance across time periods

### Business Logic
- [ ] Take-up rates make business sense (not too extreme)
- [ ] Distribution across bins is healthy (not over-concentrated)
- [ ] Calibrated score cross-validation shows logical patterns
- [ ] No concerning segments (high-propensity + high-risk concentration)

---

## References

### Related Documentation
- `Propensity_Model_Feature_Analysis_Knowledge_Base.md` - Iteration 1 analysis and business validation framework
- `Data_Analysis_Flow_Guide_Bank_Jago.md` - SQL best practices and CTE structure
- `Propensity_Model_Business_Validation_Checklist.md` - Business validation criteria

### Previous Iterations
- **Iteration 1**: Initial model (analyzed September 2025)
  - 309,557 records
  - 2.77% overall take-up rate
  - 16.55% take-up in Bin 9, 0.01% in Bin 0
  - 1,655x separation

### Stakeholder Communication
- **Data Science**: Stephanie Dioquino (model development)
- **Risk Team**: Kak Akka, Kak Fang (technical validation)
- **Mentorship**: Bang Subhan (business analysis guidance)
- **Business Users**: Zaki, Aldrics (final model selection)

### Data Sources
- Model outputs: Stephanie's shared folder (2025-10-01 delivery)
- EWS scores: `data-prd-adhoc.credit_risk_adhoc.ammar_ews_score`
- Validation period: July-August 2025 (OOT)

---

## Appendix A: Query File Naming Convention

For better script organization (per mentor's guidance):

```
20251004_propensity_iter4_nonbureau_train_pivot.sql
20251004_propensity_iter4_nonbureau_oot_pivot.sql
20251004_propensity_iter5_bureau1m_train_pivot.sql
20251004_propensity_iter5_bureau1m_oot_pivot.sql
```

**Format**: `YYYYMMDD_project_iteration_dataset_purpose.sql`

---

## Appendix B: Expected Stakeholder Questions

**Q1: Why do we need two models?**
A: Testing whether external credit bureau data (SLIK) adds enough value to justify operational complexity.

**Q2: What's the difference between "train" and "OOT"?**
A: Train = historical data model was built on. OOT = unseen future data (July-Aug 2025) to test if model works on new customers.

**Q3: What does "Bin 9" mean?**
A: Highest 10% propensity score. These customers are most likely to take up loans based on the model.

**Q4: What's a good separation ratio?**
A: From Iteration 1, we achieved 1,655x (Bin 9 vs Bin 0). Anything above 1,000x is excellent discrimination.

**Q5: Which model should we choose?**
A: Depends on OOT validation results. If Iteration 4 performs nearly as well as Iteration 5, choose Iteration 4 for simplicity.

---

## Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-04 | Ammar Siregar | Initial wiki creation for Iteration 4 & 5 analysis |

---

**Document Status**: Active Analysis
**Next Review**: After OOT validation results
**Last Updated**: 2025-10-04
