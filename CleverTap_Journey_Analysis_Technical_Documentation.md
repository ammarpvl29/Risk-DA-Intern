# CleverTap Journey Analysis - Technical Documentation

## Overview

**Project**: CleverTap User Journey Analysis for Direct Lending (DL)
**Analyst**: Ammar Siregar (Risk Data Analyst Intern)
**Date**: 2025-10-01
**Purpose**: Understand customer behavior during loan application process to identify drop-off points

---

## Objective

Analyze successful customer journeys (flag_takeup = 1) to establish baseline behavior patterns before loan agreement. Focus on understanding:
- Event sequences from loan entry to agreement
- Time spent in each journey stage
- Stage progression patterns
- Distribution of customer interactions across loan application stages

---

## Data Sources

### Primary Tables

**1. Customer Loan Details**
- **Table**: `data-prd-adhoc.temp_ammar.ammar_customer_loan_details`
- **Key Fields**:
  - `customer_id`: Unique customer identifier
  - `created_at`: Loan application creation date
  - `agreement_agreed_at`: When customer accepted agreement
  - `flag_takeup`: 1 = successful loan disbursement, 0 = no takeup
  - `is_new_offer`: 1 = new customer offer, 0 = existing
  - `is_carry_over_offer`: 1 = carry-over offer, 0 = not carry-over
- **Filter**: July 2025 agreements (agreement_agreed_at between 2025-07-01 and 2025-08-01)

**2. CleverTap User Events**
- **Table**: `jago-bank-data-production.risk_datamart.clevertap_user_events`
- **Key Fields**:
  - `customer_id`: Links to customer loan details
  - `time`: Event timestamp
  - `event_name`: Specific user action (e.g., CLICK_DL_entry_home_shortcut)
  - `session_id`: User session identifier
  - `device_platform`, `device_model`, `device_city`, `device_province`: Device metadata
- **Table Type**: Partitioned by DATE(time)
- **Partition Filter Required**: Must include DATE(time) filter for query efficiency

---

## CleverTap Event System

### What is CleverTap?

CleverTap tracks every user interaction in the Jago mobile app including:
- Screen initializations (INIT_*)
- Button clicks (CLICK_*)
- Text inputs (TEXT_*)
- Slider interactions (SLIDE_*)
- Scroll actions (SCROLL_*)
- Radio button selections (RDIO_*)

### Event Naming Convention

**Pattern**: `[ACTION]_[PRODUCT]_[SCREEN]_[ELEMENT]`

**Examples**:
- `CLICK_DL_entry_home_shortcut` - User clicked DL shortcut on home screen
- `TEXT_DL_draw_drawdown_amount` - User entered loan amount
- `INIT_DL_draw_agreement` - Agreement screen initialized
- `SCROLL_DL_draw_agreement_content` - User scrolled agreement content

---

## Journey Stage Mapping

### Stage Hierarchy (Screen Numbers 1-7)

Based on Kak Zaki's event mapping:

| Stage # | Stage Name | Description | Key Events |
|---------|------------|-------------|------------|
| 1 | Entry | Initial entry points to DL feature | CLICK_DL_entry_home_spotlight, CLICK_DL_entry_home_shortcut, CLICK_DL_entry_more_menu, CLICK_DL_entry_bellnote_link |
| 2 | Loan Hub | Dashboard showing loan offers and details | INIT_DL_inquiry_dashboard, CLICK_DL_hub_overview, CLICK_DL_loanhub_seeloanoffer |
| 3 | Landing | Loan offer landing page | INIT_DL_draw_landing, CLICK_DL_draw_landing_next, CLICK_DL_draw_landing_faq |
| 4 | Drawdown | Customer selects loan amount, duration, date | INIT_DL_draw_drawdown, TEXT_DL_draw_drawdown_amount, SLIDE_DL_draw_drawdown_duration, DATE_DL_draw_drawdown_date |
| 5 | Confirmation | Review loan details before agreement | INIT_DL_draw_confirm, CLICK_DL_draw_confirm_next |
| 6 | PII | Personal Identifiable Information collection | INIT_DL_draw_pii, CLICK_DL_draw_pii_next |
| 7 | Agreement | Terms and conditions acceptance | INIT_DL_draw_agreement, SCROLL_DL_draw_agreement_content, RDIO_DL_draw_agreement_accept |

### Analysis Boundary

