# Collection Call Timing & Loan Performance Analysis - Technical Wiki

**Analysis Date**: October 2025
**Analyst**: Ammar Siregar (Risk DA Intern)
**Cohorts Analyzed**: August 2025, September 2025
**Analysis Period**: 2025-08-01 to 2025-10-16
**Granularity**: Loan-level (deal_reference)

---

## 📋 Table of Contents

1. [Business Context](#business-context)
2. [Hypothesis](#hypothesis)
3. [Data Architecture](#data-architecture)
4. [Methodology](#methodology)
5. [Key Findings](#key-findings)
6. [Technical Implementation](#technical-implementation)
7. [Data Quality Notes](#data-quality-notes)
8. [Recommendations](#recommendations)
9. [Appendix](#appendix)

---

## 🎯 Business Context

### Objective

Understand the relationship between call center activity and loan repayment behavior. Specifically, investigate how the **timing** and **frequency** of calls made to customers—both before and after their loan due date—correlate with whether a loan becomes "bad" (defaults).

### Stakeholders

- **Risk Management Team**: Understanding collection effectiveness
- **Operations Team**: Resource allocation and capacity planning
- **Collection Vendor**: Performance evaluation
- **Product Team**: Customer experience insights

### Scope

- **Cohorts**: August 2025 and September 2025 facility start dates
- **Products**: JAG06 and JAG08 (Direct Lending products)
- **Customer Segment**: LFS customers with Bibit/Stockbit partnerships
- **Maturity Filter**: `day_maturity < 11` (early-tenure loans only)
- **Performance Definition**: Bad customer = `fpd_dpd3_mob1_act = 1` (First Payment Default at MOB 1, 3+ DPD)

---

## 🔬 Hypothesis

### Primary Research Question

**"Does the call center 'give up' on customers after a certain period of delinquency?"**

### Specific Sub-Questions

1. Do collectors stop calling after X days past due?
2. Does call frequency decrease as delinquency extends?
3. Is there a pattern where resources are reallocated away from highly delinquent accounts?
4. What is the effectiveness (pickup rate) of calls before vs after due date?

### Expected Patterns

**Hypothesis A (Give Up Pattern)**: Call volume drops significantly after 7-14 days past due
**Hypothesis B (Persistent Pattern)**: Call volume remains consistent regardless of delinquency length
**Hypothesis C (Triage Pattern)**: Some loans receive persistent follow-up, others receive none (bimodal distribution)

---

## 🗂️ Data Architecture

### Core Tables

#### 1. `data-prd-adhoc.temp_ammar.collection_analysis_aug_sept_2025_customers`

**Purpose**: Base customer and loan attributes with performance flags
**Granularity**: One row per loan (deal_reference)
**Key Fields**:

| Field | Type | Description |
|-------|------|-------------|
| `lfs_customer_id` | STRING | Customer identifier |
| `deal_reference` | STRING | Loan identifier (primary key) |
| `facility_reference` | STRING | Facility identifier |
| `facility_start_date` | DATE | Loan disbursement date |
| `day_maturity` | INTEGER | Days until first payment due (within month) |
| `due_date` | DATE | Calculated: `facility_start_date + 1 MONTH + day_maturity` |
| `cohort_name` | STRING | "August 2025" or "September 2025" |
| `flag_bad_customer` | INTEGER | 1 = Defaulted (3+ DPD at MOB1), 0 = Current |
| `flag_good_customer` | INTEGER | Inverse of `flag_bad_customer` |
| `plafond` | BIGNUMERIC | Loan amount |
| `partner_final` | STRING | Partner channel (Bibit/Stockbit) |
| `ews_calibrated_scores` | FLOAT | Early Warning Score |
| `risk_group_hci` | STRING | HCI Risk Group |
| `score_TD` | NUMERIC | ThreatMetrix Device Score |

**Source Logic**:
```sql
-- Base: credit_risk_vintage_account_direct_lending (MOB 0)
-- Performance: credit_risk_vintage_account_direct_lending (MOB 1)
-- Joined on: lfs_customer_id + facility_reference
```

**Row Count**: 642 bad customer loans (after filtering)

---

#### 2. `jago-bank-data-production.digital_lending.digital_lending_collection_daily_report_vendor`

**Purpose**: Daily collection call logs from external vendor
**Granularity**: One row per call attempt
**Partitioning**: Partitioned by `business_date` (REQUIRED in WHERE clause)

**Key Fields**:

| Field | Type | Description |
|-------|------|-------------|
| `business_date` | DATE | Partition key (data ingestion date) |
| `card_no` | STRING | Join key to `deal_reference` |
| `date` | STRING | Actual call timestamp (use `CAST(date AS DATE)`) |
| `status` | STRING | Call outcome (45+ distinct values) |
| `call_status` | STRING | Alternative status field |
| `dpd` | INTEGER | Days Past Due at time of call |
| `collector` | STRING | Collector name/ID |
| `ptp_date` | STRING | Promise to Pay date |
| `ptp_amount` | NUMERIC | Promise to Pay amount |

**Status Categories** (see [Appendix A](#appendix-a-status-mappings) for full mapping):
- **No Answer**: 'No Answer', 'EC - No answer', 'No Answer AutoDial'
- **Pickup**: 'Pickup'
- **SCBR**: 'SCBR' (Special Collection Bureau Report)
- **WhatsApp**: 'WA - Sent', 'WA - Read'
- **PTP**: 'PTP', 'PTP - Reminder'
- **Payment Plan**: 'PAYMENT PLAN', 'RENCANA PEMBAYARAN'
- **Busy**: 'Busy Auto', 'Auto Busy', 'EC - Busy call', 'Busy'
- **Invalid**: 'invalid'
- **Voicemail**: 'Voice Mail', 'Voice Message Prompt', 'Left Message'
- **Rejected/Dropped**: 'Call Rejected', 'Dropped', 'DROP CALL'

**Critical Date Filter**:
```sql
WHERE business_date >= '2025-08-01'  -- Must include August for before-due calls
  AND business_date <= CURRENT_DATE()
```

---

## 🔬 Methodology

### Analysis Framework

The analysis uses a **6-step CTE pattern** following Bank Jago best practices:

```
1. loan_base → Filter and prepare loan data with calculated due_date
2. collection_calls → Extract call records with proper date filtering
3. loan_calls_classified → Join loans + calls, classify timing (before/after due)
4. calls_before_due → Aggregate metrics for calls BEFORE due_date
5. calls_after_due → Aggregate metrics for calls AFTER due_date
6. loan_collection_summary → Combine all metrics into final loan-level view
```

### Anchor Point: Due Date

**All temporal analysis is anchored to the `due_date`:**

```sql
due_date = facility_start_date + 1 MONTH + day_maturity days
```

**Example**:
- `facility_start_date` = 2025-09-01
- `day_maturity` = 6
- `due_date` = 2025-10-07

### Call Timing Classification

```sql
CASE
  WHEN call_date < due_date THEN 'before_due'
  WHEN call_date >= due_date THEN 'after_due'
END AS call_timing
```

**Days from due calculation**:
```sql
days_from_due = call_date - due_date
-- Negative = before due (e.g., -5 = 5 days before)
-- Positive = after due (e.g., +10 = 10 days past due)
```

### Metrics Calculated

#### Before Due Date Metrics
- `total_calls_before_due`: Total call attempts before due_date
- `before_no_answer`: Count of No Answer statuses
- `before_pickup`: Count of successful pickups
- `before_scbr`: Count of SCBR flags
- `before_whatsapp`: Count of WhatsApp contacts
- `first_call_before_due`: Earliest call date before due
- `last_call_before_due`: Latest call date before due
- `collectors_before_due`: Distinct collector count

#### After Due Date Metrics
- `total_calls_after_due`: Total call attempts after due_date
- `after_no_answer`: Count of No Answer statuses
- `after_pickup`: Count of successful pickups
- `after_scbr`: Count of SCBR flags
- `after_whatsapp`: Count of WhatsApp contacts
- `first_call_after_due`: Earliest call date after due
- `last_call_after_due`: Latest call date after due
- `latest_call_timestamp_after_due`: Most recent call timestamp (TIMESTAMP type)
- `max_days_after_due_called`: Maximum delinquency day when last called
- `collectors_after_due`: Distinct collector count

---

## 🔍 Key Findings

### Finding 1: Bimodal Collection Strategy (HYPOTHESIS C CONFIRMED)

**The call center does NOT uniformly "give up" - they implement a TRIAGE strategy.**

| Follow-up Group | Loan Count | % of Total | Average Calls After Due |
|----------------|------------|------------|------------------------|
| **No Follow-Up** (NULL) | 293 | 45.6% | 0 |
| Early (0-7 days) | 186 | 29.0% | ~17 |
| Medium (8-14 days) | 13 | 2.0% | ~60 |
| Long-term (15-30 days) | 35 | 5.5% | ~150 |
| **Very Persistent** (31-44 days) | 115 | 17.9% | ~250 |

**Key Observation**: Nearly **half of all bad loans receive ZERO follow-up** after due date, while the other half receive intensive, long-term pursuit (up to 44 days).

**Distribution Pattern**:
```
No follow-up: ████████████████████████ 45.6%
0-7 days:     ██████████████ 29.0%
8-14 days:    █ 2.0%
15-30 days:   ██ 5.5%
31-44 days:   ████████ 17.9%
```

This is a **U-shaped distribution** with concentration at extremes (no follow-up OR very persistent), NOT a normal decay pattern.

---

### Finding 2: Call Volume Increases Post-Due Date

| Metric | Before Due | After Due | Change |
|--------|-----------|-----------|--------|
| **Avg calls per loan** | 90.1 | 95.9 | **+6.4%** ↑ |
| **Total calls analyzed** | 57,861 | 61,551 | **+6.4%** ↑ |

**Implication**: Collectors **intensify efforts** after due date, contradicting the "give up" hypothesis for loans that receive follow-up.

---

### Finding 3: Pickup Rate Collapse

| Metric | Before Due | After Due | Change |
|--------|-----------|-----------|--------|
| **Avg No Answer per loan** | 84.2 | 87.6 | +4.0% |
| **Avg Pickup per loan** | 0.10 | 0.03 | **-64%** ↓ |
| **No Answer Rate** | 93.4% | 91.4% | -2.0 pp |
| **Pickup Rate** | 0.11% | 0.04% | **-64%** |

**Critical Insight**:

```
Calls per successful pickup:
- Before due: 90.1 / 0.10 = 901 calls per pickup
- After due: 95.9 / 0.03 = 3,197 calls per pickup

Effectiveness drops by 3.5x after due date.
```

**Status Breakdown After Due Date**:
- 91.40% = No Answer
- 3.16% = SCBR
- 3.19% = Invalid/Busy/Technical
- 0.79% = WhatsApp
- 0.08% = Negotiation/Payment Plan
- 0.04% = **Pickup** ← Target outcome

---

### Finding 4: Peak Persistence at Day 32

**Highest call volume concentration**:
- **Day 32 past due**: 41 loans received 15,833 calls
- **Average**: 386 calls per loan on day 32 alone
- **26-36 days range**: 142 loans (22.1%) with extremely high activity

**Hypothesis**: This may indicate:
1. Legal/regulatory deadline (30-day mark triggering escalation)
2. Vendor contract milestone (performance metrics at day 30+)
3. Internal policy (final collection push before write-off consideration)

**Recommended investigation**: Check if day 30-35 aligns with any policy milestones.

---

### Finding 5: Status Shift - SCBR Usage Pattern

| Period | SCBR Calls | % of Total Calls |
|--------|-----------|------------------|
| Before Due | 1,946 | 3.36% |
| After Due | 1,946 | 3.16% |

**SCBR (Special Collection Bureau Report)** maintains consistent usage before and after due date, suggesting it's a **standard escalation flag** rather than a late-stage intervention.

**Observation**: SCBR appears in 3.2% of all calls, indicating selective use for high-risk cases regardless of timing.

---

## 💻 Technical Implementation

### Final Query Structure

```sql
WITH
-- Step 1: Calculate due dates for all loans
loan_base AS (
  SELECT *,
    DATE_ADD(DATE_ADD(facility_start_date, INTERVAL 1 MONTH), INTERVAL day_maturity DAY) AS due_date
  FROM `data-prd-adhoc.temp_ammar.collection_analysis_aug_sept_2025_customers`
  WHERE day_maturity < 11
),

-- Step 2: Extract collection calls with proper date filter
collection_calls AS (
  SELECT
    card_no as deal_reference,
    CAST(date AS DATE) as call_date,
    CAST(date AS TIMESTAMP) as call_timestamp,
    status,
    call_status,
    collector
  FROM `jago-bank-data-production.digital_lending.digital_lending_collection_daily_report_vendor`
  WHERE business_date >= '2025-08-01'  -- Critical: Must include August
    AND business_date <= CURRENT_DATE()
    AND card_no IS NOT NULL
),

-- Step 3: Join and classify call timing
loan_calls_classified AS (
  SELECT
    loan.*,
    call.call_date,
    call.status,
    call.collector,
    DATE_DIFF(call.call_date, loan.due_date, DAY) AS days_from_due,
    CASE
      WHEN call.call_date < loan.due_date THEN 'before_due'
      WHEN call.call_date >= loan.due_date THEN 'after_due'
    END AS call_timing
  FROM loan_base loan
  LEFT JOIN collection_calls call ON loan.deal_reference = call.deal_reference
),

-- Step 4: Aggregate before-due metrics
calls_before_due AS (
  SELECT
    deal_reference,
    COUNT(call_date) AS total_calls_before_due,
    COUNTIF(status IN ('No Answer', 'EC - No answer', 'No Answer AutoDial')) AS before_no_answer,
    COUNTIF(status = 'Pickup') AS before_pickup,
    COUNTIF(status = 'SCBR') AS before_scbr,
    MIN(call_date) AS first_call_before_due,
    MAX(call_date) AS last_call_before_due,
    COUNT(DISTINCT collector) AS collectors_before_due
  FROM loan_calls_classified
  WHERE call_timing = 'before_due'
  GROUP BY deal_reference
),

-- Step 5: Aggregate after-due metrics
calls_after_due AS (
  SELECT
    deal_reference,
    COUNT(call_date) AS total_calls_after_due,
    COUNTIF(status IN ('No Answer', 'EC - No answer', 'No Answer AutoDial')) AS after_no_answer,
    COUNTIF(status = 'Pickup') AS after_pickup,
    COUNTIF(status = 'SCBR') AS after_scbr,
    MAX(call_timestamp) AS latest_call_timestamp_after_due,
    DATE_DIFF(MAX(call_date), due_date, DAY) AS max_days_after_due_called,
    COUNT(DISTINCT collector) AS collectors_after_due
  FROM loan_calls_classified
  WHERE call_timing = 'after_due'
  GROUP BY deal_reference, due_date
),

-- Step 6: Combine into final summary
loan_collection_summary AS (
  SELECT
    loan.*,
    COALESCE(before.total_calls_before_due, 0) AS total_calls_before_due,
    COALESCE(before.before_no_answer, 0) AS calls_before_due_no_answer,
    COALESCE(before.before_pickup, 0) AS calls_before_due_pickup,
    COALESCE(after.total_calls_after_due, 0) AS total_calls_after_due,
    COALESCE(after.after_no_answer, 0) AS calls_after_due_no_answer,
    COALESCE(after.after_pickup, 0) AS calls_after_due_pickup,
    after.max_days_after_due_called
  FROM loan_base loan
  LEFT JOIN calls_before_due before USING (deal_reference)
  LEFT JOIN calls_after_due after USING (deal_reference)
)

SELECT * FROM loan_collection_summary
WHERE flag_bad_customer = 1
ORDER BY total_calls_after_due DESC;
```

### Validation Queries

**Check 1: Verify status sum equals total**
```sql
SELECT
  deal_reference,
  total_calls_before_due,
  (calls_before_due_no_answer + calls_before_due_pickup + calls_before_due_scbr +
   calls_before_due_whatsapp + calls_before_due_ptp + calls_before_due_payment_plan +
   calls_before_due_negotiation + calls_before_due_busy + calls_before_due_invalid +
   calls_before_due_voicemail + calls_before_due_rejected_dropped) AS status_sum,
  total_calls_before_due - status_sum AS difference
FROM loan_collection_summary
WHERE difference != 0;  -- Should return 0 rows
```

**Check 2: Verify date range coverage**
```sql
SELECT
  cohort_name,
  MIN(first_call_before_due) as earliest_call,
  MAX(last_call_after_due) as latest_call,
  MIN(due_date) as earliest_due,
  MAX(due_date) as latest_due
FROM loan_collection_summary
GROUP BY cohort_name;
```

---

## 🔧 Data Quality Notes

### Issue 1: Date Range Coverage ⚠️

**Problem**: Initial query used `business_date >= '2025-09-01'`, missing August cohort before-due calls.

**Impact**:
- August cohort loans have `due_date` in September (2025-09-01 to 2025-10-10)
- Before-due calls for August cohort occurred in **August 2025**
- Original filter excluded ~30 days of August collection data

**Fix Applied**:
```sql
WHERE business_date >= '2025-08-01'  -- Changed from '2025-09-01'
```

**Verification**:
```sql
SELECT
  cohort_name,
  COUNT(CASE WHEN total_calls_before_due = 0 THEN 1 END) as loans_no_before_calls,
  COUNT(CASE WHEN total_calls_before_due > 0 THEN 1 END) as loans_with_before_calls
FROM loan_collection_summary
GROUP BY cohort_name;
```

Expected: August 2025 cohort should have >0 before-due calls.

---

### Issue 2: Status Field Inconsistency

**Observation**: Two status fields exist: `status` and `call_status`

**Analysis Used**: Primary analysis uses `status` field

**Discrepancy Check**:
```sql
SELECT
  status,
  call_status,
  COUNT(*) as occurrences
FROM `jago-bank-data-production.digital_lending.digital_lending_collection_daily_report_vendor`
WHERE business_date = '2025-10-01'
  AND status != call_status
GROUP BY status, call_status
ORDER BY occurrences DESC;
```

**Recommendation**: Clarify with vendor which field is authoritative (asked Kak Maria as per mentor's instruction).

---

### Issue 3: NULL max_days_after_due_called

**Count**: 293 loans (45.6%) have `NULL` in this field

**Root Cause**: These loans received **zero calls after due date**

**Handling**:
- Kept as NULL (not converted to 0) to distinguish "no calls" from "called on due date (day 0)"
- Pivot tables treat NULL as separate category "No follow-up"

**Business Interpretation**: This is a **triage decision**, not missing data.

---

### Issue 4: Duplicate deal_reference Risk

**Check**: Verify loan_base has unique deal_reference

```sql
SELECT
  deal_reference,
  COUNT(*) as count
FROM loan_base
GROUP BY deal_reference
HAVING COUNT(*) > 1;
-- Should return 0 rows
```

**Result**: ✅ No duplicates found (642 unique loans)

---

## 💡 Recommendations

### 1. Investigate Triage Logic (HIGH PRIORITY)

**Objective**: Understand why 45.6% of bad loans receive zero follow-up

**Recommended Analysis**:
```sql
-- Compare characteristics of "no follow-up" vs "persistent follow-up" groups
SELECT
  CASE
    WHEN max_days_after_due_called IS NULL THEN 'No Follow-Up'
    ELSE 'Has Follow-Up'
  END as follow_up_group,

  COUNT(*) as loan_count,
  AVG(plafond) as avg_loan_amount,
  AVG(ews_calibrated_scores) as avg_ews_score,

  -- Risk distribution
  COUNT(CASE WHEN risk_group_hci = 'H' THEN 1 END) as high_risk,
  COUNT(CASE WHEN risk_group_hci = 'M' THEN 1 END) as medium_risk,
  COUNT(CASE WHEN risk_group_hci = 'L' THEN 1 END) as low_risk,

  -- Partner distribution
  COUNT(CASE WHEN partner_final LIKE '%Bibit%' THEN 1 END) as bibit_loans,
  COUNT(CASE WHEN partner_final LIKE '%Stockbit%' THEN 1 END) as stockbit_loans

FROM loan_collection_summary
WHERE flag_bad_customer = 1
GROUP BY follow_up_group;
```

**Expected Insight**: Identify if triage is based on loan size, risk score, or partner channel.

---

### 2. Alternative Contact Channels (HIGH PRIORITY)

**Finding**: 91.4% No Answer rate indicates phone calls are ineffective

**Recommendation**: Analyze WhatsApp engagement

```sql
SELECT
  CASE
    WHEN calls_after_due_whatsapp > 0 THEN 'WhatsApp Used'
    ELSE 'Phone Only'
  END as contact_strategy,

  COUNT(*) as loan_count,
  AVG(total_calls_after_due) as avg_total_calls,
  AVG(calls_after_due_pickup) as avg_pickups,
  AVG(SAFE_DIVIDE(calls_after_due_pickup, total_calls_after_due)) as avg_pickup_rate

FROM loan_collection_summary
WHERE flag_bad_customer = 1
  AND total_calls_after_due > 0
GROUP BY contact_strategy;
```

**Hypothesis to Test**: Does WhatsApp usage correlate with higher contact success?

---

### 3. Day 30-35 Policy Review (MEDIUM PRIORITY)

**Observation**: Spike in call volume at day 32 (386 avg calls per loan)

**Investigation Needed**:
1. Check internal collection policy for 30-day milestones
2. Review vendor contract SLAs for escalation timelines
3. Identify if day 30 triggers legal/regulatory actions

**Query**:
```sql
SELECT
  max_days_after_due_called,
  COUNT(*) as loan_count,
  SUM(total_calls_after_due) as total_calls,
  AVG(total_calls_after_due) as avg_calls_per_loan
FROM loan_collection_summary
WHERE max_days_after_due_called BETWEEN 28 AND 36
GROUP BY max_days_after_due_called
ORDER BY max_days_after_due_called;
```

---

### 4. Collector Performance Analysis (LOW PRIORITY)

**Current Metrics Available**:
- `collectors_before_due`: Number of distinct collectors
- `collectors_after_due`: Number of distinct collectors

**Recommended Deep Dive**:
```sql
-- Collector-level effectiveness
SELECT
  collector,
  COUNT(DISTINCT deal_reference) as loans_handled,
  SUM(CASE WHEN status = 'Pickup' THEN 1 ELSE 0 END) as total_pickups,
  COUNT(*) as total_calls,
  ROUND(SUM(CASE WHEN status = 'Pickup' THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as pickup_rate_pct
FROM loan_calls_classified
WHERE call_timing = 'after_due'
  AND collector IS NOT NULL
GROUP BY collector
HAVING COUNT(*) >= 100  -- Min 100 calls for statistical significance
ORDER BY pickup_rate_pct DESC;
```

---

### 5. Cost-Benefit Optimization (STRATEGIC)

**Key Metric**: 3,197 calls needed per successful pickup after due date

**Analysis Needed**:
```
Cost per call (vendor) × 3,197 calls = Total cost per pickup
vs
Average recovery amount per pickup

If cost > recovery, re-evaluate strategy for low-balance loans
```

**Recommendation**: Create cost-effectiveness threshold model:
```sql
WITH cost_analysis AS (
  SELECT
    CASE
      WHEN plafond <= 500000 THEN 'Small (≤500K)'
      WHEN plafond <= 1000000 THEN 'Medium (500K-1M)'
      ELSE 'Large (>1M)'
    END as loan_size_bucket,

    AVG(total_calls_after_due) as avg_calls,
    AVG(calls_after_due_pickup) as avg_pickups,
    COUNT(*) as loan_count
  FROM loan_collection_summary
  WHERE flag_bad_customer = 1
    AND total_calls_after_due > 0
  GROUP BY loan_size_bucket
)
SELECT
  *,
  -- Assume Rp 5,000 per call cost (placeholder, verify with finance)
  avg_calls * 5000 as total_collection_cost,
  plafond * 0.3 as estimated_recovery_30pct,  -- Assume 30% recovery
  (plafond * 0.3) - (avg_calls * 5000) as net_value
FROM cost_analysis;
```

If `net_value < 0` for small loans, consider automated-only collection.

---

## 📚 Appendix

### Appendix A: Status Mappings

**Full status categorization used in analysis:**

```sql
-- No Answer statuses
COUNTIF(status IN ('No Answer', 'EC - No answer', 'No Answer AutoDial'))

-- Pickup statuses
COUNTIF(status = 'Pickup')

-- SCBR statuses
COUNTIF(status = 'SCBR')

-- WhatsApp statuses
COUNTIF(status IN ('WA - Sent', 'WA - Read'))

-- Promise to Pay statuses
COUNTIF(status IN ('PTP', 'PTP - Reminder'))

-- Payment Plan statuses
COUNTIF(status IN ('PAYMENT PLAN', 'RENCANA PEMBAYARAN'))

-- Negotiation statuses
COUNTIF(status = 'UNDER NEGOTIATION')

-- Busy statuses
COUNTIF(status IN ('Busy Auto', 'Auto Busy', 'EC - Busy call', 'Busy'))

-- Invalid statuses
COUNTIF(status = 'invalid')

-- Voicemail statuses
COUNTIF(status IN ('Voice Mail', 'Voice Message Prompt', 'Left Message'))

-- Rejected/Dropped statuses
COUNTIF(status IN ('Call Rejected', 'Dropped', 'DROP CALL'))
```

**Other statuses not categorized** (appear in raw data but <0.1% frequency):
- Resign / Moved
- RTP (Refused to Pay)
- WPC (Wrong Party Contact)
- Agent Error
- Complaint - Behavior
- Complaint - Vulnerable
- Request for payment plan
- Plan Approved
- Etc. (45+ total distinct statuses)

---

### Appendix B: Sample Customer Deep Dive

**Case Study**: Customer ID `1477391542` (7 loans, all bad)

| Loan | Due Date | Calls Before | Calls After | Max Days Followed | No Answer After |
|------|----------|--------------|-------------|-------------------|-----------------|
| 87006036249351 | 2025-10-02 | 6 | 339 | 14 | 332 (97.9%) |
| 87224598955780 | 2025-10-07 | 55 | 138 | 9 | 134 (97.1%) |
| 87412258572169 | 2025-10-10 | 24 | 132 | 5 | 132 (100%) |
| 87182440596384 | 2025-10-03 | 7 | 84 | 11 | 78 (92.9%) |
| 87707335669370 | 2025-10-04 | 11 | 72 | 7 | 69 (95.8%) |
| 87036535356808 | 2025-10-06 | 12 | 49 | 4 | 46 (93.9%) |
| 87768358366132 | 2025-10-03 | 6 | 23 | 13 | 17 (73.9%) |

**Total**: 121 calls before due, 837 calls after due (691% increase)

**Key Observations**:
- Collector persistence: Up to 14 days follow-up
- No pickup success across any loan
- Pattern consistent with aggregate findings

---

### Appendix C: Pivot Table Setup Guide

**Pivot Table 1: Hypothesis Test**

Google Sheets Setup:
1. **Rows**: `max_days_after_due_called`
2. **Values**:
   - `COUNTA of lfs_customer_id` → "Loan Count"
   - `SUM of total_calls_after_due` → "Total Calls"
   - `SUM of calls_after_due_no_answer` → "No Answer Calls"
3. **Manual Grouping**:
   - Group 0-7 → "Week 1"
   - Group 8-14 → "Week 2"
   - Group 15-30 → "Month 1"
   - Group 31+ → "Extended"

**Pivot Table 2: Before vs After Comparison**

1. **Rows**: (none, summary view)
2. **Values**:
   - `AVERAGE of total_calls_before_due`
   - `AVERAGE of total_calls_after_due`
   - `AVERAGE of calls_before_due_no_answer`
   - `AVERAGE of calls_after_due_no_answer`
   - `AVERAGE of calls_before_due_pickup`
   - `AVERAGE of calls_after_due_pickup`

---

### Appendix D: Related Documentation

- **Data Dictionary**: `jago-bank-data-production.digital_lending.digital_lending_collection_daily_report_vendor.csv`
- **Base Table Schema**: `data-prd-adhoc.temp_ammar.collection_analysis_aug_sept_2025_customers.csv`
- **Previous Analysis**: `Collection_Effectiveness_Deep_Dive_Wiki.md` (customer-level, September 2025 only)
- **Analysis Framework**: `Data_Analysis_Flow_Guide_Bank_Jago - Copy.md`
- **General Knowledge**: `Handbook - Risk Data Analyst.md`

---

## 📝 Changelog

| Date | Author | Change |
|------|--------|--------|
| 2025-10-XX | Ammar Siregar | Initial documentation created |
| 2025-10-XX | Ammar Siregar | Fixed date range bug (2025-09-01 → 2025-08-01) |
| 2025-10-XX | Ammar Siregar | Added bimodal distribution finding |
| 2025-10-XX | Ammar Siregar | Added cost-benefit optimization section |

---

**Document Status**: ✅ Complete
**Last Reviewed**: 2025-10-XX
**Next Review**: 2025-11-XX
**Approver**: [Mentor Name]
