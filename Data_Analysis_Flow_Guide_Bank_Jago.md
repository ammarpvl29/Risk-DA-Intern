# 📊 Data Analysis Flow Guide - Bank Jago Risk DA Intern

**Created**: September 13, 2025  
**For**: Risk Data Analyst Interns  
**Based on**: Real mentoring sessions and Bank Jago data architecture

---

## 🎯 **Overview: The Bank Jago Way**

At Bank Jago, we follow a **systematic, step-by-step approach** to data analysis. This isn't just about writing SQL - it's about thinking like a risk analyst and delivering reliable insights for business decisions.

---

## 📋 **The 6-Step Data Analysis Framework**

### **Step 1: Understand the Business Question** 🤔

**Before touching any code, ask yourself:**

```
✅ What exactly is the business asking?
✅ Why do they need this information?
✅ What decision will be made with this data?
✅ What's the expected output format?
```

**Example Business Questions:**
- "How many LFS customers were offered loans in August?"
- "What's the conversion rate from loan offers to applications?"
- "Which customer segments have the highest NPL rates?"

**Pro Tip**: If you can't explain the business question in one sentence, you don't understand it yet.

---

### **Step 2: Identify Required Tables & Relationships** 🗂️

**Map out your data journey:**

```
Business Question → Required Data → Table Relationships → Join Keys
```

**Bank Jago Core Tables:**

| **Category** | **Table** | **Purpose** | **Key Fields** |
|--------------|-----------|-------------|----------------|
| **Customer** | `intern_data_mart_customer` | Customer profiles | `customer_id`, `id_number` |
| **Funding** | `intern_dwh_core_daily_closing_balance` | Account balances | `customer_id`, `account_number` |
| **Lending** | `intern_loan_offer_current` | Current loan offers | `customer_id`, `created_at` |
| **Lending** | `intern_loan_application` | Loan applications | `id_number`, `partner_id` |
| **Activity** | `intern_customer_individual_successful_transactions_analytics` | Transactions | `customer_id`, `transaction_date` |

**Common Join Patterns:**
```sql
-- Customer → Offers
customer.customer_id = loan_offer.customer_id

-- Customer → Applications (via ID number)
customer.id_number = loan_application.id_number

-- Customer → Balances
customer.customer_id = balance.customer_id
```

---

### **Step 3: Start Simple, Build Complex** 🔨

**The Golden Rule**: Always start with the simplest possible query.

#### **3.1 Basic Exploration**
```sql
-- ALWAYS start here
SELECT COUNT(*) FROM table_name;
SELECT * FROM table_name LIMIT 5;
SELECT DISTINCT key_field FROM table_name;
```

#### **3.2 Single Table Analysis**
```sql
-- Count by categories
SELECT 
    customer_source,
    COUNT(*) as customer_count
FROM `intern_data_mart_customer`
WHERE business_date = '2025-08-31'
GROUP BY customer_source;
```

#### **3.3 Add Complexity Gradually**
```sql
-- Now add filters and conditions
SELECT 
    customer_source,
    customer_status,
    COUNT(*) as customer_count
FROM `intern_data_mart_customer`
WHERE business_date = '2025-08-31'
    AND customer_source = 'LFS'
GROUP BY customer_source, customer_status;
```

**Why This Approach Works:**
- ✅ Easy to debug when things go wrong
- ✅ You understand each piece before combining
- ✅ Catches data quality issues early

---

### **Step 4: Handle Data Quality Issues** 🔍

**NEVER assume data is clean.** Always check for:

#### **4.1 Duplicates Check**
```sql
-- Check for multiple records per customer
SELECT 
    customer_id, 
    COUNT(*) as record_count
FROM `intern_loan_offer_daily_snapshot`
WHERE business_date = '2025-08-31'
GROUP BY customer_id
HAVING COUNT(*) > 1
LIMIT 10;
```

#### **4.2 Missing Values**
```sql
-- Check for NULLs in key fields
SELECT 
    COUNT(*) as total_records,
    COUNT(customer_id) as non_null_customer_id,
    COUNT(id_number) as non_null_id_number
FROM `intern_data_mart_customer`
WHERE business_date = '2025-08-31';
```

