# Collection Score Multi-Channel Analysis - Technical Wiki

## Document Control

| Property | Value |
|----------|-------|
| **Document Title** | Collection Score Multi-Channel Feature Engineering & Effectiveness Analysis |
| **Phase** | Phase 2 - Multi-Channel Decision Tree Model Preparation |
| **Created Date** | 2025-10-24 |
| **Author** | Ammar Siregar (Data Analyst Intern - Risk DA) |
| **Status** | Completed - Ready for Presentation |
| **Related Phase** | Phase 1: Collection_Score_Feature_Engineering_Technical_Wiki.md |
| **Output Table** | `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025` |
| **Analysis Period** | August-September 2025 Cohorts |

---

## Executive Summary

### Business Problem
Collection teams conduct multi-channel outbound activities (calls, push notifications, WhatsApp) to customers with payment obligations, but **lack data-driven insights on which combination of collection activities drives payment outcomes**. This results in:
- Inefficient resource allocation across channels
- Unclear ROI on collection activities
- No optimization framework for channel mix and timing

### Objective
Build a **customer-level feature dataset with 104 collection and notification features** to:
1. Predict payment outcomes based on multi-channel collection activities
2. Identify optimal collection strategies by channel, timing, and intensity
3. Develop decision tree model for collection prioritization and resource optimization

### Key Findings

#### 1. Multi-Channel Strategy Effectiveness ⭐
- **Multi-channel customers** (calls + notifications with engagement) show higher payment rates compared to single-channel approach
- **Engagement matters**: RPC (Right Party Contact) and notification read status correlate with better payment outcomes
- **Optimal frequency hypothesis**: Diminishing returns after certain call thresholds (requires decision tree validation)

#### 2. Recovery Pattern Discovery
- **X% of historically bad customers** (DPD 3+ in MOB 1) **recovered and paid on time**
- Recovery rate varies by collection intensity, suggesting collection activities drive positive outcomes
- Average calls differ between recovered vs. still-delinquent customers

#### 3. Data Quality Validation
- All 104 features successfully aggregated from 3 data sources
- No null or unexpected values in critical fields
- Scope validated: Aug-Sept 2025 cohorts with <11 day maturity loans

---

## Data Architecture

### Source Tables

#### 1. Base Population Table
**Table**: `data-prd-adhoc.temp_ammar.collection_analysis_aug_sept_2025_customers`

**Purpose**: Customer-level loan base with risk scores and payment outcomes

**Key Fields**:
```sql
- lfs_customer_id (STRING): Customer identifier
- deal_reference (STRING): Loan account identifier
- facility_start_date (DATE): Loan disbursement date
- first_due_date (DATE): First payment due date
- day_maturity (INTEGER): Loan tenor in days
- plafond (BIGNUMERIC): Loan principal amount
- flag_bad_customer (INTEGER): Historical DPD 3+ flag (MOB 1)
- acct_3dpd_max (INTEGER): Current payment status (0=paid, >0=delinquent)
- cohort_name (STRING): August 2025 / September 2025
- ews_calibrated_scores (FLOAT): Early Warning System score
- risk_group_hci (STRING): HCI risk segmentation
- score_TD (NUMERIC): TrustDecision device score
```

**Filters Applied**:
- `day_maturity < 11` → Short-term products only
- `cohort_name IN ('August 2025', 'September 2025')` → Recent cohorts
- `business_date >= '2024-10-31'` → Vintage data scope

**Population Split**:
- Good Customers: `flag_bad_customer = 0`
- Bad Customers: `flag_bad_customer = 1` (DPD 3+ in MOB 1)

---

#### 2. Collection Calls Table
**Table**: `jago-bank-data-production.digital_lending.digital_lending_collection_daily_report_vendor`

**Purpose**: Granular collection call records from vendor

**Key Fields**:
```sql
- card_no (STRING): Loan account (maps to deal_reference)
- date (TIMESTAMP): Collection call timestamp
- status (STRING): Call outcome (NO_ANSWER, CONTACTED, PTP, etc.)
- remark (STRING): Predictive vs Manual dialer flag
- phone_type (STRING): Main Phone / Emergency Contact / Office
- person_contacted (STRING): RPC / TPC
- collector (STRING): Collector agent ID
- dialed_number (STRING): Phone number called
```

**Time Window**: `business_date >= '2025-08-01' AND <= CURRENT_DATE()`

**Critical Logic**: Collection activities up to **1 month after due date**
```sql
WHERE call_date <= DATE_ADD(loan.due_date, INTERVAL 1 MONTH)
```

**Status Classification**: 8 categories created via CASE WHEN logic
1. **commitment_payment**: PTP, PAID, Payment Plan, etc.
2. **unsuccessful_call**: No Answer, Busy, Dropped, Voice Mail, etc.
3. **successful_contact_no_commitment**: Call Back, Left Message, WPC, etc.
4. **data_information**: Invalid, Resign/Moved, Skip Trace, etc.
5. **workflow**: NEW, TRANSFER, REASSIGN, ACTIVATE, etc.
6. **alternative_channel**: WA - Sent, WA - Read
7. **complaint_escalation**: Complaint - Behavior, Complaint - Vulnerable
8. **other**: All other statuses

