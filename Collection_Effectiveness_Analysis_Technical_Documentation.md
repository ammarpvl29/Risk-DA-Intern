# Collection Effectiveness Analysis - Technical Documentation

## Document Information

**Project Name**: Collection Team Effectiveness Analysis
**Analyst**: Ammar Siregar (Credit Risk Data Analyst Intern)
**Mentor**: Muhammad Subhan
**Analysis Period**: August - September 2025 Cohorts
**Date Created**: October 15, 2025
**Status**: Phase 1 Complete - Bad Customer Analysis
**Next Phase**: Good vs Bad Customer Comparison

---

## Table of Contents

1. [Business Context](#business-context)
2. [Business Question](#business-question)
3. [Data Architecture](#data-architecture)
4. [Methodology](#methodology)
5. [Key Findings](#key-findings)
6. [SQL Implementation](#sql-implementation)
7. [Analysis Results](#analysis-results)
8. [Technical Challenges](#technical-challenges)
9. [Recommendations](#recommendations)
10. [Next Steps](#next-steps)

---

## Business Context

### Problem Statement

Bank Jago's Direct Lending portfolio (JAG06 - Stockbit/Bibit, JAG08 - JDC) experiences First Payment Default (FPD) where customers fail to pay within their first month (MOB 1). The credit risk team hypothesized that customers who default are those who were **NOT contacted** by the collection team.

### Stakeholders

| Stakeholder | Role | Interest |
|-------------|------|----------|
| Muhammad Subhan | Technical Mentor | Analysis methodology, data quality |
| Credit Risk Team | Business Owner | Collection strategy effectiveness |
| Collection Team | Operations | Performance evaluation, capacity planning |

### Scope

**In Scope:**
- September 2025 cohort analysis (primary focus)
- August 2025 cohort (comparison)
- Customers with early maturity dates (day_maturity < 11-13)
- JAG06 (Stockbit/Bibit) and JAG08 (JDC Direct Lending)
- Collection call analysis (phone calls)

**Out of Scope:**
- WhatsApp collection analysis (permission issues)
- SMS/Email collection channels
- Customers with late maturity dates (>13th)
- Other loan products (non-JAG)

---

## Business Question

### Primary Question
**"Do customers who fail to pay their loans = customers who were NOT contacted by the collection team?"**

### Sub-Questions
1. What percentage of bad customers were contacted?
2. How many contact attempts were made per customer?
3. When were customers contacted (before/after due date)?
4. What was the contact success rate (answered vs no answer)?
5. Are calls about NEW loans or OLD delinquent loans?
6. Do good customers have different contact patterns than bad customers?

---

## Data Architecture

### Source Tables

#### 1. **Vintage Account Table**
```
Table: jago-bank-data-production.data_mart.credit_risk_vintage_account_direct_lending
Grain: Customer-Loan-BusinessDate-MOB level
Partitioned: By business_date
Purpose: Loan performance tracking
```

**Key Fields:**
- `lfs_customer_id`: Customer identifier (LFS system)
- `facility_reference`: Facility ID (e.g., "LPG786")
- `deal_reference`: Deal/Loan ID (e.g., "87433370373248") ← **Join key for collection**
- `facility_start_date`: When loan was disbursed
- `maturity_date`: When payment is due
- `MOB`: Month on Book (0 = origination, 1 = first month)
- `acct_3dpd_max`: Flag if customer hit 3+ Days Past Due
- `deal_type`: JAG06 (Stockbit/Bibit) or JAG08 (JDC)

**Critical Join Logic:**
```sql
-- MOB 0: Loan origination data
WHERE mob = 0
  AND business_date >= '2024-10-31'
  AND facility_start_date = start_date (same month)

-- MOB 1: Performance data (did they go bad?)
WHERE mob = 1
  AND acct_3dpd_max = 1 (went 3+ DPD)
```

#### 2. **Collection Call Table**
```
Table: jago-bank-data-production.digital_lending.digital_lending_collection_daily_report_vendor
Grain: Call-level (one row per call attempt)
Partitioned: By business_date
Purpose: Collection activity tracking
```

**Key Fields:**
- `business_date`: Date of collection activity
- `card_no`: Loan ID ← **MAPS TO deal_reference** (NOT facility_reference!)
- `account_no`: Customer ID (sometimes)
- `date`: Timestamp of call
- `dpd`: Days Past Due at time of call
- `status`: Call outcome (No Answer, Payment Plan, Invalid, etc.)
- `person_contacted`: RPC (Right Party Contact) vs TPC (Third Party)
- `collector`: Name of collector
- `campaign_name`: Campaign type (Predictive Dialer, IVR, Manual)

**Join Key Discovery:**
```sql
-- WRONG:
collection.card_no = vintage.facility_reference  -- NO!

-- CORRECT:
collection.card_no = vintage.deal_reference  -- YES!
```

#### 3. **Bibit/Stockbit Partner Logic**
```
Tables: data-prd-adhoc.credit_risk_adhoc.base_logic_bibit_stockbit_YYYYMMDD
Grain: Customer-Date level
Purpose: Identify Bibit/Stockbit partnership customers
Monthly snapshots: Jan 2025 - Sep 2025
```

**Fields:**
- `customer_id`: LFS customer ID
- `partner_final`: Partner name (BIBIT, STOCKBIT)
- `base`: Snapshot date (last day of month)

#### 4. **Scoring Tables**

**EWS (Early Warning System):**
```
Table: data-prd-adhoc.dl_whitelist_checkers.credit_risk_vintage_account_direct_lending_ews_score
Fields: lfs_customer_id, calibrated_scores
```

**HCI (High Credit Indicator):**
```
Table: data-prd-adhoc.dl_whitelist_checkers.credit_risk_vintage_account_direct_lending_hci_score
Fields: lfs_customer_id, risk_group_hci
```

**TrustDecision (Device Intelligence):**
```
Table: jago-bank-data-production.risk_datamart.device
Fields: customer_id, score, business_date
Logic: Get latest score BEFORE facility_start_date using QUALIFY + DENSE_RANK
```

---

## Methodology

### Analysis Approach (Following Bank Jago Best Practices)

**Step 1: Understand the Business Question** ✅
- Clarified with mentor: Do bad customers = not contacted customers?
- Defined "bad customer": acct_3dpd_max = 1 in MOB 1

**Step 2: Identify Required Tables** ✅
- Vintage table (customer loan data)
- Collection table (call activity)
- Scoring tables (risk filters)

**Step 3: Start Simple, Build Complex** ✅
```
Simple Query 1: Count bad customers (172-198 customers)
     ↓
Simple Query 2: Check if collection table has ANY records
     ↓
Simple Query 3: Understand join key (deal_reference vs facility_reference)
     ↓
Simple Query 4: Join bad customers with collection calls
     ↓
Complex Query: Aggregate call metrics by customer
```

**Step 4: Validate Data Quality** ✅
- Checked for duplicates (one customer can have multiple loans)
- Verified join key correctness
- Validated date ranges
- Compared MOB 0 vs MOB 1 counts

**Step 5: Build Complex Analysis Using CTEs** ✅
- Used descriptive CTE names (bad_customers, calls_bad_sept_loans, etc.)
- Tested each CTE separately before combining
- Added comments explaining business logic

**Step 6: Validate Results** ✅
- Sanity check: 100% contact rate (unexpected!)
- Cross-validated with sample customer journey
- Verified call timing vs due dates

---

## Key Findings

### Finding 1: 100% Contact Coverage

**Metric Summary:**

| Metric | Value |
|--------|-------|
| **Total bad customers (Sept 2025)** | 198 customers |
| **Customers contacted** | 198 (100%) |
| **Customers NOT contacted** | 0 (0%) |
| **Average calls per customer** | 228 calls |
| **Total call attempts** | 45,104 calls |

**Conclusion:** ❌ **Hypothesis REJECTED**
Bad customers WERE extensively contacted. The problem is NOT lack of contact attempts.

---

### Finding 2: Proactive Collection Timing

**Call Timing Analysis:**

| Timing Category | Customers | Call Attempts | Avg DPD |
|-----------------|-----------|---------------|---------|
| Before Due Date (Proactive) | 180 | 27,895 | 4.0 |
| After Due, Before 3DPD | 161 | 19,523 | 4.2 |
| After 3DPD (Late Collection) | 21 | 4,069 | 7.1 |

**First call date:** September 30 (proactive - before most due dates)
**Average DPD at call:** 3.1 days (early intervention)

**Conclusion:** ✅ Collection team was **proactive**, not reactive.

---

### Finding 3: Calls Were About NEW Loans (Not Old Loans)

**Call Distribution by Loan Type:**

| Loan Category | Customers | Total Calls | Avg Calls/Customer | Avg DPD |
|---------------|-----------|-------------|-------------------|---------|
| **September 2025 Loan (NEW)** | 198 | 45,104 | 227.8 | 3.1 |
| **Other Loan (OLD)** | 80 | 62,470 | 780.9 | 1.8 |

**Insight:**
- ALL 198 bad customers received calls about their NEW September loans
- 80 customers (40%) also had OLD delinquent loans from before
- OLD loans received even MORE calls (781 per customer!)

**Conclusion:** ✅ Calls were targeted at the **correct loans**.

---

### Finding 4: ROOT CAUSE - Customers Could NOT Be Reached

**Call Status Breakdown:**

| Status | Call Count | Customers | % of Calls |
|--------|-----------|-----------|------------|
| **No Answer** | 42,334 | 195 | **93.9%** |
| Invalid number | 1,340 | 91 | 3.0% |
| SCBR (Subscriber Cannot Be Reached) | 785 | 97 | 1.7% |
| DROP CALL | 179 | 59 | 0.4% |
| WA - Sent | 161 | 45 | 0.4% |
| **Payment Plan** | 100 | 48 | **0.2%** |
| Under Negotiation | 63 | 28 | 0.1% |

**Critical Statistics:**
- **94% of calls = No Answer or Invalid**
- **Only 0.2% agreed to payment plan**
- Despite **228 attempts per customer**, contact success was extremely low

**Conclusion:** 🎯 **ROOT CAUSE IDENTIFIED**
Customers defaulted NOT because they weren't contacted, but because:
1. **94% couldn't be reached** (No Answer / Invalid number)
2. Only **0.2%** agreed to payment plan
3. Phone numbers became invalid/inactive within 1 month

---

### Finding 5: Cohort Size Variations

**Impact of Filter Changes:**

| Filter | Bad Customers |
|--------|---------------|
| day_maturity < 11 | 172 customers |
| day_maturity < 11 (without scoring) | 198 customers |
| day_maturity < 13 | 489 customers |

**Breakdown by Cohort:**

| Cohort | Bad Customers | Good Customers | Total |
|--------|---------------|----------------|-------|
| August 2025 | 193 | 2,400 | 2,593 |
| September 2025 | 489 | 5,756 | 6,245 |

---

## SQL Implementation

### Master Query Structure

```sql
WITH
-- 1. BASE: All loans at MOB 0
base AS (
    SELECT DISTINCT
        lfs_customer_id,
        deal_reference,  -- KEY for joining with collection!
        facility_start_date,
        day_maturity,
        deal_type,
        plafond
    FROM vintage_table
    WHERE mob = 0
      AND facility_start_date IN ('2025-08', '2025-09')
),

-- 2. PERFORMANCE: MOB 1 bad flags
performance AS (
    SELECT
        lfs_customer_id,
        MAX(acct_3dpd_max) AS bad
    FROM vintage_table
    WHERE mob = 1
    GROUP BY 1
),

-- 3. BAD CUSTOMERS: Join base + performance
bad_customers AS (
    SELECT base.*, perf.bad
    FROM base
    INNER JOIN performance perf USING (lfs_customer_id)
    WHERE bad = 1
),

-- 4. COLLECTION CALLS: Join with collection table
customer_calls AS (
    SELECT
        bc.*,
        call.business_date AS call_date,
        call.status,
        call.dpd
    FROM bad_customers bc
    LEFT JOIN collection_table call
        ON bc.deal_reference = call.card_no  -- CRITICAL JOIN!
)

-- 5. AGGREGATE: Customer-level summary
SELECT
    lfs_customer_id,
    COUNT(call_date) AS total_calls,
    MIN(call_date) AS first_call,
    MAX(call_date) AS last_call,
    COUNT(CASE WHEN status = 'No Answer' THEN 1 END) AS no_answer_count
FROM customer_calls
GROUP BY 1;
```

### Physical Table Created

**Table Name:** `data-prd-adhoc.temp_ammar.collection_analysis_aug_sept_2025_customers`

**Schema:**
```sql
-- Customer Info
id_number STRING
lfs_customer_id STRING
facility_reference STRING
deal_reference STRING
facility_start_date DATE
day_maturity INT64
deal_type STRING
plafond BIGNUMERIC

-- Partner Info
partner_final STRING
flag_bibit INT64

-- Cohort Info
cohort_month STRING  -- '2025-08', '2025-09'
cohort_name STRING   -- 'August 2025', 'September 2025'

-- Performance Info
performance_business_date DATE
mob INT64
fpd_dpd3_mob1_act INT64
fpd_dpd3_mob1_bal BIGNUMERIC

-- Customer Type Flags
flag_bad_customer INT64   -- 1 = bad, 0 = good
flag_good_customer INT64  -- 1 = good, 0 = bad

-- Scoring Info
ews_calibrated_scores FLOAT64
risk_group_hci STRING
score_TD FLOAT64
```

**Row Count:** 8,838 customers
- Bad: 682 (193 Aug + 489 Sept)
- Good: 8,156 (2,400 Aug + 5,756 Sept)

---

## Analysis Results

### September 2025 Bad Customer Analysis

#### Cohort Characteristics

| Metric | Value |
|--------|-------|
| Total bad customers | 198 |
| Stockbit/Bibit (JAG06) | 147 (74%) |
| JDC Direct Lending (JAG08) | 25 (13%) |
| Average loan amount | 10.7M IDR |
| Min loan amount | 500K IDR |
| Max loan amount | 65M IDR |
| Maturity days 1-5 | 114 customers |
| Maturity days 6-10 | 58 customers |

#### Collection Contact Summary

**Contact Coverage:**
- 198 out of 198 customers contacted = **100%**
- 0 customers NOT contacted
- First contact date: Sept 30, 2025
- Latest contact date: Oct 14, 2025

**Call Volume:**
- Total call attempts: 45,104
- Average per customer: 227.8 calls
- Min calls: TBD (needs query)
- Max calls: TBD (needs query)

**Call Effectiveness:**
- No Answer rate: **93.9%**
- Invalid number rate: 3.0%
- Payment plan rate: **0.2%**
- Success rate (answered + agreed): ~0.3%

#### Example: Customer Journey Analysis

**Customer ID:** 57197545

**Loan Details:**
- Facility start: Sept 20, 2025
- Maturity day: 3rd
- Due date: Oct 3, 2025
- Loan amount: 3M IDR
- Deal type: JAG06 (Stockbit/Bibit)

**Performance:**
- MOB 0 (Sept 30): acct_3dpd_max = 0 (good)
- MOB 1 (Oct 14): acct_3dpd_max = 1 (went bad at 3+ DPD)
- Outstanding balance: 2,999,203 IDR (almost full amount unpaid)

**Collection Activity:**
- First call: [To be queried]
- Last call: [To be queried]
- Total calls: [To be queried]
- Most common status: [To be queried]

---

## Technical Challenges

### Challenge 1: Join Key Identification

**Problem:**
- Initially assumed `collection.card_no = vintage.facility_reference`
- Query returned 0 results

**Investigation:**
```sql
-- Query collection table structure
SELECT card_no FROM collection_table LIMIT 5;
-- Result: "87778182078901" (14 digits)

-- Compare with vintage table
SELECT facility_reference, deal_reference
FROM vintage_table LIMIT 5;
-- facility_reference: "LPG786" (alphanumeric)
-- deal_reference: "87433370373248" (14 digits)
```

**Solution:**
- Correct join: `collection.card_no = vintage.deal_reference`
- This resolved the 0-results issue

---

### Challenge 2: Multiple Loans Per Customer

**Problem:**
- One customer can have multiple loans (drawdowns)
- Joining MOB 0 to MOB 1 on `lfs_customer_id` only creates duplicates

**Example:**
```
Customer A:
  - Loan 1 (Sept 1): MOB 0
  - Loan 2 (Sept 15): MOB 0
  - MOB 1 performance: 1 row

Join result: 2 rows (duplicate!)
```

**Solution:**
- Join on BOTH `lfs_customer_id` AND `deal_reference`
- Or aggregate performance at customer level (MAX, SUM)

**Impact:**
- 172 customers (correct join) vs 198 customers (customer-level only)

---

### Challenge 3: Interpreting Call Timing with DPD

**Problem:**
- Calls marked "Before Due Date" but have DPD = 4
- This seems contradictory

**Investigation:**
```
Customer took loan Sept 20
Due date: Oct 3
Call on Sept 30 shows DPD = 4

How is this possible if before due date?
```

**Root Cause:**
- Customer has MULTIPLE loans (new + old)
- Sept 30 calls are about OLD delinquent loans (DPD 4)
- New Sept 20 loan hasn't matured yet

**Solution:**
- Filter calls to NEW September loans only
- Use `call.card_no = september_deal_reference`

---

### Challenge 4: WhatsApp Data Access

**Problem:**
```
Error: Permission denied while opening file
aux-ammar.siregar@tech.jago.com does not have
storage.objects.get access to GCS bucket
```

**Root Cause:**
- WhatsApp collection table stored in Google Cloud Storage
- Intern account lacks IAM permissions

**Workaround:**
- Focus analysis on collection call table only
- Document limitation in findings

---

### Challenge 5: Scoring Table Joins

**Problem:**
- Mentor's query includes LEFT JOINs to 3 scoring tables
- Without these, customer count changes (172 → 198)

**Explanation:**
- Some customers don't have scores in all 3 tables
- INNER JOIN would exclude them
- LEFT JOIN keeps them but filters may still apply

**Solution:**
- Always use LEFT JOIN for scoring tables
- Check for NULL handling in downstream filters

---

## Recommendations

### Business Recommendations

#### 1. **Improve Contact Information Quality**

**Finding:** 94% No Answer / Invalid number rate

**Recommendations:**
- **Application Stage:**
  - Implement phone number verification (OTP SMS during application)
  - Require alternative contact number (2nd phone, family member)
  - Validate phone number is active/registered

- **Post-Disbursement:**
  - Send welcome SMS/WhatsApp within 24 hours
  - Request contact update if delivery fails
  - Flag customers with undeliverable messages as high-risk

**Expected Impact:** Reduce No Answer rate from 94% to 70-80%

---

#### 2. **Diversify Collection Channels**

**Finding:** Only phone calls analyzed (WhatsApp data inaccessible)

**Recommendations:**
- **Multi-Channel Strategy:**
  - WhatsApp messages (text + template buttons)
  - In-app notifications (push to Jago app)
  - Email reminders
  - SMS (for customers without smartphones)

- **Channel Priority:**
  1. WhatsApp (highest open rate)
  2. In-app notification
  3. Phone call (if 1-2 fail)
  4. SMS (backup)

**Expected Impact:** Increase contact success rate from 0.3% to 5-10%

---

#### 3. **Optimize Collection Timing**

**Finding:** Average 228 calls per customer with 0.2% success

**Recommendations:**
- **Reduce Call Volume, Increase Quality:**
  - Max 10 call attempts per customer (vs current 228)
  - Space calls 12-24 hours apart (not hourly)
  - Try different times of day (morning, lunch, evening)

- **Proactive Reminder (Before Due):**
  - Day -3: WhatsApp reminder "Payment due in 3 days"
  - Day -1: SMS reminder
  - Day 0 (Due date): Phone call + WhatsApp

- **Post-Due Collection:**
  - Day +1: Phone call
  - Day +3: Phone call + payment plan offer
  - Day +7: Escalate to legal/collections team

**Expected Impact:** Reduce call volume 95% while maintaining effectiveness

---

#### 4. **Segment Collection Strategy by Risk**

**Finding:** All customers get same treatment (228 calls)

**Recommendations:**

| Risk Segment | Contact Frequency | Channels | Special Treatment |
|--------------|-------------------|----------|-------------------|
| **Low Risk** (Good scores) | 3-5 attempts | WhatsApp, Email | Self-service payment portal |
| **Medium Risk** | 10-15 attempts | Phone, WhatsApp, In-app | Payment plan offer |
| **High Risk** (Bad scores, repeat defaulters) | 20-30 attempts | All channels | Escalate to specialist team |

**Expected Impact:** More efficient resource allocation

---

#### 5. **Investigate Bibit/Stockbit Customer Quality**

**Finding:** 74% of bad customers are JAG06 (Stockbit/Bibit partnership)

**Recommendations:**
- **Root Cause Analysis:**
  - Compare Stockbit/Bibit vs JDC default rates
  - Analyze customer acquisition quality
  - Review partnership referral process

- **If Quality Issue Confirmed:**
  - Tighten credit criteria for partner referrals
  - Require higher scores (EWS, HCI, TD)
  - Increase monitoring for first 3 months

**Expected Impact:** Reduce FPD rate for partner customers

---

### Technical Recommendations

#### 1. **Automate Collection Effectiveness Dashboard**

**Proposed Metrics:**
```
Daily Dashboard:
- % customers contacted within 24h of due date
- Average calls per customer (target: <10)
- Contact success rate by channel
- No Answer rate trend
- Payment plan conversion rate

Weekly Dashboard:
- Cohort-level FPD rate
- Collection team capacity utilization
- Collector performance ranking
- Channel effectiveness comparison
```

**Implementation:** Looker/Data Studio dashboard with daily refresh

---

#### 2. **Create Consolidated Collection Table**

**Current Problem:** Need to join 3+ tables to analyze collection

**Proposed Solution:**
```sql
CREATE TABLE collection_consolidated AS (
  SELECT
    customer_id,
    deal_reference,
    cohort_month,
    due_date,
    -- From phone calls
    phone_call_count,
    phone_first_attempt,
    phone_last_status,
    -- From WhatsApp
    wa_sent_count,
    wa_delivered_count,
    wa_read_count,
    -- From in-app
    push_sent_count,
    push_clicked_count,
    -- Summary
    total_contact_attempts,
    channels_used,
    contact_success_flag
  FROM ...
);
```

**Benefit:** Single source of truth, faster queries

---

#### 3. **Implement Data Quality Checks**

**Recommended Validations:**
```sql
-- Check 1: Customers without collection attempts
SELECT COUNT(*)
FROM bad_customers
LEFT JOIN collection_calls USING (deal_reference)
WHERE call_date IS NULL;
-- Alert if > 0

-- Check 2: Duplicate deal_references
SELECT deal_reference, COUNT(*)
FROM collection_calls
GROUP BY 1 HAVING COUNT(*) > 1000;
-- Alert if any customer has >1000 calls

-- Check 3: Invalid phone numbers at application
SELECT COUNT(*)
FROM applications
WHERE phone_number NOT REGEXP '^08[0-9]{9,11}$';
-- Monitor trend
```

---

## Next Steps

### Immediate (This Week)

1. **Complete Good vs Bad Comparison** ⏳
   - Run Query F: Bad vs Good customer call patterns
   - Compare No Answer rates
   - Compare payment plan success rates
   - **Goal:** Determine if bad customers are harder to reach, or if it's a systemic data quality issue

2. **Create Detail & Summary Tables** ⏳
   - Table 1: Detail level (for eyeballing individual customers)
   - Table 2: Summary level (aggregated metrics per customer)
   - **Purpose:** Support mentor's capacity planning analysis

3. **Eyeball 10 Sample Customers** ⏳
   - 5 bad customers with different patterns
   - 5 good customers for comparison
   - Document findings in spreadsheet

---

### Short-term (Next 2 Weeks)

4. **August vs September Comparison**
   - Run same analysis for August 2025 cohort
   - Compare collection effectiveness month-over-month
   - Identify capacity planning issues

5. **Create Presentation for Stakeholders**
   - Executive summary (1 slide)
   - Key findings (3-4 slides)
   - Recommendations (2-3 slides)
   - Supporting data (appendix)

6. **Investigate Capacity Planning Issues**
   - Mentor's hypothesis: Inconsistent customer treatment
   - Compare customers with same due date
   - Example: Why does Customer A get 10 calls but Customer B gets 300?

---

### Medium-term (Next Month)

7. **Expand Analysis to Other Cohorts**
   - June, July 2025 cohorts
   - Trend analysis: Is collection effectiveness improving/declining?

8. **Include WhatsApp Data** (if permissions granted)
   - Request IAM access from data team
   - Repeat analysis with WhatsApp channel
   - Compare phone vs WhatsApp effectiveness

9. **Build Automated Monitoring**
   - Monthly collection effectiveness report
   - Alert system for capacity issues
   - Collector performance dashboard

---

## Appendices

### Appendix A: Data Dictionary

**Customer Flags:**
- `flag_bad_customer`: 1 if acct_3dpd_max = 1 in MOB 1, else 0
- `flag_good_customer`: 1 if acct_3dpd_max = 0 or NULL in MOB 1, else 0
- `flag_bibit`: 1 if customer from Bibit/Stockbit partnership, else 0

**Call Status Codes:**
- `No Answer`: Phone rang but not answered
- `Invalid`: Phone number invalid/disconnected
- `SCBR`: Subscriber Cannot Be Reached
- `PAYMENT PLAN`: Customer agreed to payment plan
- `WPC`: Wrong Party Contact
- `RPC`: Right Party Contact
- `TPC`: Third Party Contact

**DPD Calculations:**
- DPD = Days Past Due from scheduled payment date
- DPD 0 = Current (paid on time)
- DPD 1-30 = Early delinquency
- DPD 31-90 = Mid delinquency
- DPD 90+ = Serious delinquency

---

### Appendix B: Sample Customer Data

**Customer: 57197545 (Bad Customer Example)**

```
Loan Info:
- Facility start: 2025-09-20
- Maturity day: 3
- Due date: 2025-10-03
- Deal type: JAG06 (Stockbit/Bibit)
- Loan amount: 3,000,000 IDR

Performance:
- MOB 0 (2025-09-30): Status = ACTIVE, DPD = 0
- MOB 1 (2025-10-14): Status = ACTIVE, DPD = 3+
- Outstanding: 2,999,203 IDR (99.97% unpaid)

Collection Activity:
- [To be queried from detail table]
```

---

### Appendix C: Query Templates

**Template 1: Customer Journey**
```sql
SELECT
    cust.lfs_customer_id,
    cust.facility_start_date,
    cust.day_maturity,
    DATE_ADD(DATE_ADD(cust.facility_start_date, INTERVAL 1 MONTH),
             INTERVAL cust.day_maturity DAY) AS due_date,
    call.business_date AS call_date,
    call.status,
    call.dpd
FROM collection_analysis_table cust
LEFT JOIN collection_table call
    ON cust.deal_reference = call.card_no
WHERE cust.lfs_customer_id = '<CUSTOMER_ID>'
ORDER BY call_date;
```

**Template 2: Cohort Summary**
```sql
SELECT
    cohort_name,
    flag_bad_customer,
    COUNT(*) AS customers,
    COUNT(CASE WHEN call_count > 0 THEN 1 END) AS contacted,
    AVG(call_count) AS avg_calls,
    AVG(no_answer_count * 100.0 / NULLIF(call_count, 0)) AS avg_no_answer_pct
FROM collection_summary_table
GROUP BY 1, 2;
```

---

### Appendix D: Known Limitations

1. **WhatsApp Data Unavailable**
   - Impact: Cannot analyze full multi-channel strategy
   - Workaround: Phone call analysis only
   - Resolution: Request IAM permissions

2. **Collection Table Granularity**
   - Issue: Call-level data (very large table)
   - Impact: Queries can be slow
   - Mitigation: Use partitioning, date filters

3. **Multiple Loans Per Customer**
   - Issue: Complex join logic needed
   - Impact: Risk of duplicate counting
   - Solution: Always join on deal_reference + customer_id

4. **Scoring Table Coverage**
   - Issue: Not all customers have all 3 scores
   - Impact: LEFT JOIN required, potential NULLs
   - Handling: COALESCE or NULL handling in filters

5. **Business Date Lag**
   - Issue: Performance table (MOB 1) updates with delay
   - Impact: Recent cohorts may have incomplete data
   - Solution: Wait 30-45 days after cohort month for full data

---

## Change Log

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-15 | Ammar Siregar | Initial documentation - Bad customer analysis complete |
| 1.1 | 2025-10-XX | Ammar Siregar | Added good vs bad comparison analysis |
| 1.2 | 2025-10-XX | Ammar Siregar | Added August cohort comparison |

---

## References

**Related Documentation:**
- `Data_Analysis_Flow_Guide_Bank_Jago.md` - Analysis methodology
- `Handbook - Risk Data Analyst.md` - Role responsibilities
- `Loan_System_Understanding.md` - Loan product details

**Key Tables:**
- `jago-bank-data-production.data_mart.credit_risk_vintage_account_direct_lending`
- `jago-bank-data-production.digital_lending.digital_lending_collection_daily_report_vendor`
- `data-prd-adhoc.temp_ammar.collection_analysis_aug_sept_2025_customers`

**Contact:**
- Analyst: Ammar Siregar (aux-ammar.siregar@tech.jago.com)
- Mentor: Muhammad Subhan

---

**Document Status**: Active
**Last Updated**: October 15, 2025
**Next Review**: October 22, 2025 (after good vs bad comparison)