**Time Window**: `created_at` → `agreement_agreed_at`

**Why**: We only analyze customer behavior BEFORE they accept the agreement to understand the decision-making journey, not post-disbursement behavior.

**Exclusions**:
- Stage 8 (PIN/OTP) - occurs after agreement
- Stage 9 (KYC) - occurs after agreement
- Stage 10 (Processing) - occurs after agreement
- Stage 11 (Success/Failed) - final outcome after agreement

---

## Technical Implementation

### Query Architecture

**Structure**: Multi-CTE (Common Table Expression) approach following Bank Jago Data Analysis Flow Guide

**CTE Flow**:

```
base_customer
    ↓
clevertap_events (INNER JOIN)
    ↓
events_stage (CASE statement mapping)
    ↓
Final aggregation (percentage calculation)
```

### CTE 1: base_customer

**Purpose**: Filter to successful July 2025 new offer customers

```sql
WITH base_customer AS (
  SELECT
    customer_id,
    created_at,
    agreement_agreed_at,
    start_date,
    tanggal_pk_awal,
    is_new_offer,
    is_carry_over_offer,
    flag_takeup
  FROM `data-prd-adhoc.temp_ammar.ammar_customer_loan_details`
  WHERE (agreement_agreed_at >= '2025-07-01 00:00:00'
         AND agreement_agreed_at < '2025-08-01 00:00:00')
    AND flag_takeup = 1
    AND is_new_offer = 1
)
```

**Key Decisions**:
- Use `agreement_agreed_at` (not `start_date`) to identify when customer agreed
- TIMESTAMP format with explicit time for precision
- Filter to successful takeup (`flag_takeup = 1`)
- Focus on new offers (`is_new_offer = 1`)

### CTE 2: clevertap_events

**Purpose**: Link CleverTap events to customers within their journey timeframe

```sql
clevertap_events AS (
  SELECT
    bc.customer_id,
    bc.created_at,
    bc.agreement_agreed_at,
    ct.time,
    ct.event_name,
    ct.session_id,
    ct.device_platform,
    ct.device_model,
    ct.device_city,
    ct.device_province
  FROM base_customer bc
  INNER JOIN `jago-bank-data-production.risk_datamart.clevertap_user_events` ct
    ON bc.customer_id = ct.customer_id
  WHERE DATE(time) BETWEEN '2025-01-01' AND '2025-07-31'
    AND DATE(ct.time) >= bc.created_at
    AND ct.time <= bc.agreement_agreed_at
    AND ct.event_name LIKE '%DL%'
)
```

**Key Decisions**:
- **INNER JOIN**: Only include customers who have CleverTap events
- **Partition filter**: `DATE(time) BETWEEN '2025-01-01' AND '2025-07-31'` (required for partitioned table)
- **Customer time window**: `DATE(ct.time) >= bc.created_at AND ct.time <= bc.agreement_agreed_at`
- **DL events only**: `event_name LIKE '%DL%'` filters to Direct Lending events
- **Broad date range**: Starts from Jan 2025 to capture complete journeys (some customers may have created_at in June but agreement in July)

### CTE 3: events_stage

**Purpose**: Classify each event into journey stages using exact event name matching

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
                          'CLICK_DL_inquiry_dashboard_ftuecomplete', 'CLICK_DL_inquiry_dashboard_menu',
                          'CLICK_DL_inquiry_details_menu', 'INIT_DL_inquiry_details',
                          'CLICK_DL_inquiry_details_menueditloan', 'CLICK_DL_inquiry_dashboard_menulba',
                          'CLICK_DL_hub_overview', 'CLICK_DL_inquiry_details_loandtls',
                          'CLICK_DL_loanhub_seeloanoffer', 'CLICK_DL_inquiry_dashboard_infomyloan',
                          'CLICK_DL_hub_viewinfo', 'CLICK_DL_inquiry_dashboard_faq',
                          'CLICK_DL_add_dashboard_addloan')
      THEN 'loan_hub'

      -- Landing (3)
      WHEN event_name IN ('INIT_DL_draw_landing', 'CLICK_DL_draw_landing_faq',
                          'CLICK_DL_draw_landing_next')
      THEN 'landing'

      -- Loan Drawdown (4)
      WHEN event_name IN ('INIT_DL_draw_drawdown', 'TEXT_DL_draw_drawdown_amount',
                          'SLIDE_DL_draw_drawdown_duration', 'DATE_DL_draw_drawdown_date',
                          'CLICK_DL_draw_drawdown_infointerest', 'CLICK_DL_draw_drawdown_infoschedule',
                          'CLICK_DL_draw_drawdown_back', 'CLICK_DL_draw_drawdown_allamount',
                          'CLICK_DL_draw_drawdown_faq', 'CLICK_DL_draw_drawdown_next')
      THEN 'drawdown'

      -- Loan Confirmation (5)
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

