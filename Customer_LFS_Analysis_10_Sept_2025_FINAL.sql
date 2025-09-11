-- =====================================================================================
-- CUSTOMER CASA FLOW ANALYSIS - September 10, 2025 (FINAL VERSION)
-- Bank Jago Risk Data Analyst Intern Task
-- Following exact requirements from 10_sept_task.csv
-- =====================================================================================

-- TASK OVERVIEW FROM 10_sept_task.csv:
-- EXPLORE FLOW CASA (posisi august 2025=31 August 25)
-- 1. Product funding matrix by core banking (intern_dwh_core_daily_closing_balance)
-- 2. LFS currency types for funding products (intern_dwh_core_daily_closing_balance)  
-- 3. Sample 2 LFS customers onboarded Aug 10 with 3+ LFS products
-- 4. Compare intern_dwh_core_daily_closing_balance vs intern_data_mart_td_daily
-- EXPLORE FLOW TRANSACTION (posisi august 2025=31 August 25)  
-- 5. Transaction analysis for sample customers (Aug 1-31, 2025)
-- 6. Balance vs transaction correlation (Aug 10 vs Aug 31 using intern_data_mart_td_daily)

-- =====================================================================================
-- TASK 1: Product Funding Matrix by Core Banking (August 2025)
-- =====================================================================================

-- Question: Per posisi august 2025, ada berapa product funding - per product category, 
-- product funding di bank jago? per core banking (customer_source)
-- bikin matrix aja, row (product category, product name /account type) column (core banking)
-- Source: intern_dwh_core_daily_closing_balance

-- First explore what account categories exist
WITH account_exploration AS (
    SELECT 
        account_category,
        account_type,
        customer_source,
        COUNT(DISTINCT account_number) as account_count
    FROM `data-prd-adhoc.credit_risk_adhoc.intern_dwh_core_daily_closing_balance`
    WHERE full_date = '2025-08-31'
      AND total_balance > 0
    GROUP BY account_category, account_type, customer_source
    ORDER BY account_count DESC
    LIMIT 20
)

SELECT * FROM account_exploration;

-- Product Funding Matrix: Rows = Product Category + Account Type, Columns = Core Banking
WITH funding_matrix AS (
    SELECT 
        account_category as product_category,
        account_type as product_name,
        customer_source,
        COUNT(DISTINCT account_number) as account_count,
        COUNT(DISTINCT customer_id) as unique_customers,
        SUM(total_balance) as total_balance
    FROM `data-prd-adhoc.credit_risk_adhoc.intern_dwh_core_daily_closing_balance`
    WHERE full_date = '2025-08-31'
      AND total_balance > 0
      AND account_category IS NOT NULL
    GROUP BY account_category, account_type, customer_source
)

SELECT 
    product_category,
    product_name,
    -- Core Banking Columns (Account Count)
    SUM(CASE WHEN customer_source = 'LFS' THEN account_count ELSE 0 END) as LFS_accounts,
    SUM(CASE WHEN customer_source = 'WINCORE' THEN account_count ELSE 0 END) as WINCORE_accounts,
    SUM(CASE WHEN customer_source = 'OLIBS724' THEN account_count ELSE 0 END) as OLIBS724_accounts,
    -- Core Banking Columns (Customer Count)
    SUM(CASE WHEN customer_source = 'LFS' THEN unique_customers ELSE 0 END) as LFS_customers,
    SUM(CASE WHEN customer_source = 'WINCORE' THEN unique_customers ELSE 0 END) as WINCORE_customers,
    SUM(CASE WHEN customer_source = 'OLIBS724' THEN unique_customers ELSE 0 END) as OLIBS724_customers,
    -- Core Banking Columns (Balance in Millions IDR)
    ROUND(SUM(CASE WHEN customer_source = 'LFS' THEN total_balance ELSE 0 END)/1000000, 2) as LFS_balance_millions,
    ROUND(SUM(CASE WHEN customer_source = 'WINCORE' THEN total_balance ELSE 0 END)/1000000, 2) as WINCORE_balance_millions,
    ROUND(SUM(CASE WHEN customer_source = 'OLIBS724' THEN total_balance ELSE 0 END)/1000000, 2) as OLIBS724_balance_millions,
    -- Totals
    SUM(account_count) as total_accounts,
    SUM(unique_customers) as total_customers,
    ROUND(SUM(total_balance)/1000000, 2) as total_balance_millions
