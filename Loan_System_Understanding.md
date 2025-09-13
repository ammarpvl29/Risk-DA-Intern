# 🏦 Bank Jago Loan System Understanding

**Created**: September 12, 2025  
**Status**: Work in Progress (Based on Questions 1-6 Analysis)  
**Source**: Analysis of intern_loan_* tables and business context  

---

## 📊 Current Understanding

### **Loan Flow Overview** 
Based on your business context:

```
Customer Journey:
Mr. Bambang → Apply for loan → Onboarding → Customer → Lending (loan, trx)

Two Types:
1. Direct Lending (DL) - Using Jago money (12% interest/year)
2. Partnership (Pinjol) - B2B platform partner (40% interest, split profit)
```

### **Direct Lending (DL) Flow:**
```
Funding Jago (depositor money) 
↓
Loan Application (20M+ people)
↓
Onboarding loan (30-40 filters: SLIK, former pinjol check, education, income)
↓
Candidate for loans (1M+ people selected)
↓
Recheck loan
↓
Lending (100k people approved)
```

### **Partnership Flow:**
```
Partner Platform (Atome/Adakami) - 1M users
↓
Little onboarding
↓
Split: 400k handled by Partner, 400k handled by Jago
↓
Jago sees 400k users → onboarding loan → customer → lending
```

---

## 📋 Data Tables Understanding

### **1. Loan Offer Tables** ✅ **ANALYZED**

**`loan_offer_current`**:
- **Purpose**: Current active loan offers (815,839 records)
- **Customers**: 620,029 unique customers offered loans
- **Date Range**: June 2024 - September 2025 (created_at)
- **Key Fields**: customer_id, offer_type, offer_status, expires_at, created_at

**`loan_offer_daily_snapshot`**: 
- **Purpose**: Historical daily snapshots for trend analysis (21.9M records)
- **Coverage**: 41 business days (Aug 2 - Sep 11, 2025)
- **Relationship**: Current table = Latest business_date snapshot

**Key Insight**: Loan offers are actively managed with daily tracking

### **2. Loan Application Tables** 
**`intern_loan_application`**: 
- **Records**: 206 applications (2021-2024)
- **Status Distribution**:
  - REJECTED: 186 (90.3%)
  - ACTIVATED: 11 (5.3%) 
  - Approve: 7 (3.4%)
  - Reject: 2 (1.0%)

**Key Insight**: Very low approval rate, suggesting strict filtering (matches DL flow description)

### **3. Actual Loan Portfolio**
**`intern_credit_risk_loans`**: 
- **Records**: 542 actual loans (2023-2024)
- **Status**: Only 3 loans still active (539 closed/paid off)

**Key Insight**: This is the actual loan disbursement data (post-approval)

---

## 🔄 Loan Journey Flow (Current Understanding)

```
LOAN OFFER → LOAN APPLICATION → LOAN DISBURSEMENT
(620k offered) → (206 applied) → (542 actual loans)

Funnel Analysis:
- 620,029 customers offered loans
- Only 206 applied (0.03% conversion from offer to application)
- 18 approved from applications (8.7% approval rate)
- 542 actual loans disbursed (historical portfolio)
```

---

## 🎯 Questions Analysis Progress

### ✅ **Question 1 - COMPLETED**
**Compare loan_offer_current vs loan_offer_daily_snapshot**

**Finding**: 
- Current = Latest snapshot (perfect match)
- Daily snapshots for historical analysis
- Schema differences: business_date vs loan_offer_event_at

### ✅ **Question 2 - COMPLETED**
**Analyze August 25 vs July 25 LFS customer offers**

**Findings**:
- **August 25, 2025**: 2 LFS customers offered loans
  - **Total customers**: 2
  - **Earliest startdate**: 2021-04-15 (old LFS customer, 4+ years)
  - **Latest startdate**: 2023-01-13 (mature LFS customer, 2+ years)
- **July 25, 2025**: 0 LFS customers offered loans
  - **Total customers**: 0
  - No loan offers to LFS customers on this date

**Key Insight**: Very limited loan offers to LFS customers on these specific dates. August 25 shows targeting of established LFS customers (2+ years tenure)

### ✅ **Question 3 - COMPLETED**
**Track Direct Lending applications from August 25, 2025 offers**