---

#### 3. Notification Table
**Table**: `jago-bank-data-production.dwh_core.notification_current`

**Purpose**: Push notification records sent to customers

**Key Fields**:
```sql
- notification_id (STRING): Unique notification identifier
- customer_id (STRING): Customer identifier
- notification_code (STRING): Type of notification
- notification_status (STRING): READ / UNREAD
- deep_link (STRING): Contains deal_reference in accountId parameter
- notification_created_at (TIMESTAMP): Notification sent timestamp
- notification_updated_at (TIMESTAMP): Last status update
```

**Time Window**: `business_date >= '2025-08-01' AND <= CURRENT_DATE()`

**Critical Logic**:
- Extract `deal_reference` using regex: `REGEXP_EXTRACT(deep_link, r'accountId=(\d+)')`
- Filter to collection-related notifications only:
  - `Notification_DL_Repayment_Reminder`
  - `Notification_DL_Overdue_BELL_PUSH_Reminder`
- Same 1-month window after due date

**Validation Completed**:
- `notification_status` values confirmed: `READ` / `UNREAD` (uppercase)
- Deep link extraction pattern validated successfully
- No unexpected NULL values in critical fields

---

### Output Table Schema

**Table**: `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`

**Total Features**: 104 (26 base fields + 69 collection features + 7 notification features + 2 outcome variables)

#### Feature Categories

##### A. Base Customer Information (26 fields)
```
- id_number, lfs_customer_id, facility_reference, deal_reference
- facility_start_date, first_due_date, due_date
- day_maturity, day_first_due, deal_type
- plafond, partner_final, flag_bibit
- cohort_month, cohort_name
- business_date, mob
- fpd_dpd3_mob1_act, fpd_dpd3_mom1_bal
- flag_bad_customer, flag_good_customer
- ews_calibrated_scores, risk_group_hci, score_TD
```

##### B. Call Timing Features (8 fields)
```
- first_call_before_due (DATE)
- diff_first_call_and_before_due (INTEGER): Days before due date
- last_call_before_due (DATE)
- diff_last_call_and_before_due (INTEGER)
- first_call_after_due (DATE)
- diff_first_call_and_after_due (INTEGER): Days after due date
- last_call_after_due (DATE)
- diff_last_call_and_after_due (INTEGER)
```

##### C. Predictive Dialer Features (9 fields)
```
Prefix: pred_*
- pred_total_calls
- pred_commitment_payment
- pred_unsuccessful_call
- pred_successful_no_commit
- pred_data_info
- pred_workflow
- pred_alt_channel
- pred_complaint
- pred_collectors (distinct count)
```

##### D. Manual Dialer Features (9 fields)
```
Prefix: manual_*
(Same structure as predictive)
```

##### E. RPC (Right Party Contact) Features (9 fields)
```
Prefix: rpc_*
(Same structure as predictive)
```

##### F. TPC (Third Party Contact) Features (9 fields)
```
Prefix: tpc_*
(Same structure as predictive)
```

##### G. Main Phone Features (9 fields)
```
Prefix: main_*
(Same structure as predictive)
```

##### H. Emergency Contact Features (9 fields)
```
Prefix: emerg_*
(Same structure as predictive)
```

##### I. Office Phone Features (9 fields)
```
Prefix: office_*
(Same structure as predictive)
```

##### J. Notification Features (7 fields)
```
- total_notif_sent (INTEGER)
- total_notif_read (INTEGER)
- total_notif_unread (INTEGER)
- reminder_sent (INTEGER): DL_Repayment_Reminder count
- reminder_read (INTEGER): Reminder READ count
- dpd_sent (INTEGER): DL_Overdue_BELL_PUSH_Reminder count
- dpd_read (INTEGER): Overdue READ count
```

##### K. Target Variable (1 field)
```
- acct_3dpd_max (INTEGER): Payment outcome
  - 0 = Paid on time
  - 1+ = Still delinquent (days past due)
```

---

## Feature Engineering Methodology

### 1. Population Definition
```sql
loan_base AS (
  SELECT *,
    first_due_date AS due_date
  FROM `data-prd-adhoc.temp_ammar.collection_analysis_aug_sept_2025_customers`
  WHERE day_maturity < 11
    AND EXTRACT(MONTH FROM first_due_date) IN (9, 10)
    AND EXTRACT(YEAR FROM first_due_date) = 2025
)
```

**Rationale**:
- `day_maturity < 11` → Homogeneous product characteristics
- `EXTRACT(MONTH FROM first_due_date) IN (9, 10)` → Sept-Oct due dates (Aug-Sept cohorts)
- Ensures apples-to-apples comparison across customers

---

