-- =====================================================================================
-- CUSTOMER LFS ONBOARDING ANALYSIS - September 2025
-- Bank Jago Risk Data Analyst Intern Task
-- =====================================================================================

-- TASK OVERVIEW:
-- 1. Total LFS customers onboarded in August 2025 (end of month)
-- 2. Total LFS customers onboarded in August 2025 (as of August 15)
-- 3. Journey analysis for one LFS customer onboarded August 10
-- 4. Total Bank Jago customers onboarded in August 2025 (end of month)
-- 5. Total Bank Jago customers by core banking (customer_source) August 2025
-- 6. Unique customers by id_number onboarded in August 2025
-- 7. Link customer and balance data using customer_id

-- =====================================================================================
-- TASK 1: Total LFS Customer Onboarding August 2025 (End of Month)
-- =====================================================================================

-- Question: Berapa total customer on boarding di bulan august 25, posisi akhir bulan? 
-- Untuk nasabah LFS Only

WITH lfs_onboarding_august AS (
    SELECT 
        customer_id,
        customer_source,
        customer_start_date,
        business_date,
        partner_name,
        customer_status
    FROM `data-prd-adhoc.credit_risk_adhoc.intern_data_mart_customer`
    WHERE business_date = '2025-08-31'  -- End of August 2025
      AND customer_source = 'LFS'       -- LFS customers only
      AND DATE_TRUNC(customer_start_date, MONTH) = '2025-08-01'  -- Onboarded in August 2025
      AND customer_status = 'ACTIVE'    -- Active customers only
)

SELECT 
    COUNT(DISTINCT customer_id) as total_lfs_customers_onboarded_august,
    MIN(customer_start_date) as earliest_onboarding_date,
    MAX(customer_start_date) as latest_onboarding_date,
    COUNT(DISTINCT partner_name) as number_of_partner_channels
FROM lfs_onboarding_august;

-- =====================================================================================
-- TASK 2: Total LFS Customer Onboarding August 15, 2025
-- =====================================================================================

-- Question: Berapa total customer on boarding di bulan august 25, posisi tanggal 15 August 2025? 
-- Untuk nasabah LFS Only

SELECT 
    COUNT(DISTINCT customer_id) as total_lfs_customers_onboarded_by_aug15,
    MIN(customer_start_date) as earliest_onboarding_date,
    MAX(customer_start_date) as latest_onboarding_date,
    COUNT(DISTINCT partner_name) as number_of_partner_channels,
    -- Daily breakdown
    COUNT(DISTINCT CASE WHEN customer_start_date BETWEEN '2025-08-01' AND '2025-08-07' THEN customer_id END) as week1_onboarding,
    COUNT(DISTINCT CASE WHEN customer_start_date BETWEEN '2025-08-08' AND '2025-08-15' THEN customer_id END) as week2_onboarding,
    -- Additional insight: Show distribution by onboarding date
    COUNT(DISTINCT CASE WHEN customer_start_date = '2025-08-01' THEN customer_id END) as aug01_onboarding,
    COUNT(DISTINCT CASE WHEN customer_start_date = '2025-08-02' THEN customer_id END) as aug02_onboarding,
    COUNT(DISTINCT CASE WHEN customer_start_date = '2025-08-03' THEN customer_id END) as aug03_onboarding,
    COUNT(DISTINCT CASE WHEN customer_start_date = '2025-08-04' THEN customer_id END) as aug04_onboarding,
    COUNT(DISTINCT CASE WHEN customer_start_date = '2025-08-05' THEN customer_id END) as aug05_onboarding,
    COUNT(DISTINCT CASE WHEN customer_start_date = '2025-08-10' THEN customer_id END) as aug10_onboarding,
    COUNT(DISTINCT CASE WHEN customer_start_date = '2025-08-15' THEN customer_id END) as aug15_onboarding