**Findings**:
- **From August 25, 2025 offers → Applications**: **0** (no 2025 application data available)
- **Direct Lending ('JAD') applications**: **0** (JAD pattern not found in current data)
- **Applications same month (Aug 2025)**: **0** 
- **Applications next month (Sep 2025)**: **0**

**Data Limitation Analysis**:
- **Loan application date range**: May 2021 - August 2024 (206 total applications)
- **No 2025 data**: Application table contains only historical data through Aug 2024
- **No JAD pattern**: Direct Lending identification pattern not found in partner_id, product_code, or loan_application_source
- **Partner types found**: MAB (191 apps), MGR (11 apps), HCI (4 apps)

**Key Insight**: There is a **data gap** between loan offers (2025 data) and loan applications (2024 data). This suggests either a separate/newer application system or incomplete data pipeline integration.

### ✅ **Question 4 - COMPLETED**
**Track disbursed loans from August 25, 2025 offers**

**Findings**:
- **From August 25, 2025 offers → JAG facilities**: **0** (no disbursed Direct Lending loans)
- **Customer analysis**: 2 LFS customers, 3 total offers
  - Customer 1: `3277011103890001` (2 offers: 11:51 AM & 9:32 AM)
  - Customer 2: `3674022108950005` (1 offer: 1:24 AM)
- **JAG facility search result**: Neither customer has JAG-type loan facilities

**MasterLoanFacility Analysis**:
- **Total facilities**: 665+ million records (665,611,090)
- **JAG facilities found**: 502,194 total (JAG08: 492,904, JAG01: 9,051, etc.)
- **Date range**: Aug 1 - Sep 5, 2025
- **Unique customers with facilities**: 17.9+ million

**Data Architecture Challenge**:
- **CIF format mismatch**: Customer table uses hash format (`8a85410c85a665...`) vs MasterLoanFacility uses numeric (`69624767561728`)
- **Integration gap**: Cannot directly join customer → facility tables due to different identifier systems
- **System separation**: Suggests loan facilities managed in separate system from customer data

**Key Insight**: **Loan offers do NOT convert to disbursed loans** for the August 25 LFS customers. This indicates either very strict approval process or offers were declined/expired before disbursement.

### ✅ **Question 5 - COMPLETED**
**Understand MasterLoanFacility contents vs Handbook requirements**

**📊 Available Data Fields:**
1. ✅ **Limit (Plafond)**: Available - Rp 500K to Rp 7M range
2. ✅ **Outstanding**: Available - Same as limit (full utilization) 
3. ✅ **Tenor**: Calculated - 4.1 to 18.2 months range
4. ❌ **Interest Rate**: **NOT FOUND** in current schema

**📋 Data vs Handbook Comparison:**

| Field | **Handbook Expectation** | **MasterLoanFacility Reality** | **Match?** |
|-------|---------------------------|--------------------------------|------------|
| **Interest** | Risk-based scoring | **Missing** (no interest rate field) | ❌ **GAP** |
| **Limit** | $50-$5K (Digital Loans) | Rp 500K-7M (~$30-$420) | ✅ **MATCH** |
| **Outstanding** | Real-time tracking | Full utilization (-negative format) | ⚠️ **PARTIAL** |
| **Tenor** | 3-24 months (Digital) | 4.1-18.2 months | ✅ **MATCH** |

**🔍 Key Findings:**

**✅ What Works:**
- **Loan limits** align with digital lending expectations (Rp 500K-7M range)
- **Tenor range** fits handbook (4.1-18.2 months vs 3-24 months expected)
- **Outstanding tracking** shows full facility utilization
- **Status = 'A'** indicates active facilities
- **Recent dates** (Sep 2025) indicate active loan portfolio

**❌ Critical Gaps:**
- **No interest rate field** - Cannot analyze risk-based pricing
- **Negative values** suggest different accounting convention (liability format)
- **No partial utilization** - All loans show full drawdown (Plafond = Outstanding)

**📝 Data Format Notes:**
- **Negative amounts** likely represent liability/debt accounting convention
- **Immediate full drawdown** pattern suggests different loan structure than expected
- **665+ million facility records** indicate massive lending operation
- **502,194 JAG facilities** specifically for Direct Lending products

**Key Insight**: MasterLoanFacility tracks loan **capacity and utilization** effectively but lacks **interest rate data** critical for risk-based pricing analysis. The negative accounting format and full utilization pattern suggests this may be a facilities management table rather than active loan portfolio tracking.

