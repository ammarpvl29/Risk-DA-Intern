# Risk Data Analyst Intern Handbook
*Your Complete Guide to Banking Risk Analytics*

## Table of Contents
1. [Banking Fundamentals](#banking-fundamentals)
2. [Risk Data Analyst Role](#risk-data-analyst-role)
3. [Core Data Concepts](#core-data-concepts)
4. [Risk Management Framework](#risk-management-framework)
5. [Credit Risk Analytics](#credit-risk-analytics)
6. [Technical Skills & Tools](#technical-skills--tools)
7. [Bank Jago Case Study](#bank-jago-case-study)
8. [Key Metrics & KPIs](#key-metrics--kpis)
9. [Daily Activities](#daily-activities)
10. [Career Development](#career-development)

---

## Banking Fundamentals

### The Banking Business Model
Banks act as **financial intermediaries** connecting:
- **Surplus Units**: People/companies with excess funds (depositors)
- **Deficit Units**: People/companies needing funds (borrowers)

**Example Flow:**
```
Pak Bambang (Rp100M deposito, 2% bunga) 
    ↓
Bank Makmur (intermediary)
    ↓
Bu Indri (Rp50M pinjaman, 8% bunga)

Bank Profit = 8% - 2% = 6% spread
```

### Three Core Banking Functions

#### 1. **Funding (Penghimpunan Dana)**
- **Giro**: Demand deposits, very low interest
- **Tabungan**: Savings accounts, flexible withdrawals
- **Deposito**: Time deposits, higher interest rates
- **Goal**: Minimize Cost of Funds (CoF)

#### 2. **Lending (Penyaluran Kredit)**
- **Corporate Banking**: Large companies, complex products
- **SME/UMKM Banking**: Small-medium enterprises
- **Retail Banking**: Individual consumers
- **Goal**: Maximize Net Interest Margin (NIM)

#### 3. **Risk Management**
- **Identification**: Spot potential risks early
- **Measurement**: Quantify risk levels
- **Monitoring**: Track ongoing risk exposure
- **Control**: Implement mitigation strategies

---

## Risk Data Analyst Role

### Where You Fit in the Organization

**Three Lines of Defense:**
1. **First Line**: Business units (loan officers, relationship managers)
2. **Second Line**: Risk Management (where you work!) + Compliance
3. **Third Line**: Internal Audit

### Your Core Responsibilities

#### **Portfolio Analytics**
- Monitor loan portfolio health (NPL trends, DPD analysis)
- Perform vintage analysis on loan cohorts
- Calculate key risk metrics (NPL, CKPN, LDR)

#### **Credit Risk Modeling**
- Build and validate credit scoring models
- Develop Risk Acceptance Criteria (RAC)
- Perform model performance monitoring

#### **Regulatory Reporting**
- Prepare OJK compliance reports
- Maintain SLIK OJK data quality
- Support stress testing exercises

#### **Business Intelligence**
- Create risk dashboards and visualizations
- Provide insights to senior management
- Support product development with risk perspectives

---

## Core Data Concepts

### Data Types in Banking

#### **Master Data**
- Customer profiles (CIF - Customer Information File)
- Product specifications
- Organizational hierarchy
- *Characteristic: Static, foundational*

#### **Transaction Data**
- Real-time activity records
- Payment histories
- Account movements
- *Characteristic: High volume, dynamic*

#### **Position Data**
- End-of-period snapshots
- Account balances
- Outstanding loan amounts
- *Characteristic: Aggregated, point-in-time*

### Banking Systems Architecture

```
Core Banking System (CBS)
    ↓
Data Warehouse/Data Lake
    ↓
Analytics & BI Tools
    ↓
Risk Dashboards & Reports
```

**Key Systems:**
- **CBS**: Central transaction processing
- **LOS**: Loan Origination System
- **Decision Engine**: Automated credit decisions

---

## Risk Management Framework

### OJK Risk Management Requirements

**Four Core Processes:**
1. **Identifikasi**: Proactive risk identification
2. **Pengukuran**: Quantitative risk measurement  
3. **Pemantauan**: Continuous risk monitoring
4. **Pengendalian**: Risk control and mitigation

### Credit Assessment Process

#### **External Verification**
- **SLIK OJK**: Credit bureau check
- **Identity verification**: KTP, biometrics
- **AML/CTF screening**: Anti-money laundering

#### **Internal Analysis**
- **5C Analysis**: Character, Capacity, Capital, Collateral, Condition
- **Financial statement analysis**
- **Credit scoring models**

#### **Decision Making**
- **Risk Acceptance Criteria (RAC)**: Automated rules
- **Committee decisions**: Manual review cases
- **Documentation**: Audit trail maintenance

---

## Credit Risk Analytics

### Credit Scoring Fundamentals

#### **Types of Scoring Models**
1. **Application Scoring**: New customer assessment
2. **Behavioral Scoring**: Existing customer monitoring

#### **Scorecard Development Process**
1. **Data Preparation**
   - Define good/bad customers
   - Clean historical data
   - Handle missing values

2. **Variable Transformation**
   - Binning continuous variables
   - Calculate Weight of Evidence (WoE)
   - Information Value (IV) selection

3. **Model Building**
   - Logistic regression (most common)
   - Feature selection
   - Coefficient estimation

4. **Validation & Calibration**
   - Out-of-sample testing
   - ROC curve analysis
   - Gini coefficient calculation

### Risk Metrics Deep Dive

#### **Days Past Due (DPD)**
- Leading indicator of payment problems
- Buckets: 1-30, 31-60, 61-90, 91+ days
- Used for early warning systems

#### **Kolektibilitas (OJK Standard)**
| Level | Name | DPD Range | Status | Impact |
|-------|------|-----------|---------|---------|
| Kol-1 | Lancar | 0 days | Performing | Good credit history |
| Kol-2 | DPK | 1-90 days | Performing | Warning signals |
| Kol-3 | Kurang Lancar | 91-120 days | NPL | Credit reputation damaged |
| Kol-4 | Diragukan | 121-180 days | NPL | Recovery actions start |
| Kol-5 | Macet | 180+ days | NPL | Blacklisted in SLIK |

#### **Non-Performing Loans (NPL)**
```
NPL Ratio = (Kol-3 + Kol-4 + Kol-5) / Total Loans × 100%
Target: < 5% (regulatory requirement)
```

#### **Provision Coverage**
- **CKPN**: Cadangan Kerugian Penurunan Nilai
- Required reserves for expected losses
- Directly impacts bank profitability

---

## Technical Skills & Tools

### Must-Have Technical Skills

#### **SQL (Structured Query Language)**
```sql
-- Example: NPL calculation query
SELECT 
    product_type,
    COUNT(*) as total_loans,
    SUM(CASE WHEN kolektibilitas >= 3 THEN 1 ELSE 0 END) as npl_count,
    SUM(CASE WHEN kolektibilitas >= 3 THEN outstanding_amount ELSE 0 END) / 
    SUM(outstanding_amount) * 100 as npl_ratio
FROM loan_portfolio 
WHERE report_date = '2024-12-31'
GROUP BY product_type;
```

#### **Python for Data Science**
```python
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import roc_auc_score

# Example: Basic credit scoring workflow
def build_credit_score(df):
    X = df[['age', 'income', 'debt_ratio']]
    y = df['default_flag']
    
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.3)
    
    model = LogisticRegression()
    model.fit(X_train, y_train)
    
    y_pred_proba = model.predict_proba(X_test)[:, 1]
    auc = roc_auc_score(y_test, y_pred_proba)
    
    return model, auc
```

#### **Data Visualization**
- **Tableau**: Enterprise dashboards
- **Looker**: Google-based BI platform
- **Python (Matplotlib/Seaborn)**: Custom analytics

### Platform Knowledge

#### **Google BigQuery**
```sql
-- Example: Vintage analysis query
SELECT 
    origination_quarter,
    months_on_book,
    COUNT(*) as cohort_size,
    AVG(CASE WHEN dpd > 30 THEN 1 ELSE 0 END) as default_rate
FROM `bank.loan_performance`
WHERE origination_date >= '2023-01-01'
GROUP BY origination_quarter, months_on_book
ORDER BY origination_quarter, months_on_book;
```

---

## Bank Jago Case Study

### Business Model Overview

**Digital-First Banking:**
- DPK: Rp14.8 trillion (61% CASA, 39% deposits)
- Credit: Rp21.4 trillion with NPL <0.5%
- Integrated ecosystem: GoPay, Tokopedia, Bibit, Stockbit

### Unique Value Propositions

#### **Funding Innovation**
- **Pocket System**: Up to 60 separate savings accounts
- **Zero fees**: No admin charges, minimum balance
- **Ecosystem integration**: Seamless GoPay connection

#### **Lending Strategy**
1. **Channeling Model**: Partner with fintech/multifinance
2. **Direct Digital**: End-to-end app-based lending

### Jago Banking Architecture & Customer Flow

#### **Three Core Banking Flows**
```
Funding (Deposito) ←→ Bank Jago ←→ Borrower (Credit)
```

#### **Customer Onboarding Flow - Funding (LFS)**

**LFS = Life Financial System/Funding (Core Banking System)**

**Step 1: Customer Registration**
```
Mobile App (Jago) → CBS → DWH → Datamart (datamart.customer, datamart.risk)
```

**Step 2: Verification Process**
1. **Dukcapil Check**: KTP registration verification via government API
2. **Liveness Detection**: Face verification technology
3. **Biometrics**: Fingerprint/face recognition
4. **Video KYC**: Know Your Customer video verification
5. **DTOT Check**: Screening for terrorists/political persons (Indonesia specific)

#### **Customer Identity & CIF Management**

**Key Concept**: One person, multiple CIFs across core banking systems

**Example**: Mr. Bambang with KTP ID: 31740188
- **LFS CIF**: 010BZ (for funding/deposits)
- **Lending CIF**: Different CIF (for loan products)
- **Bridge**: KTP serves as unique identifier across systems

**Counting Logic:**
- **Unique LFS customers**: Use CIF count
- **Total unique Bank customers**: Use KTP (id_number) count  
- **All product instances**: Use CIF without deduplication

#### **Product Creation After Onboarding**

**Funding Products:**
1. **CASA (Current Account Saving Account)**
   - **Tabungan**: Savings account (flexible withdrawals)
   - Table: `loan_account`

2. **Deposito**: Time deposits (fixed term, higher interest)
   - Table: `dwh_core.account_daily_deposit` (snapshot data)

#### **Data Architecture & Tables**

**Production Tables (BigQuery):**
```sql
-- Customer snapshot (specific business_date)
SELECT * FROM data-prd-adhoc.credit_risk_adhoc.intern_data_mart_customer
WHERE business_date = '2025-08-31'

-- Balance snapshot (specific business_date)  
SELECT * FROM data-prd-adhoc.credit_risk_adhoc.intern_dwh_core_daily_closing_balance
WHERE business_date = '2025-08-31'

-- Transaction data (date range)
SELECT * FROM data-prd-adhoc.credit_risk_adhoc.intern_customer_individual_successful_transactions_analytics
WHERE transaction_date BETWEEN '2025-08-01' AND '2025-08-31'
```

#### **Data Types & Characteristics**

**Snapshot Data (Position Data):**
- **Characteristic**: Point-in-time capturing of current state
- **Behavior**: Values change over time, can increase or decrease
- **Risk**: Data can be "lost" if customer closes product
- **Example Timeline**:
  ```
  9/9/2025  | CIF: 010BZ | Tabungan | Balance: Rp 0
  10/9/2025 | CIF: 010BZ | Tabungan | Balance: Rp 50,000
  11/9/2025 | CIF: 010BZ | Tabungan | Balance: Rp 75,000
  ```
- **Product Closure**: If customer closes account, next snapshot shows 0, but historical data preserved in master tables

**Transaction Data (Event Data):**
- **Characteristic**: Event-driven recording, not real-time (1-hour delay)
- **Behavior**: Records daily mutations (in/out transactions)
- **Persistence**: Never deleted, complete audit trail
- **Example**: Onboarding transaction captured once and never changes

**Master Data vs Snapshot Data:**
- **Master**: Maintains product information even after closure (with active/inactive flag)
- **Snapshot**: Only shows current active positions
- **Key Difference**: Master has PK/FK relationships in CBS, but DWH has no formal PK/FK constraints

#### **Customer Acquisition Channels**

**Organic vs Non-Organic (Partner-driven):**
- Column: `partner_name` in customer table
- **Organic**: Direct Jago app registration
- **Non-Organic**: Through partner banks/platforms

#### **Medallion Architecture**
```
CBS (Core Banking System)
    ↓
DWH Bronze (dwh.core) 
    ↓
DWH Silver/Gold (Datamart: datamart.risk, datamart.customer, datamart.credit_risk)
```

### Risk DA Role at Bank Jago

#### **Digital Risk Analytics**
- **Real-time scoring**: Instant credit decisions
- **Behavioral analytics**: Transaction pattern analysis
- **Ecosystem risk**: Cross-platform risk assessment
- **Automation**: High-volume, low-touch processing

#### **Key Challenges**
- **Velocity risk**: Speed vs accuracy balance
- **Data quality**: Digital-only customer verification
- **Scale management**: Rapid growth with quality control
- **Regulatory compliance**: Traditional rules, digital operations

### Technology Stack
```
Customer Application (Mobile App)
    ↓
API Gateway + Authentication
    ↓
Decision Engine + Credit Scoring
    ↓
Core Banking System (CBS)
    ↓
Data Warehouse (DWH) - Bronze, Silver, Gold
    ↓
Data Lake + Analytics Platform (BigQuery)
    ↓
Risk Dashboards + Reporting
```

---

## Key Metrics & KPIs

### Primary Risk Metrics

#### **Portfolio Health**
- **NPL Ratio**: <5% (regulatory), <0.5% (Bank Jago target)
- **Provision Coverage**: CKPN/NPL ratio
- **Charge-off Rate**: Written-off loans percentage

#### **Operational Efficiency**
- **Approval Rate**: Applications approved %
- **Turnaround Time**: Application to decision speed
- **Cost per Application**: Processing cost efficiency

#### **Model Performance**
- **AUC (Area Under Curve)**: >0.7 minimum
- **Gini Coefficient**: Discriminatory power
- **Population Stability Index**: Model drift detection

#### **Business Impact**
- **Net Interest Margin**: Revenue efficiency
- **Cost of Funds**: Funding cost optimization
- **Loan-to-Deposit Ratio**: Asset utilization

### Advanced Analytics

#### **Vintage Analysis**
Track loan cohort performance over time:
```
Cohort Q1-2024: Month 6 default rate = 2.1%
Cohort Q2-2024: Month 6 default rate = 1.8%
→ Improvement in underwriting quality
```

#### **Flow Rate Analysis**
Model transitions between risk states:
```
Kol-1 → Kol-2: 5% monthly transition rate
Kol-2 → Kol-3: 15% monthly transition rate
Kol-3 → Recovery: 30% monthly cure rate
```

---

## Daily Activities

### Morning Routine (8:00-10:00)
- **Portfolio Review**: Check overnight NPL movements
- **Model Monitoring**: Validate scoring model performance
- **Alert Management**: Investigate risk threshold breaches
- **Data Quality**: Verify feed completeness and accuracy

### Core Analysis (10:00-15:00)
- **Deep Dives**: Analyze specific portfolio segments
- **Model Development**: Build/enhance credit scoring models
- **Reporting**: Prepare management dashboards
- **Business Support**: Answer stakeholder questions

### Strategic Work (15:00-17:00)
- **Project Work**: Long-term model improvements
- **Research**: Industry trends, regulatory changes
- **Collaboration**: Work with IT, product, and business teams
- **Documentation**: Maintain model documentation

### Weekly/Monthly Tasks
- **Committee Presentations**: Risk committee materials
- **Regulatory Reporting**: OJK submissions
- **Model Validation**: Quarterly performance reviews
- **Process Improvement**: Automation opportunities

---

## Career Development

### Learning Path

#### **Foundation (0-6 months)**
- Master SQL and basic Python
- Understand banking fundamentals
- Learn regulatory requirements
- Practice basic risk calculations

#### **Intermediate (6-18 months)**
- Build credit scoring models
- Develop advanced analytics skills
- Lead small projects
- Present to management

#### **Advanced (18+ months)**
- Design risk frameworks
- Mentor junior analysts
- Drive strategic initiatives
- External stakeholder management

### Key Certifications
- **SAS**: Statistical analysis software
- **PMP**: Project management
- **CRCM**: Certified Regulatory Compliance Manager
- **FRM**: Financial Risk Manager

### Skills Development Matrix

| Skill Category | Beginner | Intermediate | Advanced |
|---------------|----------|--------------|----------|
| **SQL** | Basic queries | Complex joins | Performance optimization |
| **Python** | Data manipulation | ML modeling | Production deployment |
| **Statistics** | Descriptive stats | Regression analysis | Advanced modeling |
| **Business** | Banking basics | Product knowledge | Strategic thinking |
| **Communication** | Basic reporting | Executive presentations | Stakeholder management |

### Career Progression

```
Risk Data Analyst (Entry)
    ↓
Senior Risk Analyst (2-3 years)
    ↓
Risk Analytics Manager (4-6 years)
    ↓
Head of Risk Analytics (7-10 years)
    ↓
Chief Risk Officer (10+ years)
```

**Alternative Paths:**
- **Product Management**: Risk-focused product development
- **Consulting**: External risk advisory
- **Fintech**: Risk roles in digital financial services
- **Regulatory**: OJK, Bank Indonesia positions

---

## Quick Reference Guide

### Essential Formulas

```
NPL Ratio = NPL Amount / Total Loans × 100%
Cost of Funds = Interest Expense / Average Funds × 100%
LDR = Total Loans / Total Deposits × 100%
NIM = (Interest Income - Interest Expense) / Average Assets × 100%
```

### Important Thresholds
- NPL Ratio: <5% (regulatory requirement)
- LDR: 78%-92% (optimal range)
- Model AUC: >0.7 (acceptable performance)
- Provision Coverage: >100% (conservative)

### Emergency Contacts
- Risk Manager: Immediate supervisor
- IT Support: System issues
- Compliance: Regulatory questions
- Data Team: Data quality issues

### Useful Resources
- OJK Regulations: www.ojk.go.id
- Bank Indonesia: www.bi.go.id
- Internal Risk Portal: [Company specific]
- Training Materials: [Company specific]

---

*This handbook is a living document. Update it regularly with new learnings and experiences during your internship journey.*

**Last Updated**: January 2025
**Version**: 1.0
**Author**: Risk Data Analyst Intern Program