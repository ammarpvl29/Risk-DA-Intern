# 🏦 Bank Jago Customer LFS Onboarding Analysis Summary
**September 2025 Analysis - August 2025 Data**

## 📊 Executive Summary

**Total Customer Acquisition**: 861,927 new customers in August 2025
**LFS Market Share**: 27.53% (237,295 customers)
**Data Quality**: 27.61% customer-balance match rate (needs improvement)
**Unique Individuals**: 770,542 people across all platforms

### ⚠️ **Critical Data Quality Insights**
Based on feedback analysis, key improvements needed:
1. **Customer Status Analysis**: ACTIVE vs non-ACTIVE status significance
2. **Variable Classification**: Key vs Demographic vs PII vs Additional Info
3. **Balance Data Coverage**: Only 27.61% customers have balance data (mainly LFS)

---

## 🎯 Task Results Analysis

### **Task 1: LFS Customer Onboarding (End of August)**
```json
{
  "total_lfs_customers_onboarded_august": "237,295",
  "earliest_onboarding_date": "2025-08-01",
  "latest_onboarding_date": "2025-08-31", 
  "number_of_partner_channels": "10"
}
```

**📈 Key Insights:**
- **237,295 LFS customers** onboarded in August 2025
- **Consistent daily onboarding** across entire month
- **10 partner channels** driving acquisition (highest among all core banking systems)

---

### **Task 2: Mid-Month LFS Onboarding (August 15)**
```json
{
  "total_lfs_customers_onboarded_by_aug15": "117,875",
  "earliest_onboarding_date": "2025-08-01",
  "latest_onboarding_date": "2025-08-15",
  "number_of_partner_channels": "10",
  "week1_onboarding": "58,010",
  "week2_onboarding": "59,865"
}
```

**📈 Mid-Month Performance:**
- **117,875 LFS customers** onboarded by August 15 (49.7% of monthly total)
- **Steady growth pattern**: Week 2 slightly outperformed Week 1
- **Daily average**: ~7,858 customers per day for first 15 days
- **All 10 partner channels** were active from start of month

**🎯 Growth Velocity Analysis:**
- **Week 1 (Aug 1-7)**: 58,010 customers (8,287 daily average)
- **Week 2 (Aug 8-15)**: 59,865 customers (7,483 daily average)
- **Peak day**: Aug 4 with 9,649 customers
- **Consistent performance**: Daily range 7,205-9,649 customers

---

### **Task 3: Customer Journey Analysis**
**Customer ID:** `XNFJK1BX1V` (Onboarded: Aug 10)

```json
{
  "customer_status": "ACTIVE",
  "total_balance": "4,257.08 IDR",
  "balance_tier": "T01: >0 to <100K IDR",
  "days_since_onboarding": "21",
  "customer_risk_status": "LOW",
  "has_gopay_saving_account": true,
  "has_mudharabah_account": false
}
```

**👤 Customer Profile Analysis:**

#### **Key Variables (Linkage)**
- `customer_id`: XNFJK1BX1V (unique identifier)
- `customer_status`: **ACTIVE** (completed KYC, not fraud/dormant)

#### **Demographic Variables (Analysis)**
- `balance_tier_description`: T01 (Low-value segment: <100K IDR)
- `customer_risk_status`: LOW (Risk assessment result)
- `days_since_onboarding`: 21 days (Recent customer)

#### **Additional Information (Business Context)**
- `has_gopay_saving_account`: TRUE (Ecosystem integration)
- `has_mudharabah_account`: FALSE (No Sharia products)

**📈 Journey Insights:**
- **ACTIVE Status**: Customer completed full onboarding (not stuck in KYC)
- **Stable Low-Risk**: Consistent balance, no red flags
- **GoPay Integration**: Part of wider Gojek ecosystem
- **Growth Potential**: Could upgrade from T01 tier

---

### **Task 4: Total Bank Jago Customer Onboarding**
```json
{
  "total_jago_customers_onboarded_august": "861,927",
  "lfs_customers": "237,295",
  "wincore_customers": "363,883", 
  "olibs_customers": "650",
  "total_partner_channels": "12"
}
```

**🏆 Platform Performance:**
- **Exceptional Growth**: 861,927 customers in one month
- **WINCORE Dominance**: Largest platform with 363,883 customers
- **LP Platform**: 260,099 customers (30.18% market share)
- **Legacy Systems**: OLIBS724 with minimal 650 customers

---

### **Task 5: Core Banking Breakdown**

| Core Banking | Customers | Market Share | Partner Channels |
|--------------|-----------|--------------|------------------|
| **WINCORE** | 363,883 | 42.22% | 1 |
| **LP** | 260,099 | 30.18% | 0 |
| **LFS** | 237,295 | 27.53% | 10 |
| **OLIBS724** | 650 | 0.08% | 1 |

**🎯 Strategic Insights:**
- **WINCORE**: Market leader, single-channel focused
- **LP**: Strong lending platform, direct acquisition
- **LFS**: Richest partner ecosystem with Gojek/GoPay integration
- **OLIBS724**: Legacy system in maintenance mode

