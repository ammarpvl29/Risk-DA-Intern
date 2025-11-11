-- =====================================================
-- PIVOT QUERIES FOR BANG GUSTIAN PRESENTATION
-- Using: data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025
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
FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`

UNION ALL

SELECT
    'Good Customers (flag_bad_customer = 0)' AS metric,
    COUNT(DISTINCT lfs_customer_id) AS value,
    ROUND(COUNT(DISTINCT lfs_customer_id) * 100.0 / (
        SELECT COUNT(DISTINCT lfs_customer_id)
        FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`
    ), 2) AS percentage
FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`
WHERE flag_bad_customer = 0

UNION ALL

SELECT
    'Bad Customers (flag_bad_customer = 1)' AS metric,
    COUNT(DISTINCT lfs_customer_id) AS value,
    ROUND(COUNT(DISTINCT lfs_customer_id) * 100.0 / (
        SELECT COUNT(DISTINCT lfs_customer_id)
        FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`
    ), 2) AS percentage
FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`
WHERE flag_bad_customer = 1

UNION ALL

SELECT
    'August 2025 Cohort' AS metric,
    COUNT(DISTINCT lfs_customer_id) AS value,
    ROUND(COUNT(DISTINCT lfs_customer_id) * 100.0 / (
        SELECT COUNT(DISTINCT lfs_customer_id)
        FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`
    ), 2) AS percentage
FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`
WHERE cohort_name = 'August 2025'

UNION ALL

SELECT
    'September 2025 Cohort' AS metric,
    COUNT(DISTINCT lfs_customer_id) AS value,
    ROUND(COUNT(DISTINCT lfs_customer_id) * 100.0 / (
        SELECT COUNT(DISTINCT lfs_customer_id)
        FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`
    ), 2) AS percentage
FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`
WHERE cohort_name = 'September 2025'

UNION ALL

SELECT
    'Average Plafond (IDR)' AS metric,
    ROUND(AVG(plafond), 0) AS value,
    NULL AS percentage
FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`

UNION ALL

SELECT
    'Average Collection Calls per Customer' AS metric,
    ROUND(AVG(pred_total_calls + manual_total_calls), 1) AS value,
    NULL AS percentage
FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`

UNION ALL

SELECT
    'Average Notifications per Customer' AS metric,
    ROUND(AVG(total_notif_sent), 1) AS value,
    NULL AS percentage
FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`

ORDER BY
    CASE metric
        WHEN 'Total Customers' THEN 1
        WHEN 'Good Customers (flag_bad_customer = 0)' THEN 2
        WHEN 'Bad Customers (flag_bad_customer = 1)' THEN 3
        WHEN 'August 2025 Cohort' THEN 4
        WHEN 'September 2025 Cohort' THEN 5
        WHEN 'Average Plafond (IDR)' THEN 6
        WHEN 'Average Collection Calls per Customer' THEN 7
        WHEN 'Average Notifications per Customer' THEN 8
    END;


-- =====================================================
-- QUERY 2: RECOVERY ANALYSIS BY COHORT
-- Simple recovery breakdown for bad customers
-- Copy to Google Sheets, no pivot needed
-- =====================================================

SELECT
    cohort_name,

    COUNT(DISTINCT lfs_customer_id) AS total_bad_customers,

    COUNTIF(acct_3dpd_max = 0) AS recovered_customers,
    COUNTIF(acct_3dpd_max > 0) AS still_delinquent_customers,

    ROUND(COUNTIF(acct_3dpd_max = 0) * 100.0 / COUNT(DISTINCT lfs_customer_id), 2) AS recovery_rate_pct,

    ROUND(AVG(CASE WHEN acct_3dpd_max = 0 THEN plafond END), 0) AS avg_plafond_recovered,
    ROUND(AVG(CASE WHEN acct_3dpd_max > 0 THEN plafond END), 0) AS avg_plafond_delinquent

FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`
WHERE flag_bad_customer = 1
GROUP BY cohort_name
ORDER BY cohort_name;


-- =====================================================
-- QUERY 3: PAYMENT OUTCOME BY COLLECTION CALL INTENSITY
-- PIVOT-READY: Shows if more calls = better payment rate
-- Paste in Sheets → Insert Pivot Table
-- Rows: call_intensity | Columns: payment_outcome | Values: customer_count
-- =====================================================

SELECT
    -- Total calls (predictive + manual)
    CASE
        WHEN (pred_total_calls + manual_total_calls) = 0 THEN '0_No_Calls'
        WHEN (pred_total_calls + manual_total_calls) BETWEEN 1 AND 10 THEN '1_Low (1-10 calls)'
        WHEN (pred_total_calls + manual_total_calls) BETWEEN 11 AND 50 THEN '2_Medium (11-50 calls)'
        WHEN (pred_total_calls + manual_total_calls) BETWEEN 51 AND 100 THEN '3_High (51-100 calls)'
        WHEN (pred_total_calls + manual_total_calls) > 100 THEN '4_Very_High (100+ calls)'
    END AS call_intensity,

    CASE
        WHEN acct_3dpd_max = 0 THEN 'Paid'
        WHEN acct_3dpd_max > 0 THEN 'Delinquent'
        ELSE 'Unknown'
    END AS payment_outcome,

    CASE
        WHEN flag_bad_customer = 1 THEN 'Bad_Customer'
        ELSE 'Good_Customer'
    END AS customer_type,

    cohort_name,

    -- Metrics
    COUNT(DISTINCT lfs_customer_id) AS customer_count,
    ROUND(AVG(pred_total_calls + manual_total_calls), 1) AS avg_total_calls,
    ROUND(AVG(pred_unsuccessful_call + manual_unsuccessful_call), 1) AS avg_no_answer_calls,
    ROUND(AVG(rpc_total_calls), 1) AS avg_rpc_calls,
    ROUND(AVG(plafond), 0) AS avg_plafond

FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`
GROUP BY call_intensity, payment_outcome, customer_type, cohort_name
ORDER BY call_intensity, payment_outcome, customer_type, cohort_name;


-- =====================================================
-- QUERY 4: PAYMENT OUTCOME BY NOTIFICATION INTENSITY
-- PIVOT-READY: Shows notification effectiveness
-- Paste in Sheets → Insert Pivot Table
-- Rows: notification_intensity | Columns: payment_outcome | Values: customer_count
-- =====================================================

SELECT
    CASE
        WHEN total_notif_sent = 0 THEN '0_No_Notifications'
        WHEN total_notif_sent BETWEEN 1 AND 2 THEN '1_Low (1-2 notif)'
        WHEN total_notif_sent BETWEEN 3 AND 5 THEN '2_Medium (3-5 notif)'
        WHEN total_notif_sent > 5 THEN '3_High (5+ notif)'
    END AS notification_intensity,

    CASE
        WHEN acct_3dpd_max = 0 THEN 'Paid'
        WHEN acct_3dpd_max > 0 THEN 'Delinquent'
        ELSE 'Unknown'
    END AS payment_outcome,

    CASE
        WHEN flag_bad_customer = 1 THEN 'Bad_Customer'
        ELSE 'Good_Customer'
    END AS customer_type,

    cohort_name,

    -- Metrics
    COUNT(DISTINCT lfs_customer_id) AS customer_count,
    ROUND(AVG(total_notif_sent), 1) AS avg_notif_sent,
    ROUND(AVG(total_notif_read), 1) AS avg_notif_read,
    ROUND(AVG(total_notif_read) * 100.0 / NULLIF(AVG(total_notif_sent), 0), 1) AS read_rate_pct,
    ROUND(AVG(plafond), 0) AS avg_plafond

FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`
GROUP BY notification_intensity, payment_outcome, customer_type, cohort_name
ORDER BY notification_intensity, payment_outcome, customer_type, cohort_name;


-- =====================================================
-- QUERY 5: COMBINED CHANNEL STRATEGY EFFECTIVENESS ⭐
-- This is THE KEY ANALYSIS for your presentation!
-- PIVOT-READY: Multi-channel vs single-channel comparison
-- =====================================================

SELECT
    -- Channel strategy
    CASE
        WHEN (pred_total_calls + manual_total_calls) = 0 AND total_notif_sent = 0
            THEN '0_No_Activity'
        WHEN (pred_total_calls + manual_total_calls) > 0 AND total_notif_sent = 0
            THEN '1_Calls_Only'
        WHEN (pred_total_calls + manual_total_calls) = 0 AND total_notif_sent > 0
            THEN '2_Notifications_Only'
        WHEN (pred_total_calls + manual_total_calls) > 0 AND total_notif_sent > 0
            THEN '3_Multi_Channel'
    END AS channel_strategy,

    -- Engagement level (did they actually reach the customer?)
    CASE
        WHEN rpc_total_calls > 0 OR total_notif_read > 0 THEN 'Engaged'
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
        WHEN flag_bad_customer = 1 THEN 'Bad_Customer'
        ELSE 'Good_Customer'
    END AS customer_type,

    cohort_name,

    -- Metrics
    COUNT(DISTINCT lfs_customer_id) AS customer_count,

    -- Payment rate (KEY METRIC!)
    ROUND(COUNTIF(acct_3dpd_max = 0) * 100.0 / COUNT(DISTINCT lfs_customer_id), 1) AS payment_rate_pct,

    -- Average activities
    ROUND(AVG(pred_total_calls + manual_total_calls), 1) AS avg_calls,
    ROUND(AVG(total_notif_sent), 1) AS avg_notifications,
    ROUND(AVG(rpc_total_calls), 1) AS avg_rpc_calls,
    ROUND(AVG(total_notif_read), 1) AS avg_notif_read,

    ROUND(AVG(plafond), 0) AS avg_plafond

FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`
GROUP BY channel_strategy, engagement_level, payment_outcome, customer_type, cohort_name
ORDER BY channel_strategy, engagement_level, payment_outcome, customer_type, cohort_name;


-- =====================================================
-- QUERY 6: RECOVERY RATE BY COLLECTION INTENSITY
-- For BAD CUSTOMERS ONLY - shows collection effectiveness
-- PIVOT-READY: Simple and powerful
-- =====================================================

SELECT
    CASE
        WHEN (pred_total_calls + manual_total_calls) = 0 THEN '0_No_Calls'
        WHEN (pred_total_calls + manual_total_calls) BETWEEN 1 AND 10 THEN '1_Low (1-10)'
        WHEN (pred_total_calls + manual_total_calls) BETWEEN 11 AND 50 THEN '2_Medium (11-50)'
        WHEN (pred_total_calls + manual_total_calls) > 50 THEN '3_High (50+)'
    END AS collection_intensity,

    cohort_name,

    COUNT(DISTINCT lfs_customer_id) AS total_bad_customers,
    COUNTIF(acct_3dpd_max = 0) AS recovered_customers,
    COUNTIF(acct_3dpd_max > 0) AS still_delinquent,

    ROUND(COUNTIF(acct_3dpd_max = 0) * 100.0 / COUNT(DISTINCT lfs_customer_id), 1) AS recovery_rate_pct,

    -- Average collection activities for recovered vs delinquent
    ROUND(AVG(CASE WHEN acct_3dpd_max = 0 THEN pred_total_calls + manual_total_calls END), 1)
        AS avg_calls_recovered,
    ROUND(AVG(CASE WHEN acct_3dpd_max > 0 THEN pred_total_calls + manual_total_calls END), 1)
        AS avg_calls_delinquent,

    -- RPC (Right Party Contact) comparison
    ROUND(AVG(CASE WHEN acct_3dpd_max = 0 THEN rpc_total_calls END), 1) AS avg_rpc_recovered,
    ROUND(AVG(CASE WHEN acct_3dpd_max > 0 THEN rpc_total_calls END), 1) AS avg_rpc_delinquent

FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`
WHERE flag_bad_customer = 1
GROUP BY collection_intensity, cohort_name
ORDER BY collection_intensity, cohort_name;


-- =====================================================
-- QUERY 7: RPC (RIGHT PARTY CONTACT) EFFECTIVENESS
-- Shows if actually reaching the customer matters
-- PIVOT-READY
-- =====================================================

SELECT
    CASE
        WHEN rpc_total_calls = 0 THEN '0_No_RPC'
        WHEN rpc_total_calls BETWEEN 1 AND 5 THEN '1_Low_RPC (1-5)'
        WHEN rpc_total_calls BETWEEN 6 AND 15 THEN '2_Medium_RPC (6-15)'
        WHEN rpc_total_calls > 15 THEN '3_High_RPC (15+)'
    END AS rpc_intensity,

    CASE
        WHEN acct_3dpd_max = 0 THEN 'Paid'
        WHEN acct_3dpd_max > 0 THEN 'Delinquent'
        ELSE 'Unknown'
    END AS payment_outcome,

    CASE
        WHEN flag_bad_customer = 1 THEN 'Bad_Customer'
        ELSE 'Good_Customer'
    END AS customer_type,

    cohort_name,

    COUNT(DISTINCT lfs_customer_id) AS customer_count,
    ROUND(COUNTIF(acct_3dpd_max = 0) * 100.0 / COUNT(DISTINCT lfs_customer_id), 1) AS payment_rate_pct,

    ROUND(AVG(rpc_total_calls), 1) AS avg_rpc_calls,
    ROUND(AVG(pred_total_calls + manual_total_calls), 1) AS avg_total_calls,

    -- RPC rate (what % of calls were successful RPC?)
    ROUND(AVG(rpc_total_calls) * 100.0 / NULLIF(AVG(pred_total_calls + manual_total_calls), 0), 1)
        AS rpc_success_rate_pct

FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`
GROUP BY rpc_intensity, payment_outcome, customer_type, cohort_name
ORDER BY rpc_intensity, payment_outcome, customer_type, cohort_name;


-- =====================================================
-- QUERY 8: NOTIFICATION READ RATE IMPACT
-- Does reading notifications correlate with payment?
-- PIVOT-READY
-- =====================================================

SELECT
    CASE
        WHEN total_notif_sent = 0 THEN '0_No_Notifications'
        WHEN total_notif_sent > 0 AND total_notif_read = 0 THEN '1_Sent_Not_Read'
        WHEN total_notif_read > 0 AND total_notif_read < total_notif_sent THEN '2_Partially_Read'
        WHEN total_notif_read > 0 AND total_notif_read = total_notif_sent THEN '3_Fully_Read'
    END AS notification_engagement,

    CASE
        WHEN acct_3dpd_max = 0 THEN 'Paid'
        WHEN acct_3dpd_max > 0 THEN 'Delinquent'
        ELSE 'Unknown'
    END AS payment_outcome,

    CASE
        WHEN flag_bad_customer = 1 THEN 'Bad_Customer'
        ELSE 'Good_Customer'
    END AS customer_type,

    cohort_name,

    COUNT(DISTINCT lfs_customer_id) AS customer_count,
    ROUND(COUNTIF(acct_3dpd_max = 0) * 100.0 / COUNT(DISTINCT lfs_customer_id), 1) AS payment_rate_pct,

    ROUND(AVG(total_notif_sent), 1) AS avg_notif_sent,
    ROUND(AVG(total_notif_read), 1) AS avg_notif_read,
    ROUND(AVG(total_notif_read) * 100.0 / NULLIF(AVG(total_notif_sent), 0), 1) AS read_rate_pct

FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`
GROUP BY notification_engagement, payment_outcome, customer_type, cohort_name
ORDER BY notification_engagement, payment_outcome, customer_type, cohort_name;


-- =====================================================
-- QUERY 9: CALL TIMING EFFECTIVENESS
-- Before vs After due date - which is more effective?
-- =====================================================

SELECT
    cohort_name,

    CASE
        WHEN flag_bad_customer = 1 THEN 'Bad_Customer'
        ELSE 'Good_Customer'
    END AS customer_type,

    CASE
        WHEN acct_3dpd_max = 0 THEN 'Paid'
        WHEN acct_3dpd_max > 0 THEN 'Delinquent'
        ELSE 'Unknown'
    END AS payment_outcome,

    COUNT(DISTINCT lfs_customer_id) AS customer_count,
    ROUND(COUNTIF(acct_3dpd_max = 0) * 100.0 / COUNT(DISTINCT lfs_customer_id), 1) AS payment_rate_pct,

    -- Average calls by timing
    ROUND(AVG(CASE
        WHEN first_call_before_due IS NOT NULL THEN pred_total_calls + manual_total_calls
    END), 1) AS avg_calls_customers_with_early_calls,

    ROUND(AVG(CASE
        WHEN first_call_before_due IS NULL AND first_call_after_due IS NOT NULL
        THEN pred_total_calls + manual_total_calls
    END), 1) AS avg_calls_customers_with_only_late_calls,

    -- Days difference analysis
    ROUND(AVG(diff_first_call_and_before_due), 1) AS avg_days_before_due,
    ROUND(AVG(diff_first_call_and_after_due), 1) AS avg_days_after_due,

    -- Count of customers by timing
    COUNTIF(first_call_before_due IS NOT NULL) AS customers_with_calls_before_due,
    COUNTIF(first_call_after_due IS NOT NULL AND first_call_before_due IS NULL)
        AS customers_with_only_calls_after_due

FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`
GROUP BY cohort_name, customer_type, payment_outcome
ORDER BY cohort_name, customer_type, payment_outcome;


-- =====================================================
-- QUERY 10: PREDICTIVE VS MANUAL DIALER COMPARISON
-- Which dialer strategy is more effective?
-- =====================================================

SELECT
    CASE
        WHEN pred_total_calls = 0 AND manual_total_calls = 0 THEN '0_No_Calls'
        WHEN pred_total_calls > 0 AND manual_total_calls = 0 THEN '1_Predictive_Only'
        WHEN pred_total_calls = 0 AND manual_total_calls > 0 THEN '2_Manual_Only'
        WHEN pred_total_calls > 0 AND manual_total_calls > 0 THEN '3_Both'
    END AS dialer_strategy,

    CASE
        WHEN acct_3dpd_max = 0 THEN 'Paid'
        WHEN acct_3dpd_max > 0 THEN 'Delinquent'
        ELSE 'Unknown'
    END AS payment_outcome,

    CASE
        WHEN flag_bad_customer = 1 THEN 'Bad_Customer'
        ELSE 'Good_Customer'
    END AS customer_type,

    cohort_name,

    COUNT(DISTINCT lfs_customer_id) AS customer_count,
    ROUND(COUNTIF(acct_3dpd_max = 0) * 100.0 / COUNT(DISTINCT lfs_customer_id), 1) AS payment_rate_pct,

    ROUND(AVG(pred_total_calls), 1) AS avg_predictive_calls,
    ROUND(AVG(manual_total_calls), 1) AS avg_manual_calls,
    ROUND(AVG(pred_total_calls + manual_total_calls), 1) AS avg_total_calls,

    -- RPC rate by dialer type
    ROUND(AVG(rpc_total_calls) * 100.0 / NULLIF(AVG(pred_total_calls + manual_total_calls), 0), 1)
        AS rpc_success_rate_pct

FROM `data-prd-adhoc.temp_ammar.collection_notification_features_sept_2025`
GROUP BY dialer_strategy, payment_outcome, customer_type, cohort_name
ORDER BY dialer_strategy, payment_outcome, customer_type, cohort_name;