FROM `data-prd-adhoc.credit_risk_adhoc.intern_data_mart_customer`
WHERE business_date = '2025-08-31'  -- Use latest available snapshot
  AND customer_source = 'LFS'       -- LFS customers only
  AND customer_start_date BETWEEN '2025-08-01' AND '2025-08-15'  -- Onboarded by Aug 15 ONLY
  AND customer_status = 'ACTIVE';   -- Active customers only

-- =====================================================================================
-- TASK 3: Customer Journey Analysis - LFS Customer Onboarded August 10
-- =====================================================================================

-- Question: Ambil salah satu customer LFS yang onboarding date 10 Augustus, 
-- lihat journey setiap posisi bussdatenya

-- Step 3a: Find LFS customers onboarded on August 10, 2025
WITH customers_aug_10 AS (
    SELECT 
        customer_id,
        customer_source,
        customer_start_date,
        partner_name,
        main_account_number,
        customer_status
    FROM `data-prd-adhoc.credit_risk_adhoc.intern_data_mart_customer`
    WHERE customer_source = 'LFS'
      AND customer_start_date = '2025-08-10'
      AND business_date >= '2025-08-10'  -- Get latest state
    LIMIT 1  -- Pick one customer for analysis
)

-- Step 3b: Track customer journey across business dates
, customer_journey AS (
    SELECT 
        c.business_date,
        c.customer_id,
        c.customer_source,
        c.customer_start_date,
        c.customer_status,
        c.total_balance,
        c.customer_total_balance,
        c.balance_tier_description,
        c.partner_name,
        c.has_gopay_saving_account,
        c.has_mudharabah_account,
        c.age,
        c.customer_risk_status,
        -- Calculate days since onboarding
        DATE_DIFF(c.business_date, c.customer_start_date, DAY) as days_since_onboarding
    FROM `data-prd-adhoc.credit_risk_adhoc.intern_data_mart_customer` c
    WHERE c.customer_id IN (SELECT customer_id FROM customers_aug_10)
      AND c.business_date >= '2025-08-10'  -- From onboarding date forward
      AND c.business_date <= '2025-08-31'  -- Through end of August
    ORDER BY c.business_date
)

SELECT 
    business_date,
    customer_id,
    customer_status,
    total_balance,
    customer_total_balance,
    balance_tier_description,
    days_since_onboarding,
    customer_risk_status,
    -- Calculate balance changes
    LAG(total_balance) OVER (ORDER BY business_date) as previous_balance,
    total_balance - LAG(total_balance) OVER (ORDER BY business_date) as balance_change,
    -- Track product adoption
    has_gopay_saving_account,
    has_mudharabah_account
FROM customer_journey
ORDER BY business_date;

-- =====================================================================================
-- TASK 4: Total Bank Jago Customer Onboarding August 2025
-- =====================================================================================

-- Question: Berapa total customer on boarding di bulan august 25, posisi akhir bulan? 
-- Untuk semua nasabah bank jago

WITH all_jago_customers_august AS (
    SELECT 
        customer_id,
        customer_source,
        customer_start_date,
        business_date,
        partner_name,
        customer_status,
        business_unit
    FROM `data-prd-adhoc.credit_risk_adhoc.intern_data_mart_customer`
    WHERE business_date = '2025-08-31'  -- End of August 2025
      AND DATE_TRUNC(customer_start_date, MONTH) = '2025-08-01'  -- Onboarded in August 2025
      AND customer_status = 'ACTIVE'    -- Active customers only
)