FROM funding_matrix
GROUP BY product_category, product_name
HAVING total_accounts > 0
ORDER BY product_category, total_balance_millions DESC;

-- =====================================================================================
-- TASK 2: LFS Currency Types for Funding Products (August 2025)
-- =====================================================================================

-- Question: Per posisi august 2025, Khusus product funding LFS, ada berapa type currency bank jago?
-- Source: intern_dwh_core_daily_closing_balance

SELECT 
    currency_code,
    COUNT(DISTINCT account_number) as account_count,
    COUNT(DISTINCT customer_id) as unique_customers,
    SUM(total_balance) as total_balance,
    ROUND(AVG(total_balance), 2) as avg_balance_per_account,
    -- Account type breakdown per currency
    COUNT(DISTINCT account_type) as account_types_count,
    STRING_AGG(DISTINCT account_type, '; ' LIMIT 10) as sample_account_types,
    -- Account category breakdown per currency  
    COUNT(DISTINCT account_category) as account_categories_count,
    STRING_AGG(DISTINCT account_category, '; ') as account_categories_list,
    -- Percentage of total LFS funding
    ROUND(COUNT(DISTINCT account_number) * 100.0 / 
          SUM(COUNT(DISTINCT account_number)) OVER(), 2) as percentage_of_accounts,
    ROUND(SUM(total_balance) * 100.0 / 
          SUM(SUM(total_balance)) OVER(), 2) as percentage_of_balance
FROM `data-prd-adhoc.credit_risk_adhoc.intern_dwh_core_daily_closing_balance`
WHERE full_date = '2025-08-31'
  AND customer_source = 'LFS'  -- LFS only
  AND total_balance > 0
GROUP BY currency_code
ORDER BY total_balance DESC;

-- Multi-currency customers analysis
WITH multi_currency_lfs AS (
    SELECT 
        customer_id,
        COUNT(DISTINCT currency_code) as currency_count,
        STRING_AGG(DISTINCT currency_code, ', ') as currencies_used,
        SUM(total_balance) as total_balance_all_currencies,
        COUNT(DISTINCT account_number) as total_accounts
    FROM `data-prd-adhoc.credit_risk_adhoc.intern_dwh_core_daily_closing_balance`
    WHERE full_date = '2025-08-31'
      AND customer_source = 'LFS'
      AND total_balance > 0
    GROUP BY customer_id
)

SELECT 
    currency_count as currencies_held,
    COUNT(*) as customer_count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage_of_customers,
    ROUND(AVG(total_balance_all_currencies), 2) as avg_total_balance,
    ROUND(AVG(total_accounts), 2) as avg_accounts_per_customer
FROM multi_currency_lfs
GROUP BY currency_count
ORDER BY currency_count;

-- =====================================================================================
-- TASK 3: Sample LFS Customers with 3+ Products (Onboarded Aug 10, 2025)
-- =====================================================================================

-- Question: Ambil sample 2 customer LFS yang on boarding di tanggal 10 August 2025,
-- yang di product funding LFS nya punya lebih dari 3 atau 5 product LFS
-- Source: intern_dwh_core_daily_closing_balance + tabel customer

-- First check if customers onboarded on Aug 10 exist
WITH aug_10_customers AS (
    SELECT 
        customer_id,
        customer_start_date,
        main_account_number,
        customer_status
    FROM `data-prd-adhoc.credit_risk_adhoc.intern_data_mart_customer`
    WHERE customer_source = 'LFS'
      AND customer_start_date = '2025-08-10'
      AND business_date = '2025-08-31'
      AND customer_status = 'ACTIVE'
),

-- Check their product count
customer_product_analysis AS (
    SELECT 
        c.customer_id,
        c.customer_start_date,
        c.main_account_number,
        COUNT(DISTINCT b.account_number) as lfs_product_count,
        COUNT(DISTINCT b.account_type) as unique_account_types,
        COUNT(DISTINCT b.account_category) as unique_account_categories,
        STRING_AGG(DISTINCT b.account_type, '; ' LIMIT 10) as account_types_list,
        STRING_AGG(DISTINCT b.account_category, '; ') as account_categories_list,
        SUM(b.total_balance) as total_balance,
        COUNT(DISTINCT b.currency_code) as currencies_count,
        STRING_AGG(DISTINCT b.currency_code, ', ') as currencies_list
    FROM aug_10_customers c
    LEFT JOIN `data-prd-adhoc.credit_risk_adhoc.intern_dwh_core_daily_closing_balance` b
        ON c.customer_id = b.customer_id
        AND b.full_date = '2025-08-31'
        AND b.customer_source = 'LFS'
        AND b.total_balance > 0
    GROUP BY c.customer_id, c.customer_start_date, c.main_account_number
)