**LFS Partner Ecosystem:**
- GoPay Unified KYC
- Bibit, Stockbit Sekuritas
- Jago Sharia, Jago Stand Alone
- Kredit Pintar (multiple channels)
- Partnership Lending

---

### **Task 6: Unique Customer Analysis**

#### **Individual vs Account Analysis**
```json
{
  "unique_individuals_onboarded": "770,542",
  "total_customer_records": "861,899", 
  "avg_products_per_individual": "1.12"
}
```

#### **Cross-Platform Customer Distribution**
```json
[
  {"core_banking_count": "1", "customer_count": "679,913", "percentage": "88.24%"},
  {"core_banking_count": "2", "customer_count": "89,902", "percentage": "11.67%"},
  {"core_banking_count": "3", "customer_count": "726", "percentage": "0.09%"},
  {"core_banking_count": "4", "customer_count": "1", "percentage": "0.0%"}
]
```

**👥 Customer Behavior Insights:**
- **88.24%** customers use single platform (focused usage)
- **11.67%** customers use 2 platforms (cross-selling success)
- **726 customers** across 3 platforms (super users)
- **1 customer** across all 4 platforms (ultimate power user!)

**📊 Product Penetration:**
- Average **1.12 products per person**
- **91,263 unique individuals** (11.76%) have multiple products
- Strong potential for **cross-selling** to single-platform users

---

### **Task 7: Customer-Balance Linkage**

#### **Data Coverage Analysis**
```json
{
  "total_customers": "861,927",
  "customers_with_balance_data": "237,969", 
  "customers_without_balance_data": "623,958",
  "percentage_with_balance": "27.61%"
}
```

#### **Account Portfolio Overview**
- **414,620 total accounts** across all customers
- **Rp 176.6 billion** total account balance
- **Average balance**: Rp 425,831 per account
- **36 unique account types** across 3 categories

#### **Core Banking Balance Distribution**
| Platform | Customers with Balance | Total Balance (Billions) | Avg Balance |
|----------|----------------------|-------------------------|-------------|
| **LFS** | 237,295 | Rp 74.1 | Rp 197,490 |
| **WINCORE** | 24 | Rp 94.8 | Rp 3.69 billion |
| **OLIBS724** | 650 | Rp 7.9 | Rp 10.7 million |
| **LP** | 0 | - | - |

#### **Product Category Analysis**
1. **TERM DEPOSIT**: Rp 122.8 billion (69.5% of total balance)
   - Dominated by WINCORE high-value customers
   - OLIBS724 Mudharabah deposits significant

2. **SAVINGS ACCOUNT**: Rp 81.2 billion (46.0% of total balance)  
   - LFS Main Accounts: 216,896 customers
   - GoPay integration: 69,724 customers active

3. **CURRENT ACCOUNT**: Rp -27.2 billion (overdraft facilities)
   - Corporate overdraft accounts in LFS

#### **Customer Segmentation by Balance**
**LFS Customer Tiers:**
- **Zero Balance**: 187,218 customers (79.1%)
- **Under 100K**: 86,913 customers (36.6%) 
- **Mid-tier (100K-1M)**: 17,977 customers (7.6%)
- **High Value (>1M)**: 8,110 customers (3.4%)

---

## 🎯 Strategic Recommendations

### **1. Data Quality Enhancement (Priority #1)**
- **Customer Status Analysis**: Segment ACTIVE vs INACTIVE/DORMANT customers
- **Variable Classification Framework**: Implement Key/Demographic/PII/Additional categorization
- **Balance Data Coverage**: Investigate why only 27.61% have balance data
- **Cross-Platform Linking**: Improve `id_number` matching across systems

### **2. Customer Status Deep Dive**
- **ACTIVE Customers**: Completed KYC, ready for products
- **INACTIVE Customers**: Potentially stuck in onboarding/KYC process
- **DORMANT Customers**: Risk assessment needed
- **FRAUD Flagged**: Security monitoring required

### **3. Variable-Focused Analysis Framework**
#### **Key Variables (for linking)**
- `customer_id`, `id_number`, `customer_cif`
- Always check these for data quality

#### **Demographic Variables (for analysis)**  
- `age_group`, `balance_tier_description`, `customer_risk_status`
- `identity_address_city`, `education`, `occupation`

#### **PII Variables (handle carefully)**
- `phone_number` → analyze operator (`phone_number_operator_name`)
- `date_of_birth` → convert to `age` 
- `email_address` → domain analysis

#### **Additional Information**
- `customer_flagged`, `is_on_pep`, `is_on_tbl`, `is_on_bbl`
- AML risk flags, business context

### **4. Future Analysis Framework** 
- **Always start with customer_status breakdown**
- **Classify variables before analysis**
- **Check data completeness per variable type**
- **Focus on ACTIVE customers for business insights**

---

## 📈 KPIs to Track

### **Growth Metrics**
- Monthly customer acquisition rate
- Partner channel contribution
- Cross-platform adoption rate

### **Quality Metrics**  
- Customer risk distribution
- Balance accumulation velocity
- Account activation rates

### **Operational Metrics**
- Data pipeline completeness
- Customer-balance linking success
- Real-time processing capability

---

**Analysis Completed:** September 9, 2025  
**Data Period:** August 2025  
**Next Review:** October 2025 (September data analysis)