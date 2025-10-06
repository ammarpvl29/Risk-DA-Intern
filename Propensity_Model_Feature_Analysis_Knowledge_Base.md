# Propensity Model Feature Analysis - Knowledge Base

## Project Overview

**Project Name**: Propensity Loan Take Up 2025
**Analyst**: Ammar Siregar (Risk Data Analyst Intern)
**Data Scientist**: Stephanie
**Mentor**: Akka, Fang, Subhan
**Objective**: Validate model feature trends against business logic and prevent high-risk customer concentration

---

## Role & Responsibilities

### Primary Role: Feature Analysis & Business Validation Expert

**Core Tasks**:
1. **Prevent High-Risk Concentration**: Ensure high-propensity customers are not disproportionately high-risk
2. **Validate Feature Trends**: Confirm model patterns align with business logic
3. **Analyze Model Results**: Deep-dive into Stephanie's model outputs (not building the model)

**NOT Responsible For**:
- Model building (Stephanie's role)
- Technical model validation (Akka & Fang's role)
- Overfitting checks (Akka & Fang's role)

---

## Model Methodology

### Target Definition
- **Target**: Loan take-up (1 = customer accepted and loan disbursed, 0 = did not take up)
- **Prediction Goal**: Predict which customers will take up a NEW loan offer

### Time Lag Principle (Critical)
- **Cannot use current month data to predict current month behavior**
- **Example**: To predict August take-up, use only July data
- **Why**: Prevents data leakage and bias
- **Our Analysis Period**: July data → August offers → September predictions

### Data Sources
**Internal Data**:
- Balance features
- Transaction history
- Demographics
- Daily activity/login patterns

**External Data (SLIK)**:
- Credit bureau data
- Customer behavior at other institutions
- Existing loan facilities

---

## Model Performance (Iteration 2 - Latest)

### Performance Metrics
- **AUC (Test)**: 0.8653
- **Gini (Test)**: 0.7305
- **KS (Test)**: 0.5765

### Score Distribution
- **Decile 10 (Highest Propensity)**: 16.55% take-up rate
- **Decile 1 (Lowest Propensity)**: 0.01% take-up rate
- **1655x difference** between highest and lowest deciles

---

## Key Feature Findings

### Top Features by Importance (from Stephanie's Model)

#### 1. fundingbalance_active_min_1month (IV: 0.2833)
**Model Pattern**: Lower balance = Higher propensity (NEGATIVE SHAP correlation)

**Evidence**:
- Score Bin 0 (lowest propensity): Mean balance = 9.8M IDR
- Score Bin 9 (highest propensity): Mean balance = 56K IDR (175x lower)
- Bad rate progression: 2.99% → 4.29% → 0.60% (as balance increases)

**Business Validation**:
- ✅ Pattern is REAL in actual data
- 🚨 Very Low Balance (0-100K): 3.6% take-up rate vs Very High Balance (10M+): 0.63%
- ⚠️ **CONCERNING**: Targets financially stressed customers

**WoE Range**: -0.5036 to 1.5002

---

#### 2. slikbalance_unsecurednoncreditcard_avg (IV: 0.5887)
**Model Pattern**: Higher existing debt = Higher propensity (POSITIVE correlation)

**Evidence**:
- No existing debt customers: 1.47% bad rate
- High debt customers (155M-514M): 6.54% bad rate
- Highest debt customers have negative WoE (-0.9472)

**Business Validation**:
- ✅ Pattern confirmed in reality
- 🚨 Customers with more debt are more likely to take new loans
- ⚠️ **VERY RISKY**: Debt accumulation pattern

**WoE Range**: -0.9472 to 0.5958

---

#### 3. slikplafond_active_moble3_max (IV: 0.3555)
**Model Pattern**: More existing facilities = Higher default risk

**Evidence**:
- Bad rate increases from 1.92% to 6.27% as facilities increase
- WoE shows negative correlation in higher bins (-0.8746)

**Business Validation**:
- ⚠️ **RISKY**: Multiple facilities indicate credit dependency

---

#### 4. devicemanufacture_latest (IV: 0.3883)
**Model Pattern**: Device type correlates with behavior

**Evidence**:
- Certain device types show declining bad rates (1.63% → 7.45%)
- WoE range: -1.0873 to 0.4924

**Business Validation**:
- ✅ **LOGICAL**: Device patterns reflect customer segments
- ✅ **ACCEPTABLE**: No concerning business risk

---

#### 5. fundingbalance_active_avg_12months (IV: 0.1587)
**Model Pattern**: Higher average balance = Lower propensity

**Evidence**:
- Average balance correlates inversely with take-up
- WoE progression shows healthy pattern

**Business Validation**:
- ✅ **SAFE**: Makes business sense
- ✅ **GOOD INVERSE RELATIONSHIP**

---

## Customer Cohort Analysis

### Carry-Over vs New Offer Performance

**New Offer Customers**:
- Take-up rate: 3.49% (High Financial Stress segment)
- Take-up rate: 2.42% (Medium Financial Stress segment)
- **Average**: ~3% take-up

**Carry-Over Customers**:
- Take-up rate: 0.76% (High Financial Stress segment)
- Take-up rate: 0.75% (Medium Financial Stress segment)
- **Average**: ~0.75% take-up

**Key Finding**: New Offers perform **4.6x better** than Carry-Over reactivation

---

## Critical Business Concerns

### 1. Financial Stress Targeting 🚨

**The Problem**:
- Model correctly identifies that lowest balance customers have highest propensity
- BUT these are financially vulnerable customers (default risk)

**Data Evidence**:
- Very Low Balance (0-100K): 3.94% take-up rate
- Low Balance (100K-1M): 5.69% take-up rate
- Very High Balance (10M+): 1.30% take-up rate

**Risk Assessment**: **DANGEROUS**

---

### 2. Inactive Customer Pattern 🔴

**The Problem**:
- Customers with NO login activity show highest take-up rates

**Data Evidence**:
- No Login: 9.86% take-up rate
- High Activity (10+ logins): 6.77% take-up rate

**Interpretation**: Suggests financially desperate customers, not engaged users

**Risk Assessment**: **CONCERNING**

---

### 3. Debt Accumulation Pattern ⚠️

**The Problem**:
- Customers with existing high debt seek more loans

**Business Risk**: Creating debt spirals, potential defaults

---

## Feature Validation Framework

### Analysis Approach

**Flow**:
1. Review model results (SHAP values, score distributions)
2. Query BigQuery to validate patterns in actual data
3. Create spreadsheet visualizations with sparklines
4. Assess business risk vs model accuracy

**NOT** creating new predictive queries - validating existing model insights

---

## Data Infrastructure

### Key Tables Used

**Customer Segmentation**:
- `data-prd-adhoc.temp_ammar.ammar_customer_loan_details`
  - Contains: `is_carry_over_offer`, `is_new_offer`, `flag_takeup`
  - Business date: 2025-08-31 (August offers)

**Customer Profile**:
- `jago-bank-data-production.data_mart.customer`
  - Contains: `total_balance`, `daily_login_count`, `age_group`
  - Business date: 2025-07-31 (July data for prediction)

**Loan Applications**:
- `jago-bank-data-production.data_mart.loan_application`
  - Links via: `id_number`
  - Contains: `disbursement_date`, `flag_disbursed`

**Key Linking Field**: `id_number` (not always `customer_id`)

---

## Validation Query Patterns

### Financial Stress Validation
```sql
-- Purpose: Validate low balance = high propensity pattern
-- Uses July customer data + August loan behavior
-- Segments: Carry-over vs New offer
-- Critical fields: total_balance, flag_takeup, is_carry_over_offer
```

### Cohort Performance Analysis
```sql
-- Purpose: Compare New Offer vs Carry-Over performance
-- Key finding: New offers 4.6x better than carry-over
-- Business implication: Focus acquisition over reactivation
```

---

## Visualization Requirements

### Sparkline Charts (Per Mentor's Template)

**Format**: Mini horizontal bar charts in spreadsheet cells

**Formula Example** (Google Sheets):
```
=SPARKLINE(bad_rate_range,{"charttype","column";"max",7;"min",0;"color",IF(trend="CONCERNING","red","green")})
```

**Purpose**:
- Show feature trend across bins at a glance
- Color code: Red = concerning, Green = safe
- Based on: EWS Score Checking template

**Reference File**: `DL Propensity Model Working File.xlsx` → Sheet: `feature trends_iter02`

---

## Business Recommendations

### Deployment Strategy

**✅ SAFE TO TARGET**:
- Medium balance customers (1M-5M IDR)
- New offer cohort
- Expected take-up: 2.42%

**⚠️ USE CAUTION**:
- Medium-high balance with stable activity
- Carry-over customers (lower conversion but lower risk)

**🚫 EXCLUDE FROM TARGETING**:
- Very low balance (<100K) - Despite 3.6% take-up, too risky
- High existing debt customers (>20M unsecured debt)
- Inactive customers with low balance (financial desperation signal)

---

## A/B Model Comparison Plan

### Model 1: Internal Data Only
- Demographics, Balance, Transaction
- No SLIK features

### Model 2: Internal + SLIK Data
- All Model 1 features + Credit bureau data
- Purpose: Measure uplift from external data

**Current Status**: Waiting on Stephanie for both model versions

---

## Key Metrics to Monitor

### Model Performance
- AUC, Gini, KS (already provided by Stephanie)

### Business Validation Metrics
- Take-up rate by balance segment
- Take-up rate by cohort (New vs Carry-over)
- Risk concentration by score decile
- Bad rate correlation with propensity score

---

## Analysis Skills Required

### Technical
- SQL querying (BigQuery)
- Excel/Google Sheets pivot analysis
- Sparkline visualization
- Data validation against business logic

### Business
- Risk assessment
- Feature interpretation
- Pattern recognition
- Recommendation development

**Focus**: Analysis and communication, NOT complex modeling

---

## Common Pitfalls to Avoid

1. ❌ **Don't use current month data to predict current month**
2. ❌ **Don't confuse customer_id with id_number** (use id_number for linking)
3. ❌ **Don't create new predictions** (validate Stephanie's model only)
4. ❌ **Don't ignore business context** (mathematically correct ≠ business safe)
5. ❌ **Don't target high-propensity if they're high-risk**

---

## Session Progress Summary

### Completed
✅ Understood role as Feature Analysis expert
✅ Analyzed Stephanie's model results (Iteration 2)
✅ Validated concerning patterns in actual data
✅ Identified financial stress targeting issue
✅ Quantified New Offer vs Carry-Over performance (4.6x difference)
✅ Created validation query framework
✅ Understood sparkline visualization requirements

### Next Steps
⏳ Import `DL Propensity Model Working File.xlsx`
⏳ Add sparkline visualizations to `feature trends_iter02` sheet
⏳ Create business risk assessment column
⏳ Present findings to mentor with visual validation
⏳ Request Model 1 vs Model 2 from Stephanie for A/B comparison

---

## Key Learnings

1. **Model Accuracy ≠ Business Safety**: Model correctly finds patterns but targets vulnerable customers
2. **New > Carry-Over**: Focus marketing budget on new customer acquisition
3. **Visual Communication Matters**: Sparklines help mentors quickly assess feature trends
4. **Time Lag is Critical**: Always use previous month data for predictions
5. **Cohort Analysis Essential**: Different customer segments behave very differently

---

## Reference Documentation

- `Data_Analysis_Flow_Guide_Bank_Jago.md` - 6-step analysis framework
- `Monthly_Loan_Offer_Performance_Report_19_Sept_2025.md` - 2.71% overall take-up rate
- `Propensity_Model_Cohort_Analysis_22_Sept_2025.md` - Carry-over 5x larger than new offers
- `Notification_Aggregation_Table_Documentation_20250926.md` - Feature engineering work
- `EWS Score Checking (Analysis Features).xlsx` - Template for sparkline format
- `DL Propensity Model Working File.xlsx` - Stephanie's model results with WoE analysis

---

**Document Version**: 1.0
**Last Updated**: 2025-10-01
**Status**: Active Analysis Phase
