-- =====================================================
-- PIVOT QUERIES FOR BANG GUSTIAN PRESENTATION
-- Run each query separately, copy results to Google Sheets
-- Then create pivot tables for visualization
-- =====================================================

-- =====================================================
-- QUERY 1: SUMMARY STATISTICS (For Tab 1 - Base/Populasi)
-- Copy this to Google Sheets, no pivot needed - just display as table
-- =====================================================

SELECT
    'Total Customers' AS metric,
    COUNT(DISTINCT lfs_customer_id) AS value,
    NULL AS percentage
FROM `data-prd-adhoc.temp_ammar.collection_analysis_aug_sept_2025_customers`

UNION ALL

SELECT
    'Good Customers (flag_bad_customer = 0)' AS metric,
    COUNT(DISTINCT lfs_customer_id) AS value,
    ROUND(COUNT(DISTINCT lfs_customer_id) * 100.0 / (
        SELECT COUNT(DISTINCT lfs_customer_id)
        FROM `data-prd-adhoc.temp_ammar.collection_analysis_aug_sept_2025_customers`
    ), 2) AS percentage
FROM `data-prd-adhoc.temp_ammar.collection_analysis_aug_sept_2025_customers`
WHERE flag_bad_customer = 0

UNION ALL

SELECT
    'Bad Customers (flag_bad_customer = 1)' AS metric,
    COUNT(DISTINCT lfs_customer_id) AS value,
    ROUND(COUNT(DISTINCT lfs_customer_id) * 100.0 / (
        SELECT COUNT(DISTINCT lfs_customer_id)
        FROM `data-prd-adhoc.temp_ammar.collection_analysis_aug_sept_2025_customers`
    ), 2) AS percentage
FROM `data-prd-adhoc.temp_ammar.collection_analysis_aug_sept_2025_customers`
WHERE flag_bad_customer = 1

UNION ALL

SELECT
    'August 2025 Cohort' AS metric,
    COUNT(DISTINCT lfs_customer_id) AS value,
    ROUND(COUNT(DISTINCT lfs_customer_id) * 100.0 / (
        SELECT COUNT(DISTINCT lfs_customer_id)
        FROM `data-prd-adhoc.temp_ammar.collection_analysis_aug_sept_2025_customers`
    ), 2) AS percentage
FROM `data-prd-adhoc.temp_ammar.collection_analysis_aug_sept_2025_customers`
WHERE cohort_name = 'August 2025'

UNION ALL

SELECT
    'September 2025 Cohort' AS metric,
    COUNT(DISTINCT lfs_customer_id) AS value,
    ROUND(COUNT(DISTINCT lfs_customer_id) * 100.0 / (
        SELECT COUNT(DISTINCT lfs_customer_id)
        FROM `data-prd-adhoc.temp_ammar.collection_analysis_aug_sept_2025_customers`
    ), 2) AS percentage
FROM `data-prd-adhoc.temp_ammar.collection_analysis_aug_sept_2025_customers`
WHERE cohort_name = 'September 2025'

UNION ALL

SELECT
    'Average Plafond (IDR)' AS metric,
    ROUND(AVG(plafond), 0) AS value,
    NULL AS percentage
FROM `data-prd-adhoc.temp_ammar.collection_analysis_aug_sept_2025_customers`

ORDER BY
    CASE metric
        WHEN 'Total Customers' THEN 1
        WHEN 'Good Customers (flag_bad_customer = 0)' THEN 2
        WHEN 'Bad Customers (flag_bad_customer = 1)' THEN 3
        WHEN 'August 2025 Cohort' THEN 4
        WHEN 'September 2025 Cohort' THEN 5
        WHEN 'Average Plafond (IDR)' THEN 6
    END;


-- =====================================================
-- QUERY 2: RECOVERY ANALYSIS (For Tab 4 - Short Analysis)
-- Shows bad customers who recovered vs still delinquent
-- Copy to Google Sheets, create pivot with recovery_status as rows
-- =====================================================

SELECT
    CASE
        WHEN acct_3dpd_max = 0 THEN 'Recovered (Paid on Time)'
        WHEN acct_3dpd_max > 0 THEN 'Still Delinquent'
        ELSE 'Unknown'
    END AS recovery_status,
    COUNT(DISTINCT lfs_customer_id) AS customer_count,
    ROUND(COUNT(DISTINCT lfs_customer_id) * 100.0 / SUM(COUNT(DISTINCT lfs_customer_id)) OVER(), 2) AS percentage,
    ROUND(AVG(plafond), 0) AS avg_plafond,
    cohort_name
