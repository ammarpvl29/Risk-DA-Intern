# Collection Activity & Payment Outcome Analysis - Technical Documentation

**Project**: Collection Score Feature Engineering - Phase 2
**Analyst**: Ammar Siregar (Risk Data Analyst Intern)
**Mentor**: Subhan
**Date**: October 2025
**Status**: Collection Calls Analysis Complete ✅ | Notification Analysis In Progress 🔄

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Critical Bug Fix: Date Filtering Logic](#critical-bug-fix-date-filtering-logic)
3. [Analysis Scope Shift: Bad to Good Customers](#analysis-scope-shift-bad-to-good-customers)
4. [Final Collection Query Architecture](#final-collection-query-architecture)
5. [Payment Outcome Integration](#payment-outcome-integration)
6. [Key Findings from Collection Analysis](#key-findings-from-collection-analysis)
7. [Tomorrow's Task: Notification Aggregation](#tomorrows-task-notification-aggregation)
8. [End Goal: Multi-Channel Decision Tree Model](#end-goal-multi-channel-decision-tree-model)

---

## Executive Summary

This analysis builds on the Collection Score feature engineering work to **correlate collection activities with actual payment outcomes**. The goal is to determine which communication methods (phone calls, WhatsApp, push notifications) most effectively drive customer payments.

**Key Achievements Today:**
- ✅ Fixed critical date filtering bug (1-month collection cycle window)
- ✅ Integrated payment outcome data from vintage table
- ✅ Shifted analysis focus from bad customers (defaulters) to good customers (payers)
- ✅ Completed 69-column feature set for collection calls
- ✅ Validated with mentor: 12/158 payment rate for September 2025 cohort

**Next Steps Tomorrow:**
- 🔄 Build WhatsApp/notification aggregation query
- 🔄 Clarify notification field definitions with Kak Maria
- 🔄 Join notification features with collection features
- 🔄 Prepare combined dataset for Python Decision Tree modeling

---

## Critical Bug Fix: Date Filtering Logic

### Problem Identified

**Original Logic** (INCORRECT ❌):
```sql
LEFT JOIN collection_calls call
  ON loan.deal_reference = call.deal_reference
-- No date filter - pulls ALL calls across all billing cycles
```

**Issue**: This approach captured calls from subsequent billing cycles, contaminating the analysis. For example:
- Loan due date: September 5, 2025
- Calls from October 10, 2025 (next cycle) were included
- Result: Cannot isolate which activities impacted **that specific payment**

### Solution Implemented

**Corrected Logic** (CORRECT ✅):
```sql
LEFT JOIN collection_calls call
  ON loan.deal_reference = call.deal_reference
  AND call.call_date <= DATE_ADD(loan.due_date, INTERVAL 1 MONTH)
```

**Rationale**:
- Collection cycle = due_date to due_date + 30 days
- After 30 days, next billing cycle begins
- This filter isolates activities relevant to one payment event

**Business Context** (from mentor):
> "We don't want calls from the next billing cycle. We want to know: did the activities in **this cycle** cause the customer to pay **this bill**?"

---

## Analysis Scope Shift: Bad to Good Customers

### Original Scope (Phase 1)
```sql
WHERE flag_bad_customer = 1  -- Analyzing defaulters
```
- **Purpose**: Understand collection effort patterns
- **Cohort**: 603 bad customers (August-September 2025)
- **Focus**: How much effort was spent on customers who didn't pay?

### New Scope (Phase 2)
```sql
WHERE flag_bad_customer = 0  -- Analyzing payers
  AND EXTRACT(MONTH FROM due_date) = 9
  AND EXTRACT(YEAR FROM due_date) = 2025
```
- **Purpose**: Identify what activities **drive successful payment**
- **Cohort**: September 2025 good customers (need count from query)
- **Focus**: What differentiated customers who paid from those who didn't?

### Mentor's Rationale

**Quote from 1-1 session**:
> "The goal is to build a model that predicts payment. We want to learn from success patterns, not just study failures. A customer with `acct_3dpd_max = 0` means they paid on time. That's our target variable."

---

## Final Collection Query Architecture

### Query Structure Overview

```
WITH
├── loan_base                    -- 603 customers, day_maturity < 11
├── collection_calls             -- Raw call data (Aug 2025 - present)
├── loan_calls_classified        -- ✅ Date filter applied + status categorization
├── call_timing                  -- First/last call before/after due date
├── calls_predictive             -- Predictive dialer aggregation
├── calls_manual                 -- Manual dialer aggregation
├── calls_rpc                    -- Right Party Contact aggregation
├── calls_tpc                    -- Third Party Contact aggregation
├── calls_main_phone             -- Main phone aggregation
├── calls_emergency              -- Emergency contact aggregation
├── calls_office                 -- Office phone aggregation
├── loan_collection_summary      -- Join all segments + add date diffs
├── vintage_data                 -- ✅ Payment outcome (acct_3dpd_max)
└── final_summary                -- Combine activity + outcome
```

### Feature Set Summary

**Total Columns**: 69

| Category | Fields | Count |
|----------|--------|-------|
| **Identifiers** | `lfs_customer_id`, `deal_reference`, `due_date`, `cohort_name`, `flag_bad_customer` | 5 |
| **Temporal Features** | `first_call_before_due`, `last_call_before_due`, `first_call_after_due`, `last_call_after_due` | 4 |
| **Date Differences** | `diff_first_call_and_before_due`, `diff_last_call_and_before_due`, `diff_first_call_and_after_due`, `diff_last_call_and_after_due` | 4 |
| **Predictive Dialer** | `pred_total_calls`, `pred_commitment_payment`, `pred_unsuccessful_call`, `pred_successful_no_commit`, `pred_data_info`, `pred_workflow`, `pred_alt_channel`, `pred_complaint`, `pred_collectors` | 9 |
| **Manual Dialer** | `manual_*` (same 9 metrics) | 9 |
| **RPC (Right Party)** | `rpc_*` (same 9 metrics) | 9 |
| **TPC (Third Party)** | `tpc_*` (same 9 metrics) | 9 |
| **Main Phone** | `main_*` (same 9 metrics) | 9 |
| **Emergency Contact** | `emerg_*` (same 9 metrics) | 9 |
| **Office Phone** | `office_*` (same 9 metrics) | 9 |
| **Payment Outcome** | `acct_3dpd_max` | 1 |

**Total**: 5 + 4 + 4 + (9 × 7) + 1 = **69 columns**

---

## Payment Outcome Integration

### Vintage Table Join

**Source**: `jago-bank-data-production.data_mart.credit_risk_vintage_account_direct_lending`

**Key Logic**:
```sql
vintage_data AS (
  SELECT
    lfs_customer_id,
    deal_reference,
    acct_3dpd_max  -- Maximum DPD in account lifecycle
  FROM `jago-bank-data-production.data_mart.credit_risk_vintage_account_direct_lending`
  WHERE business_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)  -- D-1 snapshot
)
```

**Why D-1 (Yesterday's Date)?**
- Vintage table is updated daily
- D-1 ensures we get the most recent **complete** snapshot
- Avoids partial data from today's processing

### Outcome Variable Definition

**Target Variable**: `acct_3dpd_max`

| Value | Meaning | Classification |
|-------|---------|----------------|
| `0` | Customer paid on time | **SUCCESS** ✅ |
| `> 0` | Customer went past due | **FAILURE** ❌ |

**For Decision Tree Model**:
- **Binary Classification**: `paid = (acct_3dpd_max = 0)`
- **Features**: All 68 collection activity columns
- **Goal**: Predict which customers will pay based on collection activities

---

## Key Findings from Collection Analysis

### Payment Rate (September 2025 Cohort)

**From mentor validation session**:
- **Total Customers Analyzed**: 158 (September 2025 due dates)
- **Customers Who Paid**: 12
- **Payment Rate**: 7.6% (12/158)

**Interpretation**:
- This represents the **baseline success rate** for good customers
- Decision Tree will identify which activities improve this rate
- Low payment rate suggests need for optimized collection strategy

### Call Status Clarifications

**Important Definitions** (from mentor):

1. **"Pickup"** status:
   - Customer answered the phone
   - **Does NOT mean commitment to pay**
   - Just successful contact

2. **"PTP" (Promise to Pay)** status:
   - Customer explicitly committed to payment
   - Stronger signal than pickup
   - Categorized as `commitment_payment` in our query

3. **"RPC" (Right Party Contact)**:
   - Actual borrower answered
   - More valuable than TPC (third party)

---

## Tomorrow's Task: Notification Aggregation

### Objective

Build a **notification/WhatsApp aggregation query** similar to the collection calls aggregation, to capture:
- Total notifications sent per customer
- Total notifications read
- Total notifications unread
- Categorized by notification type (Reminder vs DPD)

### Data Source

**Table**: `jago-bank-data-production.dwh_core.notification_current`

**Relevant Fields**:
- `customer_id` - Join key
- `notification_created_at` - Timestamp of notification
- `notification_code` - Type of notification
- `notification_status` - Read/Unread status (needs clarification)

### Notification Categories

**Current Placeholder Logic**:
```sql
SELECT *,
  CASE
    WHEN notification_code IN ('Notification_DL_Repayment_Reminder')
      THEN 'Reminder'
    WHEN notification_code IN ('Notification_DL_Overdue_BELL_PUSH_Reminder')
      THEN 'DPD'
  END AS push_notif_category
FROM `jago-bank-data-production.dwh_core.notification_current`
WHERE notification_code IN (
  'Notification_DL_Repayment_Reminder',
  'Notification_DL_Overdue_BELL_PUSH_Reminder'
)
```

### Expected Output Schema

**Aggregated Notification Table**:

| Column | Type | Description |
|--------|------|-------------|
| `customer_id` | STRING | Customer identifier |
| `deal_reference` | STRING | Loan identifier (if available) |
| `notification_date` | DATE | CAST(notification_created_at AS DATE) |
| `total_notifications_sent` | INTEGER | COUNT(*) |
| `total_notifications_read` | INTEGER | COUNT(WHERE status = 'read') |
| `total_notifications_unread` | INTEGER | COUNT(WHERE status = 'unread') |
| `reminder_count` | INTEGER | COUNT(WHERE category = 'Reminder') |
| `reminder_read` | INTEGER | COUNT(WHERE category = 'Reminder' AND status = 'read') |
| `dpd_count` | INTEGER | COUNT(WHERE category = 'DPD') |
| `dpd_read` | INTEGER | COUNT(WHERE category = 'DPD' AND status = 'read') |

**Total Expected Columns**: ~10 notification features

### Placeholder Aggregation Query

**Current Incomplete Draft**:
```sql
-- PLACEHOLDER - Syntax errors, needs completion
SELECT
  customer_id,
  CAST(notification_created_at AS DATE) AS notification_date,  -- ✅ Correct
  COUNT(*) AS total_notifications,                             -- ✅ Correct
  COUNT(notification_read) AS total_read,                      -- ❌ Field name unknown
  COUNT(unread) AS total_unread                                -- ❌ Field name unknown
FROM `jago-bank-data-production.dwh_core.notification_current`
WHERE notification_code IN (
  'Notification_DL_Repayment_Reminder',
  'Notification_DL_Overdue_BELL_PUSH_Reminder'
)
GROUP BY customer_id, notification_date
```

**Issues to Resolve**:
1. ❓ What is the exact field name for read/unread status?
2. ❓ Does table have `deal_reference` or only `customer_id`?
3. ⚠️ Need to apply **1-month date filter** like collection calls
4. ⚠️ Need to join with `loan_base` to get `due_date`

### Action Items for Tomorrow

**Step 1: Data Clarification** (Morning Priority)
- [ ] Send Slack message to Kak Maria asking:
  - What field indicates if notification was read/unread?
  - Difference between `WA_external` channel and `WA_read`/`WA_sent` statuses
  - Does `notification_current` table have `deal_reference` field?

**Step 2: Build Notification CTE** (After Clarification)
```sql
-- Expected structure (to be built tomorrow)
notification_data AS (
  SELECT
    n.customer_id,
    n.deal_reference,  -- If available
    CAST(n.notification_created_at AS DATE) AS notification_date,
    n.notification_code,
    n.notification_status  -- Pending field name confirmation
  FROM `jago-bank-data-production.dwh_core.notification_current` n
  INNER JOIN loan_base loan
    ON n.customer_id = loan.lfs_customer_id
    AND n.deal_reference = loan.deal_reference  -- If available
    AND notification_date <= DATE_ADD(loan.due_date, INTERVAL 1 MONTH)  -- ✅ Same 1-month window
  WHERE n.notification_code IN (
    'Notification_DL_Repayment_Reminder',
    'Notification_DL_Overdue_BELL_PUSH_Reminder'
  )
),

notification_aggregated AS (
  SELECT
    customer_id,
    deal_reference,
    COUNT(*) AS total_notif_sent,
    COUNTIF(notification_status = 'read') AS total_notif_read,  -- Pending status value
    COUNTIF(notification_status = 'unread') AS total_notif_unread,
    COUNTIF(notification_code = 'Notification_DL_Repayment_Reminder') AS reminder_sent,
    COUNTIF(notification_code = 'Notification_DL_Repayment_Reminder'
            AND notification_status = 'read') AS reminder_read,
    COUNTIF(notification_code = 'Notification_DL_Overdue_BELL_PUSH_Reminder') AS dpd_sent,
    COUNTIF(notification_code = 'Notification_DL_Overdue_BELL_PUSH_Reminder'
            AND notification_status = 'read') AS dpd_read
  FROM notification_data
  GROUP BY customer_id, deal_reference
)
```

**Step 3: Join with Collection Summary**
```sql
final_dataset AS (
  SELECT
    collection.*,
    notif.total_notif_sent,
    notif.total_notif_read,
    notif.total_notif_unread,
    notif.reminder_sent,
    notif.reminder_read,
    notif.dpd_sent,
    notif.dpd_read
  FROM loan_collection_summary collection
  LEFT JOIN notification_aggregated notif
    ON collection.lfs_customer_id = notif.customer_id
    AND collection.deal_reference = notif.deal_reference
)
```

**Expected Final Output**: 69 collection columns + 7 notification columns = **76 total columns**

---

## End Goal: Multi-Channel Decision Tree Model

### Business Question

**"Which communication method most effectively drives customer payment?"**

- Is it phone calls? (Predictive vs Manual? RPC vs TPC?)
- Is it WhatsApp messages?
- Is it push notifications? (Reminder vs DPD?)
- What combination works best?

### Modeling Approach

**Technique**: Decision Tree Classifier (Python)

**Dataset Structure**:
```
Features (X):
├── Collection Call Features (68 columns)
│   ├── Predictive Dialer metrics (9)
│   ├── Manual Dialer metrics (9)
│   ├── RPC metrics (9)
│   ├── TPC metrics (9)
│   ├── Phone Type metrics (27)
│   └── Temporal features (5)
├── Notification Features (7 columns)
│   ├── Total sent, read, unread
│   ├── Reminder metrics
│   └── DPD metrics
└── WhatsApp Features (TBD)

Target (y):
└── paid = (acct_3dpd_max == 0)
```

**Expected Insights**:
- Feature importance ranking
- Optimal call volume thresholds
- Most effective contact timing
- Best notification strategy per customer segment

### Next Phase After Data Prep

**Mentor's Plan**:
> "After you finish the notification query, I'll teach you how to build a Decision Tree in Python. We'll use this combined dataset to scientifically determine which factors have the most significant impact on loan repayment."

**Deliverables** (Next Week):
1. Combined dataset exported to CSV
2. Python Jupyter notebook with Decision Tree model
3. Feature importance analysis report
4. Business recommendations for collection optimization

---

## Complete SQL Query (Current Version)

```sql
WITH
loan_base AS (
  SELECT *,
    first_due_date AS due_date
  FROM `data-prd-adhoc.temp_ammar.collection_analysis_aug_sept_2025_customers`
  WHERE day_maturity < 11
),

collection_calls AS (
  SELECT
    card_no as deal_reference,
    CAST(date AS DATE) as call_date,
    status,
    remark,
    dialed_number,
    phone_type,
    person_contacted,
    collector
  FROM `jago-bank-data-production.digital_lending.digital_lending_collection_daily_report_vendor`
  WHERE business_date >= '2025-08-01'
    AND business_date <= CURRENT_DATE()
    AND card_no IS NOT NULL
),

loan_calls_classified AS (
  SELECT
    loan.lfs_customer_id,
    loan.deal_reference,
    loan.due_date,
    loan.cohort_name,
    loan.flag_bad_customer,
    call.call_date,
    call.status,
    call.remark,
    call.phone_type,
    call.person_contacted,
    call.collector,
    CASE
      WHEN call.status IN ('PAID', 'PTP', 'PTP - Reminder', 'PAYMENT PLAN', 'RENCANA PEMBAYARAN',
                            'Request for payment plan', 'Plan Approved', 'Broken Promise')
      THEN 'commitment_payment'

      WHEN call.status IN ('No Answer', 'EC - No answer', 'No Answer AutoDial',
                            'Busy Auto', 'Auto Busy', 'EC - Busy call', 'Busy',
                            'Call Rejected', 'Voice Mail', 'Voice Message Prompt',
                            'Dropped', 'DROP CALL', 'Outbound Local Channel Res Error',
                            'Outbound Pre-Routing Drop', 'ABORT', 'SCBR')
      THEN 'unsuccessful_call'

      WHEN call.status IN ('Call Back', 'Left Message', 'UNDER NEGOTIATION', 'RTP', 'WPC', 'Pickup')
      THEN 'successful_contact_no_commitment'

      WHEN call.status IN ('invalid', 'Resign / Moved', 'Skip Trace', 'Duplicate', 'Claim')
      THEN 'data_information'

      WHEN call.status IN ('NEW', 'TRANSFER', 'REASSIGN', 'ACTIVATE', 'Agent Error')
      THEN 'workflow'

      WHEN call.status IN ('WA - Sent', 'WA - Read')
      THEN 'alternative_channel'

      WHEN call.status IN ('Complaint - Behavior', 'Complaint - Vulnerable')
      THEN 'complaint_escalation'

      ELSE 'other'
    END AS status_category

  FROM loan_base loan
  LEFT JOIN collection_calls call
    ON loan.deal_reference = call.deal_reference
    AND call.call_date <= DATE_ADD(loan.due_date, INTERVAL 1 MONTH)  -- ✅ CRITICAL FIX
),

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
),

-- [7 segment aggregation CTEs: calls_predictive, calls_manual, calls_rpc, calls_tpc,
--  calls_main_phone, calls_emergency, calls_office - omitted for brevity]

loan_collection_summary AS (
  SELECT
    loan.lfs_customer_id,
    loan.deal_reference,
    loan.due_date,

    -- Temporal features
    timing.first_call_before_due,
    DATE_DIFF(timing.first_call_before_due, loan.due_date, DAY) as diff_first_call_and_before_due,
    timing.last_call_before_due,
    DATE_DIFF(timing.last_call_before_due, loan.due_date, DAY) as diff_last_call_and_before_due,
    timing.first_call_after_due,
    DATE_DIFF(timing.first_call_after_due, loan.due_date, DAY) as diff_first_call_and_after_due,
    timing.last_call_after_due,
    DATE_DIFF(timing.last_call_after_due, loan.due_date, DAY) as diff_last_call_and_after_due,

    loan.cohort_name,
    loan.flag_bad_customer,

    -- [All 63 collection activity columns - omitted for brevity]

  FROM loan_base loan
  LEFT JOIN call_timing timing USING (deal_reference)
  LEFT JOIN calls_predictive pred USING (deal_reference)
  LEFT JOIN calls_manual manual USING (deal_reference)
  LEFT JOIN calls_rpc rpc USING (deal_reference)
  LEFT JOIN calls_tpc tpc USING (deal_reference)
  LEFT JOIN calls_main_phone main USING (deal_reference)
  LEFT JOIN calls_emergency emerg USING (deal_reference)
  LEFT JOIN calls_office office USING (deal_reference)
),

vintage_data AS (
  SELECT
    lfs_customer_id,
    deal_reference,
    acct_3dpd_max  -- Payment outcome variable
  FROM `jago-bank-data-production.data_mart.credit_risk_vintage_account_direct_lending`
  WHERE business_date = DATE_SUB(CURRENT_DATE(), INTERVAL 1 DAY)  -- D-1 snapshot
),

final_summary AS (
  SELECT
    vintage.acct_3dpd_max,  -- ✅ Target variable
    summary.*
  FROM loan_collection_summary summary
  LEFT JOIN vintage_data vintage
    ON summary.lfs_customer_id = vintage.lfs_customer_id
    AND summary.deal_reference = vintage.deal_reference
)

SELECT *
FROM final_summary
WHERE flag_bad_customer = 0  -- ✅ Analyzing GOOD customers
  AND EXTRACT(MONTH FROM due_date) = 9  -- September 2025
  AND EXTRACT(YEAR FROM due_date) = 2025
ORDER BY pred_total_calls DESC;
```

---

## Appendix: Status Category Mapping

### Collection Call Status Categorization

| Category | Statuses Included | Business Meaning |
|----------|------------------|------------------|
| `commitment_payment` | PAID, PTP, PTP - Reminder, PAYMENT PLAN, RENCANA PEMBAYARAN, Request for payment plan, Plan Approved, Broken Promise | Customer committed to pay or already paid |
| `unsuccessful_call` | No Answer, EC - No answer, No Answer AutoDial, Busy Auto, Auto Busy, EC - Busy call, Busy, Call Rejected, Voice Mail, Voice Message Prompt, Dropped, DROP CALL, Outbound Local Channel Res Error, Outbound Pre-Routing Drop, ABORT, SCBR | Call attempt failed to reach anyone |
| `successful_contact_no_commitment` | Call Back, Left Message, UNDER NEGOTIATION, RTP, WPC, Pickup | Customer answered but didn't commit to payment |
| `data_information` | invalid, Resign / Moved, Skip Trace, Duplicate, Claim | Data quality or customer status issues |
| `workflow` | NEW, TRANSFER, REASSIGN, ACTIVATE, Agent Error | System/process statuses |
| `alternative_channel` | WA - Sent, WA - Read | WhatsApp communication (may overlap with tomorrow's task) |
| `complaint_escalation` | Complaint - Behavior, Complaint - Vulnerable | Customer complaints requiring special handling |
| `other` | Any status not listed above | Uncategorized statuses |

---

## Related Documentation

- **Previous Phase**: `Collection_Score_Feature_Engineering_Technical_Wiki.md`
- **Next Phase**: `Multi_Channel_Collection_Decision_Tree_Analysis.md` (TBD)
- **Data Dictionaries**: See `/bank_statement/` directory

---

## Change Log

| Date | Author | Change Description |
|------|--------|-------------------|
| 2025-10-20 | Ammar Siregar | Initial documentation - Collection calls analysis complete |
| 2025-10-21 | Ammar Siregar | (Planned) Add notification aggregation section |

---

**End of Document**