#### **4.3 Date Range Validation**
```sql
-- Always check your date filters
SELECT 
    MIN(business_date) as earliest_date,
    MAX(business_date) as latest_date,
    COUNT(DISTINCT business_date) as date_count
FROM `intern_data_mart_customer`;
```

#### **4.4 Deduplication Pattern**
```sql
-- Standard deduplication using window functions
WITH deduplicated AS (
    SELECT *,
        DENSE_RANK() OVER (
            PARTITION BY customer_id
            ORDER BY expires_at DESC, created_at DESC
        ) AS rank_latest
    FROM `intern_loan_offer_daily_snapshot`
    WHERE business_date = '2025-08-31'
    QUALIFY rank_latest = 1
)
SELECT * FROM deduplicated;
```

**Why DENSE_RANK() + QUALIFY?**
- More efficient than subqueries
- Handles ties properly
- Cleaner code structure

---

### **Step 5: Build Complex Joins Using CTEs** ⛓️

**Use CTEs (Common Table Expressions) to break complex logic into readable steps.**

#### **5.1 The CTE Pattern**
```sql
-- Step 1: Clean and prepare each dataset
WITH clean_offers AS (
    SELECT *,
        DENSE_RANK() OVER (
            PARTITION BY customer_id
            ORDER BY expires_at DESC, created_at DESC
        ) AS rank_latest
    FROM `intern_loan_offer_daily_snapshot`
    WHERE business_date = '2025-08-31'
    QUALIFY rank_latest = 1
),

-- Step 2: Join with customers
customer_offers AS (
    SELECT c.*, o.*
    FROM `intern_data_mart_customer` c
    LEFT JOIN clean_offers o ON c.customer_id = o.customer_id
    WHERE c.business_date = '2025-08-31'
        AND c.customer_source = 'LFS'
        AND o.customer_id IS NOT NULL
),

-- Step 3: Add applications
customer_applications AS (
    SELECT co.*, a.status as application_status
    FROM customer_offers co
    LEFT JOIN `intern_loan_application` a ON co.id_number = a.id_number
    WHERE a.partner_id LIKE '%JAG%'
)

-- Step 4: Final analysis
SELECT 
    COUNT(*) as customers_offered,
    COUNT(CASE WHEN application_status IS NOT NULL THEN 1 END) as customers_applied,
    ROUND(
        COUNT(CASE WHEN application_status IS NOT NULL THEN 1 END) * 100.0 / COUNT(*), 
        2
    ) as conversion_rate_pct
FROM customer_applications;
```

#### **5.2 CTE Best Practices**
- **One logical step per CTE**
- **Descriptive names** (`clean_offers`, not `base`)
- **Comment each CTE's purpose**
- **Test each CTE separately** during development

---

### **Step 6: Validate and Document Results** ✅

#### **6.1 Sanity Checks**
```sql
-- Always include validation queries
-- Check: Do totals make sense?
SELECT 
    'Total LFS Customers' as metric,
    COUNT(*) as value
FROM `intern_data_mart_customer`
WHERE business_date = '2025-08-31' 
    AND customer_source = 'LFS'

UNION ALL

SELECT 
    'LFS Customers with Offers' as metric,
    COUNT(*) as value
FROM customer_offers;  -- Should be much smaller
```

#### **6.2 Cross-Validation**
```sql
-- Verify results using different approaches
-- Method 1: Join-based count
-- Method 2: Subquery-based count
-- Results should match!
```

#### **6.3 Document Your Analysis**
```sql
/*
Analysis: LFS Customer Loan Offer Conversion
Date: 2025-08-31
Business Question: How many LFS customers offered loans on Aug 25 applied for Direct Lending?

Key Findings:
- 2 LFS customers offered loans on Aug 25
- 0 customers applied for Direct Lending (JAG products)
- Conversion rate: 0%

Data Sources:
- intern_loan_offer_daily_snapshot (offer data)
- intern_data_mart_customer (customer profiles)
- intern_loan_application (applications)

Notes:
- Used DENSE_RANK to handle multiple offers per customer
- Filtered for JAG products using partner_id LIKE '%JAG%'
- Limited to LFS customers only
*/
```

---

## 🎯 **Bank Jago Specific Best Practices**