SELECT 
    customer_id,
    customer_start_date,
    main_account_number,
    lfs_product_count,
    unique_account_types,
    unique_account_categories,
    account_types_list,
    account_categories_list,
    ROUND(total_balance/1000, 2) as total_balance_thousands,
    currencies_count,
    currencies_list,
    CASE 
        WHEN lfs_product_count >= 5 THEN 'HIGH_PRODUCT_USER'
        WHEN lfs_product_count >= 3 THEN 'MEDIUM_PRODUCT_USER' 
        ELSE 'LOW_PRODUCT_USER'
    END as product_user_category
FROM customer_product_analysis
WHERE lfs_product_count >= 3  -- At least 3 products as requested
ORDER BY lfs_product_count DESC, total_balance DESC
LIMIT 2;  -- Sample 2 customers

-- Store sample customers for next tasks
CREATE OR REPLACE TABLE `data-prd-adhoc.credit_risk_adhoc.temp_sample_customers_10sept` AS
WITH aug_10_customers AS (
    SELECT 
        customer_id,
        customer_start_date,
        main_account_number
    FROM `data-prd-adhoc.credit_risk_adhoc.intern_data_mart_customer`
    WHERE customer_source = 'LFS'
      AND customer_start_date = '2025-08-10'
      AND business_date = '2025-08-31'
      AND customer_status = 'ACTIVE'
),

customer_product_analysis AS (
    SELECT 
        c.customer_id,
        c.customer_start_date,
        c.main_account_number,
        COUNT(DISTINCT b.account_number) as lfs_product_count,
        SUM(b.total_balance) as total_balance
    FROM aug_10_customers c
    LEFT JOIN `data-prd-adhoc.credit_risk_adhoc.intern_dwh_core_daily_closing_balance` b
        ON c.customer_id = b.customer_id
        AND b.full_date = '2025-08-31'
        AND b.customer_source = 'LFS'
        AND b.total_balance > 0
    GROUP BY c.customer_id, c.customer_start_date, c.main_account_number
    HAVING lfs_product_count >= 3
)

SELECT 
    customer_id,
    customer_start_date,
    main_account_number,
    lfs_product_count,
    total_balance
FROM customer_product_analysis
ORDER BY lfs_product_count DESC, total_balance DESC
LIMIT 2;

-- =====================================================================================
-- TASK 4: Compare Balance Tables (August 2025)
-- =====================================================================================

-- Question: dari sample no.3 check di tabel intern_data_mart_td_daily per posisi August 2025, 
-- apa perbedaan kedua tabel tersebut?
-- Compare: intern_dwh_core_daily_closing_balance vs intern_data_mart_td_daily

WITH aug_10_customers AS (
    SELECT 
        customer_id,
        customer_start_date,
        main_account_number
    FROM `data-prd-adhoc.credit_risk_adhoc.intern_data_mart_customer`
    WHERE customer_source = 'LFS'
      AND customer_start_date = '2025-08-10'
      AND business_date = '2025-08-31'
      AND customer_status = 'ACTIVE'
),

-- Get sample customers from Task 3 (same logic)
sample_customers AS (
    SELECT 
        c.customer_id,
        c.customer_start_date,
        c.main_account_number,
        COUNT(DISTINCT b.account_number) as lfs_product_count,
        SUM(b.total_balance) as total_balance
    FROM aug_10_customers c
    LEFT JOIN `data-prd-adhoc.credit_risk_adhoc.intern_dwh_core_daily_closing_balance` b
        ON c.customer_id = b.customer_id
        AND b.full_date = '2025-08-31'
        AND b.customer_source = 'LFS'
        AND b.total_balance > 0
    GROUP BY c.customer_id, c.customer_start_date, c.main_account_number
    HAVING lfs_product_count >= 3
    ORDER BY lfs_product_count DESC, total_balance DESC
    LIMIT 2  -- Top 2 customers with most products
),

