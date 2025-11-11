/*
==============================================================================
Collection Analysis - Detail and Summary Tables
==============================================================================
Created: October 16, 2025
Analyst: Ammar Siregar
Purpose: Create detail and summary tables for collection effectiveness analysis
         following mentor's "eyeball first, don't aggregate" methodology

Based on: Mentor's audio summary requirements
Dependencies: collection_analysis_aug_sept_2025_customers (physical table)
==============================================================================
*/

-- ==============================================================================
-- TABLE 1: DETAIL TABLE (For Eyeballing Individual Customers)
-- ==============================================================================
-- One row per customer per call
-- Purpose: Manually inspect 5-10 customers before aggregating
-- Usage: Find patterns, inconsistencies, capacity planning issues

CREATE OR REPLACE TABLE `data-prd-adhoc.temp_ammar.collection_detail_per_customer` AS (
SELECT
    -- Customer Identifiers
    cust.lfs_customer_id,
    cust.id_number,
    cust.facility_reference,
    cust.deal_reference,

    -- Cohort Information
    cust.cohort_name,
    cust.cohort_month,
    cust.facility_start_date,

    -- Loan Details
    cust.day_maturity,
    cust.deal_type,
    cust.plafond,
    cust.partner_final,

    -- Customer Classification
    cust.flag_bad_customer,
    cust.flag_good_customer,

    -- Calculated Due Date
    DATE_ADD(
        DATE_ADD(cust.facility_start_date, INTERVAL 1 MONTH),
        INTERVAL cust.day_maturity DAY
    ) AS payment_due_date,

    -- Collection Call Details
    call.business_date AS call_date,
    call.date AS call_timestamp,
    call.dpd AS dpd_at_call,
    call.status AS call_status,
    call.person_contacted,
    call.collector,
    call.note AS call_note,

    -- Timing Analysis
    DATE_DIFF(
        call.business_date,
        DATE_ADD(DATE_ADD(cust.facility_start_date, INTERVAL 1 MONTH),
                INTERVAL cust.day_maturity DAY),
        DAY
    ) AS days_from_due_to_call,

    -- Call Timing Classification
    CASE
        WHEN call.business_date < DATE_ADD(DATE_ADD(cust.facility_start_date, INTERVAL 1 MONTH),
                                          INTERVAL cust.day_maturity DAY)
            THEN 'Before Due Date'
        WHEN call.business_date = DATE_ADD(DATE_ADD(cust.facility_start_date, INTERVAL 1 MONTH),
                                          INTERVAL cust.day_maturity DAY)
            THEN 'On Due Date'
        WHEN call.business_date BETWEEN
                DATE_ADD(DATE_ADD(cust.facility_start_date, INTERVAL 1 MONTH), INTERVAL cust.day_maturity DAY)
                AND DATE_ADD(DATE_ADD(DATE_ADD(cust.facility_start_date, INTERVAL 1 MONTH),
                                     INTERVAL cust.day_maturity DAY), INTERVAL 3 DAY)
            THEN '1-3 Days After Due'
        WHEN call.business_date BETWEEN
                DATE_ADD(DATE_ADD(DATE_ADD(cust.facility_start_date, INTERVAL 1 MONTH),
                                 INTERVAL cust.day_maturity DAY), INTERVAL 4 DAY)
                AND DATE_ADD(DATE_ADD(DATE_ADD(cust.facility_start_date, INTERVAL 1 MONTH),
                                     INTERVAL cust.day_maturity DAY), INTERVAL 7 DAY)
            THEN '4-7 Days After Due'
        WHEN call.business_date > DATE_ADD(DATE_ADD(DATE_ADD(cust.facility_start_date, INTERVAL 1 MONTH),
                                                    INTERVAL cust.day_maturity DAY), INTERVAL 7 DAY)
            THEN '7+ Days After Due'
        ELSE 'Unknown'
    END AS call_timing_bucket,

    -- Scoring Information (for context)
    cust.ews_calibrated_scores,
    cust.risk_group_hci,
    cust.score_TD

FROM `data-prd-adhoc.temp_ammar.collection_analysis_aug_sept_2025_customers` cust
LEFT JOIN `jago-bank-data-production.digital_lending.digital_lending_collection_daily_report_vendor` call
    ON cust.deal_reference = call.card_no
    -- Filter to calls made after loan origination
    AND call.business_date >= cust.facility_start_date
    -- Include calls up to 2 months after due date for full MOB 1 visibility
    AND call.business_date <= DATE_ADD(
        DATE_ADD(DATE_ADD(cust.facility_start_date, INTERVAL 1 MONTH),
                INTERVAL cust.day_maturity DAY),
        INTERVAL 60 DAY
    )

WHERE cust.day_maturity < 13

ORDER BY
    cust.cohort_name,
    cust.flag_bad_customer DESC,  -- Bad customers first
    cust.lfs_customer_id,
    call.business_date,
    call.date
);