### **Date Handling**
```sql
-- Always use the latest available business_date for customer data
WHERE c.business_date = '2025-08-31'  -- Latest snapshot

-- For transaction analysis, use date ranges
WHERE transaction_date BETWEEN '2025-08-01' AND '2025-08-31'
```

### **Customer Segmentation**
```sql
-- Standard customer filters
WHERE customer_source = 'LFS'        -- LFS customers only
    AND customer_status = 'ACTIVE'   -- Active customers only
    AND customer_type = 'Individual - Citizen'  -- Retail customers
```

### **Loan Product Identification**
```sql
-- Direct Lending identification
WHERE partner_id LIKE '%JAG%'        -- Direct Lending products

-- Product type analysis
WHERE product_code IN ('JAG08', 'JAG09')  -- Specific loan products
```

### **Risk Analysis Patterns**
```sql
-- Days Past Due buckets
CASE 
    WHEN days_past_due = 0 THEN 'Current'
    WHEN days_past_due BETWEEN 1 AND 30 THEN '1-30 DPD'
    WHEN days_past_due BETWEEN 31 AND 90 THEN '31-90 DPD'
    WHEN days_past_due > 90 THEN '90+ DPD (NPL)'
END as dpd_bucket
```

---

## 🚀 **Common Analysis Patterns**

### **Customer Journey Analysis**
```sql
-- Trace one customer across all systems
SELECT 'Customer Profile' as data_type, COUNT(*) as records
FROM `intern_data_mart_customer` 
WHERE customer_id = 'XNFJK1BX1V'

UNION ALL

SELECT 'Account Balances' as data_type, COUNT(*) as records
FROM `intern_dwh_core_daily_closing_balance` 
WHERE customer_id = 'XNFJK1BX1V'

UNION ALL

SELECT 'Transactions' as data_type, COUNT(*) as records
FROM `intern_customer_individual_successful_transactions_analytics` 
WHERE customer_id = 'XNFJK1BX1V';
```

### **Funnel Analysis**
```sql
-- Loan funnel: Offers → Applications → Approvals → Disbursals
WITH funnel_data AS (
    SELECT 
        COUNT(DISTINCT o.customer_id) as customers_offered,
        COUNT(DISTINCT CASE WHEN a.id_number IS NOT NULL THEN o.customer_id END) as customers_applied,
        COUNT(DISTINCT CASE WHEN a.status = 'ACTIVATED' THEN o.customer_id END) as customers_approved
    FROM loan_offers o
    LEFT JOIN loan_applications a ON o.customer_id = a.customer_id
    WHERE DATE(o.created_at) = '2025-08-25'
)
SELECT 
    customers_offered,
    customers_applied,
    customers_approved,
    ROUND(customers_applied * 100.0 / customers_offered, 2) as application_rate_pct,
    ROUND(customers_approved * 100.0 / customers_applied, 2) as approval_rate_pct
FROM funnel_data;
```

### **Time Series Analysis**
```sql
-- Daily trend analysis
SELECT 
    transaction_date,
    COUNT(*) as transaction_count,
    SUM(transaction_amount) as total_amount,
    COUNT(DISTINCT customer_id) as unique_customers
FROM `intern_customer_individual_successful_transactions_analytics`
WHERE transaction_date BETWEEN '2025-08-01' AND '2025-08-31'
    AND customer_id IN (SELECT customer_id FROM lfs_customers)
GROUP BY transaction_date
ORDER BY transaction_date;
```

---

## 🎓 **Learning Progression for Interns**

### **Week 1-2: Foundations**
- [ ] Master basic SELECT, WHERE, GROUP BY
- [ ] Understand Bank Jago table relationships
- [ ] Practice data exploration queries
- [ ] Learn to check data quality

### **Week 3-4: Intermediate Skills**
- [ ] Window functions (RANK, DENSE_RANK, ROW_NUMBER)
- [ ] CTEs for complex queries
- [ ] JOINs across multiple tables
- [ ] Date/time analysis

### **Week 5-8: Advanced Analysis**
- [ ] Customer journey mapping
- [ ] Funnel analysis
- [ ] Risk metric calculations
- [ ] Performance optimization