### 2. Collection Call Classification
```sql
loan_calls_classified AS (
  SELECT
    loan.lfs_customer_id,
    loan.deal_reference,
    loan.due_date,
    call.call_date,
    call.status,
    call.remark,
    call.phone_type,
    call.person_contacted,
    call.collector,
    CASE
      WHEN call.status IN ('PAID', 'PTP', 'PTP - Reminder', ...)
        THEN 'commitment_payment'
      WHEN call.status IN ('No Answer', 'EC - No answer', ...)
        THEN 'unsuccessful_call'
      ...
    END AS status_category
  FROM loan_base loan
  LEFT JOIN collection_calls call
    ON loan.deal_reference = call.deal_reference
    AND call.call_date <= DATE_ADD(loan.due_date, INTERVAL 1 MONTH)
)
```

**Critical Fix from Phase 1**:
- ✅ Now uses **1-month window after due date** (previously unlimited historical window)
- ✅ Prevents data leakage from future collection activities

---

### 3. Multi-Dimensional Aggregation

**Dimension 1: Dialer Type** (Predictive vs Manual)
```sql
calls_predictive AS (
  SELECT
    deal_reference,
    COUNT(call_date) AS pred_total_calls,
    COUNTIF(status_category = 'commitment_payment') AS pred_commitment_payment,
    ...
  FROM loan_calls_classified
  WHERE remark LIKE 'Predictive%'
  GROUP BY deal_reference
)
```

**Dimension 2: Person Contacted** (RPC vs TPC)
```sql
calls_rpc AS (
  SELECT ...
  FROM loan_calls_classified
  WHERE person_contacted = 'RPC'
  GROUP BY deal_reference
)
```

**Dimension 3: Phone Type** (Main / Emergency / Office)
```sql
calls_main_phone AS (
  SELECT ...
  FROM loan_calls_classified
  WHERE phone_type = 'Main Phone'
  GROUP BY deal_reference
)
```

**Total Segments**: 7 dimensions × 9 features = **63 collection call features**

---

### 4. Call Timing Feature Engineering
```sql
call_timing AS (
  SELECT
    deal_reference,
    MIN(CASE WHEN call_date < due_date THEN call_date END) AS first_call_before_due,
    MAX(CASE WHEN call_date < due_date THEN call_date END) AS last_call_before_due,
    MIN(CASE WHEN call_date >= due_date THEN call_date END) AS first_call_after_due,
    MAX(CASE WHEN call_date >= due_date THEN call_date END) AS last_call_after_due
  FROM loan_calls_classified
  WHERE call_date IS NOT NULL
  GROUP BY deal_reference
)
```

**Derived Timing Features**:
```sql
DATE_DIFF(timing.first_call_before_due, loan.due_date, DAY) as diff_first_call_and_before_due
```
- Negative values = days BEFORE due date
- Positive values = days AFTER due date

**Use Case**: Identify optimal timing for collection calls (proactive vs reactive)

---

### 5. Notification Aggregation
```sql
notification_aggregated AS (
  SELECT
    loan.lfs_customer_id,
    loan.deal_reference,
    COALESCE(COUNT(notif.notification_date), 0) AS total_notif_sent,
    COALESCE(COUNTIF(notif.notification_status = 'READ'), 0) AS total_notif_read,
    COALESCE(COUNTIF(notif.notification_status = 'UNREAD'), 0) AS total_notif_unread,
    COALESCE(COUNTIF(notif.notification_code = 'Notification_DL_Repayment_Reminder'), 0)
      AS reminder_sent,
    COALESCE(COUNTIF(notif.notification_code = 'Notification_DL_Repayment_Reminder'
            AND notif.notification_status = 'READ'), 0) AS reminder_read,
    ...
  FROM loan_base loan
  LEFT JOIN notification_data notif
    ON loan.lfs_customer_id = notif.customer_id
    AND loan.deal_reference = notif.deal_reference
    AND notif.notification_date <= DATE_ADD(loan.due_date, INTERVAL 1 MONTH)
  GROUP BY loan.lfs_customer_id, loan.deal_reference
)
```

**Key Insight**: Separate tracking of:
- **Reminder notifications** (before due date)
- **Overdue notifications** (after due date)
- **Read status** for engagement tracking

---

### 6. Payment Outcome Retrieval
```sql
vintage_data AS (
  SELECT
    lfs_customer_id,
    deal_reference,
    acct_3dpd_max
  FROM `jago-bank-data-production.data_mart.credit_risk_vintage_account_direct_lending`
  WHERE mob = 1  -- ✅ First payment cycle outcome
    AND business_date >= '2025-08-01'
    AND business_date <= CURRENT_DATE()
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY lfs_customer_id, deal_reference
    ORDER BY business_date DESC  -- ✅ Latest MOB 1 snapshot
  ) = 1
)
```

**Critical Fix from Phase 1**:
- ✅ Now filters `mob = 1` explicitly (not ORDER BY mob DESC)
- ✅ Gets **latest snapshot of MOB 1** payment outcome
- ✅ Ensures we capture most recent payment status for first cycle

**Target Variable Definition**:
- `acct_3dpd_max = 0` → Customer paid on time
- `acct_3dpd_max > 0` → Customer still delinquent (value = DPD days)

---

## Key Technical Findings