-- ==============================================================================
-- TABLE 2: SUMMARY TABLE (Customer-Level Aggregated Metrics)
-- ==============================================================================
-- One row per customer
-- Purpose: Analyze collection effectiveness and consistency at customer level
-- Metrics: count_contact, count_no_answer, min/max contact dates

CREATE OR REPLACE TABLE `data-prd-adhoc.temp_ammar.collection_summary_per_customer` AS (
WITH detail_with_due AS (
    SELECT
        lfs_customer_id,
        id_number,
        cohort_name,
        cohort_month,
        facility_start_date,
        day_maturity,
        deal_type,
        plafond,
        partner_final,
        flag_bad_customer,
        flag_good_customer,
        DATE_ADD(
            DATE_ADD(facility_start_date, INTERVAL 1 MONTH),
            INTERVAL day_maturity DAY
        ) AS payment_due_date,
        call_date,
        call_status,
        dpd_at_call,
        days_from_due_to_call,
        call_timing_bucket,
        ews_calibrated_scores,
        risk_group_hci,
        score_TD
    FROM `data-prd-adhoc.temp_ammar.collection_detail_per_customer`
)

SELECT
    -- Customer Identifiers
    lfs_customer_id,
    id_number,
    cohort_name,
    cohort_month,
    facility_start_date,
    payment_due_date,
    day_maturity,
    deal_type,
    plafond,
    partner_final,

    -- Customer Classification
    flag_bad_customer,
    flag_good_customer,

    -- CORE METRICS (As requested by mentor)
    -- 1. Total Contact Attempts
    COUNT(call_date) AS count_contact,

    -- 2. Contact Status Breakdown
    COUNT(CASE WHEN call_status = 'No Answer' THEN 1 END) AS count_no_answer,
    COUNT(CASE WHEN call_status = 'Invalid number' THEN 1 END) AS count_invalid_number,
    COUNT(CASE WHEN call_status = 'Payment Plan' THEN 1 END) AS count_payment_plan,
    COUNT(CASE WHEN call_status = 'Promise to pay' THEN 1 END) AS count_promise_to_pay,
    COUNT(CASE WHEN call_status = 'Customer Unreachable' THEN 1 END) AS count_unreachable,

    -- 3. First and Last Contact Dates
    MIN(call_date) AS minimum_date_contact,
    MAX(call_date) AS maximum_date_contact,

    -- 4. Timing Analysis (compare contact timing vs due date)
    MIN(days_from_due_to_call) AS earliest_call_days_from_due,
    MAX(days_from_due_to_call) AS latest_call_days_from_due,
    AVG(days_from_due_to_call) AS avg_call_days_from_due,

    -- 5. Contact Coverage Metrics
    COUNT(CASE WHEN call_timing_bucket = 'Before Due Date' THEN 1 END) AS calls_before_due,
    COUNT(CASE WHEN call_timing_bucket = 'On Due Date' THEN 1 END) AS calls_on_due,
    COUNT(CASE WHEN call_timing_bucket = '1-3 Days After Due' THEN 1 END) AS calls_1_3_days_after,
    COUNT(CASE WHEN call_timing_bucket = '4-7 Days After Due' THEN 1 END) AS calls_4_7_days_after,
    COUNT(CASE WHEN call_timing_bucket = '7+ Days After Due' THEN 1 END) AS calls_7plus_days_after,

    -- 6. DPD at Contact
    MIN(dpd_at_call) AS min_dpd_at_call,
    MAX(dpd_at_call) AS max_dpd_at_call,
    AVG(dpd_at_call) AS avg_dpd_at_call,

    -- 7. Contact Effort Intensity
    COUNT(DISTINCT call_date) AS distinct_days_contacted,
    ROUND(COUNT(call_date) / NULLIF(COUNT(DISTINCT call_date), 0), 2) AS avg_calls_per_day,

    -- 8. No Answer Rate (Key Metric)
    ROUND(
        COUNT(CASE WHEN call_status = 'No Answer' THEN 1 END) * 100.0 /
        NULLIF(COUNT(call_date), 0),
        2
    ) AS no_answer_rate_pct,

    -- 9. Invalid Number Rate
    ROUND(
        COUNT(CASE WHEN call_status = 'Invalid number' THEN 1 END) * 100.0 /
        NULLIF(COUNT(call_date), 0),
        2
    ) AS invalid_number_rate_pct,

    -- 10. Contact Responsiveness (days between first call and due date)
    DATE_DIFF(MIN(call_date), payment_due_date, DAY) AS days_first_call_vs_due,

    -- Scoring Information
    ews_calibrated_scores,
    risk_group_hci,
    score_TD

FROM detail_with_due
GROUP BY
    lfs_customer_id,
    id_number,
    cohort_name,
    cohort_month,
    facility_start_date,
    payment_due_date,
    day_maturity,
    deal_type,
    plafond,
    partner_final,
    flag_bad_customer,
    flag_good_customer,
    ews_calibrated_scores,
    risk_group_hci,
    score_TD

ORDER BY
    cohort_name,
    flag_bad_customer DESC,
    count_contact DESC
);


