# [WIKI] Loan Offer Notification Strategy Analysis

**Version**: 1.0
**Date**: September 23, 2025
**Analyst**: Ammar Siregar
**Stakeholder**: Subhan, Zaki

---

## 1. Objective

The primary objective of this analysis was to validate and understand the communication strategy for the Direct Lending loan offers. The analysis focused on answering the following questions posed by the mentor:
- When did App, Email, and WA notifications begin?
- What is the difference in treatment for "New Offer" vs. "Carry-Over" whitelisted customers?
- What is the timing and frequency of these notifications relative to the offer creation date?
- How do customers respond to these notifications?

The methodology followed the mentor's guidance to start with high-level summaries and then drill down into detailed "eyeball analysis" of sample customer journeys.

---

## 2. Summary of Findings (TL;DR)

1.  **Two Distinct Strategies Confirmed**: There is a clear, deliberate difference in strategy for the two cohorts.
    *   **New Offer Cohort**: Receives a high-density **"Burst"** of notifications across multiple app channels starting almost immediately (2-5 days) after the offer is created.
    *   **Carry-Over Cohort**: Is placed in a long-term **"Drip"** campaign, receiving notifications over a period of 3+ months to nurture and re-engage them.

2.  **"New Offer" Customers Are More Responsive**: The aggregate analysis showed that customers in the "New Offer" cohort have a significantly higher Click-Through Rate (CTR) on all notification types compared to the "Carry-Over" cohort.

3.  **A "No Notification" Gap Exists**: A key finding was that some customers flagged as "New Offer" (e.g., `0000075595`) receive **zero notifications** from the campaigns we analyzed. This represents a potential gap in the communication strategy.

4.  **Channel Start Dates**:
    *   **App Notifications** (Push, Bell, In-App) began on **March 1st, 2025**.
    *   **Email Notifications** began on **July 21st, 2025**.

5.  **No Evidence of WA Notifications**: We found no evidence of "WhatsApp" as a channel in the `jago_clevertap.journey_notifications` table within the relevant campaigns.

---

## 3. Analytical Workflow & Key Queries

The analysis followed an iterative, "simple-to-complex" flow.

### Step 1: High-Level Channel Analysis

We first identified all available channels and their start dates.

```sql
-- Query 1: To find the start date of each channel
SELECT
    campaign_type,
    MIN(event_date) as first_event_date,
    COUNT(*) as total_events
FROM
    `jago-bank-data-production.jago_clevertap.journey_notifications`
WHERE
    UPPER(campaign_name) LIKE ANY ('%DL%', '%JDC%')
    AND event_date >= '2025-03-01'
GROUP BY
    campaign_type;
```

### Step 2: Eyeball Validation with Sample Customers

Following the mentor's guidance, we selected two sample customers to represent each cohort and generated two detailed tables for analysis.

*   **New Offer Sample**: `0039780517`
*   **Carry-Over Sample**: `0000032148`

#### Output 1: `data offer`
This table shows the core offer details for the sample customers.

| business_date | customer_id | offer_flag | created_at | expires_at | start_facility_date |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 2025-08-31 | 0039780517 | New Offer | 2025-08-04 | 2025-09-05 | *null* |
| 2025-08-31 | 0000032148 | Carry-Over | 2025-05-02 | 2025-08-05 | *null* |

#### Output 2: `data apps notif` & `data mail notif`
These tables show the detailed notification log for each customer, enriched with the distance from offer creation (`jarak`) and a `check_column` to validate if the notification was within the offer period.

| notification_date | customer_id | event_details | check_column | days_from_offer_to_notification |
| :--- | :--- | :--- | :--- | :--- |
| 2025-05-07 | 0000032148 | ...IntroJDC_3PM | In Offer Period | 5 |
| ... | ... | ... | ... | ... |
| 2025-08-06 | 0039780517 | ...IntroJDC | In Offer Period | 2 |
| ... | ... | ... | ... | ... |

### Step 3: Final Reusable Script

We consolidated all the logic into a single, flexible "master script" that allows for easy modification and re-running of the analysis for any of the three desired outputs.