### ✅ **Question 6 - COMPLETED**
**Compare MasterLoanFacility vs StgLoanFacility**

**📊 Scale & Coverage Comparison:**

| Aspect | **MasterLoanFacility** | **StgLoanFacility** | **Difference** |
|--------|-------------------------|---------------------|----------------|
| **Total Records** | 665.6 million | 727.5 million | Staging 9% larger |
| **Unique Customers** | 17.9 million | 5.3 million | Master 3.4x more customers |
| **Date Range** | Aug 1 - Sep 5 | Aug 2 - Sep 10 | Similar coverage |
| **JAG Facilities** | 502,194 total | 1,062,770 total | Staging 2.1x more JAG |

**🎯 Critical Functional Differences:**

**✅ StgLoanFacility (Staging) HAS:**
- ✅ **InterestRate field** - 100% coverage, avg 39.47% (vs Master: 0%)
- ✅ **DPD fields** (Days Past Due tracking)
- ✅ **Collectibility data** and risk monitoring
- ✅ **Fair Value calculations**
- ✅ **More detailed loan categorization**

**❌ MasterLoanFacility (Master) MISSING:**
- ❌ **No InterestRate field** (0 records with interest data)
- ❌ **Limited risk monitoring fields**
- ❌ **No DPD tracking**

**📈 JAG (Direct Lending) Facility Distribution:**
- **JAG08**: Master 492,904 vs Staging 982,007 (Staging 2x more)
- **JAG01**: Master 9,051 vs Staging 78,189 (Staging 8.6x more)
- **Pattern**: Staging consistently has more JAG facilities across all types

**🔍 Business Purpose Interpretation:**

**MasterLoanFacility** = **Facility Management System**
- **Operational focus**: Facility capacity tracking (limits, outstanding)
- **Broader customer coverage**: 17.9M customers (includes all facility holders)
- **Purpose**: Loan origination, facility setup, limit management
- **Missing**: Detailed performance and risk metrics

**StgLoanFacility** = **Risk Analytics & Performance System**  
- **Analytical focus**: Complete loan performance data with interest rates
- **Active loan focus**: 5.3M customers with actual performing loans
- **Purpose**: Risk assessment, pricing analysis, portfolio monitoring
- **Complete data**: Interest rates (39.47% avg), DPD tracking, collectibility

**🎯 Key Insight**: 
**Data Architecture Strategy** - Bank Jago uses **dual-table approach**:
1. **Master** handles operational facility management (broader scope, basic data)
2. **Staging** handles risk analytics and performance tracking (focused scope, complete data)

This explains why **Question 5** found missing interest rate data in Master - the complete analytical data lives in Staging for risk management purposes!

---

## 📊 Key Tables We Need to Understand

### **Available Tables**:
1. ✅ `loan_offer_current` / `loan_offer_daily_snapshot` - ANALYZED
2. ❓ `loan_offer` (main historical table)  
3. ✅ `intern_loan_application` - Basic stats known
4. ✅ `intern_credit_risk_loans` - Basic stats known  
5. ❓ `customer` (LFS customers)
6. ❓ `MasterLoanFacility` 
7. ❓ `StgLoanFacility`

### **Missing Understanding**:
- How loan_offer connects to customer table
- What makes a customer "LFS customer" 
- Direct Lending identification (partner_id / product like 'JAD')
- MasterLoanFacility structure and content
- Staging vs Master facility differences

---

## 🔍 Key Insights So Far

### **Business Process Validation**:
1. **Massive Filtering**: 620k offers → 206 applications confirms strict onboarding
2. **Low Conversion**: 0.03% offer-to-application suggests selective targeting needed
3. **High Rejection**: 90%+ application rejection confirms multiple validation layers
4. **Portfolio Size**: 542 loans suggests controlled, quality-focused lending

### **Data Quality**:
1. **Good Tracking**: Daily snapshots show robust monitoring
2. **Consistent IDs**: Same customer_id across offer/application tables
3. **Complete Timeline**: June 2024 - current data available

### **Next Analysis Priority**:
1. Understand LFS customer identification
2. Map offer dates to customer acquisition patterns  
3. Track Direct Lending vs Partnership loan flows
4. Analyze facility management (Master vs Staging)

---

**Status**: Ready for Question 2 Analysis  
**Next Update**: After Questions 2-6 completion