SELECT 
    COUNT(DISTINCT customer_id) as total_jago_customers_onboarded_august,
    -- Breakdown by customer source (core banking)
    COUNT(DISTINCT CASE WHEN customer_source = 'LFS' THEN customer_id END) as lfs_customers,
    COUNT(DISTINCT CASE WHEN customer_source = 'WINCORE' THEN customer_id END) as wincore_customers,
    COUNT(DISTINCT CASE WHEN customer_source = 'OLIBS724' THEN customer_id END) as olibs_customers,
    -- Breakdown by business unit
    COUNT(DISTINCT CASE WHEN business_unit = 'Funding' THEN customer_id END) as funding_customers,
    COUNT(DISTINCT CASE WHEN business_unit = 'Lending' THEN customer_id END) as lending_customers,
    -- Partner breakdown
    COUNT(DISTINCT partner_name) as total_partner_channels,
    MIN(customer_start_date) as earliest_onboarding_date,
    MAX(customer_start_date) as latest_onboarding_date
FROM all_jago_customers_august;

-- =====================================================================================
-- TASK 5: Customer Onboarding by Core Banking (customer_source) 
-- =====================================================================================

-- Question: Berapa total customer on boarding di bulan august 25, posisi akhir bulan 
-- per core banking [customer_source]? Untuk semua nasabah bank jago

WITH customers_by_source_august AS (
    SELECT 
        customer_source,
        customer_id,
        customer_start_date,
        business_unit,
        partner_name,
        customer_status
    FROM `data-prd-adhoc.credit_risk_adhoc.intern_data_mart_customer`
    WHERE business_date = '2025-08-31'  -- End of August 2025
      AND DATE_TRUNC(customer_start_date, MONTH) = '2025-08-01'  -- Onboarded in August 2025
      AND customer_status = 'ACTIVE'    -- Active customers only
)

SELECT 
    customer_source,
    COUNT(DISTINCT customer_id) as customers_onboarded,
    ROUND(COUNT(DISTINCT customer_id) * 100.0 / SUM(COUNT(DISTINCT customer_id)) OVER(), 2) as percentage_share,
    -- Business unit breakdown per source
    COUNT(DISTINCT CASE WHEN business_unit = 'Funding' THEN customer_id END) as funding_customers,
    COUNT(DISTINCT CASE WHEN business_unit = 'Lending' THEN customer_id END) as lending_customers,
    -- Partner channels per source
    COUNT(DISTINCT partner_name) as partner_channels,
    STRING_AGG(DISTINCT partner_name, ', ') as partner_list,
    MIN(customer_start_date) as earliest_onboarding,
    MAX(customer_start_date) as latest_onboarding
FROM customers_by_source_august
GROUP BY customer_source
ORDER BY customers_onboarded DESC;

-- =====================================================================================
-- TASK 6: Unique Customers by ID Number August 2025
-- =====================================================================================

-- Question: Berapa total customer unique [id_number] on boarding di bulan august 25, 
-- posisi akhir bulan? Untuk semua nasabah bank jago

-- Note: This query assumes id_number represents KTP/identity number
-- Since schema shows id_number field exists in customer table

SELECT 
    -- Unique individual customers (by KTP/ID number)
    COUNT(DISTINCT id_number) as unique_individuals_onboarded,
    -- Total customer records (can be multiple CIFs per person)
    COUNT(DISTINCT customer_id) as total_customer_records,
    -- Ratio showing multiple products per person
    ROUND(COUNT(DISTINCT customer_id) * 1.0 / NULLIF(COUNT(DISTINCT id_number), 0), 2) as avg_products_per_individual,
    -- Breakdown by core banking
    COUNT(DISTINCT CASE WHEN customer_source = 'LFS' THEN id_number END) as unique_lfs_individuals,
    COUNT(DISTINCT CASE WHEN customer_source = 'WINCORE' THEN id_number END) as unique_wincore_individuals,
    COUNT(DISTINCT CASE WHEN customer_source = 'OLIBS724' THEN id_number END) as unique_olibs_individuals,
    COUNT(DISTINCT CASE WHEN customer_source = 'LP' THEN id_number END) as unique_lp_individuals
FROM `data-prd-adhoc.credit_risk_adhoc.intern_data_mart_customer`
WHERE business_date = '2025-08-31'  -- End of August 2025
  AND DATE_TRUNC(customer_start_date, MONTH) = '2025-08-01'  -- Onboarded in August 2025
  AND customer_status = 'ACTIVE'    -- Active customers only
  AND id_number IS NOT NULL;       -- Valid ID numbers only