```sql
-- =============================================================================
-- MASTER ANALYSIS SCRIPT: Offer & Notification Journeys
-- =============================================================================
-- This script contains all the logic for the 'data offer', 'data apps notif',
-- and 'data mail notif' outputs.
--
-- HOW TO USE:
-- 1. Modify the 'customers_to_analyze' CTE to select your customers.
-- 2. At the end of the script, uncomment and run ONLY ONE of the final
--    SELECT statements to get your desired output.
-- =============================================================================

WITH
-- -----------------------------------------------------------------------------
-- CONFIGURATION: Define which customers to analyze here
-- -----------------------------------------------------------------------------
customers_to_analyze AS (
    SELECT customer_id FROM `jago-bank-data-production.dwh_core.loan_offer_daily_snapshot`
    WHERE business_date = '2025-08-31'
    -- << To analyze specific customers, uncomment the line below and add IDs >>
    -- AND customer_id IN ('0039780517', '0000032148')
    GROUP BY customer_id
),

-- -----------------------------------------------------------------------------
-- CTE 1: LATEST OFFER DETAILS
-- -----------------------------------------------------------------------------
latest_offers AS (
    SELECT
        business_date,
        customer_id,
        created_at,
        expires_at,
        CASE
            WHEN DATE(created_at) < '2025-08-01' THEN 'Carry-Over'
            ELSE 'New Offer'
        END AS offer_flag
    FROM
        `jago-bank-data-production.dwh_core.loan_offer_daily_snapshot`
    WHERE
        business_date = '2025-08-31'
        AND last_day(CAST(expires_at AS date), MONTH) >= business_date
        AND offer_status NOT LIKE 'BLOCKED'
        AND (agreement_agreed_at IS NULL OR DATE(agreement_agreed_at) >= business_date)
    QUALIFY ROW_NUMBER() OVER(PARTITION BY customer_id ORDER BY created_at DESC) = 1
),

-- -----------------------------------------------------------------------------
-- CTE 2: FACILITY DETAILS
-- -----------------------------------------------------------------------------
facilities AS (
    SELECT
        cif AS customer_id,
        start_date
    FROM
        `jago-bank-data-production.one_reporting_views.master_loan_facility_report`
    WHERE
        business_date >= '2025-01-01'
    QUALIFY ROW_NUMBER() OVER(PARTITION BY cif ORDER BY start_date ASC) = 1
),

-- -----------------------------------------------------------------------------
-- CTE 3: NOTIFICATION LOG
-- -----------------------------------------------------------------------------
notifications AS (
    SELECT
        customer_id,
        event_date,
        campaign_name,
        campaign_type
    FROM
        `jago-bank-data-production.jago_clevertap.journey_notifications`
    WHERE
        event_date >= '2025-03-01'
        AND UPPER(campaign_name) LIKE ANY ('%DL%', '%JDC%')
)

-- =============================================================================
-- FINAL OUTPUTS: Choose ONE of the following SELECT statements to run
-- =============================================================================

-- >> OUTPUT 1: 'data offer'
/*
SELECT
    o.business_date, o.customer_id, o.offer_flag, CAST(o.created_at AS DATE) AS created_at,
    CAST(o.expires_at AS DATE) AS expires_at, f.start_date AS start_facility_date
FROM latest_offers o
LEFT JOIN facilities f ON o.customer_id = f.customer_id AND f.start_date >= DATE(o.created_at)
WHERE o.customer_id IN (SELECT customer_id FROM customers_to_analyze);
*/

-- >> OUTPUT 2: 'data apps notif'
/*
SELECT
    n.event_date AS notification_date, o.business_date, n.customer_id, n.campaign_name AS event_details,
    CASE WHEN n.event_date BETWEEN DATE(o.created_at) AND DATE(o.expires_at) THEN 'In Offer Period' ELSE 'Outside Offer Period' END AS check_column,
    DATE_DIFF(n.event_date, DATE(o.created_at), DAY) AS days_from_offer_to_notification
FROM notifications n INNER JOIN latest_offers o ON n.customer_id = o.customer_id
WHERE n.customer_id IN (SELECT customer_id FROM customers_to_analyze) AND n.campaign_type != 'Email'
ORDER BY n.customer_id, n.event_date;
*/

-- >> OUTPUT 3: 'data mail notif'
/*
SELECT
    n.event_date AS notification_date, o.business_date, n.customer_id, n.campaign_name AS event_details,
    DATE_DIFF(n.event_date, DATE(o.created_at), DAY) AS days_from_offer_to_notification
FROM notifications n INNER JOIN latest_offers o ON n.customer_id = o.customer_id
WHERE n.customer_id IN (SELECT customer_id FROM customers_to_analyze) AND n.campaign_type = 'Email'
ORDER BY n.customer_id, n.event_date;
*/
```

---

## 4. Open Questions & Next Steps

-   **WA Notifications**: A final investigation could be done to search for any other possible naming conventions for WhatsApp campaigns.
-   **Risk Grade Analysis**: The mentor's original request included checking alignment with risk grades. This analysis has not yet been performed.
-   **Formal Documentation**: This document can be finalized and shared with the relevant stakeholders.
