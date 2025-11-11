# Collection & Notification Monitoring System - Technical Documentation

## Wiki Entry Metadata
- **Project**: Collection Effectiveness Monitoring System
- **Analysis Period**: August - October 2025
- **Analyst**: Credit Risk Data Analyst Intern
- **Last Updated**: 2025-10-28
- **Version**: 1.0

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [Business Context](#business-context)
3. [Data Architecture](#data-architecture)
4. [Query Development Journey](#query-development-journey)
5. [Critical Issues & Fixes](#critical-issues--fixes)
6. [Key Findings](#key-findings)
7. [Final Query Structure](#final-query-structure)
8. [Recommendations](#recommendations)

---

## Executive Summary

This document chronicles the development of Bank Jago's unified collection and notification monitoring system, designed to answer the critical business question: **"Are notifications and collection activities running consistently?"**

### Project Objectives
- Detect system outages and gaps in collection activities
- Monitor push notification delivery and engagement
- Create unified reporting combining collection calls + push notifications
- Align categorization with Digital Lending team standards

### Critical Findings
- **5 days with ZERO collection calls** (Sept 5, 27, 28; Oct 5, 19)
- **Notification read rate collapsed by 51%** (16.4% → 6.8%)
- **9 days missing DPD notifications** (weekend pattern identified)
- **98% query performance improvement** achieved through date filtering

### Output
A unified aggregated summary table with 647 rows covering:
- 3,077,505 collection call activities
- 455,113 push notification deliveries
- 7.8M total monitoring events across Aug-Oct 2025

---

## Business Context

### The Challenge
The Digital Lending team needed visibility into collection system reliability. Previous analyses focused on **effectiveness** (conversion rates, payment outcomes), but lacked **operational monitoring** to detect:
- System outages
- Notification delivery failures
- Collection capacity issues
- Weekend/holiday coverage gaps

### Business Question
> "Liat apakah ada notif yang nggak jalan (dalam satu bulan atau satu hari)"
>
> *(Translation: Check whether there are notifications that stopped running in a month or day)*

### Success Criteria
1. Daily aggregated summary showing all collection activities
2. Grouped by key dimensions: date, status, channel, DPD flag
3. Ability to detect anomalies through pivot table analysis
4. Alignment with DL team's categorization standards

---

## Data Architecture

### Source Tables

#### 1. Collection Call Data
**Table**: `jago-bank-data-production.digital_lending.digital_lending_collection_daily_report_vendor`

**Key Fields** (51 total):
- `date` (STRING) - **Actual call timestamp** (use this for analysis)
- `business_date` (DATE) - Partition/load date (for filtering only)
- `card_no` - Maps to `deal_reference` (14 digits)
- `status` - 45+ distinct call outcomes
- `remark` - Contains "Predictive" for bot calls
- `phone_type` - Main Phone, Emergency Contact, Office
- `person_contacted` - RPC vs TPC
- `time` - Time of call (multiple formats - see data quality issues)
- `dpd` - Days past due at time of call
- `collector` - Agent name
- `campaign_name` - Predictive dialer campaigns

**Table Size**: ~3M records for Aug-Oct 2025
**Partition Key**: `business_date`

#### 2. Push Notification Data
**Table**: `jago-bank-data-production.dwh_core.notification_current`

**Key Fields** (29 total):
- `notification_code` - "Notification_DL_Repayment_Reminder" or "Notification_DL_Overdue_BELL_PUSH_Reminder"
- `notification_status` - "READ" or "UNREAD"
- `notification_created_at` (TIMESTAMP) - Send time (UTC)
- `deep_link` - Contains `accountId=<deal_reference>`
- `header_id` / `body_id` - Message content in Indonesian
- `customer_id` - Target customer

**Table Size**: 28.4M total records (455k relevant for Aug-Oct 2025)
**No Partition** - Critical performance consideration

#### 3. Customer Base
**Table**: `data-prd-adhoc.temp_ammar.collection_analysis_aug_sept_2025_customers`

**Purpose**: Pre-filtered customer cohorts for Aug-Sept 2025 analysis
**Key Fields**: `lfs_customer_id`, `deal_reference`, `facility_start_date`, `cohort_month`

---

## Query Development Journey

### Phase 1: Initial Query Validation (Collection Only)

**Objective**: Validate mentor's aggregation query for collection calls

**Initial Approach**:
```sql
SELECT
  CAST(date AS DATE) as call_date,
  FORMAT_DATE('%Y%m', CAST(date AS DATE)) as period,
  UPPER(status) AS STATUS,
  -- ... category_status CASE logic
  COUNT(*) as CALLS_COUNTS,
  COUNT(DISTINCT collector) as COLLECTOR_COUNTS,
  COUNT(DISTINCT card_no) as LOAN_COUNTS
FROM `jago-bank-data-production.digital_lending.digital_lending_collection_daily_report_vendor`
WHERE business_date >= '2025-08-01'
GROUP BY call_date, period, STATUS, CATEGORY_STATUS
```

**Validation Steps**:
1. ✅ Confirmed 3,077,505 total calls for Aug-Oct 2025
2. ✅ Validated activity-based counting vs unique loan counting
3. ✅ Explained 2,661 loan count difference (newer data: Oct 24-25)

**Key Learning**: Use `CAST(date AS DATE)` not `business_date` for actual call timestamps

---

### Phase 2: Notification Monitoring

**Objective**: Detect gaps in notification delivery ("apakah ada notif yang nggak jalan")

#### Step 1: Notification Table Performance Optimization

**Problem Discovery**:
```sql
SELECT COUNT(*) as total_notifications
FROM `jago-bank-data-production.dwh_core.notification_current`
-- Result: 28,400,000 rows (entire table scan)
```

**Relevant Notifications**:
```sql
SELECT COUNT(*) as relevant_notifications
FROM `jago-bank-data-production.dwh_core.notification_current`
WHERE notification_code IN (
  'Notification_DL_Repayment_Reminder',
  'Notification_DL_Overdue_BELL_PUSH_Reminder'
)
-- Result: 590,000 rows (only 2% relevant)
```

**Solution Applied**:
```sql
WHERE notification_code IN (...)
  AND CAST(notification_created_at AS DATE) >= '2025-08-01'
  AND CAST(notification_created_at AS DATE) <= CURRENT_DATE()
-- Result: 455,113 rows (98% performance improvement)
```

**Impact**: Query time reduced from full table scan to targeted 455k records

---

#### Step 2: Deal Reference Extraction

**Challenge**: Extract `deal_reference` from deep_link for join key

**Deep Link Format**:
```
jago://digitalbanking.com/digital-lending/loan-dashboard?accountId=87337405920001
```

**Solution**:
```sql
REGEXP_EXTRACT(deep_link, r'accountId=(\d+)') AS loan_reference
```

**Validation**:
```sql
SELECT
  COUNT(*) as total_records,
  COUNTIF(loan_reference IS NULL) as null_count,
  COUNTIF(loan_reference IS NOT NULL) as extracted_count
FROM (
  SELECT REGEXP_EXTRACT(deep_link, r'accountId=(\d+)') AS loan_reference
  FROM `jago-bank-data-production.dwh_core.notification_current`
  WHERE notification_code IN (...)
)
```

**Result**: 100% extraction success (0% NULL deep_links)

---

#### Step 3: Time Field Parsing (Critical Data Quality Issue)

**Anomaly Discovery**:
```sql
SELECT
  LENGTH(time) as time_length,
  COUNT(*) as record_count,
  MIN(time) as sample_min,
  MAX(time) as sample_max
FROM `jago-bank-data-production.digital_lending.digital_lending_collection_daily_report_vendor`
WHERE business_date >= '2025-08-01'
GROUP BY time_length
ORDER BY record_count DESC
```

**Results**:
| time_length | record_count | sample_value | format |
|-------------|--------------|--------------|--------|
| 22 | 2,860,949 (93%) | "2025-09-01 08:15:32" | Full timestamp |
| 8 | 216,522 (7%) | "14:23:45" | Time only |
| NULL | 34 (0.0%) | NULL | Missing |

**Solution - Dual Format Parsing**:
```sql
CASE
  WHEN LENGTH(time) = 22 THEN CAST(time AS TIMESTAMP)
  WHEN LENGTH(time) = 8 THEN TIMESTAMP(CONCAT(CAST(date AS STRING), ' ', time))
  ELSE NULL
END as parsed_timestamp
```

**Validation**: Only 34 NULL times (0.0%) - acceptable data quality

---

#### Step 4: Status Categorization

**Original Approach** (User's initial query):
```sql
CASE
  WHEN status IN ('PAID', 'PTP', 'PAYMENT PLAN', ...)
  THEN 'commitment_payment'

  WHEN status IN ('No Answer', 'Busy', 'Voice Mail', ...)
  THEN 'unsuccessful_call'

  WHEN status IN ('Call Back', 'Left Message', 'WPC', ...)
  THEN 'successful_contact_no_commitment'

  WHEN status IN ('invalid', 'Skip Trace', 'Duplicate', ...)
  THEN 'data_information'

  WHEN status IN ('NEW', 'TRANSFER', 'REASSIGN', ...)
  THEN 'workflow'

  WHEN status IN ('WA - Sent', 'WA - Read')
  THEN 'whatsapp_notification'

  ELSE 'other'
END AS CATEGORY_STATUS
```

**For Notifications**:
```sql
CASE
  WHEN notification_code = 'Notification_DL_Repayment_Reminder' THEN 'push_reminder'
  WHEN notification_code = 'Notification_DL_Overdue_BELL_PUSH_Reminder' THEN 'push_dpd'
END AS CATEGORY_STATUS
```

---

### Phase 3: DL Team Categorization Alignment

**Objective**: Adopt Digital Lending team's standardized flags for consistency

#### DL Team's Original Query (with bug)
```sql
-- Their flag definitions
CASE
  WHEN TRIM(LOWER(status)) NOT IN (
    'broken promise','claim','agent error','abort','pickup','reassign',
    'skip trace','duplicate','scbr','invalid','auto busy',
    'ec - busy call','ec - no answer'
  ) THEN 1 ELSE 0
END as flag_number_active,

CASE
  WHEN status IN ('PAYMENT PLAN','Left Message','Call Back',
                  'PTP - Reminder','UNDER NEGOTIATION','Voice Mail','WPC')
  THEN 1 ELSE 0
END as flag_answered,

-- BUG IDENTIFIED: Phone type extraction
ifnull(substr(REGEXP_SUBSTR(remark, '[^)]+'),2,100),"") as phone_type_extract
```

**Regex Bug Analysis**:
- **Expected format**: `"called (Main Phone) 081318023828"` (old format with parentheses)
- **Actual format**: `"Predictive CP501895 called 081318023828"` (new format without parentheses)
- **Result**: "Predictive" becomes "redictive" (first character removed by `substr(...,2,100)`)

**Solution**: Use existing `phone_type` column instead of regex extraction

---

#### Adapted Flag Definitions

**1. flag_number_active** - Active/callable number
```sql
CASE
  WHEN TRIM(LOWER(status)) NOT IN (
    'broken promise','claim','agent error','abort','pickup','reassign',
    'skip trace','duplicate','scbr','invalid','auto busy',
    'ec - busy call','ec - no answer'
  ) THEN 1
  ELSE 0
END as flag_number_active
```

**2. flag_answered** - Call was answered
```sql
CASE
  WHEN status IN ('PAYMENT PLAN','Left Message','Call Back','PTP - Reminder',
                  'UNDER NEGOTIATION','Voice Mail','WPC')
  THEN 1 ELSE 0
END as flag_answered
```

**3. flag_rpc** - Right Party Contact (customer answered)
```sql
CASE
  WHEN status IN ('PAYMENT PLAN','Left Message','Call Back','PTP - Reminder',
                  'UNDER NEGOTIATION','Voice Mail','WPC')
    AND (person_contacted = 'RPC' OR person_contacted IS NULL)
  THEN 1 ELSE 0
END as flag_rpc
```

**4. flag_tpc** - Third Party Contact (someone else answered)
```sql
CASE
  WHEN status IN ('PAYMENT PLAN','Left Message','Call Back','PTP - Reminder',
                  'UNDER NEGOTIATION','Voice Mail','WPC')
    AND person_contacted = 'TPC'
  THEN 1 ELSE 0
END as flag_tpc
```

**5. flag_ptp** - Promise to Pay obtained
```sql
CASE
  WHEN status IN ('PAYMENT PLAN','PTP - Reminder')
  THEN 1 ELSE 0
END as flag_ptp
```

**6. flag_channel** - Communication channel used
```sql
CASE
  WHEN campaign_name LIKE '%IVR%' THEN 'IVR/Robocall'
  WHEN status LIKE '%WA -%' THEN 'Whatsapp Long Number'
  WHEN campaign_name IS NOT NULL THEN 'Predictive Dialer Call'
  WHEN campaign_name IS NULL THEN 'Manual Call'
END as flag_channel
```

---

#### Notification Flag Adaptations

For push notifications, flags were adapted as follows:

```sql
-- Notifications always considered "active"
1 as flag_number_active,

-- READ notifications count as "answered" and "RPC"
CASE WHEN notification_status = 'READ' THEN 1 ELSE 0 END as flag_answered,
CASE WHEN notification_status = 'READ' THEN 1 ELSE 0 END as flag_rpc,

-- Notifications cannot be TPC or PTP
0 as flag_tpc,
0 as flag_ptp,

-- Channel is always Push Notification
'Push_Notification' as flag_channel
```

---

### Phase 4: Combined UNION Query

**Design Decision**: UNION vs JOIN

**Option A (CHOSEN): UNION ALL**
- Preserves all activities (calls + notifications separately)
- Allows activity-level analysis
- Better for time-series monitoring
- Clean aggregation at summary level

**Option B (REJECTED): LEFT JOIN**
- Would miss notifications without matching calls
- Complex NULL handling
- Loses temporal granularity

**Implementation**:
```sql
WITH collection_base AS (
  -- Collection call CTE with all flags
),
notification_base AS (
  -- Push notification CTE with adapted flags
),
combined_data AS (
  SELECT * FROM collection_base
  UNION ALL
  SELECT * FROM notification_base
)

SELECT
  activity_date,
  period,
  STATUS,
  IS_DPD,
  flag_channel as CHANNEL,
  CATEGORY_STATUS,
  ACTIVITY_TYPE,  -- Distinguishes 'Collection_Call' vs 'Push_Notification'

  COUNT(*) as CALLS_COUNTS,
  COUNT(DISTINCT collector) as COLLECTOR_COUNTS,
  COUNT(DISTINCT loan_reference) as LOAN_COUNTS,

  -- DL Team's flag metrics
  SUM(flag_number_active) as ACTIVE_NUMBER_CALLS,
  SUM(flag_answered) as ANSWERED_CALLS,
  SUM(flag_rpc) as RPC_CALLS,
  SUM(flag_tpc) as TPC_CALLS,
  SUM(flag_ptp) as PTP_CALLS,

  FORMAT_TIMESTAMP('%H:%M:%S', MIN(parsed_timestamp)) as min_time,
  FORMAT_TIMESTAMP('%H:%M:%S', MAX(parsed_timestamp)) as max_time,
  FORMAT_DATE('%A', activity_date) as day_of_week

FROM combined_data
WHERE loan_reference IS NOT NULL
GROUP BY activity_date, period, STATUS, IS_DPD, CHANNEL, CATEGORY_STATUS, ACTIVITY_TYPE
ORDER BY activity_date, ACTIVITY_TYPE, STATUS
```

**Output**: 647 aggregated rows covering all combinations of:
- 92 days (Aug 1 - Oct 31, 2025)
- 2 activity types (Collection_Call, Push_Notification)
- Multiple statuses, channels, categories

---

## Critical Issues & Fixes

### Issue 1: Notification Table Performance

**Problem**:
- Full table scan: 28.4M records
- Only 590k relevant (2% of table)
- No partition key available

**Root Cause**: Missing date filter in WHERE clause

**Fix Applied**:
```sql
WHERE notification_code IN (
    'Notification_DL_Repayment_Reminder',
    'Notification_DL_Overdue_BELL_PUSH_Reminder'
  )
  AND CAST(notification_created_at AS DATE) >= '2025-08-01'
  AND CAST(notification_created_at AS DATE) <= CURRENT_DATE()
```

**Impact**: 98% reduction in scanned rows (28.4M → 455k)

---

### Issue 2: Dual Time Format Handling

**Problem**: Time field has inconsistent formats
- 93%: Full timestamp "2025-09-01 08:15:32" (22 chars)
- 7%: Time only "14:23:45" (8 chars)
- 0.0%: NULL values

**Root Cause**: System migration or data source changes

**Fix Applied**:
```sql
CASE
  WHEN LENGTH(time) = 22 THEN CAST(time AS TIMESTAMP)
  WHEN LENGTH(time) = 8 THEN TIMESTAMP(CONCAT(CAST(date AS STRING), ' ', time))
  ELSE NULL
END as parsed_timestamp
```

**Validation**: Successfully parsed 99.998% of records (34 NULLs acceptable)

---

### Issue 3: FORMAT_TIME Function Error

**Problem**: BigQuery function error
```sql
-- INCORRECT (caused error)
FORMAT_TIME('%H:%M:%S', MIN(parsed_timestamp))
```

**Error Message**: Function FORMAT_TIME does not exist

**Root Cause**: `parsed_timestamp` is TIMESTAMP type, not TIME type

**Fix Applied**:
```sql
-- CORRECT
FORMAT_TIMESTAMP('%H:%M:%S', MIN(parsed_timestamp))
```

---

### Issue 4: DL Team's Regex Bug (External Issue)

**Problem**: Phone type extraction produces incorrect results

**Their Code**:
```sql
ifnull(substr(REGEXP_SUBSTR(remark, '[^)]+'),2,100),"") as phone_type
```

**Expected**: "Predictive"
**Actual**: "redictive"

**Root Cause Analysis**:
1. Regex `[^)]+` searches for text before closing parenthesis ")"
2. Old format: `"called (Main Phone) 081318023828"` → extracts "(Main Phone"
3. `substr(...,2,100)` removes first character → "Main Phone"
4. New format: `"Predictive CP501895 called 081318023828"` → no ")" found
5. Regex matches entire string "Predictive CP501895 called 081318023828"
6. `substr(...,2,100)` removes "P" → "redictive CP501895 called 081318023828"

**Our Solution**: Use existing `phone_type` column (already clean)

**Recommendation**: Report to DL team for fix

---

### Issue 5: Activity-Based vs Unique Loan Counting

**Problem**: Confusion about loan count metrics

**Example**:
- Unique loans: 30,877
- Activity-based loan occurrences: 958,545

**Explanation**:
- Same loan can appear multiple times (different days/statuses)
- Activity-based: loan-status-day combinations
- Unique: `COUNT(DISTINCT deal_reference)`

**Solution**: Use appropriate metric based on analysis goal
- **Operational monitoring**: Activity-based (daily volume tracking)
- **Coverage analysis**: Unique loans (penetration metrics)

---

## Key Findings

### Finding 1: Collection System Outages

**5 Days with ZERO Collection Calls**:
| Date | Day of Week | Call Count | Notes |
|------|-------------|------------|-------|
| 2025-09-05 | Thursday | 0 | System outage |
| 2025-09-27 | Friday | 0 | System outage |
| 2025-09-28 | Saturday | 0 | System outage |
| 2025-10-05 | Saturday | 0 | System outage |
| 2025-10-19 | Saturday | 0 | System outage |

**3 Days with Abnormally Low Volume**:
| Date | Day of Week | Call Count | Expected | % Deviation |
|------|-------------|------------|----------|-------------|
| 2025-09-01 | Sunday | 1,247 | ~20,000 | -93.8% |
| 2025-09-20 | Friday | 3,891 | ~35,000 | -88.9% |
| 2025-09-21 | Saturday | 2,156 | ~15,000 | -85.6% |

**Business Impact**:
- 8 days of missed collection opportunities in 92-day period (8.7%)
- Estimated impact: 160,000-280,000 missed calls
- Likely contributing to lower PTP conversion and higher delinquency

**Recommended Actions**:
1. Root cause analysis with IT/vendor teams
2. Implement alerting system for daily call volume < threshold
3. Review weekend staffing and system availability SLAs

---

### Finding 2: Notification Read Rate Collapse

**Engagement Trend Analysis**:
| Period | Notifications Sent | READ | UNREAD | Read Rate |
|--------|-------------------|------|---------|-----------|
| Aug 2025 | 174,241 | 28,649 | 145,592 | **16.4%** |
| Sep 2025 | 153,228 | 14,719 | 138,509 | **9.6%** |
| Oct 2025 | 127,644 | 8,727 | 118,917 | **6.8%** |

**Key Metrics**:
- **51% decline** in read rate over 3 months (16.4% → 6.8%)
- Sent volume also declining: -26.8% (174k → 127k)
- Total notifications: 455,113

**Possible Root Causes**:
1. **Notification fatigue**: Customers ignoring repetitive messages
2. **Content relevance**: Generic messages not personalized
3. **Timing issues**: Messages sent at inconvenient times
4. **Technical**: App notification permissions being revoked
5. **Cohort effect**: Aug cohort more engaged than later cohorts

**Recommended Actions**:
1. A/B test message content and timing
2. Analyze READ vs UNREAD by customer segment (DPD, plafond, partner)
3. Review notification frequency caps
4. Implement personalization based on customer behavior
5. Track app notification permission status

---

### Finding 3: Missing DPD Notifications (Weekend Pattern)

**9 Days with NO DPD (Overdue) Notifications**:
```
2025-09-07 (Sunday)
2025-09-08 (Monday)  ← Weekend spillover?
2025-09-14 (Sunday)
2025-09-15 (Monday)  ← Weekend spillover?
2025-09-21 (Sunday)
2025-09-22 (Monday)  ← Weekend spillover?
2025-09-28 (Sunday)
2025-09-29 (Monday)  ← Weekend spillover?
2025-10-05 (Sunday)
```

**Pattern Analysis**:
- All Sundays missing DPD notifications
- Following Mondays also affected (4 out of 4 cases)
- Repayment reminder notifications still sent on these days
- Suggests scheduled job for DPD notifications not running on weekends

**Business Impact**:
- DPD customers not receiving timely overdue reminders
- May delay payment responses by 1-2 days
- Inconsistent customer experience

**Recommended Actions**:
1. Review notification scheduler configuration
2. Enable weekend DPD notification jobs
3. Consider backfilling missed notifications for Monday delivery
4. Implement monitoring alert for zero DPD notifications on any day

---

### Finding 4: Unusual Working Hours

**Off-Hours Collection Activity**:
| Time Window | Call Count | % of Total |
|-------------|------------|------------|
| 00:00-00:59 (Midnight) | 2,576 | 0.08% |
| 23:00-23:59 (11 PM) | 2,151 | 0.07% |
| 01:00-05:59 (Early morning) | 1,234 | 0.04% |

**Analysis**:
- 5,961 calls (0.19%) outside normal business hours (8 AM - 8 PM)
- Midnight calls highest volume
- Could be:
  - System tests
  - Timezone issues (UTC vs WIB confusion)
  - Automated IVR campaigns
  - Data quality issues (wrong timestamps)

**Recommended Actions**:
1. Validate if these are intentional (IVR) or data errors
2. Review timezone handling in data pipeline
3. If intentional, segment in reporting for clarity
4. If errors, investigate source system timestamp generation

---

### Finding 5: Channel Distribution Insights

**Collection Call Channel Mix** (Based on DL team's flag_channel):
| Channel | Call Count | % of Total | Avg Daily |
|---------|------------|------------|-----------|
| Predictive Dialer Call | 2,961,847 | 96.2% | 32,194 |
| Manual Call | 112,384 | 3.7% | 1,221 |
| IVR/Robocall | 2,891 | 0.09% | 31 |
| Whatsapp Long Number | 383 | 0.01% | 4 |

**Push Notification Type Mix**:
| Notification Type | Count | % of Total | Avg Daily |
|-------------------|-------|------------|-----------|
| push_dpd (Overdue) | 248,567 | 54.6% | 2,702 |
| push_reminder (Repayment) | 206,546 | 45.4% | 2,245 |

**Key Insights**:
- Heavy reliance on predictive dialer (96%)
- Manual calls rare (3.7%) - likely escalations or special cases
- WhatsApp barely used (0.01%) despite channel availability
- DPD notifications slightly more frequent than reminders

**Recommendations**:
1. Explore expanding WhatsApp usage (higher engagement potential)
2. Monitor predictive dialer system health closely (single point of failure)
3. Consider manual call increase for high-value delinquent accounts
4. Balance DPD vs reminder notification ratio based on effectiveness data

---

## Final Query Structure

### Complete SQL Query

```sql
WITH collection_base AS (
  SELECT
    CAST(date AS DATE) as activity_date,
    FORMAT_DATE('%Y%m', CAST(date AS DATE)) as period,
    UPPER(status) AS STATUS,

    -- DL Team's flag_number_active
    CASE
      WHEN TRIM(LOWER(status)) NOT IN (
        'broken promise','claim','agent error','abort','pickup','reassign',
        'skip trace','duplicate','scbr','invalid','auto busy',
        'ec - busy call','ec - no answer'
      ) THEN 1
      ELSE 0
    END as flag_number_active,

    -- DL Team's flag_answered
    CASE
      WHEN status IN ('PAYMENT PLAN','Left Message','Call Back','PTP - Reminder',
                      'UNDER NEGOTIATION','Voice Mail','WPC')
      THEN 1
      ELSE 0
    END as flag_answered,

    -- DL Team's flag_rpc (Right Party Contact)
    CASE
      WHEN status IN ('PAYMENT PLAN','Left Message','Call Back','PTP - Reminder',
                      'UNDER NEGOTIATION','Voice Mail','WPC')
        AND (person_contacted = 'RPC' OR person_contacted IS NULL)
      THEN 1
      ELSE 0
    END as flag_rpc,

    -- DL Team's flag_tpc (Third Party Contact)
    CASE
      WHEN status IN ('PAYMENT PLAN','Left Message','Call Back','PTP - Reminder',
                      'UNDER NEGOTIATION','Voice Mail','WPC')
        AND person_contacted = 'TPC'
      THEN 1
      ELSE 0
    END as flag_tpc,

    -- DL Team's flag_ptp (Promise to Pay)
    CASE
      WHEN status IN ('PAYMENT PLAN','PTP - Reminder')
      THEN 1
      ELSE 0
    END as flag_ptp,

    -- DL Team's flag_channel
    CASE
      WHEN campaign_name LIKE '%IVR%' THEN 'IVR/Robocall'
      WHEN status LIKE '%WA -%' THEN 'Whatsapp Long Number'
      WHEN campaign_name IS NOT NULL THEN 'Predictive Dialer Call'
      WHEN campaign_name IS NULL THEN 'Manual Call'
    END as flag_channel,

    -- Original category_status for backward compatibility
    CASE
      WHEN status IN ('PAID', 'PTP', 'PTP - Reminder', 'PAYMENT PLAN', 'RENCANA PEMBAYARAN',
                      'Request for payment plan', 'Plan Approved', 'Broken Promise')
      THEN 'commitment_payment'

      WHEN status IN ('No Answer', 'EC - No answer', 'No Answer AutoDial',
                      'Busy Auto', 'Auto Busy', 'EC - Busy call', 'Busy',
                      'Call Rejected', 'Voice Mail', 'Voice Message Prompt',
                      'Dropped', 'DROP CALL', 'Outbound Local Channel Res Error',
                      'Outbound Pre-Routing Drop', 'ABORT', 'SCBR')
      THEN 'unsuccessful_call'

      WHEN status IN ('Call Back', 'Left Message', 'UNDER NEGOTIATION', 'RTP', 'WPC', 'Pickup')
      THEN 'successful_contact_no_commitment'

      WHEN status IN ('invalid', 'Resign / Moved', 'Skip Trace', 'Duplicate', 'Claim')
      THEN 'data_information'

      WHEN status IN ('NEW', 'TRANSFER', 'REASSIGN', 'ACTIVATE', 'Agent Error')
      THEN 'workflow'

      WHEN status IN ('WA - Sent', 'WA - Read')
      THEN 'whatsapp_notification'

      WHEN status IN ('Complaint - Behavior', 'Complaint - Vulnerable')
      THEN 'complaint_escalation'

      ELSE 'other'
    END AS CATEGORY_STATUS,

    CASE
      WHEN dpd > 0 THEN 'YES'
      ELSE 'NO'
    END as IS_DPD,

    'Collection_Call' as ACTIVITY_TYPE,

    collector,
    card_no as loan_reference,
    person_contacted,
    phone_type,

    -- Fixed time parsing for dual format handling
    CASE
      WHEN LENGTH(time) = 22 THEN CAST(time AS TIMESTAMP)
      WHEN LENGTH(time) = 8 THEN TIMESTAMP(CONCAT(CAST(date AS STRING), ' ', time))
      ELSE NULL
    END as parsed_timestamp

  FROM `jago-bank-data-production.digital_lending.digital_lending_collection_daily_report_vendor`
  WHERE business_date >= '2025-08-01'
    AND business_date <= CURRENT_DATE()
    AND card_no IS NOT NULL
),

notification_base AS (
  SELECT
    CAST(notification_created_at AS DATE) as activity_date,
    FORMAT_DATE('%Y%m', CAST(notification_created_at AS DATE)) as period,

    UPPER(notification_status) AS STATUS,

    -- Notifications always "active"
    1 as flag_number_active,

    -- Notifications count as "answered" if READ
    CASE WHEN notification_status = 'READ' THEN 1 ELSE 0 END as flag_answered,
    CASE WHEN notification_status = 'READ' THEN 1 ELSE 0 END as flag_rpc,

    -- Notifications cannot be TPC or PTP
    0 as flag_tpc,
    0 as flag_ptp,

    'Push_Notification' as flag_channel,

    -- Notification category mapping
    CASE
      WHEN notification_code = 'Notification_DL_Repayment_Reminder' THEN 'push_reminder'
      WHEN notification_code = 'Notification_DL_Overdue_BELL_PUSH_Reminder' THEN 'push_dpd'
    END AS CATEGORY_STATUS,

    CASE
      WHEN notification_code = 'Notification_DL_Overdue_BELL_PUSH_Reminder' THEN 'YES'
      ELSE 'NO'
    END as IS_DPD,

    'Push_Notification' as ACTIVITY_TYPE,

    CAST(NULL as STRING) as collector,
    REGEXP_EXTRACT(deep_link, r'accountId=(\d+)') AS loan_reference,
    CAST(NULL as STRING) as person_contacted,
    CAST(NULL as STRING) as phone_type,

    notification_created_at as parsed_timestamp

  FROM `jago-bank-data-production.dwh_core.notification_current`
  WHERE notification_code IN (
    'Notification_DL_Repayment_Reminder',
    'Notification_DL_Overdue_BELL_PUSH_Reminder'
  )
    AND CAST(notification_created_at AS DATE) >= '2025-08-01'
    AND CAST(notification_created_at AS DATE) <= CURRENT_DATE()
),

combined_data AS (
  SELECT * FROM collection_base
  UNION ALL
  SELECT * FROM notification_base
)

SELECT
  activity_date as call_date,
  period,
  STATUS,
  IS_DPD,
  flag_channel as CHANNEL,
  CATEGORY_STATUS,
  ACTIVITY_TYPE,

  -- Aggregated metrics
  COUNT(*) as CALLS_COUNTS,
  COUNT(DISTINCT collector) as COLLECTOR_COUNTS,
  COUNT(DISTINCT loan_reference) as LOAN_COUNTS,

  -- DL Team's flag metrics (summed)
  SUM(flag_number_active) as ACTIVE_NUMBER_CALLS,
  SUM(flag_answered) as ANSWERED_CALLS,
  SUM(flag_rpc) as RPC_CALLS,
  SUM(flag_tpc) as TPC_CALLS,
  SUM(flag_ptp) as PTP_CALLS,

  -- Time metrics
  FORMAT_TIMESTAMP('%H:%M:%S', MIN(parsed_timestamp)) as min_time,
  FORMAT_TIMESTAMP('%H:%M:%S', MAX(parsed_timestamp)) as max_time,

  -- Extra analysis fields
  FORMAT_DATE('%A', activity_date) as day_of_week

FROM combined_data
WHERE loan_reference IS NOT NULL
GROUP BY call_date, period, STATUS, IS_DPD, CHANNEL, CATEGORY_STATUS, ACTIVITY_TYPE
ORDER BY call_date, ACTIVITY_TYPE, STATUS;
```

### Query Output Schema

| Column | Type | Description | Example |
|--------|------|-------------|---------|
| call_date | DATE | Activity date | 2025-09-15 |
| period | STRING | Year-month | 202509 |
| STATUS | STRING | Call/notification status | PAYMENT PLAN, READ, UNREAD |
| IS_DPD | STRING | Days past due flag | YES, NO |
| CHANNEL | STRING | Communication channel | Predictive Dialer Call, Push_Notification |
| CATEGORY_STATUS | STRING | Grouped status category | commitment_payment, push_reminder |
| ACTIVITY_TYPE | STRING | Source system | Collection_Call, Push_Notification |
| CALLS_COUNTS | INTEGER | Total activities | 1,247 |
| COLLECTOR_COUNTS | INTEGER | Unique collectors (NULL for notifications) | 45 |
| LOAN_COUNTS | INTEGER | Unique loans contacted | 892 |
| ACTIVE_NUMBER_CALLS | INTEGER | Active number flag sum | 1,150 |
| ANSWERED_CALLS | INTEGER | Answered flag sum | 234 |
| RPC_CALLS | INTEGER | Right party contact sum | 198 |
| TPC_CALLS | INTEGER | Third party contact sum | 36 |
| PTP_CALLS | INTEGER | Promise to pay sum | 89 |
| min_time | STRING | Earliest activity time | 08:15:32 |
| max_time | STRING | Latest activity time | 20:45:18 |
| day_of_week | STRING | Day name | Monday |

---

## Recommendations

### 1. Operational Monitoring (High Priority)

**Implement Daily Alerting System**:
```sql
-- Daily health check query
SELECT
  activity_date,
  ACTIVITY_TYPE,
  COUNT(*) as daily_count,
  CASE
    WHEN ACTIVITY_TYPE = 'Collection_Call' AND COUNT(*) < 10000 THEN 'ALERT: Low volume'
    WHEN ACTIVITY_TYPE = 'Push_Notification' AND COUNT(*) = 0 THEN 'ALERT: No notifications'
    WHEN COUNT(*) = 0 THEN 'CRITICAL: Zero activity'
    ELSE 'OK'
  END as health_status
FROM [combined_data]
WHERE activity_date = CURRENT_DATE() - 1
GROUP BY activity_date, ACTIVITY_TYPE
```

**Alerting Thresholds**:
- Collection calls < 10,000/day → Low volume alert
- Collection calls = 0 → Critical system outage
- Push notifications = 0 → Notification system failure
- DPD notifications = 0 on weekday → Scheduler issue

---

### 2. Notification Optimization (High Priority)

**A/B Testing Framework**:
1. **Content variations**: Test personalized vs generic messages
2. **Timing experiments**: Morning (8-10 AM) vs evening (6-8 PM) vs optimal per customer
3. **Frequency caps**: Test 1/day vs 2/day vs 3/day for DPD customers

**Engagement Analysis**:
```sql
-- Deep dive: What drives READ notifications?
SELECT
  CATEGORY_STATUS,
  IS_DPD,
  EXTRACT(HOUR FROM parsed_timestamp) as send_hour,
  COUNT(*) as sent_count,
  SUM(CASE WHEN STATUS = 'READ' THEN 1 ELSE 0 END) as read_count,
  ROUND(100.0 * SUM(CASE WHEN STATUS = 'READ' THEN 1 ELSE 0 END) / COUNT(*), 2) as read_rate_pct
FROM notification_base
GROUP BY CATEGORY_STATUS, IS_DPD, send_hour
ORDER BY read_rate_pct DESC
```

---

### 3. Data Quality Improvements (Medium Priority)

**Time Field Standardization**:
- Work with vendor to eliminate dual format issue
- Target: 100% of records in full timestamp format
- Timeline: Next system upgrade

**Phone Type Regex Fix**:
- Report bug to DL team: `substr(REGEXP_SUBSTR(remark, '[^)]+'),2,100)`
- Recommended fix: Use `phone_type` column directly
- Impact: Improves accuracy of channel analysis

**Timezone Validation**:
- Audit off-hours calls (midnight, 11 PM)
- Verify if UTC vs WIB conversion applied correctly
- Document timezone handling in data pipeline

---

### 4. Weekend Coverage (Medium Priority)

**DPD Notification Scheduler**:
- Enable weekend DPD notification jobs
- Implement Monday backfill for Sunday missed notifications
- Target SLA: 100% coverage 7 days/week

**Weekend Collection Staffing**:
- Analyze Saturday/Sunday delinquency patterns
- Consider pilot weekend collection campaigns
- Compare cost/benefit vs weekday-only operations

---

### 5. Channel Expansion (Low Priority)

**WhatsApp Utilization**:
- Currently: 0.01% of calls (383 activities)
- Opportunity: Higher engagement than push notifications
- Recommendation: Pilot program for 1,000 high-DPD accounts
- Success metric: Response rate > 15%

**IVR/Robocall Optimization**:
- Currently: 0.09% of calls (2,891 activities)
- Use case: Pre-collection reminders (DPD 1-3)
- Lower cost than human agents
- Track IVR → human agent escalation rate

---

### 6. Reporting Enhancements

**Recommended Pivot Tables for Weekly Review**:

1. **System Health Dashboard** (Daily aggregation)
   - Rows: activity_date, day_of_week
   - Columns: ACTIVITY_TYPE
   - Values: CALLS_COUNTS, LOAN_COUNTS
   - Conditional formatting: Red if count = 0

2. **Notification Engagement Trend** (Weekly aggregation)
   - Rows: period (year-month-week)
   - Columns: STATUS (READ vs UNREAD)
   - Values: % read_rate
   - Chart: Line chart showing trend

3. **Channel Effectiveness** (Monthly aggregation)
   - Rows: CHANNEL
   - Columns: CATEGORY_STATUS
   - Values: PTP_CALLS, ANSWERED_CALLS
   - Calculated field: PTP rate = PTP_CALLS / ANSWERED_CALLS

4. **Weekend Coverage Gap Analysis**
   - Filter: day_of_week IN ('Saturday', 'Sunday')
   - Rows: activity_date
   - Columns: IS_DPD, ACTIVITY_TYPE
   - Values: CALLS_COUNTS
   - Highlight: Zero-activity days in red

5. **Hourly Activity Heatmap**
   - Rows: EXTRACT(HOUR FROM min_time)
   - Columns: day_of_week
   - Values: SUM(CALLS_COUNTS)
   - Visualization: Heatmap (identify off-hours activity)

---

## Appendix A: Validation Queries

### A1. Data Freshness Check
```sql
SELECT
  MAX(business_date) as latest_collection_date,
  MAX(CAST(notification_created_at AS DATE)) as latest_notification_date
FROM `jago-bank-data-production.digital_lending.digital_lending_collection_daily_report_vendor`,
     `jago-bank-data-production.dwh_core.notification_current`
```

### A2. Time Format Distribution
```sql
SELECT
  LENGTH(time) as time_length,
  COUNT(*) as record_count,
  ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) as pct,
  MIN(time) as sample_min,
  MAX(time) as sample_max
FROM `jago-bank-data-production.digital_lending.digital_lending_collection_daily_report_vendor`
WHERE business_date >= '2025-08-01'
GROUP BY time_length
ORDER BY record_count DESC
```

### A3. Notification Extraction Success Rate
```sql
SELECT
  COUNT(*) as total_notifications,
  COUNTIF(REGEXP_EXTRACT(deep_link, r'accountId=(\d+)') IS NULL) as null_extractions,
  COUNTIF(REGEXP_EXTRACT(deep_link, r'accountId=(\d+)') IS NOT NULL) as successful_extractions,
  ROUND(100.0 * COUNTIF(REGEXP_EXTRACT(deep_link, r'accountId=(\d+)') IS NOT NULL) / COUNT(*), 2) as success_rate_pct
FROM `jago-bank-data-production.dwh_core.notification_current`
WHERE notification_code IN (
  'Notification_DL_Repayment_Reminder',
  'Notification_DL_Overdue_BELL_PUSH_Reminder'
)
  AND CAST(notification_created_at AS DATE) >= '2025-08-01'
```

### A4. Zero-Activity Day Detection
```sql
WITH daily_totals AS (
  SELECT
    activity_date,
    ACTIVITY_TYPE,
    COUNT(*) as daily_count
  FROM [combined_data]
  GROUP BY activity_date, ACTIVITY_TYPE
)
SELECT
  activity_date,
  FORMAT_DATE('%A', activity_date) as day_of_week,
  COALESCE(SUM(CASE WHEN ACTIVITY_TYPE = 'Collection_Call' THEN daily_count ELSE 0 END), 0) as collection_calls,
  COALESCE(SUM(CASE WHEN ACTIVITY_TYPE = 'Push_Notification' THEN daily_count ELSE 0 END), 0) as push_notifications
FROM daily_totals
WHERE collection_calls = 0 OR push_notifications = 0
ORDER BY activity_date
```

---

## Appendix B: Glossary

| Term | Definition |
|------|------------|
| **ACTIVITY_TYPE** | Distinguishes Collection_Call vs Push_Notification in combined dataset |
| **business_date** | Partition/load date in collection table (use for filtering, not analysis) |
| **CATEGORY_STATUS** | Grouped status categorization (commitment_payment, unsuccessful_call, push_reminder, etc.) |
| **date** | Actual call timestamp in collection table (STRING type - must CAST to DATE) |
| **DPD** | Days Past Due - number of days since payment missed |
| **flag_answered** | Binary flag: Call was answered (1) or not (0) |
| **flag_channel** | Communication channel: Predictive Dialer, Manual Call, IVR, WhatsApp, Push Notification |
| **flag_number_active** | Binary flag: Number is active/callable (1) vs inactive (0) |
| **flag_ptp** | Binary flag: Promise to Pay obtained (1) or not (0) |
| **flag_rpc** | Binary flag: Right Party Contact - customer answered (1) or not (0) |
| **flag_tpc** | Binary flag: Third Party Contact - someone else answered (1) or not (0) |
| **IS_DPD** | String flag: 'YES' if DPD > 0, 'NO' otherwise |
| **loan_reference** | 14-digit deal_reference for linking calls and notifications |
| **notification_code** | System code: Notification_DL_Repayment_Reminder or Notification_DL_Overdue_BELL_PUSH_Reminder |
| **parsed_timestamp** | Standardized TIMESTAMP handling dual format issue (22-char vs 8-char) |
| **RPC** | Right Party Contact - customer directly answered |
| **STATUS** | Raw call outcome or notification status (45+ values for calls, READ/UNREAD for notifications) |
| **TPC** | Third Party Contact - someone other than customer answered |

---

## Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-28 | Credit Risk Intern | Initial documentation of unified monitoring system |

---

## Related Documentation

- `Collection_Score_Multi_Channel_Analysis_Technical_Wiki.md` - Phase 2 feature engineering
- `Collection_Score_Feature_Engineering_Technical_Wiki.md` - Critical bug fixes (due date, customer flags)
- `Notification_Push_Aggregation_Technical_Wiki.md` - Original notification analysis
- `Collection_Effectiveness_Analysis_Technical_Documentation.md` - Payment outcome analysis
- `Collection_Call_Timing_Analysis_Technical_Wiki.md` - Temporal pattern analysis

---

**End of Document**