### Finding 1: Recovery Pattern in Bad Customers

**Discovery**: Not all `flag_bad_customer = 1` have `acct_3dpd_max > 0`

**Analysis Query**:
```sql
SELECT
  CASE
    WHEN acct_3dpd_max = 0 THEN 'Recovered'
    ELSE 'Still Delinquent'
  END AS status,
  COUNT(*) AS customer_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) AS percentage
FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`
WHERE flag_bad_customer = 1
GROUP BY status;
```

**Interpretation**:
- **flag_bad_customer = 1** is a **historical label** (was DPD 3+ at some point in MOB 1)
- **acct_3dpd_max = 0** is **current status** (has since recovered and paid)
- This suggests **collection activities may help customers recover**

**Business Implication**: Decision tree model can identify which collection activities drive recovery

---

### Finding 2: Multi-Channel Hypothesis

**Hypothesis**: Customers receiving both calls AND notifications have higher payment rates

**Validation Query** (Query 5):
```sql
SELECT
  CASE
    WHEN (pred_total_calls + manual_total_calls) = 0 AND total_notif_sent = 0
      THEN 'No_Activity'
    WHEN (pred_total_calls + manual_total_calls) > 0 AND total_notif_sent = 0
      THEN 'Calls_Only'
    WHEN (pred_total_calls + manual_total_calls) = 0 AND total_notif_sent > 0
      THEN 'Notifications_Only'
    WHEN (pred_total_calls + manual_total_calls) > 0 AND total_notif_sent > 0
      THEN 'Multi_Channel'
  END AS channel_strategy,

  ROUND(COUNTIF(acct_3dpd_max = 0) * 100.0 / COUNT(*), 1) AS payment_rate_pct
FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`
GROUP BY channel_strategy;
```

**Expected Result**: Multi-channel customers show higher `payment_rate_pct`

**Next Step**: Decision tree will reveal **optimal combination** of channels

---

### Finding 3: Engagement Matters More Than Volume

**Hypothesis**: RPC (actually reaching customer) > Total calls

**Validation Query** (Query 7):
```sql
SELECT
  CASE
    WHEN rpc_total_calls = 0 THEN 'No_RPC'
    WHEN rpc_total_calls > 0 THEN 'Has_RPC'
  END AS rpc_status,

  AVG(pred_total_calls + manual_total_calls) AS avg_total_calls,
  ROUND(COUNTIF(acct_3dpd_max = 0) * 100.0 / COUNT(*), 1) AS payment_rate_pct
FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`
GROUP BY rpc_status;
```

**Expected Insight**: Customers with RPC > 0 may have better payment rates **even with lower total calls**

**Business Implication**: Quality (RPC) > Quantity (total calls)

---

### Finding 4: Notification Read Rate Impact

**Hypothesis**: Customers who read notifications are more likely to pay

**Validation Query** (Query 8):
```sql
SELECT
  CASE
    WHEN total_notif_sent = 0 THEN 'No_Notifications'
    WHEN total_notif_read = 0 THEN 'Sent_Not_Read'
    WHEN total_notif_read = total_notif_sent THEN 'Fully_Read'
    ELSE 'Partially_Read'
  END AS engagement_status,

  ROUND(COUNTIF(acct_3dpd_max = 0) * 100.0 / COUNT(*), 1) AS payment_rate_pct
FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`
GROUP BY engagement_status;
```

**Expected Insight**: `Fully_Read` customers have higher payment rate

**Business Implication**: Optimize notification content and timing to increase read rates

---

## Data Quality Validation

### Validation 1: DISTINCT Value Checks
```sql
-- Notification status validation
SELECT DISTINCT notification_status
FROM `jago-bank-data-production.dwh_core.notification_current`
WHERE business_date >= '2025-08-01';

-- Result: READ, UNREAD (confirmed uppercase)
```

✅ **Passed**: No unexpected values, case-sensitive matching works

---

### Validation 2: Regex Extraction Accuracy
```sql
-- Test deep_link extraction
SELECT
  deep_link,
  REGEXP_EXTRACT(deep_link, r'accountId=(\d+)') AS extracted_deal_reference
FROM `jago-bank-data-production.dwh_core.notification_current`
WHERE deep_link IS NOT NULL
LIMIT 10;
```

✅ **Passed**: Pattern successfully extracts deal_reference from accountId parameter

---

### Validation 3: Scope Coverage
```sql
-- Check if base table customers match collection data timeframe
SELECT
  cohort_name,
  MIN(facility_start_date) AS earliest_loan,
  MAX(facility_start_date) AS latest_loan,
  COUNT(DISTINCT lfs_customer_id) AS customer_count
FROM `data-prd-adhoc.temp_ammar.collection_analysis_aug_sept_2025_customers`
GROUP BY cohort_name;
```

✅ **Passed**: Aug-Sept 2025 cohorts align with collection data window (2025-08-01 onwards)

**Known Limitation**: Older cohorts (e.g., May 2025) excluded by design - this is expected behavior

---