### **Week 9-12: Business Focus**
- [ ] Automated reporting
- [ ] Dashboard creation
- [ ] Business presentation skills
- [ ] Advanced risk modeling

---

## 📝 **Common Mistakes to Avoid**

### **❌ Don't Do This:**
```sql
-- Writing one giant query without testing
SELECT COUNT(*) 
FROM table1 t1
JOIN table2 t2 ON t1.id = t2.id
JOIN table3 t3 ON t2.id = t3.id
WHERE t1.date > '2025-01-01'
    AND t2.status = 'ACTIVE'
    AND t3.amount > 1000;  -- Could be completely wrong!
```

### **✅ Do This Instead:**
```sql
-- Test each piece first
WITH base_customers AS (
    SELECT * FROM table1 WHERE date > '2025-01-01'
),
active_customers AS (
    SELECT c.*, t2.status
    FROM base_customers c
    JOIN table2 t2 ON c.id = t2.id
    WHERE t2.status = 'ACTIVE'
),
final_result AS (
    SELECT ac.*, t3.amount
    FROM active_customers ac
    JOIN table3 t3 ON ac.id = t3.id
    WHERE t3.amount > 1000
)
SELECT COUNT(*) FROM final_result;
```

---

## 🔥 **Pro Tips from Experienced Analysts**

1. **Start Every Analysis with EDA (Exploratory Data Analysis)**
   ```sql
   SELECT * FROM table_name LIMIT 10;
   DESCRIBE table_name;
   SELECT COUNT(*), COUNT(DISTINCT key_field) FROM table_name;
   ```

2. **Use Comments Liberally**
   ```sql
   -- Business logic: Only include customers onboarded in last 90 days
   WHERE customer_start_date >= DATE_SUB(CURRENT_DATE(), INTERVAL 90 DAY)
   ```

3. **Save Your Queries with Context**
   ```sql
   /*
   File: lfs_customer_offer_analysis_20250831.sql
   Analyst: [Your Name]
   Purpose: Analyze LFS customer loan offer conversion rates
   Stakeholder: Risk Management Team
   Due Date: 2025-09-01
   */
   ```

4. **Always Include Row Counts in Results**
   ```sql
   SELECT 
       *,
       COUNT(*) OVER() as total_rows  -- Helps validate results
   FROM analysis_results;
   ```

5. **Create Reusable Code Blocks**
   ```sql
   -- Standard LFS customer filter
   WHERE business_date = (SELECT MAX(business_date) FROM `intern_data_mart_customer`)
       AND customer_source = 'LFS'
       AND customer_status = 'ACTIVE'
   ```

---

## 🎯 **Quick Reference: Key Patterns**

### **Deduplication**
```sql
WITH dedupe AS (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY key ORDER BY date DESC) as rn
    FROM table_name
    QUALIFY rn = 1
)
```

### **Running Totals**
```sql
SELECT 
    date,
    amount,
    SUM(amount) OVER (ORDER BY date) as running_total
FROM transactions;
```

### **Percentage Calculations**
```sql
SELECT 
    category,
    COUNT(*) as count,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM table_name
GROUP BY category;
```

### **Date Filtering**
```sql
-- Last 30 days
WHERE date >= DATE_SUB(CURRENT_DATE(), INTERVAL 30 DAY)

-- Specific month
WHERE DATE_TRUNC(date, MONTH) = '2025-08-01'

-- Business date (for snapshot tables)
WHERE business_date = '2025-08-31'
```

---

## 📚 **Further Learning Resources**

1. **Internal Documentation**
   - `Handbook - Risk Data Analyst.md`
   - `Loan_System_Understanding.md`
   - `Customer_LFS_Analysis_Summary.md`

2. **SQL Skills Development**
   - BigQuery documentation
   - Window functions deep dive
   - Advanced JOIN patterns

3. **Banking Domain Knowledge**
   - Understanding NPL calculations
   - Credit scoring fundamentals
   - Regulatory reporting requirements

---

**Remember**: Good data analysis is 20% technical skills and 80% understanding the business context. Always ask "What story is the data telling?" and "How does this help Bank Jago make better decisions?"

**Happy Analyzing!** 🚀

---

*Last updated: September 13, 2025*  
*Next review: October 13, 2025*