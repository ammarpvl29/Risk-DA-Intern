# Customer Journey + Notification Analysis - Combined Technical Wiki

## Table of Contents
- [Overview](#overview)
- [Business Context](#business-context)
- [Data Architecture](#data-architecture)
- [Query Implementation](#query-implementation)
- [Key Findings](#key-findings)
- [Case Study Analysis](#case-study-analysis)
- [Known Limitations](#known-limitations)
- [Next Steps](#next-steps)
- [References](#references)

---

## Overview

**Project Name**: Acquisition Dashboard - Customer Journey & Notification Effectiveness Analysis
**Date**: 2025-10-04
**Analyst**: Ammar Siregar (Risk Data Analyst Intern)
**Stakeholders**: Kak Zaki (Product Analytics), Bang Subhan (Mentor)
**Purpose**: Combined analysis of customer journey behavior and notification channel effectiveness

### Objectives

1. **Understand Customer Journey**: Track user interactions from loan offer to disbursement across 7 stages
2. **Measure Notification Effectiveness**: Compare 5 notification channels (WhatsApp, Push, Bell, In-App, Email)
3. **Identify System Issues**: Detect notification delays and CleverTap event capture gaps
4. **Support Acquisition Dashboard**: Provide data foundation for business stakeholder reporting

### Analysis Approach

**Three-Step Workflow** (per mentor's guidance):
1. **Step 1**: Process CleverTap detailed event data (journey stages)
2. **Step 2**: Process notification aggregated data (channel metrics)
3. **Step 3**: Combine datasets for integrated analysis (X₁N + Y₁N → Combined)

**Key Principle**: "Jangan sampai ketimpa" (Don't overwrite data)
- Save each step's output before proceeding
- Enables debugging without re-running expensive queries
- Maintains data audit trail

---

## Business Context

### Customer Journey Stages (7 Stages)

Based on Kak Zaki's CleverTap event mapping:

| Stage # | Stage Name | Description | Key Events | Business Meaning |
|---------|------------|-------------|------------|------------------|
| 1 | **Entry** | Initial DL feature access | `CLICK_DL_entry_home_*` | Customer awareness |
| 2 | **Loan Hub** | Dashboard with offers | `INIT_DL_inquiry_dashboard` | Interest confirmation |
| 3 | **Landing** | Loan offer landing page | `INIT_DL_draw_landing` | Offer consideration |
| 4 | **Drawdown** | Amount/duration selection | `TEXT_DL_draw_drawdown_amount` | Active configuration |
| 5 | **Confirmation** | Review loan details | `INIT_DL_draw_confirm` | Pre-commitment review |
| 6 | **PII** | Personal info collection | `INIT_DL_draw_pii` | Formal application |
| 7 | **Agreement** | Terms acceptance | `RDIO_DL_draw_agreement_accept` | Commitment |

**Journey Window**: `created_at` (offer creation) → `start_date` (disbursement)

**Important Update** (2025-10-04):
- Changed upper bound from `agreement_agreed_at` to `start_date`
- **Reason**: Captures events ON disbursement date (last-minute decisions)
- **Impact**: More accurate journey tracking for fast executors

---

### Notification Channels (5 Channels)

| Channel | Campaign Type | Sent Event | Click Event | Coverage |
|---------|---------------|------------|-------------|----------|
| **WhatsApp** | External blast | `SentAt` | `ReadAt` | ~High (direct to phone) |
| **Push Notif** | Mobile Push | `*_SENT` | `*_CLICK` | Medium (requires app install) |
| **Bell Notif** | App Inbox | `*_SENT` | `*_CLICK` | Medium (requires app login) |
| **In-App** | InApp | `*_VIEWED` | `*_CLICKED` | Low (requires active session) |
| **Email** | Email | `*_VIEWED` | `*_CLICKED` | Low (email engagement low) |

**Business Questions**:
1. Which channel drives most conversions?
2. Are notifications arriving on time?
3. Do customers respond to multiple channels or single channel?
4. What's the time lag between notification and customer action?

---

## Data Architecture

### Source Tables

#### 1. Customer Loan Details (Base)
```
Table: data-prd-adhoc.temp_ammar.ammar_customer_loan_details
Type: Snapshot table (business_date partitioned)

Key Fields:
  customer_id (STRING): Unique customer identifier
  business_date (DATE): Snapshot date (2025-07-31 for July analysis)
  created_at (DATE): Loan offer creation date
  expires_at (DATE): Offer expiration date
  start_date (DATE): Loan facility start (disbursement)
  agreement_agreed_at (TIMESTAMP): Agreement acceptance timestamp
  flag_takeup (INTEGER): 1 = successful disbursement
  is_new_offer (INTEGER): 1 = new customer offer
  is_carry_over_offer (INTEGER): 1 = repeat customer offer
  flag_has_facility (INTEGER): 1 = customer has active facility
```

#### 2. CleverTap User Events (Journey Data)
```
Table: jago-bank-data-production.risk_datamart.clevertap_user_events
Type: Partitioned by DATE(time)

Key Fields:
  customer_id (STRING): Links to loan details
  time (TIMESTAMP): Event occurrence timestamp
  event_name (STRING): Specific user action
  session_id (STRING): Session identifier

Partition Filter Required: DATE(time) BETWEEN '2025-01-01' AND '2025-08-31'
```

#### 3. Journey Notifications (CleverTap Channels)
```
Table: jago-bank-data-production.jago_clevertap.journey_notifications
Type: Event log

Key Fields:
  customer_id (STRING): Links to loan details
  event_date (DATE): Notification event date
  event_ts (TIMESTAMP): Notification event timestamp
  event_name (STRING): Notification action (SENT, VIEWED, CLICK, CLICKED)
  campaign_name (STRING): Campaign identifier
  campaign_type (STRING): Channel type (Push, InApp, Email, etc.)
  journey_id (INTEGER): Journey identifier
```

#### 4. WhatsApp Blast Results (External Channel)
```
Table: jago-data-sandbox.temp_digital_lending.gtm_whatsapp_blast_result
Type: External notification log

Key Fields:
  customer_id (STRING): Links to loan details
  TemplateName (STRING): WhatsApp template used
  SentAt (TIMESTAMP): When WhatsApp was sent
  ReadAt (TIMESTAMP): When customer read message
  DeliveredAt (TIMESTAMP): Delivery confirmation
  Status (STRING): Delivery status

UNPIVOT Pattern: Transform SentAt/ReadAt columns into rows for consistency
```

---

### Data Flow Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ STEP 1: CleverTap Journey Events                           │
├─────────────────────────────────────────────────────────────┤
│ base_customer (2 customers)                                 │
│         ↓                                                   │
│ INNER JOIN clevertap_user_events                           │
│         ↓                                                   │
│ events_stage (CASE mapping to 7 stages)                    │
│         ↓                                                   │
│ GROUP BY customer → Aggregate event counts & timestamps    │
│         ↓                                                   │
│ OUTPUT: clevertap_journey (21 columns per customer)        │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ STEP 2: Notification Channel Metrics                       │
├─────────────────────────────────────────────────────────────┤
│ base_customer (2 customers)                                 │
│         ↓                                                   │
│ ┌──────────────────┐        ┌──────────────────┐          │
│ │ notifications    │        │ wa_unpivoted     │          │
│ │ (Push/Bell/      │        │ (WhatsApp from   │          │
│ │  InApp/Email)    │        │  external table) │          │
│ └──────────────────┘        └──────────────────┘          │
│         ↓                            ↓                      │
│         └────────── UNION ALL ───────┘                     │
│                      ↓                                      │
│         all_notifications (5 channels combined)            │
│                      ↓                                      │
│ GROUP BY customer → Aggregate sent/click counts & dates    │
│                      ↓                                      │
│ OUTPUT: notification_summary (24 columns per customer)     │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│ STEP 3: Combined Analysis (Script Adjustment)              │
├─────────────────────────────────────────────────────────────┤
│ clevertap_journey (from Step 1)                            │
│         ↓                                                   │
│ LEFT JOIN notification_summary (from Step 2)              │
│         ↓                                                   │
│ OUTPUT: Combined view (45+ columns per customer)           │
│         Journey metrics + Notification metrics             │
└─────────────────────────────────────────────────────────────┘
```

---

## Query Implementation

### Step 1: CleverTap Journey Aggregation

**Purpose**: Capture detailed customer interaction patterns across 7 journey stages

**Key Technical Decisions**:
1. **Time Window**: `DATE(ct.time) >= bc.created_at AND DATE(ct.time) <= bc.start_date`
   - **Critical Change** (2025-10-04): Changed from `< bc.start_date` to `<= bc.start_date`
   - **Reason**: Captures same-day facility events (fast executors)
   - **Example**: Customer 0017267841 had 12 entry events ON 2025-07-29 (facility date)

2. **Event Filtering**: `ct.event_name LIKE '%DL%'`
   - Focuses on Direct Lending events only
   - Excludes other product events (savings, investment, etc.)

3. **Partition Range**: `DATE(time) BETWEEN '2025-01-01' AND '2025-08-31'`
   - Broad range captures complete journeys
   - Extends to August for early-month disbursements

**Query Structure**:
```sql
WITH base_customer AS (
  -- Filter to 2 case study customers
  SELECT * FROM ammar_customer_loan_details
  WHERE customer_id IN ('0017267841', '0087287778')
    AND flag_takeup = 1
    AND is_new_offer = 1
),
clevertap_events AS (
  -- Join CleverTap events within journey window
  -- KEY FIX: DATE(ct.time) <= bc.start_date (includes facility date)
),
events_stage AS (
  -- Map 58 event types to 7 stages via CASE statement
),
-- Aggregate: event counts + latest timestamps + time differences
SELECT
  customer_id,
  total_entry, total_loan_hub, ..., total_agreement,
  latest_entry_timestamp, ..., latest_agreement_timestamp,
  diff_agree_created, ..., diff_agree_pii
FROM base_customer
LEFT JOIN events_stage
GROUP BY customer_id;
```

**Output Schema** (21 columns):
- 5 general info: business_date, customer_id, created_at, expiry_date, facility_date
- 7 event counts: total_entry, total_loan_hub, ..., total_agreement
- 7 timestamps: latest_entry_timestamp, ..., latest_agreement_timestamp
- 7 time diffs: diff_agree_created, ..., diff_agree_pii

---

### Step 2: Notification Channel Aggregation

**Purpose**: Measure notification delivery and engagement across 5 channels

**Key Technical Decisions**:
1. **Channel Normalization**:
   ```sql
   CASE
     WHEN campaign_type IN ('Mobile Push - Android', 'Mobile Push - iOS', 'Push') THEN 'Push Notif'
     WHEN campaign_type IN ('App Inbox', 'NotificationInbox') THEN 'Bell Notif'
     WHEN campaign_type = 'InApp' THEN 'In-App'
     WHEN campaign_type = 'Email' THEN 'Email'
   END AS comms_type
   ```

2. **Interaction Classification**:
   ```sql
   CASE
     WHEN UPPER(event_name) LIKE '%SENT%' THEN 'Sent'
     WHEN campaign_type = 'InApp' AND UPPER(event_name) LIKE '%VIEWED%' THEN 'Sent'
     WHEN UPPER(event_name) LIKE '%CLICK%' THEN 'Click'
   END AS interaction
   ```

3. **WhatsApp UNPIVOT**:
   ```sql
   UNPIVOT(event_date FOR event_name IN (
     SentAt AS 'Sent',
     ReadAt AS 'Read'
   ))
   ```
   - Transforms columns → rows for consistency with CleverTap format

**Query Structure**:
```sql
WITH offer AS (
  -- Base customer filter
),
notifications AS (
  -- CleverTap channels (Push, Bell, InApp, Email)
  -- Normalize campaign_type → comms_type
  -- Classify event_name → interaction (Sent/Click)
),
wa_unpivoted AS (
  -- WhatsApp external table
  -- UNPIVOT SentAt/ReadAt → event_name
),
all_notifications AS (
  -- UNION ALL: Combine CleverTap + WhatsApp
),
-- Aggregate per channel: sent count, click count, first date, last date
SELECT
  customer_id,
  push_sent_count, push_click_count, push_first_date, push_last_date,
  bell_sent_count, ...,
  inapp_sent_count, ...,
  email_sent_count, ...,
  wa_sent_count, ...
FROM offer
LEFT JOIN all_notifications
GROUP BY customer_id;
```

**Output Schema** (24 columns):
- 9 general info: business_date, customer_id, created_at, expires_at, start_date, flag_has_facility, flag_takeup, is_new_offer, is_carry_over_offer
- 20 notification metrics: 4 metrics × 5 channels (sent_count, click_count, first_date, last_date)

---

### Step 3: Combined Analysis (Final Query)

**Purpose**: Join CleverTap journey + Notification metrics for integrated view

**Critical Implementation Note**:
> "Run this ONLY after Step 1 and Step 2 outputs are saved"
> - Mentor's guidance: "Jangan sampai ketimpa" (Don't overwrite intermediate data)

**Query Structure**:
```sql
-- Reuse Step 1 query as CTE: clevertap_journey
-- Reuse Step 2 query as CTE: notification_summary

SELECT
  cj.*,  -- All 21 CleverTap journey columns
  ns.push_sent_count,
  ns.push_click_count,
  ns.push_first_date,
  ns.push_last_date,
  -- ... all 20 notification metrics
FROM clevertap_journey cj
LEFT JOIN notification_summary ns ON cj.customer_id = ns.customer_id
ORDER BY cj.customer_id;
```

**Output Schema** (45 columns):
- 21 from CleverTap journey
- 24 from notification summary (9 overlap with journey → dedupe in SELECT)
- Final: ~45 unique columns per customer

---

## Key Findings

### Discovery 1: Notification Delay Issue (Customer 0017267841)

**Timeline Analysis**:
```
2025-07-02: Offer created (created_at)
2025-07-11: WhatsApp sent (9 days after offer) ✅
2025-07-26: WhatsApp read by customer ✅
2025-07-29: Loan disbursed (facility_date) ✅
2025-07-30: Bell notification sent (1 day AFTER disbursement) ❌
2025-08-19: Push notification sent (48 days AFTER offer, 21 days AFTER disbursement) ❌
```

**Journey Data**:
```
Total Events: 12 entry, 40 loan hub, 2 landing, 13 drawdown, 2 confirmation, 2 pii, 4 agreement
Latest Entry: 2025-07-29 23:33:55 (ON facility date - captured due to <= fix)
Latest Hub: 2025-07-29 23:34:37 (same day as facility)
```

**Analysis**:
- ✅ Customer responded to **WhatsApp** (only timely notification)
- ❌ Push and Bell notifications arrived **after loan was already disbursed**
- ✅ Customer completed loan despite in-app notification failure
- 📊 Journey events captured on facility date (validates `<= start_date` fix)

**Business Impact**:
- WhatsApp proved critical backup channel
- In-app notification system has timing issues
- Customer succeeded via alternative path

**Reported to**: Kak Zaki (2025-10-04) via Slack

---

### Discovery 2: High Engagement Pattern (Customer 0087287778)

**Timeline Analysis**:
```
2025-07-02: Offer created
2025-07-05: Push notification sent (3 days after offer) ✅
2025-07-05: Bell notification sent (3 days after offer) ✅
2025-07-05: Customer entered app (same day as notifications) ✅
2025-07-31: Loan disbursed
```

**Journey Data**:
```
Total Events: 31 entry, 130 loan hub, 16 landing, 151 drawdown, 15 confirmation, 3 pii, 4 agreement
Latest Entry: 2025-07-31 13:19:13 (facility date)
Latest Hub: 2025-07-31 13:20:02 (facility date)
```

**Notification Data**:
```
Push: 24 sent, 2 clicks
Bell: 19 sent, 12 clicks
In-App: 9 sent, 7 clicks
WhatsApp: 0 sent
Email: 0 sent
```

**Analysis**:
- ✅ In-app notifications sent on time (3 days after offer)
- ✅ High engagement: 130 loan hub events, 151 drawdown events
- ✅ Customer actively explored loan options over 29 days
- ⚠️ No WhatsApp sent (different strategy for this segment?)
- 📊 Journey tracked up to facility date (last-minute activity captured)

**Customer Profile**: "Long Thinker, Fast Executor"
- 29 days from created to facility (consideration period)
- High exploration activity (130 loan hub visits)
- Multiple notification interactions (12 bell clicks)

---

### Discovery 3: CleverTap Event Loss (Expected Behavior)

**Context**: Customer 0017267841 previously showed zero events in 100-sample analysis

**After Query Fix** (`<= start_date`):
```
Previous (< start_date): 0 events captured
Current (<= start_date): 12 entry, 40 loan hub, 2 landing, 13 drawdown, etc.
```

**Root Cause**: Events occurred **ON facility date** (2025-07-29), previously excluded by `< start_date` filter

**Validation from Kak Zaki** (2025-10-02):
> "CleverTap ngga capture semua event, ada loss event nya, jadi masih OK kok data nya. Kemungkinan user2 gini tuh ngga ke generate clevertapid nya, jadi event inapp gak ada yg ke record/cuma ke record sebagian. Its normal kok."

**Business Implication**:
- CleverTap event loss is **system limitation, not data issue**
- 36% of customers show zero/minimal events (from 100-sample analysis)
- Alternative entry points exist (push notification → direct UVP page, bypassing loan hub)
- Journey metrics represent **trackable interactions only**, not complete customer journey

---

## Case Study Analysis

### Comparative Summary

| Metric | Customer 0017267841 | Customer 0087287778 |
|--------|---------------------|---------------------|
| **Offer Created** | 2025-07-02 | 2025-07-02 |
| **Facility Date** | 2025-07-29 | 2025-07-31 |
| **Journey Duration** | 27 days | 29 days |
| **Total Journey Events** | 75 | 319 |
| **Primary Channel** | WhatsApp | In-App (Push/Bell) |
| **WhatsApp Sent** | ✅ Day 9 | ❌ Not sent |
| **Push Notif Sent** | ❌ Day 48 (LATE) | ✅ Day 3 |
| **Bell Notif Sent** | ❌ Day 28 (LATE) | ✅ Day 3 |
| **Entry Events** | 12 | 31 |
| **Loan Hub Events** | 40 | 130 |
| **Drawdown Events** | 13 | 151 |
| **Behavior Pattern** | Quick decision, WA-driven | Long exploration, in-app driven |

### Business Insights

**Multi-Channel Strategy Critical**:
- No single channel has 100% reliability
- WhatsApp serves as critical backup when in-app fails
- Different customer segments prefer different channels

**Notification Timing Matters**:
- 3-day delay (Customer 0087287778): ✅ Acceptable, customer engaged
- 48-day delay (Customer 0017267841): ❌ Unacceptable, but WhatsApp compensated

**Journey Patterns Vary**:
- Some customers decide quickly (low event counts)
- Some customers explore extensively (high loan hub engagement)
- Both patterns can lead to successful conversion

---

## Known Limitations

### 1. CleverTap Event Capture Gap

**Issue**: 36% of successful customers show zero CleverTap events

**Root Causes** (per Kak Zaki):
1. Missing `clevertap_id` generation (system limitation)
2. Push notification direct access (bypasses in-app tracking)
3. Inherent event loss in CleverTap system

**Impact on Analysis**:
- Journey metrics represent **trackable subset only**
- Cannot assume "zero events = no engagement"
- Cross-validate with disbursement success (ground truth)

**Mitigation**:
- Use LEFT JOIN (include all customers, even with zero events)
- Interpret absence of evidence ≠ evidence of absence
- Focus on customers WITH events for pattern analysis

---

### 2. Notification Time Window Ambiguity

**Challenge**: When should notification window close?

**Previous Approach**: `event_date < COALESCE(start_date, expires_at)`
- **Problem**: Excludes notifications sent after agreement but before disbursement

**Current Approach**: Removed strict upper bound, rely on data range filter
- **Trade-off**: May include post-disbursement notifications
- **Future Fix**: Add explicit validation `WHERE event_date <= start_date` in analysis layer

---

### 3. WhatsApp Data Source Separation

**Issue**: WhatsApp data in different table (`temp_digital_lending.gtm_whatsapp_blast_result`)

**Challenges**:
1. Different schema (requires UNPIVOT transformation)
2. Different event naming convention (SentAt/ReadAt vs SENT/CLICK)
3. External dependency (may have different data quality issues)

**Current Solution**: UNION ALL pattern to combine sources
- Normalize event naming before UNION
- Map `ReadAt` → `Click` for consistency

---

### 4. Period Field Extraction

**Not Applicable for Journey+Notification Analysis**:
- `period` field only relevant for propensity model scoring
- Not needed for customer journey tracking
- Removed from final combined query to reduce complexity

---

## Next Steps

### Immediate (Next 3 Days)

1. **Scale to Full Cohort**:
   - Remove `LIMIT` and `WHERE customer_id IN (...)` filters
   - Run on all July 2025 successful new offers (~100+ customers)
   - Validate notification delay issue prevalence

2. **Quantify Notification Delay**:
   - Calculate: % of customers affected by >7 day notification delay
   - Breakdown by channel (Push vs Bell vs In-App)
   - Create summary report for stakeholders

3. **Create Business Summary**:
   - Notification channel effectiveness ranking
   - Average time from notification to first entry
   - Channel-specific conversion rates

---

### Short-term (Next Week)

1. **Dashboard Data Preparation**:
   - Aggregate journey metrics by customer segment
   - Calculate stage drop-off rates (funnel analysis)
   - Prepare visualization-ready datasets

2. **Expand Analysis Scope**:
   - Compare New Offer vs Carry-Over customer patterns
   - Analyze failed takeup customers (flag_takeup = 0) for drop-off insights
   - Time-series analysis (journey duration trends)

3. **Stakeholder Presentation**:
   - Present to Zaki and Aldrics (business users)
   - "Window shopping" approach: show findings, discuss implications
   - Gather feedback for dashboard requirements

---

### Medium-term (Next 2 Weeks)

1. **Acquisition Dashboard Build**:
   - Define KPIs with business stakeholders
   - Create automated data refresh queries
   - Design dashboard UI/UX with visualization team

2. **Root Cause Investigation**:
   - Collaborate with engineering on notification delay issue
   - Test notification system for systematic failures
   - Propose fixes or backup channel strategy

3. **Documentation Handoff**:
   - Create operational runbook for dashboard maintenance
   - Document query dependencies and refresh schedules
   - Train business users on dashboard interpretation

---

## References

### Related Documentation
- `CleverTap_Journey_Analysis_Technical_Documentation.md` - Stage mapping and event definitions
- `Notification_Aggregation_Table_Documentation_20250926.md` - Notification channel logic
- `Data_Analysis_Flow_Guide_Bank_Jago.md` - SQL best practices (CTE structure, 3-step workflow)
- `CleverTap_Customer_Journey_Aggregation_Wiki.md` - Journey aggregation methodology

### Key Data Tables
- `data-prd-adhoc.temp_ammar.ammar_customer_loan_details` - Customer loan offers base
- `jago-bank-data-production.risk_datamart.clevertap_user_events` - User interaction events
- `jago-bank-data-production.jago_clevertap.journey_notifications` - Notification events (CleverTap)
- `jago-data-sandbox.temp_digital_lending.gtm_whatsapp_blast_result` - WhatsApp notifications

### Stakeholder Communication
- **Product Analytics**: Kak Zaki (CleverTap event mapping, notification delay investigation)
- **Mentorship**: Bang Subhan (3-step workflow, business validation)
- **Business Users**: Zaki, Aldrics (dashboard requirements, final stakeholders)

### Key Slack Discussions
- **2025-10-02**: CleverTap event loss explanation (Kak Zaki)
  - Confirmed 36% event loss is normal system behavior
  - Missing clevertap_id causes incomplete tracking
  - Push notification direct access bypasses in-app events

- **2025-10-04**: Customer 0017267841 notification delay report
  - 48-day push notification delay (after disbursement)
  - WhatsApp proved critical backup channel
  - Escalated for technical investigation

---

## Appendix A: Event Mapping Reference

### CleverTap Event Categories (58 Events → 7 Stages)

**Stage 1 - Entry** (4 events):
```
CLICK_DL_entry_home_spotlight
CLICK_DL_entry_home_shortcut
CLICK_DL_entry_more_menu
CLICK_DL_entry_bellnote_link
```

**Stage 2 - Loan Hub** (15 events):
```
INIT_DL_inquiry_dashboard
CLICK_DL_hub_overview
CLICK_DL_loanhub_seeloanoffer
[... 12 more events]
```

**Stage 3 - Landing** (3 events):
```
INIT_DL_draw_landing
CLICK_DL_draw_landing_faq
CLICK_DL_draw_landing_next
```

**Stage 4 - Drawdown** (10 events):
```
INIT_DL_draw_drawdown
TEXT_DL_draw_drawdown_amount
SLIDE_DL_draw_drawdown_duration
[... 7 more events]
```

**Stage 5 - Confirmation** (5 events):
```
INIT_DL_draw_confirm
CLICK_DL_draw_confirm_next
[... 3 more events]
```

**Stage 6 - PII** (3 events):
```
INIT_DL_draw_pii
CLICK_DL_draw_pii_next
CLICK_DL_draw_pii_back
```

**Stage 7 - Agreement** (5 events):
```
INIT_DL_draw_agreement
SCROLL_DL_draw_agreement_content
RDIO_DL_draw_agreement_accept
CLICK_DL_draw_agreement_next
CLICK_DL_draw_agreement_back
```

**Excluded - Open Market** (not relevant for July 2025):
```
INIT_underwriting_uvp
INIT_DL_underwriting_uvp
CLICK_underwriting_uvp_home
```

---

## Appendix B: Query Performance Notes

### Execution Times (Approximate)

| Query Component | Records Scanned | Execution Time | Cost |
|-----------------|-----------------|----------------|------|
| base_customer (2 customers) | ~3M | <1 sec | Negligible |
| clevertap_events (INNER JOIN) | ~500M | 15-30 sec | Low |
| notifications (INNER JOIN) | ~100M | 10-20 sec | Low |
| wa_unpivoted (INNER JOIN) | ~5M | 5-10 sec | Negligible |
| Combined query (Steps 1+2+3) | ~600M | 30-60 sec | Low-Medium |

**Optimization Tips**:
1. Always include partition filters (`DATE(time) BETWEEN ...`)
2. Filter to specific customers early (`WHERE customer_id IN (...)`)
3. Use INNER JOIN for required relationships (reduces dataset)
4. Save intermediate results as temp tables for large-scale analysis

---

## Appendix C: Known Edge Cases

### Case 1: Events After Agreement

**Example**: Customer 3667852930 (from 100-sample analysis)
```
Agreement: 2025-07-12 15:15:52
Latest Entry: 2025-07-26 16:21:41 (14 days AFTER agreement)
```

**Interpretation**: Customer returned to app post-agreement (not part of conversion journey)

**Handling**: Time difference calculations show negative values (expected)

---

### Case 2: Missing Loan Hub (Direct Access)

**Example**: Customer 4T6L4JV6AX (from 100-sample analysis)
```
Entry events: 1
Loan Hub events: 0
Landing events: 2
Drawdown events: 5
```

**Interpretation**: Push notification → direct UVP landing page, bypassed loan hub

**Validation**: Per Kak Zaki, this is valid flow for push notification clicks

---

### Case 3: WhatsApp Read After Disbursement

**Example**: Customer 0017267841
```
Facility date: 2025-07-29
WhatsApp sent: 2025-07-11
WhatsApp read: 2025-07-26 (3 days BEFORE facility)
```

**Note**: WhatsApp `ReadAt` may be approximate, not exact open timestamp

---

## Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-04 | Ammar Siregar | Initial wiki creation based on combined query development |

---

**Document Status**: Active Analysis
**Next Review**: After full cohort analysis
**Last Updated**: 2025-10-04