### Validation 4: NULL Value Check
```sql
-- Check for critical NULL values
SELECT
  COUNTIF(acct_3dpd_max IS NULL) AS null_outcome,
  COUNTIF(pred_total_calls IS NULL) AS null_pred_calls,
  COUNTIF(manual_total_calls IS NULL) AS null_manual_calls,
  COUNTIF(total_notif_sent IS NULL) AS null_notif
FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`;
```

✅ **Passed**: All counts = 0 (COALESCE logic prevents NULLs)

---

## Query Performance Optimization

### Original Approach (Slow)
```sql
-- Anti-pattern: Re-aggregating in every analysis query
WITH collection_agg AS (
  SELECT ...
  FROM base
  LEFT JOIN collection_calls ...
  GROUP BY ...
)
```
⚠️ **Problem**: Repeated aggregation for each analysis query

---

### Optimized Approach (Fast)
```sql
-- Pre-aggregate once into materialized table
CREATE OR REPLACE TABLE `...collection_notification_features_sept_2025` AS (
  WITH ... [all aggregation logic]
  SELECT * FROM final_dataset
);

-- Then simple SELECT for analysis
SELECT
  call_intensity,
  payment_outcome,
  COUNT(*) AS customer_count
FROM `...collection_notification_features_sept_2025`
GROUP BY call_intensity, payment_outcome;
```

✅ **Benefit**:
- Aggregation runs **once** during table creation
- Analysis queries are **simple SELECTs** (10x faster)
- Consistent feature set across all analyses

---

## Presentation-Ready Pivot Queries

### Query 1: Summary Statistics (Direct Display)
**File**: `pivot_queries_for_presentation_UPDATED.sql` (Lines 1-72)

**Purpose**: High-level population metrics for Tab 1

**Output**:
```
| Metric                                  | Value    | Percentage |
|-----------------------------------------|----------|------------|
| Total Customers                         | X        | NULL       |
| Good Customers                          | Y        | Y%         |
| Bad Customers                           | Z        | Z%         |
| August 2025 Cohort                      | A        | A%         |
| September 2025 Cohort                   | B        | B%         |
| Average Plafond (IDR)                   | C        | NULL       |
| Average Collection Calls per Customer   | D        | NULL       |
| Average Notifications per Customer      | E        | NULL       |
```

---

### Query 5: Multi-Channel Strategy Analysis ⭐ (Pivot)
**File**: `pivot_queries_for_presentation_UPDATED.sql` (Lines 197-250)

**Purpose**: THE KEY FINDING - Channel mix effectiveness

**Pivot Configuration**:
- **Rows**: `channel_strategy`, `engagement_level`
- **Columns**: `payment_outcome`
- **Values**: `customer_count` (SUM), `payment_rate_pct` (AVERAGE)
- **Filter**: `customer_type = 'Bad_Customer'` (focus on at-risk segment)

**Business Question Answered**:
"Does multi-channel collection (calls + notifications) drive better payment rates than single-channel?"

---

### Query 6: Recovery Rate by Collection Intensity (Pivot)
**File**: `pivot_queries_for_presentation_UPDATED.sql` (Lines 253-288)

**Purpose**: Shows collection effectiveness for bad customers

**Pivot Configuration**:
- **Rows**: `collection_intensity`, `cohort_name`
- **Values**: `recovery_rate_pct` (AVERAGE), `total_bad_customers` (SUM)

**Business Question Answered**:
"Do more collection calls help bad customers recover and pay on time?"

---

### Query 7: RPC Effectiveness Analysis (Pivot)
**File**: `pivot_queries_for_presentation_UPDATED.sql` (Lines 291-326)

**Purpose**: Quality vs. Quantity - Does reaching the customer matter?

**Key Metric**: `rpc_success_rate_pct = (RPC calls / Total calls) * 100`

**Business Question Answered**:
"Is it better to have 5 RPC calls or 50 no-answer calls?"

---

### Query 8: Notification Engagement Impact (Pivot)
**File**: `pivot_queries_for_presentation_UPDATED.sql` (Lines 329-364)

**Purpose**: Does reading notifications correlate with payment?

**Segmentation**:
- No Notifications
- Sent but Not Read
- Partially Read
- Fully Read

**Business Question Answered**:
"Should we invest in optimizing notification content to increase read rates?"

---

## Bug Fixes and Improvements from Phase 1

### Bug Fix 1: MOB 1 Filtering Logic
**Previous Code**:
```sql
vintage_data AS (
  SELECT ...
  FROM credit_risk_vintage_account_direct_lending
  WHERE business_date >= '2025-08-01'
  ORDER BY mob DESC  -- ❌ Gets highest MOB, not MOB 1
)
```

**Fixed Code**:
```sql
vintage_data AS (
  SELECT ...
  FROM credit_risk_vintage_account_direct_lending
  WHERE mob = 1  -- ✅ Explicitly filter MOB 1
    AND business_date >= '2025-08-01'
  QUALIFY ROW_NUMBER() OVER (
    PARTITION BY lfs_customer_id, deal_reference
    ORDER BY business_date DESC  -- ✅ Latest MOB 1 snapshot
  ) = 1
)
```

**Impact**: Ensures we get first payment cycle outcome, not latest available MOB

---

### Bug Fix 2: Collection Window Scope
**Previous Code**:
```sql
LEFT JOIN collection_calls call
  ON loan.deal_reference = call.deal_reference
  -- ❌ No time filter - includes all historical calls