-- ==============================================================================
-- VALIDATION QUERIES
-- ==============================================================================

-- Validate Detail Table Row Counts
SELECT
    'Detail Table Row Count' AS metric,
    COUNT(*) AS value
FROM `data-prd-adhoc.temp_ammar.collection_detail_per_customer`

UNION ALL

SELECT
    'Detail - Unique Customers' AS metric,
    COUNT(DISTINCT lfs_customer_id) AS value
FROM `data-prd-adhoc.temp_ammar.collection_detail_per_customer`

UNION ALL

-- Validate Summary Table Row Counts
SELECT
    'Summary Table Row Count' AS metric,
    COUNT(*) AS value
FROM `data-prd-adhoc.temp_ammar.collection_summary_per_customer`

UNION ALL

-- Check for customers with no calls
SELECT
    'Customers with No Calls' AS metric,
    COUNT(*) AS value
FROM `data-prd-adhoc.temp_ammar.collection_summary_per_customer`
WHERE count_contact = 0 OR count_contact IS NULL;


-- ==============================================================================
-- EYEBALLING QUERIES (For Manual Inspection)
-- ==============================================================================

-- Query 1: Sample 5 Bad Customers with Different Contact Patterns
-- Use this to manually inspect individual customer journeys
SELECT
    lfs_customer_id,
    cohort_name,
    payment_due_date,
    count_contact,
    count_no_answer,
    minimum_date_contact,
    maximum_date_contact,
    days_first_call_vs_due,
    no_answer_rate_pct
FROM `data-prd-adhoc.temp_ammar.collection_summary_per_customer`
WHERE flag_bad_customer = 1
ORDER BY count_contact DESC
LIMIT 5;

-- Query 2: Sample 5 Good Customers for Comparison
SELECT
    lfs_customer_id,
    cohort_name,
    payment_due_date,
    count_contact,
    count_no_answer,
    minimum_date_contact,
    maximum_date_contact,
    days_first_call_vs_due,
    no_answer_rate_pct
FROM `data-prd-adhoc.temp_ammar.collection_summary_per_customer`
WHERE flag_good_customer = 1
ORDER BY count_contact DESC
LIMIT 5;