**Key Decisions**:
- Use exact event name matching (IN clause) vs LIKE patterns for precision
- Map based on Kak Zaki's official screen_numb mapping
- Category "other" captures unmapped events (FAQ clicks, back buttons, etc.)

### Final Aggregation: Stage Percentages

**Purpose**: Calculate distribution of events across journey stages per customer

```sql
SELECT
  customer_id,
  COUNT(*) AS total_events,
  ROUND(COUNTIF(stage_name = 'entry') * 100.0 / COUNT(*), 2) AS pct_entry,
  ROUND(COUNTIF(stage_name = 'loan_hub') * 100.0 / COUNT(*), 2) AS pct_loan_hub,
  ROUND(COUNTIF(stage_name = 'landing') * 100.0 / COUNT(*), 2) AS pct_landing,
  ROUND(COUNTIF(stage_name = 'drawdown') * 100.0 / COUNT(*), 2) AS pct_drawdown,
  ROUND(COUNTIF(stage_name = 'confirmation') * 100.0 / COUNT(*), 2) AS pct_confirmation,
  ROUND(COUNTIF(stage_name = 'pii') * 100.0 / COUNT(*), 2) AS pct_pii,
  ROUND(COUNTIF(stage_name = 'agreement') * 100.0 / COUNT(*), 2) AS pct_agreement,
  ROUND(COUNTIF(stage_name = 'other') * 100.0 / COUNT(*), 2) AS pct_other
FROM events_stage
GROUP BY customer_id
ORDER BY customer_id
```

**Output**: One row per customer with percentage breakdown

---

## Key Technical Challenges & Solutions

### Challenge 1: Partitioned Table Requirement

**Problem**: `clevertap_user_events` is partitioned by DATE(time), query will fail without date filter

**Solution**: Add broad partition filter `DATE(time) BETWEEN '2025-01-01' AND '2025-07-31'` to satisfy partition requirement while capturing complete customer journeys

**Why Broad Range**: Some customers may have created loan applications in June 2025 but agreed in July 2025, so we need events from before July

---

### Challenge 2: TIMESTAMP vs DATE Comparison

**Problem**: `agreement_agreed_at` is TIMESTAMP, dates need proper comparison format

**Solution**:
- Use explicit TIMESTAMP format: `agreement_agreed_at >= '2025-07-01 00:00:00'`
- End boundary uses next month start: `agreement_agreed_at < '2025-08-01 00:00:00'`
- This captures all events on July 31st up to 23:59:59

---

### Challenge 3: Customer Time Window Filtering

**Problem**: Need events only between customer's application creation and agreement acceptance

**Solution**: Two-level filtering:
1. Broad partition filter for table access
2. Customer-specific filter: `DATE(ct.time) >= bc.created_at AND ct.time <= bc.agreement_agreed_at`

**Trade-off**: Using DATE() for created_at (day precision) and TIMESTAMP for agreement_agreed_at (second precision) provides proper boundary handling

---

### Challenge 4: Event Anomalies

**Observation**: Customer TRGW8QXQ9P showed `TEXT_DL_draw_drawdown_amount` (stage 4) before `INIT_DL_draw_agreement` (stage 7)

**Implication**: Users may not follow linear stage progression

**Decision**: Map events to stages based on event name regardless of temporal order. Stage classification is by event type, not sequence.

**Follow-up**: Research question for Mas Jaki to understand expected vs actual user paths

---

## Sample Customer Analysis

### Customer: TRGW8QXQ9P

**Profile**:
- `created_at`: 2025-07-03
- `agreement_agreed_at`: 2025-07-07 14:36:30
- `flag_takeup`: 1 (successful)
- First event: `CLICK_DL_entry_home_shortcut` at 2025-07-07 08:01:47
- Total DL events: 900+ events over ~6.5 hours

**Journey Duration**: ~6 hours 35 minutes from first event to agreement