-- Additional analysis: Customers with multiple core banking relationships
WITH customer_platform_analysis AS (
    SELECT 
        id_number,
        COUNT(DISTINCT customer_source) as core_banking_count,
        STRING_AGG(DISTINCT customer_source, ', ') as core_banking_systems,
        COUNT(DISTINCT customer_id) as total_cif_count
    FROM `data-prd-adhoc.credit_risk_adhoc.intern_data_mart_customer`
    WHERE business_date = '2025-08-31'
      AND DATE_TRUNC(customer_start_date, MONTH) = '2025-08-01'
      AND customer_status = 'ACTIVE'
      AND id_number IS NOT NULL
    GROUP BY id_number
)

SELECT 
    core_banking_count,
    COUNT(*) as customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage,
    -- Show examples of multi-platform customers
    COUNT(CASE WHEN core_banking_count > 1 THEN 1 END) as multi_platform_customers
FROM customer_platform_analysis
GROUP BY core_banking_count
ORDER BY core_banking_count;

-- =====================================================================================
-- TASK 7: Link Customer and Balance Data
-- =====================================================================================

-- Question: Try to link between with customer and balance, using customer_id 
-- {filter customer pada poin 4}

-- Using customers from Task 4 (all Bank Jago customers onboarded in August 2025)
SELECT 
    -- Customer summary
    COUNT(DISTINCT c.customer_id) as total_customers,
    COUNT(DISTINCT CASE WHEN b.account_number IS NOT NULL THEN c.customer_id END) as customers_with_balance_data,
    COUNT(DISTINCT CASE WHEN b.account_number IS NULL THEN c.customer_id END) as customers_without_balance_data,
    
    -- Balance summary
    COUNT(DISTINCT b.account_number) as total_accounts,
    SUM(b.total_balance) as total_account_balance,
    AVG(b.total_balance) as avg_account_balance,
    
    -- Account type breakdown
    COUNT(DISTINCT b.account_type) as unique_account_types,
    COUNT(DISTINCT b.account_category) as unique_account_categories,
    STRING_AGG(DISTINCT b.account_category, ', ') as category_list,
    
    -- By core banking system
    COUNT(DISTINCT CASE WHEN c.customer_source = 'LFS' AND b.account_number IS NOT NULL THEN c.customer_id END) as lfs_with_balance,
    COUNT(DISTINCT CASE WHEN c.customer_source = 'WINCORE' AND b.account_number IS NOT NULL THEN c.customer_id END) as wincore_with_balance,
    COUNT(DISTINCT CASE WHEN c.customer_source = 'OLIBS724' AND b.account_number IS NOT NULL THEN c.customer_id END) as olibs_with_balance,
    COUNT(DISTINCT CASE WHEN c.customer_source = 'LP' AND b.account_number IS NOT NULL THEN c.customer_id END) as lp_with_balance,
    
    -- Percentage with balance data
    ROUND(COUNT(DISTINCT CASE WHEN b.account_number IS NOT NULL THEN c.customer_id END) * 100.0 / 
          COUNT(DISTINCT c.customer_id), 2) as percentage_with_balance
          
FROM `data-prd-adhoc.credit_risk_adhoc.intern_data_mart_customer` c
LEFT JOIN `data-prd-adhoc.credit_risk_adhoc.intern_dwh_core_daily_closing_balance` b
    ON c.customer_id = b.customer_id  -- Link by customer_id
    AND b.full_date = '2025-08-31'    -- End of August balance
WHERE c.business_date = '2025-08-31'  -- End of August customer snapshot
  AND DATE_TRUNC(c.customer_start_date, MONTH) = '2025-08-01'  -- Onboarded in August 2025
  AND c.customer_status = 'ACTIVE';   -- Active customers only