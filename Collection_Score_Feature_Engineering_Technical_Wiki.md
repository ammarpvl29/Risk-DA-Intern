# Collection Score Feature Engineering - Technical Wiki

**Project Name**: Collection Score ML Feature Development
**Analysis Date**: October 20, 2025
**Analyst**: Ammar Siregar (Risk DA Intern)
**Mentor**: Muhammad Subhan
**Data Source Expert**: Kak Maria (Digital Lending Data Analyst)
**Cohorts Analyzed**: August 2025, September 2025
**Status**: ✅ Phase 1 Complete - Segmented Aggregations Built

---

## 📋 Table of Contents

1. [Business Context](#business-context)
2. [Objective](#objective)
3. [Critical Bug Fixes](#critical-bug-fixes)
4. [Data Architecture](#data-architecture)
5. [Segmentation Logic](#segmentation-logic)
6. [Technical Implementation](#technical-implementation)
7. [Query Structure](#query-structure)
8. [Output Schema](#output-schema)
9. [Key Findings](#key-findings)
10. [Next Steps](#next-steps)
11. [Appendix](#appendix)

---

## 🎯 Business Context

### Problem Statement

The collection team needs a **machine learning model** to predict:
1. Which customers are likely to pay
2. Which collection methods are most effective for each customer type

Currently, the team has "All Activity" aggregated metrics (15 columns). The model needs **granular features** showing effectiveness by:
- **Dialer Type**: Predictive (automated bot) vs Manual (human collector)
- **Contact Person**: RPC (Right Party - actual customer) vs TPC (Third Party)
- **Phone Type**: Main Phone, Emergency Contact, Office, Mobile

### Stakeholders

| Stakeholder | Role | Need |
|-------------|------|------|
| Muhammad Subhan | Technical Mentor | Feature engineering methodology |
| Credit Risk Team | Model Owners | ML model features |
| Collection Team | Operations | Effectiveness insights |
| Kak Maria | Data Expert | Collection table schema expertise |

### Expected Outcome

**From**: 1 aggregation with 15 metrics
**To**: 7 segmented aggregations with 8-15 metrics each = **56-105 feature columns**

These features will be used as inputs for ML model to predict payment likelihood and optimal contact strategy.

---

## 🐛 Critical Bug Fixes

### Bug 1: Incorrect Due Date Calculation ❌

**Problem Found**: October 20, 2025

**Original Logic** (WRONG):
```sql
DATE_ADD(DATE_ADD(facility_start_date, INTERVAL 1 MONTH), INTERVAL day_maturity DAY) AS due_date

-- Where day_maturity = EXTRACT(DAY FROM maturity_date)
```

**Issue**:
- `maturity_date` = Full loan maturity (when entire loan ends), NOT first payment due
- Calculated due dates were **8-29 days off** from actual first payment due date

**Validation Results**:
| facility_start_date | actual_first_due_date | calculated_due_date | days_difference |
|---------------------|----------------------|---------------------|-----------------|
| 2025-08-13 | 2025-10-01 | 2025-09-14 | **17** ❌ |
| 2025-08-22 | 2025-10-02 | 2025-09-24 | **8** ❌ |
| 2025-09-20 | 2025-10-20 | 2025-11-09 | **-20** ❌ |

**Corrected Logic** (CORRECT):
```sql
first_due_date AS due_date  -- Use actual first_due_date from system
```

**Impact**: All collection timing analysis (before/after due) was miscalculated in previous analyses.

---

### Bug 2: Overlapping Customer Flags ❌

**Problem Found**: October 20, 2025

**Original Logic** (WRONG):
```sql
CASE
    WHEN COALESCE(y.fpd_dpd3_mob1_act, 0) = 1 THEN 1  -- DPD flag
    ELSE 0
END AS flag_bad_customer,

CASE
    WHEN COALESCE(y.fpd_dpd3_mom1_bal, 0) = 0 THEN 1  -- ❌ BALANCE, not flag!
    ELSE 0
END AS flag_good_customer
```

**Issue**:
- `flag_bad_customer` checks DPD flag ✅
- `flag_good_customer` checks **balance** ❌
- Customer can be flagged as BOTH bad AND good if they defaulted but later paid

**Example**:
```
Customer 1477391542:
- fpd_dpd3_mob1_act = 1 (went 3+ DPD) → flag_bad_customer = 1 ✅
- fpd_dpd3_mom1_bal = 0 (paid after defaulting) → flag_good_customer = 1 ❌
Result: BOTH flags = 1 (impossible!)
```

**Corrected Logic** (CORRECT):
```sql
CASE
    WHEN COALESCE(y.fpd_dpd3_mob1_act, 0) = 1 THEN 1
    ELSE 0
END AS flag_bad_customer,

CASE
    WHEN COALESCE(y.fpd_dpd3_mob1_act, 0) = 0 THEN 1  -- ✅ Same field, inverse logic
    ELSE 0
END AS flag_good_customer
```

**Impact**: Mutually exclusive flags now correctly separate bad vs good customers.

---

## 🗂️ Data Architecture

### Core Tables

#### 1. Base Customer Table (CORRECTED)

**Table**: `data-prd-adhoc.temp_ammar.collection_analysis_aug_sept_2025_customers`
**Grain**: One row per loan (deal_reference)
**Created**: October 20, 2025 (rebuilt with fixes)

**Key Fields**:

| Field | Type | Description | Notes |
|-------|------|-------------|-------|
| `lfs_customer_id` | STRING | Customer ID | Can have multiple loans |
| `deal_reference` | STRING | Loan ID | Primary key, JOIN to collection table |
| `facility_reference` | STRING | Facility ID | Not used for collection join |
| `facility_start_date` | DATE | Loan disbursement date | |
| `first_due_date` | DATE | **Actual first payment due date** | ✅ NEW: From system |
| `day_maturity` | INTEGER | Day of month from maturity_date | Legacy field, not used |
| `day_first_due` | INTEGER | Day of month from first_due_date | ✅ NEW: Extracted day |
| `cohort_name` | STRING | "August 2025" or "September 2025" | |
| `flag_bad_customer` | INTEGER | 1 = Defaulted (3+ DPD MOB1) | ✅ FIXED |
| `flag_good_customer` | INTEGER | 1 = Did not default | ✅ FIXED |
| `plafond` | BIGNUMERIC | Loan amount | |
| `partner_final` | STRING | Partner (Bibit/Stockbit) | |

**Row Count**: 8,838 customers total
- Bad customers: 682 (193 Aug + 489 Sept)
- Good customers: 8,156

---

#### 2. Collection Call Detail Table

**Table**: `jago-bank-data-production.digital_lending.digital_lending_collection_daily_report_vendor`
**Grain**: One row per call attempt
**Partitioned By**: `business_date` (REQUIRED in WHERE clause)

**Key Fields**:

| Field | Type | Description | Use Case |
|-------|------|-------------|----------|
| `business_date` | DATE | Partition key (data load date) | Filter only, not for analysis |
| `card_no` | STRING | **Maps to deal_reference** | JOIN key to loan table |
| `date` | STRING | **Actual call timestamp** | ✅ Use this for analysis |
| `status` | STRING | Call outcome (45+ values) | Main analysis field |
| `remark` | STRING | **Predictive Dialer flag** | ✅ Segmentation key |
| `phone_type` | STRING | Main/Emergency/Office/Mobile | ✅ Segmentation key |
| `person_contacted` | STRING | RPC (customer) / TPC (third party) | ✅ Segmentation key |
| `collector` | STRING | Collector name/ID | For counting distinct collectors |
| `dpd` | INTEGER | Days Past Due at call time | Timing validation |
| `call_status` | STRING | Alternative status field | Not used (status is primary) |

**Critical Date Logic**:
```sql
-- ❌ WRONG: business_date is partition date (when data loaded)
WHERE business_date >= '2025-08-01'

-- ✅ CORRECT: Use CAST(date AS DATE) for actual call date
SELECT CAST(date AS DATE) as call_date
```

**Status Categories** (45+ distinct values):

| Category | Status Values | Meaning |
|----------|---------------|---------|
| **No Answer** | 'No Answer', 'EC - No answer', 'No Answer AutoDial' | Phone rang, not answered |
| **Pickup** | 'Pickup' | Customer answered (IVR only) |
| **SCBR** | 'SCBR' | Subscriber Cannot Be Reached |
| **WhatsApp** | 'WA - Sent', 'WA - Read' | WhatsApp message |
| **PTP** | 'PTP', 'PTP - Reminder' | Promise To Pay |
| **Payment Plan** | 'PAYMENT PLAN', 'RENCANA PEMBAYARAN' | Payment plan agreed |
| **Negotiation** | 'UNDER NEGOTIATION' | Under negotiation |
| **Busy** | 'Busy Auto', 'Auto Busy', 'EC - Busy call', 'Busy' | Line busy |
| **Invalid** | 'invalid' | Invalid phone number |
| **Voicemail** | 'Voice Mail', 'Voice Message Prompt', 'Left Message' | Voicemail |
| **Rejected/Dropped** | 'Call Rejected', 'Dropped', 'DROP CALL' | Call failed |

---

## 🔍 Segmentation Logic

### Meeting with Kak Maria (Digital Lending Data Analyst)

**Date**: October 20, 2025
**Key Insights**:

#### 1. Predictive vs Manual Dialer

**Two Types of Calling**:
- **Predictive Dialer** = Automated bot system (can call hundreds per day)
- **Manual Dialer** = Human collector inputs numbers manually

**How to Identify**:
```sql
CASE
  WHEN remark LIKE 'Predictive%' THEN 'Predictive Dialer'  -- Bot
  ELSE 'Manual Dialer'  -- Human
END
```

**Validation**: Hundreds of calls per day? → Predictive Dialer (makes sense per Kak Maria)

---

#### 2. Phone Type Classification

**Three Phone Number Types**:

| Phone Type | Description | Usage Priority |
|------------|-------------|----------------|
| **Main Phone** (utama) | Customer primary number | Called first |
| **Emergency Contact** | Called if main unreachable for days | Called second |
| **Office/Work** | Work phone number | Called third |
| **Mobile** | Alternative mobile | Rare |

**Field**: `phone_type` column

---

#### 3. Person Contacted

**Two Contact Types**:

| Code | Meaning | Description |
|------|---------|-------------|
| **RPC** | Right Party Contact | Actual customer answered |
| **TPC** | Third Party Contact | Someone else answered (family, colleague) |

**Field**: `person_contacted` column

---

### Segmentation Distribution (Bad Customers Only)

**Query Results**: October 20, 2025

| Segment | Dimension | Call Count | Percentage |
|---------|-----------|------------|------------|
| **Dialer Type** | Predictive Dialer | 113,696 | 96.1% |
| | Manual Dialer | 4,606 | 3.9% |
| **Person Contacted** | RPC (Right Party) | 18,483 | 33.5% |
| | TPC (Third Party) | 36,667 | 66.5% |
| **Phone Type** | Main Phone | 80,411 | 68.0% |
| | Emergency Contact | 22,597 | 19.1% |
| | Office | 14,121 | 11.9% |
| | Mobile | 1,174 | 1.0% |

**Key Observation**: 96% of calls are automated (Predictive Dialer), only 4% manual.

---

## 💻 Technical Implementation

### Query Architecture

**Pattern**: Bank Jago CTE Best Practices

```
1. loan_base → Load loans with corrected first_due_date
2. collection_calls → Extract call records with segmentation fields
3. loan_calls_classified → Join loans + calls
4. calls_[segment]_1 → Aggregate for Predictive Dialer
5. calls_[segment]_2 → Aggregate for Manual Dialer
6. calls_[segment]_3 → Aggregate for RPC
7. calls_[segment]_4 → Aggregate for TPC
8. calls_[segment]_5 → Aggregate for Main Phone
9. calls_[segment]_6 → Aggregate for Emergency Contact
10. calls_[segment]_7 → Aggregate for Office Phone
11. loan_collection_summary → Combine all segments into final table
```

**Total CTEs**: 11 (1 base + 1 calls + 1 classified + 7 segments + 1 summary)

---

### Core Metrics per Segment

**8 Standard Metrics** (replicated across all 7 segments):

| Metric | SQL Logic | Purpose |
|--------|-----------|---------|
| `total_calls_[segment]` | `COUNT(call_date)` | Total call attempts |
| `[segment]_no_answer` | `COUNTIF(status IN ('No Answer', ...))` | Unreachable rate |
| `[segment]_pickup` | `COUNTIF(status = 'Pickup')` | Success rate (IVR) |
| `[segment]_scbr` | `COUNTIF(status = 'SCBR')` | Subscriber unreachable |
| `[segment]_whatsapp` | `COUNTIF(status IN ('WA - Sent', ...))` | WhatsApp usage |
| `[segment]_ptp` | `COUNTIF(status IN ('PTP', ...))` | Promise to Pay |
| `[segment]_payment_plan` | `COUNTIF(status IN ('PAYMENT PLAN', ...))` | Payment plan agreed |
| `[segment]_collectors` | `COUNT(DISTINCT collector)` | Collector diversity |

**Future Expansion**: Can add 5 more metrics (busy, invalid, voicemail, negotiation, rejected_dropped) → 13 metrics per segment = 91 total columns

---

## 📊 Query Structure

### Simplified Example (2 Segments)

```sql
WITH
loan_base AS (
  SELECT *,
    first_due_date AS due_date  -- ✅ CORRECTED
  FROM `data-prd-adhoc.temp_ammar.collection_analysis_aug_sept_2025_customers`
  WHERE day_maturity < 11
),

collection_calls AS (
  SELECT
    card_no as deal_reference,
    CAST(date AS DATE) as call_date,  -- ✅ CORRECTED
    status,
    remark,  -- ✅ For Predictive/Manual
    phone_type,  -- ✅ For Phone segmentation
    person_contacted,  -- ✅ For RPC/TPC
    collector
  FROM `jago-bank-data-production.digital_lending.digital_lending_collection_daily_report_vendor`
  WHERE business_date >= '2025-08-01'
    AND business_date <= CURRENT_DATE()
    AND card_no IS NOT NULL
),

-- Segment 1: Predictive Dialer
calls_predictive AS (
  SELECT
    deal_reference,
    COUNT(call_date) AS total_calls_predictive,
    COUNTIF(status IN ('No Answer', 'EC - No answer', 'No Answer AutoDial')) AS predictive_no_answer,
    COUNTIF(status = 'Pickup') AS predictive_pickup,
    -- ... 5 more metrics
    COUNT(DISTINCT collector) AS predictive_collectors
  FROM loan_calls_classified
  WHERE remark LIKE 'Predictive%'  -- ✅ Segmentation filter
  GROUP BY deal_reference
),

-- Segment 2: Manual Dialer
calls_manual AS (
  SELECT
    deal_reference,
    COUNT(call_date) AS total_calls_manual,
    COUNTIF(status IN ('No Answer', 'EC - No answer', 'No Answer AutoDial')) AS manual_no_answer,
    COUNTIF(status = 'Pickup') AS manual_pickup,
    -- ... 5 more metrics
    COUNT(DISTINCT collector) AS manual_collectors
  FROM loan_calls_classified
  WHERE remark NOT LIKE 'Predictive%' OR remark IS NULL  -- ✅ Segmentation filter
  GROUP BY deal_reference
),

-- ... Continue for 5 more segments

-- Final Summary
loan_collection_summary AS (
  SELECT
    loan.lfs_customer_id,
    loan.deal_reference,
    loan.due_date,
    loan.cohort_name,
    loan.flag_bad_customer,

    -- Predictive Dialer metrics (8 columns)
    COALESCE(pred.total_calls_predictive, 0) AS total_calls_predictive,
    COALESCE(pred.predictive_no_answer, 0) AS predictive_no_answer,
    -- ... 6 more metrics

    -- Manual Dialer metrics (8 columns)
    COALESCE(man.total_calls_manual, 0) AS total_calls_manual,
    COALESCE(man.manual_no_answer, 0) AS manual_no_answer,
    -- ... 6 more metrics

    -- ... Continue for 5 more segments

  FROM loan_base loan
  LEFT JOIN calls_predictive pred USING (deal_reference)
  LEFT JOIN calls_manual man USING (deal_reference)
  -- ... 5 more JOINs
)

SELECT * FROM loan_collection_summary
WHERE flag_bad_customer = 1;
```

---

## 📐 Output Schema

### Table Design

**Proposed Table**: `data-prd-adhoc.temp_ammar.collection_score_features_aug_sept_2025`
**Grain**: One row per loan (deal_reference)
**Row Count**: 8,838 customers (682 bad, 8,156 good)

### Column Structure

**Base Columns** (5):
- `lfs_customer_id` (STRING)
- `deal_reference` (STRING)
- `due_date` (DATE)
- `cohort_name` (STRING)
- `flag_bad_customer` (INTEGER)

**Feature Columns** (56 = 7 segments × 8 metrics):

| Segment | Column Prefix | Columns Count | Example Columns |
|---------|---------------|---------------|-----------------|
| 1. Predictive Dialer | `predictive_*` | 8 | `total_calls_predictive`, `predictive_no_answer`, `predictive_pickup` |
| 2. Manual Dialer | `manual_*` | 8 | `total_calls_manual`, `manual_no_answer`, `manual_pickup` |
| 3. RPC (Right Party) | `rpc_*` | 8 | `total_calls_rpc`, `rpc_no_answer`, `rpc_pickup` |
| 4. TPC (Third Party) | `tpc_*` | 8 | `total_calls_tpc`, `tpc_no_answer`, `tpc_pickup` |
| 5. Main Phone | `main_phone_*` | 8 | `total_calls_main_phone`, `main_phone_no_answer`, `main_phone_pickup` |
| 6. Emergency Contact | `emergency_*` | 8 | `total_calls_emergency`, `emergency_no_answer`, `emergency_pickup` |
| 7. Office Phone | `office_*` | 8 | `total_calls_office`, `office_no_answer`, `office_pickup` |

**Total Columns**: 5 base + 56 features = **61 columns**

---

## 🔍 Key Findings

### Finding 1: Predictive Dialer Dominance

**Distribution**:
- **96.1% Predictive Dialer** (automated bot)
- **3.9% Manual Dialer** (human collectors)

**Implication**: Collection strategy heavily relies on automation. Manual intervention is rare and likely for special cases.

---

### Finding 2: Third Party Contact Majority

**Distribution**:
- **66.5% TPC** (Third Party Contact - not the customer)
- **33.5% RPC** (Right Party Contact - actual customer)

**Implication**: Collectors often reach family/colleagues instead of customer. This may indicate:
1. Customer avoiding calls
2. Phone number shared with family
3. Customer phone inactive

---

### Finding 3: Main Phone Preference

**Distribution**:
- **68.0% Main Phone** (primary number)
- **19.1% Emergency Contact**
- **11.9% Office Phone**
- **1.0% Mobile**

**Implication**: Collection team prioritizes main number, escalates to emergency/office when main fails.

---

### Finding 4: Sample Customer Analysis

**Top Bad Customer** (deal_reference: 87842049168827):

| Metric | Value | Insight |
|--------|-------|---------|
| Total Calls | 1,790 | Extremely high call volume |
| Predictive Calls | 1,782 (99.6%) | Almost all automated |
| Manual Calls | 8 (0.4%) | Minimal human intervention |
| No Answer Rate | 97.5% | Customer unreachable |
| Pickup Rate | 0% | Zero successful contacts |
| Main Phone Calls | 1,036 (57.9%) | Tried main number most |
| Emergency Calls | 373 (20.8%) | Escalated to emergency |
| Office Calls | 381 (21.3%) | Also tried office |

**Pattern**: High-volume automated calling with zero success → Customer completely unreachable.

---

## 🚀 Next Steps

### Phase 2: Expand Metrics (Optional)

Add 5 more status categories per segment:
- `[segment]_busy`
- `[segment]_invalid`
- `[segment]_voicemail`
- `[segment]_negotiation`
- `[segment]_rejected_dropped`

**Result**: 7 segments × 13 metrics = **91 feature columns**

---

### Phase 3: Add Baseline "All Activity"

Include original aggregation (before segmentation) for comparison:
- `total_calls_all`
- `all_no_answer`
- `all_pickup`
- ... (15 metrics)

**Result**: 91 segmented + 15 baseline = **106 total columns**

---

### Phase 4: Save to Production Table

```sql
CREATE OR REPLACE TABLE `data-prd-adhoc.temp_ammar.collection_score_features_aug_sept_2025` AS (
  -- Full query here
);
```

---

### Phase 5: Model Integration

**Handoff to Data Science Team**:
- Feature table ready for ML model training
- Target variable: `flag_bad_customer`
- Features: 56-106 columns (depending on expansion)

**Expected Model Output**:
1. **Probability of payment**: Given customer characteristics + collection features
2. **Optimal contact strategy**: Which segment (Predictive/Manual, RPC/TPC, Main/Emergency) yields highest success rate

---

## 📚 Appendix

### A. Status Code Reference

**Full Status Mapping** (45+ distinct values from raw data):

```sql
-- High Priority Statuses
'No Answer'              -- Most common (90%+)
'Pickup'                 -- IVR success
'SCBR'                   -- Subscriber Cannot Be Reached
'WA - Sent', 'WA - Read' -- WhatsApp
'PTP', 'PTP - Reminder'  -- Promise to Pay
'PAYMENT PLAN', 'RENCANA PEMBAYARAN'  -- Payment plan

-- Medium Priority
'invalid'                -- Invalid number
'Busy Auto', 'Busy'      -- Line busy
'UNDER NEGOTIATION'      -- Negotiating
'Voice Mail'             -- Voicemail

-- Low Priority
'Call Rejected'
'Dropped', 'DROP CALL'
'Resign / Moved'
'RTP'                    -- Refused to Pay
'WPC'                    -- Wrong Party Contact
'Agent Error'
'Complaint - Behavior'
'Complaint - Vulnerable'
-- ... 30+ more rare statuses
```

---

### B. Data Quality Checks

**Validation Queries**:

```sql
-- Check 1: Verify no duplicate deal_reference
SELECT deal_reference, COUNT(*)
FROM loan_base
GROUP BY deal_reference
HAVING COUNT(*) > 1;
-- Should return 0 rows

-- Check 2: Verify flags are mutually exclusive
SELECT flag_bad_customer, flag_good_customer, COUNT(*)
FROM loan_base
GROUP BY 1, 2;
-- Should only show (0,1) and (1,0), never (1,1)

-- Check 3: Verify first_due_date exists for all loans
SELECT COUNT(*) as total, COUNT(first_due_date) as with_due_date
FROM loan_base;
-- Both should be equal

-- Check 4: Verify collection calls have valid dates
SELECT COUNT(*) as total_calls,
       COUNT(CASE WHEN CAST(date AS DATE) IS NULL THEN 1 END) as null_dates
FROM collection_calls;
-- null_dates should be 0
```

---

### C. Performance Notes

**Query Runtime**:
- Loan base: ~2 seconds
- Collection calls: ~5 seconds (partitioned table)
- Full aggregation (7 segments): ~15 seconds
- Total runtime: **~22 seconds**

**Optimization Tips**:
1. Always use `business_date` filter for collection table (partition pruning)
2. Use `deal_reference` for joins (indexed)
3. Aggregate before joining (reduce data volume)
4. Use COALESCE for NULL handling (prevents NULL propagation)

---

### D. Related Documentation

**Dependencies**:
- `Collection_Call_Timing_Analysis_Technical_Wiki.md` - Original timing analysis (with wrong due date)
- `Collection_Effectiveness_Deep_Dive_Wiki.md` - Customer-level analysis (September only)
- `Collection_Effectiveness_Analysis_Technical_Documentation.md` - First analysis attempt (with bugs)
- `Data_Analysis_Flow_Guide_Bank_Jago - Copy.md` - Analysis best practices

**Data Dictionaries**:
- `jago-bank-data-production.digital_lending.digital_lending_collection_daily_report_vendor.csv`
- `data-prd-adhoc.temp_ammar.collection_analysis_aug_sept_2025_customers.csv`
- `jago-bank-data-production.data_mart.credit_risk_vintage_account_direct_lending.csv`

---

### E. Meeting Notes

**Meeting with Kak Maria** (October 20, 2025):

**Attendees**: Ammar Siregar, Kak Maria (Digital Lending DA)

**Key Takeaways**:
1. ✅ **Predictive Dialer Identification**: Use `remark` field, look for "Predictive" prefix
2. ✅ **Manual Dialer**: Anything without "Predictive" or NULL remark
3. ✅ **Phone Types**: Three types (Main, Emergency, Office) - call priority order
4. ✅ **High Call Volume**: Hundreds per day via Predictive Dialer is normal (automated)
5. ✅ **Emergency Contact**: Only called if main number fails for several days

**Action Items**:
- [x] Use `remark` for dialer type segmentation
- [x] Use `phone_type` for phone segmentation
- [x] Use `person_contacted` for RPC/TPC segmentation
- [ ] Future: Analyze emergency contact escalation timing

---

## 📝 Changelog

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-20 | Ammar Siregar | Initial documentation - segmentation complete |
| 1.0.1 | 2025-10-20 | Ammar Siregar | Added bug fix details (due date + flags) |
| 1.0.2 | 2025-10-20 | Ammar Siregar | Added Kak Maria meeting notes |

---

**Document Status**: ✅ Active - Phase 1 Complete
**Last Updated**: October 20, 2025
**Next Review**: After Phase 2 expansion (additional metrics)
**Approver**: Muhammad Subhan (Technical Mentor)

---

**For Questions or Clarifications**:
- Analyst: Ammar Siregar (aux-ammar.siregar@tech.jago.com)
- Technical Mentor: Muhammad Subhan
- Data Expert: Kak Maria (Digital Lending Data Analyst)