FROM `data-prd-adhoc.temp_ammar.collection_analysis_aug_sept_2025_customers`
WHERE flag_bad_customer = 1  -- Only bad customers
GROUP BY recovery_status, cohort_name
ORDER BY cohort_name, recovery_status;


-- =====================================================
-- QUERY 3: PAYMENT OUTCOME BY COLLECTION CALL INTENSITY
-- This is PIVOT-READY: Paste in Sheets, then Pivot
-- Rows: call_intensity | Columns: payment_outcome | Values: COUNT
-- =====================================================

WITH aggregated AS (
    SELECT
        lfs_customer_id,
        deal_reference,
        flag_bad_customer,
        acct_3dpd_max,
        cohort_name,

        -- Aggregate collection calls from collection_detail
        COALESCE(SUM(CASE WHEN status = 'NO_ANSWER' THEN 1 ELSE 0 END), 0) AS calls_no_answer,
        COALESCE(SUM(CASE WHEN status = 'CONTACTED' THEN 1 ELSE 0 END), 0) AS calls_contacted,
        COALESCE(SUM(CASE WHEN status = 'PROMISE_TO_PAY' THEN 1 ELSE 0 END), 0) AS calls_ptp,
        COALESCE(COUNT(CASE WHEN collection_date <= due_date THEN 1 END), 0) AS calls_before_due,
        COALESCE(COUNT(CASE WHEN collection_date > due_date THEN 1 END), 0) AS calls_after_due,
        COALESCE(COUNT(*), 0) AS calls_total

    FROM (
        -- Base customers
        SELECT DISTINCT
            lfs_customer_id,
            deal_reference,
            flag_bad_customer,
            acct_3dpd_max,
            cohort_name,
            first_due_date AS due_date
        FROM `data-prd-adhoc.temp_ammar.collection_analysis_aug_sept_2025_customers`
    ) base

    LEFT JOIN (
        SELECT
            CAST(loan_id AS STRING) AS deal_reference,
            status,
            DATE(collection_date) AS collection_date
        FROM `jago-bank-data-production.digital_lending.digital_lending_collection_daily_report_vendor`
        WHERE business_date >= '2025-08-01'
        AND business_date <= CURRENT_DATE()
    ) collection
    ON base.deal_reference = collection.deal_reference

    GROUP BY 1,2,3,4,5
)

SELECT
    -- Call intensity buckets
    CASE
        WHEN calls_total = 0 THEN '0_No_Calls'
        WHEN calls_total BETWEEN 1 AND 10 THEN '1_Low (1-10 calls)'
        WHEN calls_total BETWEEN 11 AND 50 THEN '2_Medium (11-50 calls)'
        WHEN calls_total BETWEEN 51 AND 100 THEN '3_High (51-100 calls)'
        WHEN calls_total > 100 THEN '4_Very High (100+ calls)'
    END AS call_intensity,

    -- Payment outcome
    CASE
        WHEN acct_3dpd_max = 0 THEN 'Paid'
        WHEN acct_3dpd_max > 0 THEN 'Delinquent'
        ELSE 'Unknown'
    END AS payment_outcome,

    -- Customer type
    CASE
        WHEN flag_bad_customer = 1 THEN 'Bad Customer'
        ELSE 'Good Customer'
    END AS customer_type,

    cohort_name,

    -- Metrics
    COUNT(DISTINCT lfs_customer_id) AS customer_count,
    ROUND(AVG(calls_total), 1) AS avg_calls_total,
    ROUND(AVG(calls_no_answer), 1) AS avg_calls_no_answer,
    ROUND(AVG(calls_contacted), 1) AS avg_calls_contacted,
    ROUND(AVG(calls_before_due), 1) AS avg_calls_before_due,
    ROUND(AVG(calls_after_due), 1) AS avg_calls_after_due

FROM aggregated
GROUP BY call_intensity, payment_outcome, customer_type, cohort_name
ORDER BY call_intensity, payment_outcome, customer_type, cohort_name;


-- =====================================================
-- QUERY 4: PAYMENT OUTCOME BY NOTIFICATION INTENSITY
-- This is PIVOT-READY: Paste in Sheets, then Pivot
-- Rows: notification_intensity | Columns: payment_outcome | Values: COUNT
-- =====================================================

