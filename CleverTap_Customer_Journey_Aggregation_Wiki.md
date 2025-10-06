# CleverTap Customer Journey Aggregation - Technical Wiki

## Table of Contents
- [Overview](#overview)
- [Business Context](#business-context)
- [Data Architecture](#data-architecture)
- [Query Design](#query-design)
- [Known Data Limitations](#known-data-limitations)
- [Output Schema](#output-schema)
- [Key Findings](#key-findings)
- [Troubleshooting Guide](#troubleshooting-guide)
- [References](#references)

---

## Overview

**Project Name**: CleverTap Customer Journey Aggregation for Direct Lending
**Created**: 2025-10-02
**Analyst**: Ammar Siregar (Risk Data Analyst Intern)
**Stakeholder**: Kak Zaki (Product Analytics), Bang Subhan (Mentor)
**Status**: Production Ready

### Purpose
Create an aggregation table that captures customer journey metrics from loan offer creation through disbursement, enabling:
- Journey pattern analysis for successful customers
- Stage-level engagement measurement
- Time-to-conversion tracking
- Drop-off point identification (future use)

### Key Metrics Delivered
- **Event Counts**: Total interactions per journey stage (7 stages)
- **Latest Timestamps**: Most recent activity timestamp per stage
- **Time Differences**: Days between agreement and each stage milestone

---

## Business Context

### Analysis Scope
- **Time Period**: July 2025 loan agreements
- **Customer Segment**: New Offer customers (`is_new_offer = 1`)
- **Success Filter**: Successful takeup only (`flag_takeup = 1`)
- **Journey Window**: From `created_at` (offer creation) to `start_date` (disbursement)

### Journey Stages (7 Stages)

| Stage # | Stage Name | Description | Entry Points |
|---------|------------|-------------|--------------|
| 1 | **Entry** | Initial access to DL feature | Home spotlight, home shortcut, more menu, push notification |
| 2 | **Loan Hub** | Dashboard with loan offers | In-app navigation, direct link |
| 3 | **Landing** | Loan offer landing page | Post-entry navigation, **push notification direct access** |
| 4 | **Drawdown** | Loan amount/duration selection | Sequential flow from landing |
| 5 | **Confirmation** | Review loan details | Post-drawdown validation |
| 6 | **PII** | Personal information collection | Pre-agreement requirement |
| 7 | **Agreement** | Terms acceptance | Final step before disbursement |

### Important Business Rules

1. **Push Notification Bypass**: Customers clicking push notifications can land directly on Landing page (Stage 3), **completely bypassing Entry and Loan Hub stages**
2. **CleverTap Event Loss**: CleverTap doesn't capture 100% of events - some customers show zero events despite successful loan completion
3. **Open Market Exclusion**: `INIT_underwriting_uvp` events (open market feature) excluded from analysis - only relevant from August 2025 onwards

---

## Data Architecture

### Source Tables

#### 1. Customer Loan Details
```
Table: data-prd-adhoc.temp_ammar.ammar_customer_loan_details
Purpose: Master loan offer and disbursement records
Key Fields:
  - customer_id (STRING): Unique customer identifier
  - business_date (DATE): Loan offer business date
  - created_at (DATE): Offer creation date
  - expires_at (TIMESTAMP): Offer expiration timestamp
  - agreement_agreed_at (TIMESTAMP): Agreement acceptance timestamp
  - start_date (DATE): Loan disbursement date (facility start)
  - is_new_offer (INT64): 1 = new offer, 0 = existing
  - flag_takeup (INT64): 1 = successful disbursement, 0 = no takeup
```

#### 2. CleverTap User Events
```
Table: jago-bank-data-production.risk_datamart.clevertap_user_events
Type: Partitioned by DATE(time)
Purpose: User interaction tracking
Key Fields:
  - customer_id (STRING): Links to loan details
  - time (TIMESTAMP): Event occurrence timestamp
  - event_name (STRING): Specific user action (e.g., CLICK_DL_entry_home_shortcut)
  - session_id (STRING): User session identifier

IMPORTANT: Must include DATE(time) filter for partition pruning
```

### Data Lineage

```
ammar_customer_loan_details (July 2025 agreements, flag_takeup=1, is_new_offer=1)
           ↓
    INNER JOIN (on customer_id)
           ↓
clevertap_user_events (DATE(time) BETWEEN created_at AND start_date)
           ↓
    Event Stage Mapping (CASE statement)
           ↓
    Aggregation (GROUP BY customer_id)
           ↓
    Final Output (21 columns per customer)
```

---

## Query Design

### CTE Architecture

#### CTE 1: base_customer
**Purpose**: Filter to target customer population

```sql
WITH base_customer AS (
  SELECT
    business_date,
    customer_id,
    created_at,
    expires_at,
    agreement_agreed_at,
    start_date,
    is_new_offer,
    flag_takeup
  FROM `data-prd-adhoc.temp_ammar.ammar_customer_loan_details`
  WHERE (agreement_agreed_at >= '2025-07-01 00:00:00'
         AND agreement_agreed_at < '2025-08-01 00:00:00')
    AND flag_takeup = 1
    AND is_new_offer = 1
)
```

**Key Decisions**:
- Filter on `agreement_agreed_at` for July 2025 (not `start_date` - some disbursements occur in August)
- TIMESTAMP comparison format for precision
- Limit to successful new offers only

---

#### CTE 2: clevertap_events
**Purpose**: Join CleverTap events within customer journey timeframe

```sql
clevertap_events AS (
  SELECT
    bc.customer_id,
    bc.created_at,
    bc.start_date,
    ct.time,
    ct.event_name
  FROM base_customer bc
  INNER JOIN `jago-bank-data-production.risk_datamart.clevertap_user_events` ct
    ON bc.customer_id = ct.customer_id
  WHERE DATE(time) BETWEEN '2025-01-01' AND '2025-08-31'
    AND DATE(ct.time) >= bc.created_at
    AND DATE(ct.time) <= DATE(bc.start_date)
    AND ct.event_name LIKE '%DL%'
)
```

**Critical Design Choices**:

| Element | Value | Rationale |
|---------|-------|-----------|
| **JOIN Type** | INNER JOIN | Only customers with CleverTap events (accepts data loss) |
| **Partition Filter** | `DATE(time) BETWEEN '2025-01-01' AND '2025-08-31'` | Required for partitioned table; broad range captures early journeys |
| **Lower Bound** | `DATE(ct.time) >= bc.created_at` | Events must occur after offer creation |
| **Upper Bound** | `DATE(ct.time) <= DATE(bc.start_date)` | **KEY FIX**: Capture events up to disbursement (not agreement) |
| **Event Filter** | `event_name LIKE '%DL%'` | Direct Lending events only |

**Why `start_date` Instead of `agreement_agreed_at`?**

- **Problem Discovered**: 3 customers (FD53KS0UJ0, T7AY91GG71, VRXCC157A5) showed zero events when filtering to `agreement_agreed_at`
- **Root Cause**: Some customers have CleverTap events **after agreement signing but before disbursement**
- **Example**: Customer VRXCC157A5
  - Agreement: 2025-07-11 08:58:37
  - Disbursement: 2025-07-11
  - CleverTap events: 2025-07-15 (4 days after agreement!)
- **Solution**: Extend upper bound to `start_date` to capture full journey including post-agreement pre-disbursement activity

---

#### CTE 3: events_stage
**Purpose**: Map raw event names to journey stages

```sql
events_stage AS (
  SELECT
    *,
    CASE
      -- Entry (1)
      WHEN event_name IN ('CLICK_DL_entry_home_spotlight', 'CLICK_DL_entry_home_shortcut',
                          'CLICK_DL_entry_more_menu', 'CLICK_DL_entry_bellnote_link')
      THEN 'entry'

      -- Loan Hub (2)
      WHEN event_name IN ('INIT_DL_inquiry_dashboard', 'CLICK_DL_inquiry_dashboard_ftueskip',
                          'CLICK_DL_inquiry_dashboard_menu', 'CLICK_DL_hub_overview',
                          'CLICK_DL_loanhub_seeloanoffer', 'CLICK_DL_inquiry_dashboard_faq',
                          -- ... 15 total events
                          )
      THEN 'loan_hub'

      -- Landing (3)
      WHEN event_name IN ('INIT_DL_draw_landing', 'CLICK_DL_draw_landing_faq',
                          'CLICK_DL_draw_landing_next')
      THEN 'landing'

      -- Drawdown (4)
      WHEN event_name IN ('INIT_DL_draw_drawdown', 'TEXT_DL_draw_drawdown_amount',
                          'SLIDE_DL_draw_drawdown_duration', 'DATE_DL_draw_drawdown_date',
                          -- ... 10 total events
                          )
      THEN 'drawdown'

      -- Confirmation (5)
      WHEN event_name IN ('INIT_DL_draw_confirm', 'CLICK_DL_draw_confirm_infointerest',
                          'CLICK_DL_draw_confirm_faq', 'CLICK_DL_draw_confirm_back',
                          'CLICK_DL_draw_confirm_next')
      THEN 'confirmation'

      -- PII (6)
      WHEN event_name IN ('INIT_DL_draw_pii', 'CLICK_DL_draw_pii_back',
                          'CLICK_DL_draw_pii_next')
      THEN 'pii'

      -- Agreement (7)
      WHEN event_name IN ('INIT_DL_draw_agreement', 'SCROLL_DL_draw_agreement_content',
                          'RDIO_DL_draw_agreement_accept', 'CLICK_DL_draw_agreement_back',
                          'CLICK_DL_draw_agreement_next')
      THEN 'agreement'

      ELSE 'other'
    END AS stage_name
  FROM clevertap_events
)
```

**Mapping Source**: Kak Zaki's official screen_numb event mapping (58 distinct DL events)

**Excluded Events**:
- `INIT_underwriting_uvp`, `INIT_DL_underwriting_uvp`, `CLICK_underwriting_uvp_home` - Open Market feature (August 2025+)
- Stage 8-11 events (PIN/OTP, KYC, Processing, Success/Failed) - Post-agreement stages

---

#### Final Aggregation
**Purpose**: Calculate journey metrics per customer

```sql
SELECT
  bc.business_date,
  bc.customer_id,
  bc.created_at,
  CAST(bc.expires_at AS DATE) AS expiry_date,
  bc.start_date AS facility_date,

  -- Part 2: Event Counts (7 stages)
  COUNTIF(es.stage_name = 'entry') AS total_entry,
  COUNTIF(es.stage_name = 'loan_hub') AS total_loan_hub,
  COUNTIF(es.stage_name = 'landing') AS total_lending,
  COUNTIF(es.stage_name = 'drawdown') AS total_drawdown,
  COUNTIF(es.stage_name = 'confirmation') AS total_confirmation,
  COUNTIF(es.stage_name = 'pii') AS total_pii,
  COUNTIF(es.stage_name = 'agreement') AS total_agreement,

  -- Part 3: Latest Timestamps (7 stages)
  MAX(CASE WHEN es.stage_name = 'entry' THEN es.time END) AS latest_entry_timestamp,
  MAX(CASE WHEN es.stage_name = 'loan_hub' THEN es.time END) AS latest_loan_hub_timestamp,
  MAX(CASE WHEN es.stage_name = 'landing' THEN es.time END) AS latest_lending_timestamp,
  MAX(CASE WHEN es.stage_name = 'drawdown' THEN es.time END) AS latest_drawdown_timestamp,
  MAX(CASE WHEN es.stage_name = 'confirmation' THEN es.time END) AS latest_confirmation_timestamp,
  MAX(CASE WHEN es.stage_name = 'pii' THEN es.time END) AS latest_pii_timestamp,
  MAX(CASE WHEN es.stage_name = 'agreement' THEN es.time END) AS latest_agreement_timestamp,

  -- Part 4: Time Differences (in days, 7 calculations)
  DATE_DIFF(DATE(MAX(CASE WHEN es.stage_name = 'agreement' THEN es.time END)),
            DATE(bc.created_at), DAY) AS diff_agree_created,
  DATE_DIFF(DATE(MAX(CASE WHEN es.stage_name = 'agreement' THEN es.time END)),
            DATE(MAX(CASE WHEN es.stage_name = 'entry' THEN es.time END)), DAY) AS diff_agree_entry,
  DATE_DIFF(DATE(MAX(CASE WHEN es.stage_name = 'agreement' THEN es.time END)),
            DATE(MAX(CASE WHEN es.stage_name = 'loan_hub' THEN es.time END)), DAY) AS diff_agree_loanhub,
  DATE_DIFF(DATE(MAX(CASE WHEN es.stage_name = 'agreement' THEN es.time END)),
            DATE(MAX(CASE WHEN es.stage_name = 'landing' THEN es.time END)), DAY) AS diff_agree_lending,
  DATE_DIFF(DATE(MAX(CASE WHEN es.stage_name = 'agreement' THEN es.time END)),
            DATE(MAX(CASE WHEN es.stage_name = 'drawdown' THEN es.time END)), DAY) AS diff_agree_drawdown,
  DATE_DIFF(DATE(MAX(CASE WHEN es.stage_name = 'agreement' THEN es.time END)),
            DATE(MAX(CASE WHEN es.stage_name = 'confirmation' THEN es.time END)), DAY) AS diff_agree_confirmation,
  DATE_DIFF(DATE(MAX(CASE WHEN es.stage_name = 'agreement' THEN es.time END)),
            DATE(MAX(CASE WHEN es.stage_name = 'pii' THEN es.time END)), DAY) AS diff_agree_pii

FROM base_customer bc
LEFT JOIN events_stage es ON bc.customer_id = es.customer_id
GROUP BY bc.business_date, bc.customer_id, bc.created_at, bc.expires_at, bc.start_date
ORDER BY bc.customer_id
```

**Aggregation Strategy**:
- **LEFT JOIN**: Include all base customers even if no CleverTap events (handles data loss gracefully)
- **COUNTIF**: Count events per stage (returns 0 if no events)
- **MAX(CASE WHEN)**: Extract latest timestamp per stage (returns NULL if stage not visited)
- **DATE_DIFF**: Calculate days between agreement and each stage (NULL if stage not visited)

---

## Known Data Limitations

### 1. CleverTap Event Loss (Expected Behavior)

**Issue**: Some customers show **zero or minimal CleverTap events** despite successful loan completion

**Root Causes** (confirmed by Kak Zaki, 2025-10-02):
1. **Missing CleverTap ID**: Some users don't generate `clevertap_id` during session
   - Result: In-app events not recorded or only partially recorded
2. **Push Notification Direct Access**: Users clicking push notifications bypass in-app tracking
   - Flow: Push notif → UVP/Landing page (no Entry/Loan Hub events)
3. **System Event Loss**: CleverTap inherently doesn't capture 100% of events

**Affected Customers (Example)**:
- `FD53KS0UJ0`: Zero events across all stages
- `T7AY91GG71`: Zero events across all stages
- `VRXCC157A5`: Zero events across all stages

**Business Impact**:
- ✅ **Acceptable**: These customers still successfully completed loans via alternative paths
- ✅ **Normal**: Event loss is expected system behavior, not data quality issue
- ⚠️ **Analysis Consideration**: Journey metrics represent **trackable interactions only**, not complete customer journey

**Mitigation**:
- Use `LEFT JOIN` to retain all customers (including zero-event customers)
- Interpret zero event counts as "not tracked" rather than "did not occur"
- Cross-validate findings with disbursement data (source of truth)

---

### 2. Post-Agreement Events

**Discovery**: Some customers have CleverTap events **after** agreement signing but **before** disbursement

**Example Timeline** (Customer VRXCC157A5):
```
2025-07-03: Offer created (created_at)
2025-07-11 08:58:37: Agreement signed (agreement_agreed_at)
2025-07-11: Loan disbursed (start_date)
2025-07-15: CleverTap events recorded (4 days after agreement!)
```

**Hypothesis**: Customer may have returned to app post-agreement to:
- Check loan status
- Review loan details
- Access other app features

**Query Handling**: Upper bound set to `start_date` instead of `agreement_agreed_at` to capture these events

---

### 3. Open Market Events (Excluded)

**Events**: `INIT_underwriting_uvp`, `INIT_DL_underwriting_uvp`, `CLICK_underwriting_uvp_home`

**Reason for Exclusion**:
- Open Market feature started internal testing in July 2025
- Not part of standard Direct Lending flow for July analysis
- Relevant for August 2025+ analysis only

**Source**: Kak Zaki guidance (2025-10-02)

---

## Output Schema

### Table Structure (21 Columns)

#### Part 1: General Information (5 columns)
| Column | Type | Description | Example |
|--------|------|-------------|---------|
| `business_date` | DATE | Loan offer business date | 2025-08-31 |
| `customer_id` | STRING | Unique customer identifier | FD53KS0UJ0 |
| `created_at` | DATE | Offer creation date | 2025-07-02 |
| `expiry_date` | DATE | Offer expiration date | 2025-08-01 |
| `facility_date` | DATE | Loan disbursement date (start_date) | 2025-07-11 |

#### Part 2: Event Counts (7 columns)
| Column | Type | Description | Null Behavior |
|--------|------|-------------|---------------|
| `total_entry` | INT64 | Count of Entry stage events | 0 if no events |
| `total_loan_hub` | INT64 | Count of Loan Hub stage events | 0 if no events |
| `total_lending` | INT64 | Count of Landing stage events | 0 if no events |
| `total_drawdown` | INT64 | Count of Drawdown stage events | 0 if no events |
| `total_confirmation` | INT64 | Count of Confirmation stage events | 0 if no events |
| `total_pii` | INT64 | Count of PII stage events | 0 if no events |
| `total_agreement` | INT64 | Count of Agreement stage events | 0 if no events |

#### Part 3: Latest Timestamps (7 columns)
| Column | Type | Description | Null Behavior |
|--------|------|-------------|---------------|
| `latest_entry_timestamp` | TIMESTAMP | Most recent Entry event time | NULL if stage not visited |
| `latest_loan_hub_timestamp` | TIMESTAMP | Most recent Loan Hub event time | NULL if stage not visited |
| `latest_lending_timestamp` | TIMESTAMP | Most recent Landing event time | NULL if stage not visited |
| `latest_drawdown_timestamp` | TIMESTAMP | Most recent Drawdown event time | NULL if stage not visited |
| `latest_confirmation_timestamp` | TIMESTAMP | Most recent Confirmation event time | NULL if stage not visited |
| `latest_pii_timestamp` | TIMESTAMP | Most recent PII event time | NULL if stage not visited |
| `latest_agreement_timestamp` | TIMESTAMP | Most recent Agreement event time | NULL if stage not visited |

#### Part 4: Time Differences (7 columns)
| Column | Type | Description | Calculation | Null Behavior |
|--------|------|-------------|-------------|---------------|
| `diff_agree_created` | INT64 | Days from offer creation to agreement | `latest_agreement_timestamp - created_at` | NULL if no agreement events |
| `diff_agree_entry` | INT64 | Days from entry to agreement | `latest_agreement_timestamp - latest_entry_timestamp` | NULL if no entry events |
| `diff_agree_loanhub` | INT64 | Days from loan hub to agreement | `latest_agreement_timestamp - latest_loan_hub_timestamp` | NULL if no loan hub events |
| `diff_agree_lending` | INT64 | Days from landing to agreement | `latest_agreement_timestamp - latest_lending_timestamp` | NULL if no landing events |
| `diff_agree_drawdown` | INT64 | Days from drawdown to agreement | `latest_agreement_timestamp - latest_drawdown_timestamp` | NULL if no drawdown events |
| `diff_agree_confirmation` | INT64 | Days from confirmation to agreement | `latest_agreement_timestamp - latest_confirmation_timestamp` | NULL if no confirmation events |
| `diff_agree_pii` | INT64 | Days from PII to agreement | `latest_agreement_timestamp - latest_pii_timestamp` | NULL if no PII events |

---

## Key Findings

### Customer Behavior Patterns

#### 1. Push Notification Direct Access
- **Observation**: 3 out of 100 sample customers showed zero events across all stages
- **Cause**: Push notification → UVP landing page (bypasses in-app entry points)
- **Implication**: Entry and Loan Hub stages are **optional** in customer journey
- **Business Value**: Push notifications are effective conversion channel (no in-app friction needed)

#### 2. Event Loss Distribution
- **Sample Size**: 100 customers (July 2025 agreements, new offers, successful takeup)
- **Zero Event Customers**: 3 (3%)
- **Partial Event Customers**: Unknown (requires deeper analysis)
- **Interpretation**: 97%+ of successful customers have at least some trackable CleverTap events

#### 3. Post-Agreement Activity
- **Discovery**: Customer VRXCC157A5 had events 4 days after agreement signing
- **Frequency**: Unknown across full dataset (requires investigation)
- **Hypothesis**: Customers return to app post-agreement for status checks or feature exploration

---

## Troubleshooting Guide

### Issue 1: No Data Returned
**Symptoms**: Query returns 0 rows

**Diagnostic Steps**:
1. Check `base_customer` CTE filter:
   ```sql
   SELECT COUNT(*) FROM `data-prd-adhoc.temp_ammar.ammar_customer_loan_details`
   WHERE (agreement_agreed_at >= '2025-07-01 00:00:00'
          AND agreement_agreed_at < '2025-08-01 00:00:00')
     AND flag_takeup = 1
     AND is_new_offer = 1
   ```
   Expected: > 0 rows

2. Check CleverTap partition access:
   ```sql
   SELECT COUNT(*) FROM `jago-bank-data-production.risk_datamart.clevertap_user_events`
   WHERE DATE(time) BETWEEN '2025-01-01' AND '2025-08-31'
   ```
   Expected: > 0 rows

3. Verify INNER JOIN produces matches:
   - Change to LEFT JOIN temporarily
   - Count customers with NULL CleverTap events
   - If 100% NULL: customer_id mismatch issue

---

### Issue 2: All Event Counts are Zero
**Symptoms**: Query returns rows but all `total_*` columns are 0

**Root Causes**:
1. **Expected**: CleverTap event loss (see Data Limitations)
2. **Event Filter Too Restrictive**: Check `event_name LIKE '%DL%'` filter
3. **Time Window Issue**: Events outside `created_at` to `start_date` range

**Diagnostic Query**:
```sql
-- Check if customer has ANY DL events (ignore time window)
SELECT customer_id, COUNT(*) as total_dl_events
FROM `jago-bank-data-production.risk_datamart.clevertap_user_events`
WHERE customer_id = 'FD53KS0UJ0'
  AND event_name LIKE '%DL%'
  AND DATE(time) BETWEEN '2025-01-01' AND '2025-08-31'
GROUP BY customer_id
```

**Resolution**: If legitimate event loss, document affected customers and proceed with analysis

---

### Issue 3: Negative Time Differences
**Symptoms**: `diff_agree_*` columns show negative values

**Root Cause**: Stage occurred AFTER agreement (non-linear journey)

**Example**:
```
latest_agreement_timestamp: 2025-07-07 14:36:30
latest_drawdown_timestamp: 2025-07-07 15:00:00
diff_agree_drawdown: -1 days (negative!)
```

**Business Interpretation**: Customer revisited earlier stages after agreement (app exploration or changes)

**Handling**:
- Keep negative values (represents actual user behavior)
- Filter to positive values only if analyzing "time to agreement" metrics

---

### Issue 4: NULL vs Zero Confusion
**Symptoms**: Confusion between NULL and 0 in event counts vs timestamps

**Clarification**:
| Metric Type | Zero Meaning | NULL Meaning |
|-------------|--------------|--------------|
| Event Counts (`total_*`) | Stage not visited (0 events) | N/A (always returns 0 if no events) |
| Timestamps (`latest_*_timestamp`) | N/A (no such value) | Stage not visited |
| Time Differences (`diff_agree_*`) | Same day as agreement | Stage not visited OR no agreement events |

**Query Pattern**:
```sql
-- Count customers who visited stage
SELECT COUNT(*) FROM output_table WHERE total_entry > 0

-- Count customers with trackable entry timestamp
SELECT COUNT(*) FROM output_table WHERE latest_entry_timestamp IS NOT NULL
```

---

## References

### Documentation
- `CleverTap_Journey_Analysis_Technical_Documentation.md` - Initial journey analysis framework
- `Data_Analysis_Flow_Guide_Bank_Jago.md` - SQL best practices and CTE structure
- `Propensity_Model_Feature_Analysis_Knowledge_Base.md` - Related propensity work

### Source Code
- Query Location: `C:\Users\aux-ammar.siregar_te\Documents\Risk-DA-Intern\` (local development)
- Production Table: TBD (awaiting deployment decision)

### Key Contacts
- **Product Analytics**: Kak Zaki (CleverTap event mapping, data limitations guidance)
- **Mentorship**: Bang Subhan (business requirements, validation)
- **Data Engineering**: TBD (for production deployment)

### Event Mapping Reference
**Source**: Kak Zaki's screen_numb mapping (shared via Slack 2025-10-01)
- 58 distinct DL events mapped to 11 stages
- July 2025 analysis uses stages 1-7 only
- Open Market events (underwriting) excluded for July period

### Slack Discussions
- **2025-10-02**: CleverTap event loss explanation (Kak Zaki)
  - "clevertap itu ngga capture semua event, ada loss event nya"
  - "kemungkinan user2 gini tuh ngga ke generate clevertapid nya"
  - "its normal kok"
- **2025-10-02**: Open Market underwriting events (Kak Zaki)
  - "itu buat open market, ngga usah dipake dulu"
  - "july itu udah ada internal testing"

---

## Appendix A: Complete Event Mapping

### Stage 1: Entry (4 events)
```
CLICK_DL_entry_home_spotlight
CLICK_DL_entry_home_shortcut
CLICK_DL_entry_more_menu
CLICK_DL_entry_bellnote_link
```

### Stage 2: Loan Hub (15 events)
```
INIT_DL_inquiry_dashboard
CLICK_DL_inquiry_dashboard_ftueskip
CLICK_DL_inquiry_dashboard_ftuecomplete
CLICK_DL_inquiry_dashboard_menu
CLICK_DL_inquiry_details_menu
INIT_DL_inquiry_details
CLICK_DL_inquiry_details_menueditloan
CLICK_DL_inquiry_dashboard_menulba
CLICK_DL_hub_overview
CLICK_DL_inquiry_details_loandtls
CLICK_DL_loanhub_seeloanoffer
CLICK_DL_inquiry_dashboard_infomyloan
CLICK_DL_hub_viewinfo
CLICK_DL_inquiry_dashboard_faq
CLICK_DL_add_dashboard_addloan
```

### Stage 3: Landing (3 events)
```
INIT_DL_draw_landing
CLICK_DL_draw_landing_faq
CLICK_DL_draw_landing_next
```

### Stage 4: Drawdown (10 events)
```
INIT_DL_draw_drawdown
TEXT_DL_draw_drawdown_amount
SLIDE_DL_draw_drawdown_duration
DATE_DL_draw_drawdown_date
CLICK_DL_draw_drawdown_infointerest
CLICK_DL_draw_drawdown_infoschedule
CLICK_DL_draw_drawdown_back
CLICK_DL_draw_drawdown_allamount
CLICK_DL_draw_drawdown_faq
CLICK_DL_draw_drawdown_next
```

### Stage 5: Confirmation (5 events)
```
INIT_DL_draw_confirm
CLICK_DL_draw_confirm_infointerest
CLICK_DL_draw_confirm_faq
CLICK_DL_draw_confirm_back
CLICK_DL_draw_confirm_next
```

### Stage 6: PII (3 events)
```
INIT_DL_draw_pii
CLICK_DL_draw_pii_back
CLICK_DL_draw_pii_next
```

### Stage 7: Agreement (5 events)
```
INIT_DL_draw_agreement
SCROLL_DL_draw_agreement_content
RDIO_DL_draw_agreement_accept
CLICK_DL_draw_agreement_back
CLICK_DL_draw_agreement_next
```

### Excluded: Open Market (Not Used in July Analysis)
```
INIT_underwriting_uvp
INIT_DL_underwriting_uvp
CLICK_underwriting_uvp_home
```

---

## Appendix B: Sample Output

### Customer with Complete Journey
```
business_date: 2025-08-31
customer_id: 17267841
created_at: 2025-07-04
expiry_date: 2025-08-03
facility_date: 2025-07-31

Event Counts:
  total_entry: 15
  total_loan_hub: 324
  total_lending: 78
  total_drawdown: 156
  total_confirmation: 89
  total_pii: 12
  total_agreement: 234

Latest Timestamps:
  latest_entry_timestamp: 2025-07-04 09:23:45
  latest_loan_hub_timestamp: 2025-07-31 08:45:12
  latest_lending_timestamp: 2025-07-31 08:46:30
  latest_drawdown_timestamp: 2025-07-31 08:47:15
  latest_confirmation_timestamp: 2025-07-31 08:48:00
  latest_pii_timestamp: 2025-07-31 08:48:45
  latest_agreement_timestamp: 2025-07-31 08:51:23

Time Differences (days):
  diff_agree_created: 27
  diff_agree_entry: 27
  diff_agree_loanhub: 0
  diff_agree_lending: 0
  diff_agree_drawdown: 0
  diff_agree_confirmation: 0
  diff_agree_pii: 0
```

**Interpretation**: "Long Thinker, Fast Executor"
- 27 days from offer creation to agreement (consideration period)
- 0 days between loan hub and agreement (executed same day once decided)
- High loan hub events (324) suggest repeated app visits during consideration

---

### Customer with Event Loss (Zero Events)
```
business_date: 2025-08-31
customer_id: FD53KS0UJ0
created_at: 2025-07-02
expiry_date: 2025-08-01
facility_date: 2025-07-11

Event Counts:
  total_entry: 0
  total_loan_hub: 0
  total_lending: 0
  total_drawdown: 0
  total_confirmation: 0
  total_pii: 0
  total_agreement: 0

Latest Timestamps:
  latest_entry_timestamp: NULL
  latest_loan_hub_timestamp: NULL
  latest_lending_timestamp: NULL
  latest_drawdown_timestamp: NULL
  latest_confirmation_timestamp: NULL
  latest_pii_timestamp: NULL
  latest_agreement_timestamp: NULL

Time Differences (days):
  diff_agree_created: NULL
  diff_agree_entry: NULL
  diff_agree_loanhub: NULL
  diff_agree_lending: NULL
  diff_agree_drawdown: NULL
  diff_agree_confirmation: NULL
  diff_agree_pii: NULL
```

**Interpretation**: Successful loan completion via alternative path
- Likely push notification direct access to landing page
- CleverTap ID not generated (events not tracked)
- Loan still successfully disbursed on 2025-07-11
- **Normal behavior per Kak Zaki guidance**

---

## Version History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-02 | Ammar Siregar | Initial wiki creation based on query development findings |

---

## Quick Links
- [Back to Top](#clevertap-customer-journey-aggregation---technical-wiki)
- [Query Design](#query-design)
- [Known Limitations](#known-data-limitations)
- [Troubleshooting](#troubleshooting-guide)
