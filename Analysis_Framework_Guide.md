# 📊 Bank Jago Data Analysis Framework Guide
**For Risk Data Analyst Intern Tasks**

---

## 🎯 **Pre-Analysis Checklist**

Before starting any analysis, ALWAYS ask these questions:

### **1. Customer Status Breakdown**
```sql
-- ALWAYS START WITH THIS QUERY
SELECT 
  customer_status,
  COUNT(*) as customer_count,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as percentage
FROM `data-prd-adhoc.credit_risk_adhoc.intern_data_mart_customer`
WHERE business_date = 'YYYY-MM-DD'
GROUP BY customer_status
ORDER BY customer_count DESC;
```

**Why this matters:**
- **ACTIVE**: Completed KYC, ready for products (focus here for business insights)
- **INACTIVE**: Stuck in onboarding/KYC process
- **DORMANT**: Inactive customers (risk assessment needed)
- **Other statuses**: May include fraud flags or special cases

### **2. Variable Classification**

Before analyzing any field, classify it:

#### **🔑 Key Variables (for linking tables)**
- `customer_id` - Primary identifier
- `id_number` - KTP/National ID (for deduplication)
- `customer_cif` - Mambu-generated identifier
- `account_number` - Account linking

**Analysis Focus**: Data quality, uniqueness, linkage success

#### **📊 Demographic Variables (for business analysis)**
- `age_group` - Customer segmentation
- `balance_tier_description` - Value tier analysis
- `customer_risk_status` - Risk distribution
- `identity_address_city`, `identity_address_province` - Geographic analysis
- `education`, `occupation`, `industry` - Socioeconomic profiling
- `partner_name` - Acquisition channel analysis

**Analysis Focus**: Business insights, segmentation, trends

#### **🔒 PII Variables (handle carefully)**
- `phone_number` → Use `phone_number_operator_name` for analysis
- `date_of_birth` → Use `age` or `age_group` 
- `email_address` → Extract domain for analysis
- `full_name`, `id_number` → Avoid direct analysis

**Analysis Focus**: Transform before analyzing, protect privacy

#### **ℹ️ Additional Information (contextual flags)**
- `customer_flagged` - Product flags
- `is_on_pep` - Politically Exposed Person flag
- `is_on_tbl` - Terrorist Blacklist flag
- `is_on_bbl` - Bank Blacklist flag
- `has_gopay_saving_account` - Product integration flags

**Analysis Focus**: Risk flags, compliance, business context

---

## 📋 **Analysis Templates**

### **Template 1: Customer Segmentation Analysis**
```sql
-- Step 1: Check customer status distribution
SELECT customer_status, COUNT(*) as count
FROM intern_data_mart_customer 
WHERE business_date = 'YYYY-MM-DD'
GROUP BY customer_status;

-- Step 2: Focus on ACTIVE customers for business analysis
SELECT 
  customer_source,
  balance_tier_description,
  customer_risk_status,
  COUNT(*) as customer_count
FROM intern_data_mart_customer
WHERE business_date = 'YYYY-MM-DD'
  AND customer_status = 'ACTIVE'  -- Focus on active customers
GROUP BY customer_source, balance_tier_description, customer_risk_status
ORDER BY customer_count DESC;
```

### **Template 2: Geographic Analysis**
```sql
-- Always check data completeness first
SELECT 
  CASE 
    WHEN identity_address_province IS NULL THEN 'Missing Province'
    ELSE identity_address_province 
  END as province_group,
  COUNT(*) as customer_count
FROM intern_data_mart_customer
WHERE business_date = 'YYYY-MM-DD'
  AND customer_status = 'ACTIVE'
GROUP BY province_group
ORDER BY customer_count DESC;
```

### **Template 3: Risk Assessment Analysis**
```sql
-- Multi-dimensional risk view
SELECT 
  customer_risk_status,
  balance_tier_description,
  CASE 
    WHEN is_on_pep = true THEN 'PEP'
    WHEN is_on_tbl = true THEN 'Terrorist List'
    WHEN is_on_bbl = true THEN 'Bank Blacklist'
    ELSE 'Clean'
  END as compliance_flag,
  COUNT(*) as customer_count
FROM intern_data_mart_customer
WHERE business_date = 'YYYY-MM-DD'
  AND customer_status = 'ACTIVE'
GROUP BY customer_risk_status, balance_tier_description, compliance_flag
ORDER BY customer_count DESC;
```

---

## 🔍 **Analysis Workflow**

### **Step 1: Data Quality Check**
1. Check `customer_status` distribution
2. Verify date ranges and completeness
3. Identify null/missing values in key fields
4. Test linkage between tables using key variables

### **Step 2: Variable Classification**
1. List all variables in your analysis
2. Classify each as Key/Demographic/PII/Additional
3. Plan appropriate handling for each type
4. Focus analysis on Demographic and Additional variables

### **Step 3: Business Analysis**
1. **Filter to ACTIVE customers** for business insights
2. Use demographic variables for segmentation
3. Cross-reference with additional information flags
4. Provide business context and actionable insights

### **Step 4: Results Interpretation**
1. **Customer Status Impact**: How do non-ACTIVE customers affect results?
2. **Data Completeness**: What percentage of data is missing/null?
3. **Business Implications**: What actions should the business take?
4. **Risk Assessment**: Any compliance or risk flags to highlight?

---

## ⚠️ **Common Mistakes to Avoid**

### **❌ DON'T:**
- Mix ACTIVE and INACTIVE customers without explanation
- Analyze PII variables directly (phone numbers, birthdates)
- Ignore customer_status in your analysis
- Assume all customer records represent active business

### **✅ DO:**
- Always start with customer_status breakdown
- Classify variables before using them
- Focus on ACTIVE customers for business insights
- Handle PII appropriately (transform first)
- Explain data quality issues in your results

---

## 🎯 **Key Prompts for Future Analysis**

When requesting analysis, include:

1. **"Start with customer_status breakdown"**
2. **"Focus on ACTIVE customers for business insights"**
3. **"Classify variables as Key/Demographic/PII/Additional"**
4. **"Check data completeness for each variable"**
5. **"Transform PII variables appropriately"**

### **Example Improved Prompt:**
```
"Analyze LFS customer acquisition in September 2025. 
Start with customer_status breakdown, then focus on ACTIVE customers. 
Classify variables before analysis and check data completeness. 
Break down by demographic variables like balance_tier and partner_name.
Handle any PII variables appropriately and highlight risk flags."
```

---

## 📊 **Data Completeness Checklist**

Before concluding any analysis:

```sql
-- Data completeness check template
SELECT 
  'customer_id' as field_name,
  COUNT(*) as total_records,
  COUNT(customer_id) as non_null_records,
  ROUND(COUNT(customer_id) * 100.0 / COUNT(*), 2) as completeness_pct
FROM intern_data_mart_customer
WHERE business_date = 'YYYY-MM-DD'
  AND customer_status = 'ACTIVE'

UNION ALL

SELECT 
  'balance_tier_description',
  COUNT(*),
  COUNT(balance_tier_description),
  ROUND(COUNT(balance_tier_description) * 100.0 / COUNT(*), 2)
FROM intern_data_mart_customer
WHERE business_date = 'YYYY-MM-DD'
  AND customer_status = 'ACTIVE';
```

---

**Remember**: Good analysis starts with understanding your data quality and customer status distribution. Always classify your variables and focus on ACTIVE customers for business insights!