WITH notification_agg AS (
    SELECT
        lfs_customer_id,
        deal_reference,
        flag_bad_customer,
        acct_3dpd_max,
        cohort_name,

        -- Aggregate notifications
        COALESCE(COUNT(DISTINCT notification_id), 0) AS notification_total,
        COALESCE(SUM(CASE WHEN notification_status = 'READ' THEN 1 ELSE 0 END), 0) AS notification_read,
        COALESCE(SUM(CASE WHEN notification_status = 'UNREAD' THEN 1 ELSE 0 END), 0) AS notification_unread

    FROM (
        -- Base customers
        SELECT DISTINCT
            lfs_customer_id,
            deal_reference,
            flag_bad_customer,
            acct_3dpd_max,
            cohort_name,
            first_due_date AS due_date
        FROM `data-prd-adhoc.temp_ammar.collection_analysis_aug_sept_2025_customers`
    ) base

    LEFT JOIN (
        SELECT
            customer_id,
            notification_id,
            notification_status,
            REGEXP_EXTRACT(deep_link, r'accountId=(\d+)') AS deal_reference_extracted,
            DATE(notification_created_at) AS notification_date
        FROM `jago-bank-data-production.dwh_core.notification_current`
        WHERE business_date >= '2025-08-01'
        AND business_date <= CURRENT_DATE()
        AND deep_link IS NOT NULL
    ) notif
    ON base.lfs_customer_id = notif.customer_id
    AND base.deal_reference = notif.deal_reference_extracted

    GROUP BY 1,2,3,4,5
)

SELECT
    -- Notification intensity buckets
    CASE
        WHEN notification_total = 0 THEN '0_No_Notifications'
        WHEN notification_total BETWEEN 1 AND 2 THEN '1_Low (1-2 notif)'
        WHEN notification_total BETWEEN 3 AND 5 THEN '2_Medium (3-5 notif)'
        WHEN notification_total > 5 THEN '3_High (5+ notif)'
    END AS notification_intensity,

    -- Payment outcome
    CASE
        WHEN acct_3dpd_max = 0 THEN 'Paid'
        WHEN acct_3dpd_max > 0 THEN 'Delinquent'
        ELSE 'Unknown'
    END AS payment_outcome,

    -- Customer type
    CASE
        WHEN flag_bad_customer = 1 THEN 'Bad Customer'
        ELSE 'Good Customer'
    END AS customer_type,

    cohort_name,

    -- Metrics
    COUNT(DISTINCT lfs_customer_id) AS customer_count,
    ROUND(AVG(notification_total), 1) AS avg_notification_total,
    ROUND(AVG(notification_read), 1) AS avg_notification_read,
    ROUND(AVG(notification_unread), 1) AS avg_notification_unread,
    ROUND(AVG(notification_read) * 100.0 / NULLIF(AVG(notification_total), 0), 1) AS pct_read

FROM notification_agg
GROUP BY notification_intensity, payment_outcome, customer_type, cohort_name
ORDER BY notification_intensity, payment_outcome, customer_type, cohort_name;


-- =====================================================
-- QUERY 5: COMBINED CHANNEL EFFECTIVENESS
-- Multi-channel analysis: Calls + Notifications combined
-- This is PIVOT-READY for advanced analysis
-- =====================================================

WITH combined_channels AS (
    SELECT
        base.lfs_customer_id,
        base.deal_reference,
        base.flag_bad_customer,
        base.acct_3dpd_max,
        base.cohort_name,

        -- Collection calls
        COALESCE(COUNT(DISTINCT collection.collection_date), 0) AS calls_total,
        COALESCE(SUM(CASE WHEN collection.status = 'CONTACTED' THEN 1 ELSE 0 END), 0) AS calls_contacted,

        -- Notifications
        COALESCE(COUNT(DISTINCT notif.notification_id), 0) AS notification_total,
        COALESCE(SUM(CASE WHEN notif.notification_status = 'READ' THEN 1 ELSE 0 END), 0) AS notification_read

    FROM (
        SELECT DISTINCT
            lfs_customer_id,
            deal_reference,
            flag_bad_customer,
            acct_3dpd_max,
            cohort_name,
            first_due_date AS due_date
        FROM `data-prd-adhoc.temp_ammar.collection_analysis_aug_sept_2025_customers`
    ) base

    LEFT JOIN (
        SELECT
            CAST(loan_id AS STRING) AS deal_reference,
            status,
            DATE(collection_date) AS collection_date
        FROM `jago-bank-data-production.digital_lending.digital_lending_collection_daily_report_vendor`
        WHERE business_date >= '2025-08-01'
        AND business_date <= CURRENT_DATE()
    ) collection
    ON base.deal_reference = collection.deal_reference

    LEFT JOIN (
        SELECT
            customer_id,
            notification_id,
            notification_status,
            REGEXP_EXTRACT(deep_link, r'accountId=(\d+)') AS deal_reference_extracted
        FROM `jago-bank-data-production.dwh_core.notification_current`
        WHERE business_date >= '2025-08-01'
        AND business_date <= CURRENT_DATE()
        AND deep_link IS NOT NULL
    ) notif
    ON base.lfs_customer_id = notif.customer_id
    AND base.deal_reference = notif.deal_reference_extracted

    GROUP BY 1,2,3,4,5
)

