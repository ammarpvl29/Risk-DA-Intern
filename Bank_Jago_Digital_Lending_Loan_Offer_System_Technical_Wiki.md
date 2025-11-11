# Bank Jago Digital Lending - Loan Offer System Technical Documentation

**Document Type:** Technical Wiki Entry - System Architecture & Business Process
**Domain:** Digital Lending - Credit Risk
**Last Updated:** 2025-11-07
**Status:** ✅ Active Documentation
**Audience:** Data Analysts, Risk Team, Engineering
**Knowledge Level:** Based on TUPR Dashboard Development (Nov 2025)

---

## Table of Contents

1. [Executive Overview](#executive-overview)
2. [Loan Offer Lifecycle](#loan-offer-lifecycle)
3. [Underwriting Waterfall Process](#underwriting-waterfall-process)
4. [Campaign Segmentation Strategy](#campaign-segmentation-strategy)
5. [Product Portfolio](#product-portfolio)
6. [Take-Up Process & Metrics](#take-up-process--metrics)
7. [Data Architecture](#data-architecture)
8. [Temporal Mechanics](#temporal-mechanics)
9. [Business Rules & Logic](#business-rules--logic)
10. [Performance Metrics](#performance-metrics)
11. [Known Limitations & Edge Cases](#known-limitations--edge-cases)
12. [Open Questions](#open-questions)
13. [Glossary](#glossary)

---

## Executive Overview

### System Purpose

Bank Jago's Digital Lending system manages the end-to-end lifecycle of **pre-approved loan offers** to retail customers. The system:

1. **Underwrites** customers through automated waterfall logic
2. **Generates** personalized loan offers with specific limits and terms
3. **Delivers** offers through digital channels (app, WhatsApp, email)
4. **Tracks** customer acceptance and disbursement
5. **Measures** campaign effectiveness via Take-Up Rate (TUPR)

### Key Metrics (October 2025)

| Metric | Value | Definition |
|--------|-------|------------|
| **Total Offers** | 553,528 | Customers with active loan offers |
| **Disbursed** | 4,715 | Customers who accepted and drew down |
| **TUPR** | 0.85% | Overall take-up rate (disbursed/offers) |
| **New Offers** | 81,372 (14.7%) | Offers created in current month |
| **Carry-Over** | 472,156 (85.3%) | Offers from previous months still active |

### System Scale

- **Monthly Volume:** 80K-580K active offers
- **Campaigns:** 3 main segments (BAU, CT, Weekly)
- **Products:** 4+ loan products (JAG06, JAG08, JAG09, JAG01, JAG71)
- **Risk Tiers:** 6 brackets (L, LM, M, MH, H, NO_BUREAU)
- **Data Sources:** 8+ tables across dwh_core, data_mart, dl_whitelist schemas

---

## Loan Offer Lifecycle

### Stage 1: Customer Eligibility (Underwriting)

**Process Flow:**
```
Customer → Waterfall Evaluation → Segment Assignment → Offer Generation → Upload to System
```

**Key Attributes Evaluated:**
1. **Credit Bureau Score** (if available) → Risk Bracket
2. **Transaction History** (L4M, L12M) → Behavioral Segment
3. **Account Tenure** (MOB - Month on Books) → Maturity
4. **Income Estimation** → Limit Calculation
5. **Delinquency Risk** (EWS Score) → Risk Grade
6. **Geographic/Demographic** → Test Eligibility

**Outputs:**
- `waterfall_failure_step`: Step at which customer passed/failed
- `risk_bracket`: L, LM, M, MH, H, NO_BUREAU
- `campaign_segment`: BAU, CT, Weekly
- `campaign_category`: Specific test name (e.g., "CT 10: Never Trx")
- `flag_offer_upload`: Yes/No (whether offer should be created)

---

### Stage 2: Offer Generation

**When:** After customer passes waterfall (step "99. Passed Underwriting Waterfall")

**Offer Attributes:**

| Field | Description | Example |
|-------|-------------|---------|
| `customer_id` | Unique customer identifier | "0000086000" |
| `created_at` | Offer creation timestamp | 2025-09-04 10:23:15 |
| `expires_at` | Offer expiry timestamp | 2025-10-04 23:59:59 |
| `product_code` | Loan product type | JAG06, JAG08, JAG09 |
| `offer_status` | Current status | ENABLED, DISABLED, EXPIRED |
| `risk_bracket` | Risk grade | L, LM, M, MH, H |
| `installment_initial_facility_limit` | Installment loan limit (IDR) | 10,000,000 |
| `overdraft_initial_facility_limit` | Overdraft limit (IDR) | 5,000,000 |

**Business Rules:**

1. **Offer Duration:**
   - Standard: 30 days (1 month)
   - Special campaigns: Can vary (detected via `DATE_DIFF(expires_at, created_at)`)

2. **Limit Calculation:**
   - Based on income estimation (CBAS model)
   - Capped by risk bracket maximums
   - Product-specific limits apply

3. **Offer Status:**
   - `ENABLED`: Active, customer can accept
   - `DISABLED`: Manually disabled (policy/fraud)
   - `EXPIRED`: Past expiry date

---

### Stage 3: Offer Delivery

**Channels:** (Inferred from notification tables)
1. **In-App Notification** (CleverTap journey)
2. **WhatsApp Blast** (GTM campaigns)
3. **Push Notification** (Mobile app)
4. **Email** (For specific segments)

**Delivery Timing:**
- **BAU:** Continuous delivery as customers qualify
- **CT:** Campaign-specific schedules (monthly cohorts)
- **Weekly:** Rapid iteration (weekly batches)

---

### Stage 4: Customer Decision

**Customer Journey:**
```
Receive Notification → View Offer in App → Review Terms → Accept/Reject
```

**Acceptance Indicators:**
- `agreement_agreed_at IS NOT NULL`: Customer accepted offer
- `facility_start_date`: Date when loan facility became active

**Rejection Paths:**
1. **Explicit Rejection:** Customer declines in app (not tracked in current data)
2. **Implicit Rejection:** Offer expires without acceptance (most common)
3. **Partial Acceptance:** Customer views but doesn't complete (not tracked)

---

### Stage 5: Disbursement (Take-Up)

**When:** After customer accepts and completes KYC/documentation

**Disbursement Data:**

| Field | Source Table | Description |
|-------|--------------|-------------|
| `facility_start_date` | credit_risk_vintage_account_direct_lending | Loan start date |
| `plafond_facility` | CRVADL | Total facility limit granted |
| `plafond` | CRVADL | Initial drawdown amount |
| `outstanding_balance` | CRVADL | Current outstanding (at MOB 0) |

**Matching Logic:**
```sql
-- Offer → Disbursement matching
WHERE facility_start_date > offer.key_date  -- After offer was active
  AND FORMAT_DATE('%Y-%m', facility_start_date) = FORMAT_DATE('%Y-%m', offer.key_date)  -- Same month
  AND deal_type IN ('JAG06', 'JAG08', 'JAG09')  -- Product match
```

**Key Insight:**
- Not all accepted offers disburse in the same month (timing lag)
- Some offers expire before disbursement (KYC incomplete)
- Multiple offers can exist for same customer (only latest counts)

---

## Underwriting Waterfall Process

### Waterfall Concept

A **waterfall** is a series of sequential checks that filter customers for loan eligibility. Customers "flow down" the waterfall until they either:
1. **Pass all checks** → Offer generated
2. **Fail a check** → Stopped at that step (recorded in `waterfall_failure_step`)

### Waterfall Types

Bank Jago operates **3 parallel waterfalls**:

#### 1. BAU Waterfall (Business As Usual)

**Purpose:** Standard underwriting for control group

**Data Source:** `dl_wl_final_whitelist_raw_history`

**Selection Criteria:**
```sql
WHERE waterfall_failure_step = '99. Passed Underwriting Waterfall'
  AND flag_offer_upload = 'Yes'
  AND NOT IN (credit_test_waterfall)  -- Exclude CT customers
```

**Volume:** ~70-80% of total offers

**Characteristics:**
- Stable, proven risk models
- Lower experiment risk
- Baseline for A/B testing

---

#### 2. CT Waterfall (Credit Test)

**Purpose:** Experimental campaigns testing new risk criteria

**Data Source:** `dl_wl_final_whitelist_credit_test_raw_history`

**Selection Criteria:**
```sql
WHERE waterfall_failure_step = '99. Passed Underwriting Waterfall'
  AND flag_offer_upload = 'Yes'
  AND category IS NOT NULL  -- Test category assignment
```

**Volume:** ~10-25% of total offers (varies by month)

**Test Categories (October 2025):**

| Category | Description | Volume | TUPR |
|----------|-------------|--------|------|
| **CT 10: Never Trx** | Customers with no transactions | 138,444 | 0.41% |
| **CT 3a: Expansion Trx > L12M** | Transaction expansion opportunity | 19,583 | N/A |
| **CT 6: Jago MOB** | Tenure-based targeting | 6,622 | 13.16% |
| **CT 9: Highrisk EWS** | High EWS score segment | 5,406 | 1.87% |
| **CT 2: Trx L4-L12M** | Recent transaction activity | 3,001 | N/A |
| **CT 7: Area + Trx** | Geographic + behavioral | 507 | N/A |

**Key Insight:**
- CT 6 (Jago MOB) has highest TUPR (13.16%) - successful test!
- CT 10 (Never Trx) has largest volume but low TUPR (0.41%) - risky segment

---

#### 3. Weekly Waterfall

**Purpose:** Rapid iteration testing (A/B tests with 1-week cycles)

**Data Source:** `dl_wl_final_whitelist_weekly_raw_history`

**Selection Criteria:**
```sql
WHERE waterfall_failure_step = '99. Passed Underwriting Waterfall'
  AND flag_offer_upload = 'Yes'
```

**Volume:** <1% of total offers (small experiments)

**Characteristics:**
- Fast feedback loops
- Higher risk tolerance
- Quick wins/failures

---

### Waterfall Step Structure

**Step Numbering:**
- **01-98:** Specific failure reasons (e.g., "05. Bureau Score Too Low")
- **99:** "Passed Underwriting Waterfall" ✅
- **NULL:** Customer not evaluated

**Example Waterfall Steps:** (Inferred, not confirmed)
```
01. Customer Not Active
02. Insufficient Account History (MOB < 3)
03. Existing Loan Outstanding
04. Bureau Score Too Low
05. High Delinquency Risk (EWS)
...
99. Passed Underwriting Waterfall ✅
```

**Data Quality Note:**
- Only customers at step "99" with `flag_offer_upload = 'Yes'` should have offers
- If offer exists but waterfall shows different step → data inconsistency

---

### Risk Bracket Assignment

**Definition:** Risk grade assigned during underwriting based on credit score + behavior

| Bracket | Description | TUPR (Oct 2025) | Volume | Notes |
|---------|-------------|-----------------|--------|-------|
| **L** | Low Risk | 6.56% | 162,006 | Highest TUPR - best customers |
| **LM** | Low-Medium Risk | 4.64% | 212,079 | Second best TUPR |
| **M** | Medium Risk | 3.64% | 111,394 | Average performance |
| **MH** | Medium-High Risk | 6.13% | 55,911 | Anomaly - higher than M (investigate!) |
| **H** | High Risk | 0.83% | 5,012 | Low TUPR - risky segment |
| **NO_BUREAU** | No Credit Bureau Data | 0.00% | 7,126 | **Zero disbursements** - policy restriction |

**Key Findings:**
1. **Inverse relationship (generally):** Lower risk → Higher TUPR ✅
2. **MH anomaly:** 6.13% TUPR (higher than M at 3.64%) - needs investigation
3. **NO_BUREAU policy:** Appears to be hard block (0% TUPR across all months)

---

### Limit Calculation Logic

**Inputs:**
1. **Income Estimation** (from CBAS model or waterfall tables)
2. **Risk Bracket** (determines max multiplier)
3. **Product Type** (JAG06 vs JAG08 have different limits)

**Formula:** (Inferred)
```
limit = MIN(
  income * risk_multiplier,
  product_max_limit,
  regulatory_max_limit
)
```

**Limit Tiers Distribution (Oct 2025):**

| Tier | Range (IDR) | Volume | TUPR | Insight |
|------|-------------|--------|------|---------|
| **<5M** | 0 - 4,999,999 | 12,638 | 3.16% | Small loans |
| **5-10M** | 5,000,000 - 9,999,999 | 90,913 | **7.83%** | **Sweet spot!** |
| **10-20M** | 10,000,000 - 19,999,999 | 199,974 | 4.94% | Mid-range |
| **>20M** | 20,000,000+ | 250,003 | 3.13% | Large loans, lower TUPR |

**Key Insight:**
- **5-10M tier has highest TUPR (7.83%)** - customers most comfortable with mid-range limits
- Very high limits (>20M) have lower TUPR (3.13%) - customers hesitant about large debt

---

## Campaign Segmentation Strategy

### Segmentation Hierarchy

```
All Customers
├── BAU (Control)
│   └── Standard underwriting (70-80%)
│
├── CT (Credit Tests)
│   ├── CT 1: Area
│   ├── CT 2: Trx L4-L12M
│   ├── CT 3: Trx L12M+
│   ├── CT 3a: Expansion Trx > L12M
│   ├── CT 6: Jago MOB
│   ├── CT 7: Area + Trx
│   ├── CT 9: Highrisk EWS
│   └── CT 10: Never Trx
│   └── (10-25%)
│
├── Weekly (Rapid Tests)
│   └── Various experiments (<1%)
│
├── Open Market (Non-Targeted)
│   └── JAG09 flexi loan offers (3.6%)
│
└── Employee & Partner Payroll
    └── JAG01, JAG71 special programs (<0.01%)
```

---

### BAU (Business As Usual)

**Definition:** Control group using proven underwriting criteria

**Selection Logic:**
```sql
-- Customer passes BAU waterfall
-- AND not in CT waterfall (deduplication)
```

**Characteristics:**
- **Volume:** 393,169 customers (68% of Oct 2025)
- **TUPR:** 1.02% (baseline)
- **Stability:** Month-over-month consistent
- **Purpose:** Benchmark for experiments

**Key Metrics (Oct 2025):**
```
New BAU:        57,029 customers, 1,749 disbursed (3.07% TUPR)
Carry-Over BAU: 336,140 customers, 2,338 disbursed (0.70% TUPR)
```

**Insight:** New offers have **4.4x higher TUPR** than carry-over (3.07% vs 0.70%)

---

### CT (Credit Test)

**Definition:** Experimental segments testing new targeting hypotheses

**Selection Logic:**
```sql
-- Customer passes CT waterfall
-- Takes priority over BAU (higher rnk in deduplication)
```

**Test Portfolio:**

#### High Performers:
- **CT 6: Jago MOB** - 13.16% TUPR (tenure-based works!)
- **CT 9: Highrisk EWS** - 1.87% TUPR (manageable risk segment)

#### Large Volume Tests:
- **CT 10: Never Trx** - 138,444 customers, 0.41% TUPR (largest CT, low conversion)
- **CT 3a: Expansion Trx** - 19,583 customers (expansion opportunity)

#### Specialized:
- **CT 7: Area + Trx** - 507 customers (geographic experiment)

**Overall CT Performance (Oct 2025):**
```
Total CT:       143,498 customers
Disbursed:      281 customers
TUPR:           0.20% (lower than BAU 1.02%)
```

**Key Finding:** Most CT tests underperform BAU → Need optimization or graduation

---

### Weekly (Rapid Iteration)

**Definition:** Fast-cycle A/B tests with weekly cohorts

**Characteristics:**
- **Volume:** 0-75 customers/month (very small)
- **TUPR:** Highly variable (0% to 13% across months)
- **Purpose:** Quick validation before scaling to CT

**Data Limitation:** Limited historical data available (started mid-2025?)

---

### Open Market (Non-Targeted)

**Definition:** JAG09 flexi loan offers to customers who didn't qualify for targeted campaigns

**Selection Logic:**
```sql
-- Customer has offer
-- BUT not in BAU/CT/Weekly waterfall
-- AND product_code = 'JAG09'
```

**Characteristics:**
- **Volume:** 20,544 customers (3.56% of Oct 2025)
- **TUPR:** **3.96%** (higher than BAU 1.02%!) 🎯
- **Products:** JAG09 only (flexi loan)

**Key Insight:**
- Open Market (non-targeted) has **3.9x higher TUPR than BAU**!
- JAG09 flexi loan is highly attractive to customers
- Suggests value in "always-on" product availability vs. targeted campaigns

---

### Employee & Partner Payroll

**Definition:** Special loan programs for Bank Jago employees and partner companies

**Selection Logic:**
```sql
-- Customer has offer
-- BUT not in BAU/CT/Weekly waterfall
-- AND product_code IN ('JAG01', 'JAG71')
```

**Characteristics:**
- **Volume:** 5 customers (0.001% of Oct 2025)
- **TUPR:** 0% (Oct), varies by month
- **Products:** JAG01, JAG71 (special programs)

**Data Limitation:** Very low volume → difficult to assess performance

---

### Segment Prioritization (Deduplication Logic)

**Rule:** Customer can only belong to ONE segment

**Priority Order:**
```
1. BAU (rank 1) - If customer in BAU waterfall only
2. CT (rank 2) - If customer in CT waterfall (overrides BAU)
3. Weekly (rank 3) - If customer in Weekly waterfall (overrides CT/BAU)
4. Open Market - If no waterfall match AND JAG09
5. Employee/Partner - If no waterfall match AND JAG01/JAG71
```

**Implementation:**
```sql
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY customer_id, business_date
  ORDER BY rnk ASC  -- Lower rank = higher priority
) = 1
```

---

## Product Portfolio

### Product Overview

| Code | Name | Type | Target Segment | Oct 2025 TUPR |
|------|------|------|----------------|---------------|
| **JAG06** | Installment Loan | Term Loan | Mass market | 1.16% |
| **JAG08** | Overdraft | Revolving | Mass market | 3.76% |
| **JAG09** | Flexi Loan | Revolving | Open market | **12.85%** |
| **JAG01** | Employee Program | Term Loan | Employees | N/A |
| **JAG71** | Partner Payroll | Term Loan | Partners | N/A |

---

### JAG06 - Installment Loan

**Product Characteristics:**
- **Type:** Fixed-term installment loan
- **Limit Field:** `installment_initial_facility_limit`
- **Tenure:** Fixed (3, 6, 12, 24 months - inferred)
- **Repayment:** Fixed monthly installments

**Performance (Oct 2025):**
```
Volume:         462,948 customers (83.5% of total)
Disbursed:      3,371 customers
TUPR:           1.16%
```

**Volume Trend:**
- First appeared in **Sept-Oct 2025** (new product launch)
- Quickly became largest volume product
- Likely replaced or supplemented older loan products

**Key Insight:** Largest volume but relatively low TUPR - mass market appeal but low urgency?

---

### JAG08 - Overdraft Facility

**Product Characteristics:**
- **Type:** Revolving credit line (like credit card)
- **Limit Field:** `overdraft_initial_facility_limit`
- **Tenure:** Ongoing (no fixed term)
- **Repayment:** Flexible, pay as used

**Performance (Oct 2025):**
```
Volume:         81,360 customers (14.7% of total)
Disbursed:      985 customers
TUPR:           3.76%
```

**Key Insight:**
- **3.2x higher TUPR than JAG06** (3.76% vs 1.16%)
- Revolving credit more attractive than fixed-term?
- Flexibility drives take-up

---

### JAG09 - Flexi Loan

**Product Characteristics:**
- **Type:** Flexible revolving loan
- **Limit Field:** `overdraft_initial_facility_limit` (shares field with JAG08)
- **Tenure:** Flexible
- **Target:** Open market (non-targeted customers)

**Performance (Oct 2025):**
```
Volume:         8,873 customers (1.6% of total)
Disbursed:      359 customers
TUPR:           12.85% 🌟
```

**Key Insights:**
- **Highest TUPR of all products** (12.85% - 11x higher than JAG06!)
- Open market (non-targeted) product
- Suggests strong product-market fit
- Small volume but exceptional conversion

**Historical Note:**
- Prominent in early 2025 (Jan-Aug)
- Volume decreased in Sept-Oct (possibly by design - focus on JAG06?)

---

### JAG01 - Employee Loan Program

**Product Characteristics:**
- **Type:** Special employee benefit loan
- **Limit Field:** Varies
- **Target:** Bank Jago employees only

**Performance (Oct 2025):**
```
Volume:         319 customers
Disbursed:      N/A
TUPR:           N/A (very low volume)
```

**Data Limitation:** Too few customers for statistical significance

---

### JAG71 - Partner Payroll Loan

**Product Characteristics:**
- **Type:** Payroll-linked loan for partner companies
- **Limit Field:** Varies
- **Target:** Employees of partner companies

**Performance (Oct 2025):**
```
Volume:         1 customer
Disbursed:      0
TUPR:           0%
```

**Data Limitation:** Essentially no data available

---

### Product Limit Ranges

**Observed Limits (Oct 2025):**

| Product | Min Limit | Max Limit | Most Common Tier |
|---------|-----------|-----------|------------------|
| JAG06 | ~1M | ~50M | 10-20M (largest volume) |
| JAG08 | ~1M | ~30M | >20M (high limits offered) |
| JAG09 | ~1M | ~30M | 5-10M (sweet spot) |

**Insight:** Higher limits don't always mean higher TUPR - JAG09 with mid-range limits outperforms

---

## Take-Up Process & Metrics

### TUPR Definition

**Take-Up Rate (TUPR)** = The percentage of loan offers that convert to disbursements

**Formula:**
```
TUPR = (Customers Disbursed / Total Customers Offered) × 100%
```

**Alternative Calculation:**
```
TUPR by Limit = (Total Limit Disbursed / Total Limit Offered) × 100%
```

**Note:** TUPR by customer is typically **2x higher** than TUPR by limit
- Customers tend to take smaller amounts than offered
- Example (Oct 2025): Customer TUPR = 0.85%, Limit TUPR = 0.45%

---

### TUPR Calculation Logic

**SQL Pattern:**
```sql
-- Numerator: Customers disbursed
COUNT(DISTINCT CASE WHEN flag_disburse = 1 THEN customer_id END)

-- Denominator: Total customers offered
COUNT(DISTINCT customer_id)

-- TUPR
ROUND(
  COUNT(DISTINCT CASE WHEN flag_disburse = 1 THEN customer_id END) * 100.0 /
  NULLIF(COUNT(DISTINCT customer_id), 0),
  2
) AS take_up_rate_pct
```

**Important:** Must use `SAFE_DIVIDE` or `NULLIF` to handle zero division

**Common Mistake:**
```sql
-- ❌ WRONG - averages pre-calculated percentages
AVG(tupr_pct)

-- ✅ CORRECT - recalculates from summed components
SUM(disbursed) / SUM(offered) * 100
```

---

### Disbursement Matching Logic

**Challenge:** How to match an offer to a disbursement?

**Current Logic:**
```sql
-- Offer side
SELECT
  customer_id,
  key_date,  -- Month of offer (LAST_DAY of created_at or expires_at - 1 month)
  product_code,
  limit_offer
FROM base_loan_offer

-- Disbursement side
SELECT
  customer_id,
  facility_start_date,
  deal_type,
  plafond_facility
FROM credit_risk_vintage_account_direct_lending
WHERE mob = 0  -- Only first month of loan

-- Matching
ON customer_id = customer_id
  AND facility_start_date > key_date  -- After offer became active
  AND FORMAT_DATE('%Y-%m', facility_start_date) = FORMAT_DATE('%Y-%m', key_date)  -- Same month
```

**Key Rules:**
1. **Same customer** (customer_id match)
2. **Same month** (offer and disburse in same calendar month)
3. **After offer active** (facility_start_date > key_date)
4. **MOB = 0** (Only count initial disbursement, not subsequent drawdowns)

**Edge Cases:**
- Customer receives offer on Sept 25 → Disburses Oct 5 → **NOT counted** (different months)
- Customer has multiple offers → Only **latest offer** counts
- Customer disburses multiple times → Only **first disbursement** (MOB = 0) counts

---

### TUPR Benchmarks

**Overall Performance (2025):**

| Month | Customers | Disbursed | TUPR | Notes |
|-------|-----------|-----------|------|-------|
| **2025-03** | 46,495 | 2,749 | **5.91%** | Anomaly - special campaign? |
| **2025-04** | 314,312 | 5,746 | 1.83% | |
| **2025-05** | 275,652 | 5,125 | 1.86% | |
| **2025-06** | 270,416 | 2,729 | 1.01% | |
| **2025-07** | 271,719 | 3,003 | 1.11% | |
| **2025-08** | 275,964 | 3,099 | 1.12% | |
| **2025-09** | 584,779 | 5,827 | 1.00% | |
| **2025-10** | 553,528 | 4,715 | **0.85%** | Lowest since Jan |

**Trend Analysis:**
- **March spike:** 5.91% TUPR (needs investigation - data quality or campaign success?)
- **Stable period:** Apr-Sep around 1.0-1.5%
- **October decline:** 0.85% TUPR (high carry-over volume dilutes TUPR)

---

### TUPR Drivers

**Positive Drivers (Higher TUPR):**
1. **New Offers:** 2.69% TUPR (vs 0.54% carry-over)
2. **Low Risk Grade:** L bracket = 6.56% TUPR
3. **Product Type:** JAG09 = 12.85% TUPR
4. **Mid-Range Limits:** 5-10M tier = 7.83% TUPR
5. **Overdraft Products:** JAG08 = 3.76% TUPR

**Negative Drivers (Lower TUPR):**
1. **Carry-Over Offers:** 0.54% TUPR (aging offers lose urgency)
2. **High Risk Grade:** H bracket = 0.83% TUPR, NO_BUREAU = 0%
3. **Large Limits:** >20M tier = 3.13% TUPR (customer hesitation)
4. **CT Tests:** 0.20% TUPR (most tests underperform BAU)

**Key Insight:** **Freshness matters!** New offers have 5x higher TUPR than carry-over

---

### First Utilization Rate

**Definition:** How much of the offered limit does customer actually draw?

**Formula:**
```
Utilization = (plafond / plafond_facility) × 100%
```

**Observed Pattern:** (From validation data)
- Most customers draw **50-80%** of offered limit on first drawdown
- NOT 100% utilization (conservative initial usage)

**Implication:**
- Customers more cautious than limits suggest
- Opportunity for upsell/limit increase post-disbursement

---

## Data Architecture

### Core Tables

#### 1. `dwh_core.loan_offer_daily_snapshot`

**Purpose:** Daily snapshot of all active loan offers

**Key Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `business_date` | DATE | Snapshot date (LAST_DAY of month) |
| `customer_id` | STRING | Customer identifier |
| `created_at` | TIMESTAMP | When offer was created |
| `updated_at` | TIMESTAMP | Last modification |
| `agreement_agreed_at` | TIMESTAMP | When customer accepted |
| `expires_at` | TIMESTAMP | When offer expires |
| `product_code` | STRING | JAG06, JAG08, JAG09, etc. |
| `offer_status` | STRING | ENABLED, DISABLED, EXPIRED |
| `risk_bracket` | STRING | L, LM, M, MH, H, NO_BUREAU |
| `installment_initial_facility_limit` | NUMERIC | Installment loan limit |
| `overdraft_initial_facility_limit` | NUMERIC | Overdraft limit |

**Snapshot Logic:**
```sql
-- Only snapshots on:
-- 1. Last day of month (LAST_DAY)
-- 2. Current date (for near real-time tracking)
WHERE business_date = LAST_DAY(business_date) OR business_date = CURRENT_DATE()
```

**Important:** This is a **snapshot table**, not transaction log
- Same offer appears in multiple snapshots (one per month while active)
- Need deduplication when counting unique customers

---

#### 2. `dl_whitelist_checkers.dl_wl_final_whitelist_raw_history` (BAU)

**Purpose:** Historical record of BAU waterfall evaluations

**Key Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `business_date` | DATE | Evaluation date |
| `customer_id` | STRING | Customer identifier |
| `waterfall_failure_step` | STRING | Step where customer stopped |
| `flag_offer_upload` | STRING | Yes/No - create offer? |
| `risk_group` | STRING | HCI risk group |
| `ews_calibrated_scores_bin` | STRING | EWS score bucket |
| `income` | NUMERIC | Estimated income |

**Usage:**
```sql
-- Get customers who passed BAU waterfall
WHERE waterfall_failure_step = '99. Passed Underwriting Waterfall'
  AND flag_offer_upload = 'Yes'
```

---

#### 3. `dl_whitelist_checkers.dl_wl_final_whitelist_credit_test_raw_history` (CT)

**Purpose:** Historical record of Credit Test waterfall evaluations

**Key Fields:** (Same as BAU, plus:)

| Field | Type | Description |
|-------|------|-------------|
| `category` | STRING | CT test name (e.g., "CT 10: Never Trx") |

**Usage:**
```sql
-- Get customers who passed CT waterfall
WHERE waterfall_failure_step = '99. Passed Underwriting Waterfall'
  AND flag_offer_upload = 'Yes'
  AND category IS NOT NULL
```

---

#### 4. `dl_whitelist_checkers.dl_wl_final_whitelist_weekly_raw_history` (Weekly)

**Purpose:** Historical record of Weekly rapid test evaluations

**Key Fields:** Similar to CT

**Usage:** Same pattern as BAU/CT

---

#### 5. `data_mart.credit_risk_vintage_account_direct_lending` (CRVADL)

**Purpose:** Loan portfolio vintage analysis (disbursements + performance)

**Key Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `business_date` | DATE | Reporting date |
| `lfs_customer_id` | STRING | Customer ID (note: different naming!) |
| `deal_type` | STRING | JAG06, JAG08, JAG09 |
| `facility_start_date` | DATE | When loan started |
| `mob` | INTEGER | Months on book (0 = first month) |
| `plafond_facility` | NUMERIC | Total facility limit |
| `plafond` | NUMERIC | Drawn amount |
| `outstanding_balance` | NUMERIC | Current balance (negative = owed) |

**Usage:**
```sql
-- Get disbursements
WHERE mob = 0  -- First month only
  AND facility_start_date >= '2025-01-01'
  AND deal_type IN ('JAG06', 'JAG08', 'JAG09')
```

**Important:** `outstanding_balance` is **negative** for amounts owed by customer!

---

#### 6. `data_mart.customer`

**Purpose:** Customer master data (demographics)

**Key Fields:**

| Field | Type | Description |
|-------|------|-------------|
| `business_date` | DATE | Snapshot date |
| `customer_id` | STRING | Customer identifier |
| `date_of_birth` | DATE | DOB |
| `gender` | STRING | Gender |
| `city` | STRING | City of residence |

**Usage:**
```sql
-- Calculate age
DATE_DIFF(CURRENT_DATE(), date_of_birth, YEAR) AS age

-- Age tiers
CASE
  WHEN age < 21 THEN '<21'
  WHEN age BETWEEN 21 AND 25 THEN '21-25'
  WHEN age BETWEEN 26 AND 30 THEN '26-30'
  ...
END AS age_tier
```

---

### Data Lineage

**TUPR Dashboard Pipeline:**

```
┌─────────────────────────────────────────────────┐
│ SOURCE TABLES                                    │
└─────────────────────────────────────────────────┘
    │
    ├─► loan_offer_daily_snapshot (offers)
    ├─► dl_wl_*_raw_history (waterfall × 3)
    ├─► customer (demographics)
    └─► credit_risk_vintage_account_direct_lending (disbursements)
    │
    ▼
┌─────────────────────────────────────────────────┐
│ QUERY 1: base_loan_offer_snapshot               │
│ • Filter to ENABLED offers                       │
│ • Deduplicate by customer_id, business_date     │
│ • Calculate source (new vs carry-over)          │
│ • Calculate key_date for matching               │
│ Output: 577,680 rows (Oct 2025)                 │
└─────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────┐
│ QUERY 2: base_loan_offer_with_demo              │
│ • JOIN customer table (demographics)            │
│ • Calculate age_tier                            │
│ Output: 577,680 rows (no loss)                  │
└─────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────┐
│ QUERY 2.5: base_loan_offer_with_campaign        │
│ • COALESCE multi-month lookback (4 joins)       │
│ • Split Unknown by product_code                 │
│ • Assign campaign_segment & category            │
│ Output: 577,680 rows (no loss)                  │
└─────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────┐
│ QUERY 3: tupr_dashboard_final_dataset           │
│ • JOIN disbursement data (CRVADL)               │
│ • Calculate flag_disburse (0/1)                 │
│ • Aggregate by dimensions                       │
│ • Calculate TUPR %                              │
│ Output: ~1,500 rows (dimensional)               │
└─────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────┐
│ QUERY 4: tupr_dashboard_monthly_summary         │
│ • Aggregate to month + source + segment         │
│ • High-level KPIs only                          │
│ Output: ~20 rows                                │
└─────────────────────────────────────────────────┘
    │
    ▼
┌─────────────────────────────────────────────────┐
│ LOOKER DASHBOARD                                 │
│ • KPI boxes (from Query 4)                      │
│ • Pivot tables (from Query 3)                   │
│ • Trend charts (from Query 3)                   │
└─────────────────────────────────────────────────┘
```

---

## Temporal Mechanics

### New vs Carry-Over Classification

**Definition:**
- **New Offer:** Created in the current snapshot month
- **Carry-Over Offer:** Created in a previous month, still active in current month

**Logic:**
```sql
CASE
  WHEN LAST_DAY(DATE(created_at), MONTH) < business_date THEN 'carry over'
  ELSE 'new'
END AS source
```

**Example:**
```
Offer created: 2025-09-15
Business_date: 2025-10-31

LAST_DAY(2025-09-15) = 2025-09-30
2025-09-30 < 2025-10-31 → 'carry over' ✅
```

**Distribution (Oct 2025):**
```
New:         81,372 customers (14.7%)
Carry-Over:  472,156 customers (85.3%)
```

**Key Insight:** **85% of offers are carry-over** - most customers don't take up immediately

---

### Key Date Calculation

**Purpose:** Determine which month an offer "belongs to" for TUPR calculation

**Logic:**
```sql
CASE
  WHEN DATE_DIFF(DATE(expires_at), DATE(created_at), MONTH) = 1
    THEN DATE(created_at)  -- Standard 1-month offer
  ELSE DATE_SUB(CAST(expires_at AS DATE), INTERVAL 1 MONTH)  -- Non-standard duration
END AS key_date
```

**Why this matters:**
- Offer created Sept 15, expires Oct 15 → key_date = Sept 15 (belongs to Sept)
- Offer created Sept 15, expires Dec 15 → key_date = Nov 15 (belongs to Nov - non-standard)

**Loan Start Date:**
```sql
LAST_DAY(DATE_SUB(CAST(expires_at AS DATE), INTERVAL 1 MONTH)) AS loan_start_date
```

**Purpose:** Month when loan would start if accepted (used for matching)

---

### COALESCE Multi-Month Lookback

**Problem:** Carry-over offers created in Sept won't match Sept waterfall when viewed in Oct snapshot

**Example:**
```
Offer created: 2025-09-15
Waterfall evaluation: 2025-09-30
October snapshot: 2025-10-31

Simple join: Oct snapshot (10-31) ≠ Sept waterfall (09-30) → NO MATCH ❌
```

**Solution:** Try multiple months via COALESCE

```sql
COALESCE(
  current_month.campaign,   -- Try Oct waterfall first
  prev_1_month.campaign,    -- Then try Sept waterfall
  next_1_month.campaign,    -- Then try Nov waterfall
  prev_2_month.campaign     -- Finally try Aug waterfall
) AS campaign_segment
```

**Join Pattern:**
```sql
-- Join 0: Current month
LEFT JOIN waterfall e0
  ON offer.customer_id = e0.customer_id
  AND LAST_DAY(offer.business_date) = LAST_DAY(DATE(e0.business_date))

-- Join 1: Previous month (-1)
LEFT JOIN waterfall e1
  ON offer.customer_id = e1.customer_id
  AND LAST_DAY(DATE_SUB(offer.business_date, INTERVAL 1 MONTH)) = LAST_DAY(DATE(e1.business_date))

-- Join 2: Next month (+1)
LEFT JOIN waterfall e2
  ON offer.customer_id = e2.customer_id
  AND LAST_DAY(DATE_ADD(offer.business_date, INTERVAL 1 MONTH)) = LAST_DAY(DATE(e2.business_date))

-- Join 3: 2 months back (-2)
LEFT JOIN waterfall e3
  ON offer.customer_id = e3.customer_id
  AND LAST_DAY(DATE_SUB(offer.business_date, INTERVAL 2 MONTH)) = LAST_DAY(DATE(e3.business_date))
```

**Effectiveness (Oct 2025):**
```
Found in Current Month:       493,963 (85.51%)
Found in Previous Month (-1):  63,239 (10.95%) ← Filled by COALESCE!
Found in 2 Months Back (-2):      500 ( 0.09%) ← Filled by COALESCE!
Not Found:                     20,478 ( 3.54%) → Split by product_code
```

**Result:** **11% of data filled** through multi-month lookback ✅

---

### LAST_DAY Normalization

**Purpose:** Normalize all dates to month-end for consistent monthly joins

**Pattern:**
```sql
LAST_DAY(date_value) AS normalized_date
```

**Example:**
```
Input: 2025-10-05 → Output: 2025-10-31
Input: 2025-10-15 → Output: 2025-10-31
Input: 2025-10-31 → Output: 2025-10-31
```

**Why this matters:**
- Waterfall runs on 2025-09-30 (end of Sept)
- Offer created 2025-09-15 (mid Sept)
- JOIN on exact dates won't match
- JOIN on LAST_DAY will match ✅

---

## Business Rules & Logic

### Rule 1: One Offer Per Customer Per Month

**Implementation:**
```sql
QUALIFY DENSE_RANK() OVER (
  PARTITION BY customer_id, business_date
  ORDER BY created_at DESC, updated_at DESC
) = 1
```

**Effect:** If customer has multiple offers on same business_date, take the **latest**

---

### Rule 2: One Segment Per Customer

**Priority:**
1. BAU (rank 1)
2. CT (rank 2 - overrides BAU if customer qualifies for both)
3. Weekly (rank 3 - overrides CT/BAU)

**Implementation:**
```sql
QUALIFY ROW_NUMBER() OVER (
  PARTITION BY customer_id, business_date
  ORDER BY rnk ASC
) = 1
```

---

### Rule 3: Unknown Categorization by Product

**Logic:**
```sql
CASE
  WHEN campaign IS NOT NULL THEN campaign
  WHEN campaign IS NULL AND product_code = 'JAG09' THEN 'Open Market'
  WHEN campaign IS NULL AND product_code != 'JAG09' THEN 'Employee and Partner Payroll'
  ELSE 'Unknown'
END
```

**Rationale:**
- JAG09 = Flexi loan for non-targeted customers (Open Market)
- JAG01, JAG71 = Employee/partner programs (not in standard waterfall)

---

### Rule 4: Offer Expiry Filter

**Logic:**
```sql
WHERE LAST_DAY(CAST(expires_at AS DATE), MONTH) >= LAST_DAY(business_date, MONTH)
```

**Effect:** Only include offers that are still valid for the snapshot month

**Example:**
```
Offer expires: 2025-09-30
Business_date: 2025-10-31

LAST_DAY(2025-09-30) = 2025-09-30
LAST_DAY(2025-10-31) = 2025-10-31

2025-09-30 < 2025-10-31 → EXCLUDE ✅ (offer expired before Oct)
```

---

### Rule 5: Agreement Date Filter

**Logic:**
```sql
WHERE (LAST_DAY(DATE(agreement_agreed_at), MONTH) >= business_date
       OR DATE(agreement_agreed_at) IS NULL)
```

**Effect:**
- If customer accepted offer, only include in months **after** acceptance
- If not accepted (NULL), include in all valid months

---

### Rule 6: TUPR Month Cutoff

**Logic:**
```sql
WHERE key_date < DATE_TRUNC(CURRENT_DATE(), MONTH)
```

**Effect:** Exclude current month from TUPR calculation (incomplete data)

**Example (Today = 2025-11-07):**
```
Current month start: 2025-11-01
key_date = 2025-11-15 → EXCLUDE ✅ (current month not complete)
key_date = 2025-10-15 → INCLUDE ✅ (previous month complete)
```

---

## Performance Metrics

### Historical TUPR Trend (2025)

```
Month    | Customers | Disbursed | TUPR   | Notes
---------|-----------|-----------|--------|---------------------------
2025-01  | 84,880    | 725       | 0.85%  | Baseline
2025-02  | 97,191    | 929       | 0.96%  |
2025-03  | 46,495    | 2,749     | 5.91%  | ⚠️ ANOMALY - Investigate!
2025-04  | 314,312   | 5,746     | 1.83%  | High volume month
2025-05  | 275,652   | 5,125     | 1.86%  |
2025-06  | 270,416   | 2,729     | 1.01%  |
2025-07  | 271,719   | 3,003     | 1.11%  |
2025-08  | 275,964   | 3,099     | 1.12%  | Stable period
2025-09  | 584,779   | 5,827     | 1.00%  | Volume spike
2025-10  | 553,528   | 4,715     | 0.85%  | Lowest since Jan
```

**Average TUPR (excl. March):** ~1.0-1.5%

---

### Segment Performance (Oct 2025)

```
Segment                      | Customers | Disbursed | TUPR    | Performance
-----------------------------|-----------|-----------|---------|-------------
BAU                          | 401,258   | 4,087     | 1.02%   | Baseline ✓
CT (All)                     | 143,498   | 281       | 0.20%   | Underperforming ⚠️
  ├─ CT 6: Jago MOB          | 105       | 12        | 13.16%  | ⭐ Winner!
  ├─ CT 9: Highrisk EWS      | 4,949     | 27        | 1.87%   | Good ✓
  └─ CT 10: Never Trx        | 138,444   | 242       | 0.41%   | Poor ❌
Open Market                  | 8,768     | 347       | 3.96%   | ⭐ Strong!
Employee & Partner Payroll   | 4         | 0         | 0.00%   | Too small
Weekly                       | 0         | 0         | --      | No volume
```

**Key Findings:**
1. ⭐ **CT 6 (Jago MOB)** is the star performer (13.16% TUPR)
2. ⭐ **Open Market** (non-targeted JAG09) outperforms BAU by 3.9x
3. ❌ **CT 10 (Never Trx)** has huge volume but terrible conversion (0.41%)

---

### Product Performance (Oct 2025)

```
Product | Volume  | Disbursed | TUPR    | Insight
--------|---------|-----------|---------|------------------
JAG09   | 8,873   | 359       | 12.85%  | ⭐ Highest TUPR!
JAG08   | 81,360  | 985       | 3.76%   | Good conversion
JAG06   | 462,948 | 3,371     | 1.16%   | Mass market
JAG01   | 319     | N/A       | N/A     | Too small
JAG71   | 1       | 0         | 0%      | Too small
```

---

## Known Limitations & Edge Cases

### 1. March 2025 Anomaly

**Observation:** 5.91% TUPR (6x higher than average)

**Possible Causes:**
- Data quality issue (duplicate counts?)
- Special campaign (urgent need product?)
- Seasonal effect (end of quarter?)
- Product launch (new attractive terms?)

**Status:** ⚠️ **Requires investigation**

---

### 2. MH Risk Grade Paradox

**Observation:** MH (Medium-High) has higher TUPR than M (Medium)

```
M  (Medium):      3.64% TUPR
MH (Medium-High): 6.13% TUPR
```

**Expected:** Lower risk → Higher TUPR (inverse relationship)

**Possible Causes:**
- MH customers more credit-hungry (accept any offer)
- M customers more selective (wait for better terms)
- Risk scoring misalignment

**Status:** ⚠️ **Requires investigation**

---

### 3. NO_BUREAU Zero Disbursement Policy

**Observation:** 0% TUPR across all months

**Possible Causes:**
- **Hard policy block** (offers shown but disbursement prohibited)
- Manual approval required (not captured in automated flow)
- Compliance restriction

**Status:** ⚠️ **Confirm with policy team**

---

### 4. Timing Lag in Disbursement Matching

**Issue:** Customer accepts offer in Oct, but disburses in Nov → Not counted in Oct TUPR

**Current Logic:**
```sql
FORMAT_DATE('%Y-%m', facility_start_date) = FORMAT_DATE('%Y-%m', key_date)
```

**Implication:** TUPR for month M might increase retroactively when month M+1 data arrives

**Mitigation:** Only report TUPR for **complete months** (exclude current month)

---

### 5. Multiple Offers Per Customer

**Scenario:** Customer receives:
- Sept 10: JAG08 offer (5M limit)
- Sept 20: JAG06 offer (10M limit)

**Current Logic:** Takes **latest offer** (Sept 20 JAG06)

**Edge Case:** What if customer accepted Sept 10 offer before Sept 20 offer created?
- Possible data inconsistency
- Need to validate against agreement_agreed_at

---

### 6. Cross-Month Offer Lifespan

**Example:**
- Offer created: Sept 25
- Offer expires: Oct 25 (30-day lifespan)

**Question:** Which month does this belong to?
- Sept (created month)?
- Oct (expiry month)?
- Both (spans 2 months)?

**Current Logic:** Uses `key_date` calculation to assign to one month

---

### 7. Customer Table Row Loss

**Observation:**
- Query 2 input: 577,680 rows
- Query 2 output: 577,680 rows (same)
- Query 4 output: 553,528 unique customers (**4.2% loss**)

**Cause:** LEFT JOIN to customer table with date filter:
```sql
WHERE c.business_date >= '2025-01-01'
```

**Implication:** 24,152 customers (4.2%) don't have matching customer records in 2025
- Could be new customers added after snapshot
- Could be data quality issue

**Status:** ⚠️ **Acceptable loss, but monitor**

---

## Open Questions

### Business Process Questions

1. **Offer Approval Workflow**
   - Q: Who approves limits before offer generation?
   - Q: Is there manual review for high limits (>20M)?
   - Q: What triggers offer regeneration (limit increase)?

2. **Customer Communication**
   - Q: How many times is a customer notified about the same offer?
   - Q: What channels are used (app push, SMS, WhatsApp, email)?
   - Q: Is there A/B testing on notification copy/timing?

3. **Waterfall Step Details**
   - Q: What are the exact step names/numbers (01-98)?
   - Q: What percentage fail at each step?
   - Q: Are there common failure points to optimize?

4. **March 2025 Anomaly**
   - Q: What happened in March to cause 5.91% TUPR?
   - Q: Was there a special campaign or product launch?
   - Q: Is the data accurate or is this a measurement issue?

5. **NO_BUREAU Policy**
   - Q: Why are NO_BUREAU customers offered loans if they can never disburse?
   - Q: Is this a regulatory restriction or internal policy?
   - Q: Should we stop offering to NO_BUREAU customers?

---

### Data & Technical Questions

6. **Deduplication Logic**
   - Q: Can a customer truly have multiple offers on the same business_date?
   - Q: If yes, why (product variation, limit revision)?
   - Q: Should we count as separate offers or consolidate?

7. **Agreement Timestamp**
   - Q: When exactly is `agreement_agreed_at` recorded?
   - Q: Is this acceptance in app, or completion of documentation?
   - Q: Can customer accept multiple times (change of mind)?

8. **Disbursement Timing**
   - Q: What's the average time from acceptance to disbursement?
   - Q: What % of accepted offers eventually disburse?
   - Q: Why do some acceptances not result in disbursement?

9. **Product Codes**
   - Q: Are there other product codes (JAG02-05, JAG07, etc.)?
   - Q: What do JAG31 and JAG71 specifically represent?
   - Q: Is there a product master table with full definitions?

10. **Income Estimation**
    - Q: How is income estimated (CBAS model)?
    - Q: What inputs does CBAS use?
    - Q: How accurate is the estimation vs. actual income?

---

### Campaign & Segmentation Questions

11. **CT Test Design**
    - Q: Who designs the CT tests (Data Science, Product, Risk)?
    - Q: How long do tests run before graduation/termination?
    - Q: What's the success criteria for test graduation?

12. **Weekly Waterfall**
    - Q: When did Weekly waterfall start?
    - Q: What's the typical Weekly test duration?
    - Q: How many customers are typically in a Weekly cohort?

13. **Open Market Strategy**
    - Q: Is JAG09 intentionally for "non-qualified" customers?
    - Q: Why does Open Market have 4x higher TUPR than BAU?
    - Q: Should we expand Open Market offering?

14. **Segment Overlap**
    - Q: Can a customer move between segments (BAU → CT → BAU)?
    - Q: Is segment assignment permanent or monthly?
    - Q: What triggers segment re-assignment?

---

### Performance & Optimization Questions

15. **Carry-Over Optimization**
    - Q: Why do 85% of offers carry over?
    - Q: Should we shorten offer duration (increase urgency)?
    - Q: Should we re-notify carry-over customers?

16. **TUPR Improvement Levers**
    - Q: What initiatives are planned to improve 0.85% baseline TUPR?
    - Q: Is there industry benchmark for DL take-up rates?
    - Q: What's the target TUPR for 2025/2026?

17. **Product Mix Optimization**
    - Q: Should we shift from JAG06 to JAG09 (higher TUPR)?
    - Q: Why was JAG06 launched if JAG09 performs better?
    - Q: Is there product cannibalization analysis?

18. **Limit Optimization**
    - Q: Are limits too high (>20M tier has low TUPR)?
    - Q: Should we focus on 5-10M "sweet spot"?
    - Q: Do customers want smaller, frequent loans vs. large, rare loans?

---

### Data Quality & Governance Questions

19. **Data Lineage**
    - Q: Who owns each source table (dwh_core, dl_whitelist, data_mart)?
    - Q: What's the update frequency (daily, hourly, batch)?
    - Q: Are there data quality monitors in place?

20. **Historical Data Retention**
    - Q: How far back does waterfall history go?
    - Q: Are there data purge policies?
    - Q: Can we access 2024 data for YoY comparison?

21. **Waterfall Version Control**
    - Q: How are waterfall rule changes tracked?
    - Q: Is there A/B testing between waterfall versions?
    - Q: How do we measure waterfall performance improvements?

22. **Dashboard Accuracy**
    - Q: What's the SLA for TUPR dashboard data freshness?
    - Q: How often should queries be re-run (daily, weekly, monthly)?
    - Q: Who validates dashboard accuracy?

---

## Glossary

### Terms

| Term | Definition |
|------|------------|
| **BAU** | Business As Usual - control group underwriting |
| **CBAS** | Credit Bureau Augmented Score - income estimation model |
| **COALESCE** | SQL function returning first non-NULL value from list |
| **CRVADL** | credit_risk_vintage_account_direct_lending (disbursement table) |
| **CT** | Credit Test - experimental campaign segment |
| **Deal Type** | Product code in disbursement table (JAG06, JAG08, JAG09) |
| **EWS** | Early Warning Score - delinquency risk model |
| **Facility** | Credit line granted to customer (limit) |
| **HCI** | (Unknown acronym - risk scoring system?) |
| **JAG06** | Installment loan product code |
| **JAG08** | Overdraft facility product code |
| **JAG09** | Flexi loan product code (Open Market) |
| **Key Date** | Month when offer is "active" for TUPR measurement |
| **LAST_DAY** | SQL function normalizing dates to month-end |
| **MOB** | Months on Book - loan tenure |
| **Plafond** | Drawn amount (from Indonesian banking term) |
| **Plafond Facility** | Total facility limit |
| **Risk Bracket** | Risk grade (L, LM, M, MH, H, NO_BUREAU) |
| **TUPR** | Take-Up Rate - % of offers converting to disbursements |
| **Waterfall** | Sequential underwriting checks |

### Metrics

| Metric | Formula | Example |
|--------|---------|---------|
| **TUPR by Customer** | (Disbursed / Offered) × 100% | 4,715 / 553,528 × 100% = 0.85% |
| **TUPR by Limit** | (Limit Disbursed / Limit Offered) × 100% | 94.1B / 21.1T × 100% = 0.45% |
| **Utilization** | (Plafond / Plafond Facility) × 100% | 5M / 10M × 100% = 50% |
| **Carry-Over %** | (Carry-Over / Total) × 100% | 472K / 553K × 100% = 85.3% |

### Status Codes

| Code | Meaning | Action |
|------|---------|--------|
| **ENABLED** | Active, customer can accept | Normal state |
| **DISABLED** | Manually disabled | Investigate reason |
| **EXPIRED** | Past expiry date | Archive/exclude |

### Waterfall Steps

| Step | Meaning | Action |
|------|---------|--------|
| **01-98** | Failed at specific check | Customer rejected |
| **99** | "Passed Underwriting Waterfall" | Create offer if flag_offer_upload = 'Yes' |
| **NULL** | Not evaluated | Customer outside scope |

---

## Related Documentation

| Document | Purpose | Location |
|----------|---------|----------|
| **TUPR Dashboard Complete Wiki** | Dashboard technical specs | TUPR_Dashboard_Complete_Technical_Wiki_20251106.md |
| **TUPR Campaign Segmentation Wiki** | Query 2.5 detailed logic | TUPR_Campaign_Segmentation_Technical_Wiki_20251106.md |
| **Nov 6-7 Updates Wiki** | Recent fixes & validations | TUPR_Dashboard_Nov6_7_Updates_Technical_Wiki.md |
| **RFC: Propensity Loan Take Up** | Original project proposal | [RFC] Propensity Loan Take Up 2025.md |

---

## Document Metadata

**Created:** 2025-11-07
**Last Updated:** 2025-11-07
**Author:** Ammar Siregar (Risk Data Analyst Intern)
**Reviewers:** Pending
**Version:** 1.0
**Status:** ✅ Draft - Awaiting Review

**Changelog:**
- 2025-11-07: Initial version compiled from TUPR dashboard development insights

**Next Review Date:** 2025-12-01 (or when new business processes are documented)

---

**End of Wiki Entry**