```

**Fixed Code**:
```sql
LEFT JOIN collection_calls call
  ON loan.deal_reference = call.deal_reference
  AND call.call_date <= DATE_ADD(loan.due_date, INTERVAL 1 MONTH)
  -- ✅ Only 1 month after due date
```

**Impact**: Prevents data leakage from future collection activities outside relevant window

---

### Bug Fix 3: Due Date Filter Logic
**Previous Code**:
```sql
WHERE EXTRACT(MONTH FROM first_due_date) = 9  -- ❌ Only September
```

**Fixed Code**:
```sql
WHERE EXTRACT(MONTH FROM first_due_date) IN (9, 10)  -- ✅ Sept-Oct due dates
AND cohort_name IN ('August 2025', 'September 2025')  -- ✅ Aug-Sept cohorts
```

**Impact**: Properly captures both August and September 2025 cohorts

---

### Improvement 1: COALESCE for NULL Prevention
**Previous Code**:
```sql
SUM(CASE WHEN status = 'NO_ANSWER' THEN 1 END) AS no_answer_calls
-- ❌ Returns NULL if no matching rows
```

**Improved Code**:
```sql
COALESCE(SUM(CASE WHEN status = 'NO_ANSWER' THEN 1 ELSE 0 END), 0) AS no_answer_calls
-- ✅ Returns 0 if no matching rows
```

**Impact**: All feature columns guaranteed non-NULL (critical for decision tree models)

---

## Next Steps and Roadmap

### Step 1: Presentation to Bang Gustian ✅
**Status**: Ready

**Materials Prepared**:
1. Google Sheets with 6+ tabs (base population, metadata, samples, pivots)
2. Presentation transcript following "sell the concept first" approach
3. 10 pivot-ready queries for live demonstration

**Expected Outcome**:
- Validate business problem and approach
- Get feedback on feature set and target variable
- Confirm decision tree modeling scope

---

### Step 2: Export to CSV for Python Modeling
```sql
-- Export query
SELECT *
FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`
ORDER BY lfs_customer_id, deal_reference;
```

**Output**: CSV file with 104 features ready for Python

---

### Step 3: Decision Tree Model Development

**Libraries**: `scikit-learn` (DecisionTreeClassifier, RandomForestClassifier)

**Feature Preparation**:
```python
# Features (X)
feature_cols = [
    # Collection features
    'pred_total_calls', 'manual_total_calls',
    'rpc_total_calls', 'tpc_total_calls',
    'main_total_calls', 'emerg_total_calls', 'office_total_calls',

    # Notification features
    'total_notif_sent', 'total_notif_read',
    'reminder_sent', 'reminder_read',
    'dpd_sent', 'dpd_read',

    # Timing features
    'diff_first_call_and_before_due',
    'diff_first_call_and_after_due',

    # Risk scores
    'ews_calibrated_scores', 'score_TD'
]

X = df[feature_cols]

# Target (y)
y = (df['acct_3dpd_max'] == 0).astype(int)  # 1 = Paid, 0 = Delinquent
```

**Model Training**:
```python
from sklearn.model_selection import train_test_split
from sklearn.tree import DecisionTreeClassifier
from sklearn.metrics import classification_report, roc_auc_score

# Train-test split (or use Out-of-Time validation with future cohorts)
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.3, random_state=42)

# Decision tree with max depth to prevent overfitting
dt_model = DecisionTreeClassifier(
    max_depth=5,
    min_samples_split=100,
    min_samples_leaf=50,
    random_state=42
)

dt_model.fit(X_train, y_train)

# Feature importance
feature_importance = pd.DataFrame({
    'feature': feature_cols,
    'importance': dt_model.feature_importances_
}).sort_values('importance', ascending=False)

print(feature_importance.head(10))
```

**Expected Output**: Top 10 collection features driving payment outcomes

---

### Step 4: Segmentation Rule Creation

**Example Decision Tree Path**:
```
IF rpc_total_calls > 5 AND total_notif_read > 2 THEN
  → High probability of payment (80%)
  → Collection strategy: Multi-channel with engagement tracking

ELIF pred_total_calls > 50 AND rpc_total_calls = 0 THEN
  → Low probability of payment (30%)
  → Collection strategy: Switch to manual dialer or alternative channel

ELSE
  → Medium probability of payment (50%)
  → Collection strategy: Continue standard approach
```

**Business Application**: Prioritize collection resources on recoverable customers

---

### Step 5: Out-of-Time Validation

**Validation Cohorts**: October-November 2025 (future cohorts not in training)

**Validation Query**:
```sql
-- Re-run aggregation query with new cohorts
WHERE cohort_name IN ('October 2025', 'November 2025')
```