**Use Case**: High-engagement customer useful for understanding complete successful journey patterns

---

## Data Validation

### Customer-Event Overlap Check

**Query Used**:
```sql
SELECT COUNT(DISTINCT c.customer_id) AS overlapping_customers
FROM `data-prd-adhoc.temp_ammar.ammar_customer_loan_details` c
INNER JOIN `jago-bank-data-production.risk_datamart.clevertap_user_events` ct
  ON c.customer_id = ct.customer_id
WHERE c.flag_takeup = 1
  AND c.is_new_offer = 1
  AND (c.agreement_agreed_at >= '2025-07-01 00:00:00'
       AND c.agreement_agreed_at < '2025-08-01 00:00:00')
```

**Result**: 3,058 customers with both loan records and CleverTap events

**Validation**: Confirmed INNER JOIN approach will produce meaningful dataset

---

## Expected Outputs

### Per-Customer Metrics

| Column | Description | Data Type |
|--------|-------------|-----------|
| customer_id | Unique customer identifier | STRING |
| total_events | Count of all DL events in journey | INTEGER |
| pct_entry | % of events in Entry stage | FLOAT (rounded to 2 decimals) |
| pct_loan_hub | % of events in Loan Hub stage | FLOAT (rounded to 2 decimals) |
| pct_landing | % of events in Landing stage | FLOAT (rounded to 2 decimals) |
| pct_drawdown | % of events in Drawdown stage | FLOAT (rounded to 2 decimals) |
| pct_confirmation | % of events in Confirmation stage | FLOAT (rounded to 2 decimals) |
| pct_pii | % of events in PII stage | FLOAT (rounded to 2 decimals) |
| pct_agreement | % of events in Agreement stage | FLOAT (rounded to 2 decimals) |
| pct_other | % of events not mapped to stages 1-7 | FLOAT (rounded to 2 decimals) |

### Analysis Applications

1. **Baseline Successful Journey Pattern**: Understand typical stage distribution for customers who complete loans
2. **Drop-off Analysis (Future)**: Compare successful vs failed customer stage patterns
3. **Stage Engagement**: Identify which stages require most customer interaction
4. **Journey Optimization**: Find stages with excessive friction (high event counts, long duration)

---

## Future Enhancements

### Planned Additions

1. **Window Functions**: Add cumulative_events, time_from_start, stage_sequence columns (currently not implemented)
2. **Failed Customer Comparison**: Analyze customers with flag_takeup = 0 to identify drop-off patterns
3. **Carry-Over vs New Offer**: Compare journey patterns between customer segments
4. **Time-Based Analysis**: Calculate minutes spent per stage
5. **Session Analysis**: Track session breaks and return patterns

---

## References

### Event Mapping Source
- **Source**: Kak Zaki's screen_numb mapping
- **Coverage**: 58 distinct DL event types identified in July 2025 data
- **Stages Mapped**: 1-11 (Entry through Success/Failure)

### Related Documentation
- `Propensity_Model_Feature_Analysis_Knowledge_Base.md` - Propensity model work (separate project)
- `Data_Analysis_Flow_Guide_Bank_Jago.md` - SQL best practices and CTE structure guidelines

---

## Query Execution Notes

### Performance Considerations

- **Partition Pruning**: DATE(time) filter ensures only necessary partitions are scanned
- **INNER JOIN**: Reduces dataset to customers with events, improving efficiency
- **CTE Structure**: Enables query optimization and readability

### Best Practices Applied

✅ Use explicit column selection (no SELECT *)
✅ Filter early in CTEs (base_customer filters before JOIN)
✅ Use INNER JOIN for required relationships
✅ Apply partition filters for partitioned tables
✅ Use TIMESTAMP precision for temporal boundaries
✅ Round percentages to 2 decimal places for readability
✅ Order final output for consistent results

---

## Document Metadata

**Version**: 1.0
**Created**: 2025-10-01
**Status**: Active Development
**Next Review**: After initial query results analysis

---

## Glossary

- **CleverTap**: Mobile analytics platform tracking user interactions
- **DL**: Direct Lending product
- **flag_takeup**: Binary indicator of successful loan disbursement
- **agreement_agreed_at**: Timestamp when customer accepted loan terms
- **Partition**: BigQuery table organization strategy for query performance
- **CTE**: Common Table Expression, temporary named result set in SQL
- **Stage**: Defined step in loan application journey (Entry → Agreement)