-- Query 3: Detailed Call History for a Specific Customer
-- Replace 'CUSTOMER_ID_HERE' with actual customer ID from Query 1 or 2
/*
SELECT
    lfs_customer_id,
    payment_due_date,
    call_date,
    call_timestamp,
    dpd_at_call,
    call_status,
    days_from_due_to_call,
    call_timing_bucket,
    person_contacted,
    collector
FROM `data-prd-adhoc.temp_ammar.collection_detail_per_customer`
WHERE lfs_customer_id = 'CUSTOMER_ID_HERE'
ORDER BY call_date, call_timestamp;
*/


-- ==============================================================================
-- CAPACITY PLANNING ANALYSIS QUERIES
-- ==============================================================================

-- Query 4: Find Inconsistencies in Customer Treatment
-- Compare customers with same due date (same day_maturity) in same cohort
SELECT
    cohort_name,
    day_maturity,
    flag_bad_customer,
    COUNT(*) AS customer_count,
    AVG(count_contact) AS avg_calls_per_customer,
    MIN(count_contact) AS min_calls,
    MAX(count_contact) AS max_calls,
    STDDEV(count_contact) AS stddev_calls,
    AVG(days_first_call_vs_due) AS avg_days_first_call_vs_due
FROM `data-prd-adhoc.temp_ammar.collection_summary_per_customer`
GROUP BY cohort_name, day_maturity, flag_bad_customer
ORDER BY cohort_name, day_maturity;

-- Query 5: Identify Outliers (Capacity Planning Issues)
-- Customers with extremely high or low contact attempts
WITH stats AS (
    SELECT
        AVG(count_contact) AS mean_calls,
        STDDEV(count_contact) AS stddev_calls
    FROM `data-prd-adhoc.temp_ammar.collection_summary_per_customer`
    WHERE flag_bad_customer = 1
)

SELECT
    s.lfs_customer_id,
    s.cohort_name,
    s.payment_due_date,
    s.count_contact,
    s.days_first_call_vs_due,
    CASE
        WHEN s.count_contact > st.mean_calls + (2 * st.stddev_calls) THEN 'Very High Contact'
        WHEN s.count_contact < st.mean_calls - (2 * st.stddev_calls) THEN 'Very Low Contact'
        ELSE 'Normal'
    END AS contact_effort_category
FROM `data-prd-adhoc.temp_ammar.collection_summary_per_customer` s
CROSS JOIN stats st
WHERE s.flag_bad_customer = 1
    AND (s.count_contact > st.mean_calls + (2 * st.stddev_calls)
         OR s.count_contact < st.mean_calls - (2 * st.stddev_calls))
ORDER BY s.count_contact DESC;


-- ==============================================================================
-- BAD vs GOOD CUSTOMER COMPARISON
-- ==============================================================================

-- Query 6: Compare Collection Patterns - Bad vs Good Customers
SELECT
    cohort_name,
    flag_bad_customer,
    CASE WHEN flag_bad_customer = 1 THEN 'Bad Customer' ELSE 'Good Customer' END AS customer_type,
    COUNT(*) AS customer_count,

    -- Contact Metrics
    AVG(count_contact) AS avg_total_calls,
    AVG(count_no_answer) AS avg_no_answer_calls,
    AVG(count_invalid_number) AS avg_invalid_number_calls,
    AVG(count_payment_plan) AS avg_payment_plan_calls,

    -- Timing Metrics
    AVG(days_first_call_vs_due) AS avg_days_first_call_vs_due,
    AVG(distinct_days_contacted) AS avg_distinct_days_contacted,

    -- Rate Metrics
    AVG(no_answer_rate_pct) AS avg_no_answer_rate_pct,
    AVG(invalid_number_rate_pct) AS avg_invalid_number_rate_pct,

    -- Customers with No Calls
    COUNT(CASE WHEN count_contact = 0 OR count_contact IS NULL THEN 1 END) AS customers_not_contacted

FROM `data-prd-adhoc.temp_ammar.collection_summary_per_customer`
GROUP BY cohort_name, flag_bad_customer
ORDER BY cohort_name, flag_bad_customer DESC;