-- Balance data from core table
core_balance_data AS (
    SELECT 
        'intern_dwh_core_daily_closing_balance' as source_table,
        customer_id,
        full_date as date_field,
        COUNT(DISTINCT account_number) as account_count,
        COUNT(DISTINCT account_type) as account_types,
        SUM(total_balance) as total_balance,
        AVG(total_balance) as avg_balance,
        COUNT(DISTINCT currency_code) as currency_count,
        STRING_AGG(DISTINCT currency_code, ', ') as currencies,
        STRING_AGG(DISTINCT account_category, ', ') as categories,
        STRING_AGG(DISTINCT account_type, '; ' LIMIT 5) as sample_account_types
    FROM `data-prd-adhoc.credit_risk_adhoc.intern_dwh_core_daily_closing_balance`
    WHERE customer_id IN (SELECT customer_id FROM sample_customers)
      AND full_date = '2025-08-31'
    GROUP BY customer_id, full_date
),

-- Balance data from TD daily table  
td_balance_data AS (
    SELECT 
        'intern_data_mart_td_daily' as source_table,
        customer_id,
        business_date as date_field,
        COUNT(DISTINCT account_number) as account_count,
        COUNT(DISTINCT product_type) as account_types,
        SUM(balance) as total_balance,
        AVG(balance) as avg_balance,
        COUNT(DISTINCT currency) as currency_count,
        STRING_AGG(DISTINCT currency, ', ') as currencies,
        STRING_AGG(DISTINCT product_subtype, ', ') as categories,
        STRING_AGG(DISTINCT product_type, '; ' LIMIT 5) as sample_account_types,
        -- TD-specific fields
        AVG(interest_rate) as avg_interest_rate,
        COUNT(DISTINCT CASE WHEN maturity_date IS NOT NULL THEN account_number END) as accounts_with_maturity,
        AVG(tenor) as avg_tenor_days,
        STRING_AGG(DISTINCT business_stream, ', ') as business_streams
    FROM `data-prd-adhoc.credit_risk_adhoc.intern_data_mart_td_daily`
    WHERE customer_id IN (SELECT customer_id FROM sample_customers)
      AND business_date = '2025-08-31'
    GROUP BY customer_id, business_date
)

-- Side by side comparison
SELECT 
    COALESCE(c.customer_id, t.customer_id) as customer_id,
    'TABLE_COMPARISON' as analysis_type,
    -- Core table data
    c.source_table as core_table,
    c.account_count as core_accounts,
    ROUND(c.total_balance/1000, 2) as core_total_balance_thousands,
    c.currencies as core_currencies,
    c.categories as core_categories,
    c.sample_account_types as core_account_types,
    -- TD table data
    t.source_table as td_table,
    t.account_count as td_accounts,
    ROUND(t.total_balance/1000, 2) as td_total_balance_thousands,
    t.currencies as td_currencies,
    t.categories as td_categories,
    t.sample_account_types as td_account_types,
    ROUND(t.avg_interest_rate, 4) as td_avg_interest_rate,
    t.accounts_with_maturity as td_maturity_accounts,
    ROUND(t.avg_tenor_days, 0) as td_avg_tenor_days,
    t.business_streams as td_business_streams,
    -- Differences
    ROUND((COALESCE(c.total_balance, 0) - COALESCE(t.total_balance, 0))/1000, 2) as balance_difference_thousands,
    COALESCE(c.account_count, 0) - COALESCE(t.account_count, 0) as account_count_difference,
    -- Analysis
    CASE 
        WHEN c.customer_id IS NULL THEN 'Only in TD table'
        WHEN t.customer_id IS NULL THEN 'Only in Core table'
        ELSE 'In both tables'
    END as table_presence
FROM core_balance_data c
FULL OUTER JOIN td_balance_data t ON c.customer_id = t.customer_id;

-- =====================================================================================
-- TASK 5: Transaction Analysis for Sample Customers (Aug 1-31, 2025)
-- =====================================================================================

-- Question: dari kedua sample no.3 check di tabel transaksi, transaksi per tgl 1 august - 31 august,
-- sort customer_id, transaction_date --> analisa alur dan transaksi apa saja yang dilakukan nasabah?

