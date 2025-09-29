# Notification Journey Analysis for New vs. Carry-over Loan Offers

**Version**: 1.0
**Date**: 2025-09-24
**Author**: Ammar Siregar (via Gemini Assistant)
**Status**: Completed

---

## 1. Objective

This analysis aims to compare the marketing notification journeys for two distinct customer segments:
1.  Customers receiving a **New Loan Offer**.
2.  Customers who have a **Carry-over Loan Offer** from a previous period.

The goal is to identify differences in marketing strategy, customer engagement, and derive actionable insights from a Risk Management perspective.

---

## 2. Methodology

The analysis was conducted by joining the master loan offer table (`data-prd-adhoc.temp_ammar.ammar_customer_loan_details`) with the notification events table (`jago-bank-data-production.jago_clevertap.journey_notifications`).

Two sample customers were selected for a detailed journey review based on the `business_date` of `2025-08-31`:
*   **New Offer Customer**: `XH6LV61SRJ`
*   **Carry-over Offer Customer**: `0451153832`

Calculated fields were created to categorize event types (`interaction`), communication channels (`comms_type`), and to measure the time between offer creation and the first/last notification (`diff_notif_first`, `diff_notif_last`).

---

## 3. Final Query

The following query was used to generate the final dataset for the analysis.

```sql
WITH offer AS (
  SELECT *
  FROM data-prd-adhoc.temp_ammar.ammar_customer_loan_details
  WHERE business_date = '2025-08-31'
)
,
notifications AS (
  SELECT n.* except (customer_id), o.*,
    CASE
      WHEN UPPER(n.event_name) LIKE '%SENT%' THEN '01. Sent'
      WHEN UPPER(n.event_name) LIKE ANY ('%VIEW%', '%IMPRESS%') THEN '02. View'
      WHEN UPPER(n.event_name) LIKE '%CLICK%' THEN '03. Click'
      ELSE '04. Other'
    END AS interaction,
    CASE
      WHEN n.campaign_type IN ('Mobile Push - Android', 'Mobile Push - iOS', 'Push') THEN 'Push Notif'
      WHEN n.campaign_type IN ('App Inbox', 'NotificationInbox') THEN 'Bell Notif'
      WHEN n.campaign_type = 'InApp' THEN 'In-App'
      WHEN n.campaign_type = 'Email' THEN 'Email'
      ELSE n.campaign_type
    END AS comms_type
  FROM
    `jago-bank-data-production.jago_clevertap.journey_notifications` n
    INNER JOIN offer o ON n.customer_id = o.customer_id
  WHERE
    (UPPER(n.campaign_name) LIKE '%DL%'
    OR UPPER(n.campaign_name) LIKE '%JDC%')
    AND n.event_date >= '2025-08-10'
)
,
notification_journeys AS (
  SELECT 
    *,
    MIN(event_date) OVER (PARTITION BY customer_id) as first_notification_date,
    MAX(event_date) OVER (PARTITION BY customer_id) as last_notification_date
  FROM notifications
  WHERE customer_id IN ('XH6LV61SRJ', '0451153832')
)

-- Final SELECT with the new date difference columns
SELECT 
  *,
  DATE_DIFF(first_notification_date, DATE(created_at), DAY) as diff_notif_first,
  DATE_DIFF(last_notification_date, DATE(created_at), DAY) as diff_notif_last
FROM notification_journeys
ORDER BY customer_id, event_date;
```

---

## 4. Analysis & Findings

### Journey of a "Carry-over Offer" Customer (`0451153832`)

*   **Channels**: Receives notifications via **Push Notif** and **Bell Notif**.
*   **Engagement**: The journey is limited to `Sent` -> `View`. This customer sees the notifications but does not actively click on them.
*   **Strategy**: Notably, this customer was targeted with a `BetterOffer_Retargeting_BetterOffer` campaign, indicating a specific strategy to re-engage hesitant customers.

### Journey of a "New Offer" Customer (`XH6LV61SRJ`)

*   **Channels**: Targeted across a wider range of channels: **Push Notif**, **Bell Notif**, and **In-App** messages.
*   **Engagement**: This customer shows a full-funnel journey: `Sent` -> `View` -> **`Click`**. The click event is a strong signal of high intent and engagement.
*   **Strategy**: The marketing strategy is more intensive, with a higher volume and variety of campaigns targeting the user at different points of the drop-off funnel.

---

## 5. Key Risk Insights

This analysis provides the following actionable insights for the Risk team:

1.  **Digital Engagement as a Potential Risk Proxy:**
    *   **Insight:** There is a clear difference in digital engagement between the segments.
    *   **Hypothesis:** Highly engaged customers (like the 'New Offer' example) may be more conscientious and represent a lower credit risk.
    *   **Recommendation:** Initiate an analysis to correlate historical marketing engagement levels with loan performance (e.g., default rates). This could become a valuable feature for risk modeling.

2.  **"Better Offer" Strategy and Potential Risk Layering:**
    *   **Insight:** The business uses "better offers" to convert hesitant, carry-over customers.
    *   **Hypothesis:** While this may increase take-up, giving more favorable terms (e.g., lower rate, higher principal) to initially hesitant customers may increase the overall risk profile of the portfolio.
    *   **Recommendation:** Isolate and monitor the performance of loans originating from these "better offer" campaigns. Compare their default rates and profitability against standard loan cohorts.

3.  **Marketing Spend vs. Profitability:**
    *   **Insight:** Significant marketing resources are used to target both segments.
    *   **Hypothesis:** The cost of acquiring a customer impacts the profitability of that loan. There may be a point of diminishing returns for marketing to unengaged customers.
    *   **Recommendation:** Analyze the cost-per-acquisition for each segment and weigh it against their risk profile and profitability. Determine if marketing efforts for low-engagement segments can be optimized to reduce costs without significantly impacting take-up rates.