SELECT
    -- Combined channel strategy
    CASE
        WHEN calls_total = 0 AND notification_total = 0 THEN '0_No_Activity'
        WHEN calls_total > 0 AND notification_total = 0 THEN '1_Calls_Only'
        WHEN calls_total = 0 AND notification_total > 0 THEN '2_Notifications_Only'
        WHEN calls_total > 0 AND notification_total > 0 THEN '3_Multi_Channel'
    END AS channel_strategy,

    -- Engagement level
    CASE
        WHEN calls_contacted > 0 OR notification_read > 0 THEN 'Engaged'
        ELSE 'Not_Engaged'
    END AS engagement_level,

    -- Payment outcome
    CASE
        WHEN acct_3dpd_max = 0 THEN 'Paid'
        WHEN acct_3dpd_max > 0 THEN 'Delinquent'
        ELSE 'Unknown'
    END AS payment_outcome,

    -- Customer type
    CASE
        WHEN flag_bad_customer = 1 THEN 'Bad Customer'
        ELSE 'Good Customer'
    END AS customer_type,

    cohort_name,

    -- Metrics
    COUNT(DISTINCT lfs_customer_id) AS customer_count,
    ROUND(AVG(calls_total), 1) AS avg_calls,
    ROUND(AVG(notification_total), 1) AS avg_notifications,
    ROUND(SUM(CASE WHEN acct_3dpd_max = 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 1) AS payment_rate_pct

FROM combined_channels
GROUP BY channel_strategy, engagement_level, payment_outcome, customer_type, cohort_name
ORDER BY channel_strategy, engagement_level, payment_outcome, customer_type, cohort_name;


-- =====================================================
-- QUERY 6: SIMPLE RECOVERY RATE BY COLLECTION INTENSITY
-- For bad customers only - easier to present
-- =====================================================

WITH collection_intensity AS (
    SELECT
        base.lfs_customer_id,
        base.acct_3dpd_max,
        base.cohort_name,
        COALESCE(COUNT(*), 0) AS calls_total
    FROM (
        SELECT DISTINCT
            lfs_customer_id,
            deal_reference,
            acct_3dpd_max,
            cohort_name
        FROM `data-prd-adhoc.temp_ammar.collection_analysis_aug_sept_2025_customers`
        WHERE flag_bad_customer = 1  -- Only bad customers
    ) base
    LEFT JOIN (
        SELECT
            CAST(loan_id AS STRING) AS deal_reference,
            DATE(collection_date) AS collection_date
        FROM `jago-bank-data-production.digital_lending.digital_lending_collection_daily_report_vendor`
        WHERE business_date >= '2025-08-01'
        AND business_date <= CURRENT_DATE()
    ) collection
    ON base.deal_reference = collection.deal_reference
    GROUP BY 1,2,3
)

SELECT
    CASE
        WHEN calls_total = 0 THEN '0_No_Calls'
        WHEN calls_total BETWEEN 1 AND 10 THEN '1_Low (1-10)'
        WHEN calls_total BETWEEN 11 AND 50 THEN '2_Medium (11-50)'
        WHEN calls_total > 50 THEN '3_High (50+)'
    END AS collection_intensity,

    cohort_name,

    COUNT(DISTINCT lfs_customer_id) AS total_bad_customers,
    SUM(CASE WHEN acct_3dpd_max = 0 THEN 1 ELSE 0 END) AS recovered_customers,
    SUM(CASE WHEN acct_3dpd_max > 0 THEN 1 ELSE 0 END) AS still_delinquent,

    ROUND(
        SUM(CASE WHEN acct_3dpd_max = 0 THEN 1 ELSE 0 END) * 100.0 /
        COUNT(DISTINCT lfs_customer_id),
        1
    ) AS recovery_rate_pct

FROM collection_intensity
GROUP BY collection_intensity, cohort_name
ORDER BY collection_intensity, cohort_name;