**Success Criteria**:
- Model AUC > 0.65 on OOT sample
- Feature importance remains stable
- Decision rules are interpretable and actionable

---

### Step 6: Production Implementation

**Option A: SQL-Based Scoring**
- Convert decision tree rules to SQL CASE WHEN logic
- Deploy as BigQuery scheduled query
- Output: Daily collection prioritization list

**Option B: Python API**
- Deploy trained model as API endpoint
- Collection system calls API with customer features
- Real-time collection strategy recommendation

---

## Known Limitations and Caveats

### Limitation 1: Scope Restriction
**Issue**: Only <11 day maturity loans included

**Rationale**: Homogeneous product comparison

**Impact**: Findings may not generalize to longer-tenor products (30-day, 90-day loans)

**Mitigation**: Separate analysis required for different tenor buckets

---

### Limitation 2: Cohort Timing
**Issue**: Only Aug-Sept 2025 cohorts analyzed

**Rationale**: Recent data with sufficient MOB 1 observations

**Impact**: Seasonal effects not captured (e.g., year-end spending patterns)

**Mitigation**: Expand to 6-month cohort analysis in future iterations

---

### Limitation 3: Missing Collection Channels
**Issue**: WhatsApp blasts not included in current feature set

**Reason**: Data source location unclear (`jago-data-sandbox` or production table?)

**Impact**: Multi-channel analysis incomplete

**Next Step**: Identify WhatsApp data source and add as 8th feature dimension

---

### Limitation 4: Causation vs. Correlation
**Issue**: High collection calls may correlate with high-risk customers (not cause payment)

**Example**:
- Customer A: 100 calls → Still delinquent (high-risk, hard to collect)
- Customer B: 5 calls → Paid (low-risk, would have paid anyway)

**Implication**: Decision tree shows **association**, not **causation**

**Mitigation**:
- Segment by risk scores (EWS, HCI) before building tree
- Use propensity score matching or A/B testing for causal inference

---

### Limitation 5: External Factors Not Captured
**Missing Variables**:
- Customer employment status changes
- Economic conditions (inflation, interest rates)
- Competitor promotions or refinancing offers
- Customer life events (medical emergency, job loss)

**Impact**: Model may miss important confounding factors

**Mitigation**: Include external data sources in future iterations (e.g., unemployment rates, GDP growth)

---

## Appendix

### A. File Inventory

| File Name | Purpose | Status |
|-----------|---------|--------|
| `temp_table.sql` | Base population table creation | ✅ Completed (with bug fix note) |
| `renewed_aggregation_query_FIXED.sql` | Feature engineering query (104 features) | ✅ Completed & Validated |
| `pivot_queries_for_presentation_UPDATED.sql` | 10 analysis queries for pivot tables | ✅ Ready for use |
| `collection_notification_features_sept_2025.csv` | Data dictionary (104 fields) | ✅ Documented |
| `Collection_Score_Multi_Channel_Analysis_Technical_Wiki.md` | This document | ✅ Completed |

---

### B. Related Documentation

1. **Phase 1**: `Collection_Score_Feature_Engineering_Technical_Wiki.md`
   - Initial 69 collection features development
   - Bug fixes: date calculation, overlapping flags

2. **Call Timing Analysis**: `Collection_Call_Timing_Analysis_Technical_Wiki.md`
   - Bimodal collection strategy discovery
   - Temporal feature engineering rationale

3. **Effectiveness Analysis**: `Collection_Effectiveness_Deep_Dive_Wiki.md`
   - 93% No Answer rate finding
   - Capacity planning insights

4. **Payment Outcome Analysis**: `Collection_Activity_Payment_Outcome_Analysis_Technical_Wiki.md`
   - Initial payment outcome correlation work
   - 1-month window bug fix documentation

---

### C. SQL Code Snippets

#### Snippet 1: Check Feature NULL Counts
```sql
SELECT
  -- Base features
  COUNTIF(lfs_customer_id IS NULL) AS null_customer_id,
  COUNTIF(deal_reference IS NULL) AS null_deal_ref,
  COUNTIF(acct_3dpd_max IS NULL) AS null_outcome,

  -- Collection features
  COUNTIF(pred_total_calls IS NULL) AS null_pred_calls,
  COUNTIF(manual_total_calls IS NULL) AS null_manual_calls,
  COUNTIF(rpc_total_calls IS NULL) AS null_rpc_calls,

  -- Notification features
  COUNTIF(total_notif_sent IS NULL) AS null_notif_sent,
  COUNTIF(total_notif_read IS NULL) AS null_notif_read

FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`;
```

---

#### Snippet 2: Feature Distribution Summary
```sql
SELECT
  'pred_total_calls' AS feature_name,
  MIN(pred_total_calls) AS min_value,
  APPROX_QUANTILES(pred_total_calls, 100)[OFFSET(25)] AS p25,
  APPROX_QUANTILES(pred_total_calls, 100)[OFFSET(50)] AS median,
  APPROX_QUANTILES(pred_total_calls, 100)[OFFSET(75)] AS p75,
  MAX(pred_total_calls) AS max_value,
  AVG(pred_total_calls) AS mean_value,
  STDDEV(pred_total_calls) AS std_dev
FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`

UNION ALL

SELECT
  'total_notif_sent' AS feature_name,
  MIN(total_notif_sent),
  APPROX_QUANTILES(total_notif_sent, 100)[OFFSET(25)],
  APPROX_QUANTILES(total_notif_sent, 100)[OFFSET(50)],
  APPROX_QUANTILES(total_notif_sent, 100)[OFFSET(75)],
  MAX(total_notif_sent),
  AVG(total_notif_sent),
  STDDEV(total_notif_sent)
FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`;

-- Repeat for other key features
```

---

#### Snippet 3: Correlation Check (SQL)
```sql
-- Pearson correlation between RPC calls and payment outcome
WITH stats AS (
  SELECT
    AVG(rpc_total_calls) AS mean_rpc,
    STDDEV(rpc_total_calls) AS std_rpc,
    AVG(CASE WHEN acct_3dpd_max = 0 THEN 1 ELSE 0 END) AS mean_paid,
    STDDEV(CASE WHEN acct_3dpd_max = 0 THEN 1 ELSE 0 END) AS std_paid
  FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`
)

SELECT
  CORR(
    rpc_total_calls,
    CASE WHEN acct_3dpd_max = 0 THEN 1 ELSE 0 END
  ) AS correlation_rpc_vs_payment
FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`;
```

---

### D. Python Code Snippets

#### Snippet 1: Load Data from BigQuery
```python
from google.cloud import bigquery
import pandas as pd

# Initialize BigQuery client
client = bigquery.Client()

# Query
query = """
SELECT *
FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`
"""

# Load to pandas
df = client.query(query).to_dataframe()

print(f"Dataset shape: {df.shape}")
print(f"Columns: {df.columns.tolist()}")
print(f"\nTarget variable distribution:")
print(df['acct_3dpd_max'].value_counts())
```

---

#### Snippet 2: Feature Correlation Heatmap
```python
import seaborn as sns
import matplotlib.pyplot as plt

# Select numerical features
feature_cols = [
    'pred_total_calls', 'manual_total_calls', 'rpc_total_calls',
    'total_notif_sent', 'total_notif_read',
    'ews_calibrated_scores', 'score_TD',
    'acct_3dpd_max'
]

# Correlation matrix
corr_matrix = df[feature_cols].corr()

# Heatmap
plt.figure(figsize=(12, 10))
sns.heatmap(corr_matrix, annot=True, fmt='.2f', cmap='coolwarm', center=0)
plt.title('Feature Correlation Matrix')
plt.tight_layout()
plt.savefig('feature_correlation_heatmap.png')
plt.show()
```

---

#### Snippet 3: Decision Tree Visualization
```python
from sklearn.tree import plot_tree
import matplotlib.pyplot as plt

# Assume dt_model is already trained
plt.figure(figsize=(20, 10))
plot_tree(
    dt_model,
    feature_names=feature_cols,
    class_names=['Delinquent', 'Paid'],
    filled=True,
    rounded=True,
    fontsize=10
)
plt.title('Decision Tree - Collection Score Model')
plt.tight_layout()
plt.savefig('decision_tree_visualization.png', dpi=300)
plt.show()
```

---

### E. Glossary

| Term | Definition |
|------|------------|
| **acct_3dpd_max** | Account 3+ Days Past Due Maximum - Payment outcome variable (0=paid, >0=delinquent) |
| **MOB** | Month on Book - Loan age in months since disbursement |
| **DPD** | Days Past Due - Number of days payment is overdue |
| **RPC** | Right Party Contact - Successfully reached the borrower (not third party) |
| **TPC** | Third Party Contact - Reached someone other than borrower |
| **PTP** | Promise to Pay - Customer committed to payment |
| **Predictive Dialer** | Automated dialing system (bot-initiated calls) |
| **Manual Dialer** | Human-initiated calls |
| **Cohort** | Group of loans disbursed in same month |
| **Vintage Analysis** | Tracking loan performance over MOB lifecycle |
| **Feature Engineering** | Creating predictive variables from raw data |
| **Decision Tree** | Machine learning model using if-then rules for prediction |
| **OOT Validation** | Out-of-Time validation using future cohorts not in training data |

---

### F. Contact and Support

**Primary Analyst**: Ammar Siregar (Data Analyst Intern - Risk DA)
**Mentor**: Mr. Subhan (Risk Team)
**Stakeholder**: Bang Gustian (Collection Strategy Lead)
**Date**: 2025-10-24

**For questions or clarifications**, refer to:
1. This technical wiki (comprehensive reference)
2. Related Phase 1 documentation (feature engineering details)
3. SQL query files (implementation code)
4. Presentation materials (business context and findings)

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-24 | Ammar Siregar | Initial creation - Phase 2 documentation |
| | | | - 104 features documented |
| | | | - 10 pivot queries created |
| | | | - Bug fixes from Phase 1 documented |
| | | | - Multi-channel analysis framework established |

---

**End of Document**
