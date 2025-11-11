# TUPR Diagnostic Findings - Root Cause Analysis

**Date:** 2025-11-04
**Issue:** TUPR showing 88% after switching to agreement_agreed_at (expected ~3%)
**Status:** ✅ ROOT CAUSE IDENTIFIED

---

## 🔴 CRITICAL FINDING: agreement_agreed_at is 96% NULL

### Query 1 Results - NULL Value Analysis
```
Total records:             4,664,022
Non-null agreement_agreed_at:  189,235 (4.06%)
NULL agreement_agreed_at:    4,474,787 (95.94%)
```

**THIS IS THE ROOT CAUSE:** The `agreement_agreed_at` field is only populated for 4% of loan offers. When we filter by this field, we lose 96% of the offer population.

---

## 📊 Impact Analysis

### Query 3 Results - Population Loss
```
All Records:                              807,758 customers
Same Month (agreement = business_date):    38,553 customers (4.8%)
October 2025 - by business_date:          772,333 customers
October 2025 - by agreement_agreed_at:      5,779 customers (0.7%)
```

**Population Loss:** 772,333 → 5,779 = **99.25% of customers excluded**

### Query 5 Results - October Breakdown
```
Total October customers (business_date):  772,333
Customers with agreement_agreed_at:        28,515 (3.7%)
Customers with Oct agreement_agreed_at:     5,763 (0.7%)
```

**96% of October offers have NULL agreement_agreed_at!**

---

## 🎯 Why TUPR Shows 88%

### Query 6 Results - Disbursement Matching
```
Total October Offers (by business_date):                772,333 customers
Matched with Disbursement (any month):                   25,312 customers → 3.28% TUPR ✅ REAL
Matched with Disbursement (same month, business_date):    5,248 customers → 0.68% TUPR
Matched with Disbursement (same month, agreement_at):     5,189 customers → 88.18% TUPR ❌ WRONG
```

**The 88% TUPR is calculated as:**
- Numerator: 5,189 customers (disbursed with non-null Oct agreement_agreed_at)
- Denominator: 5,779 customers (total with non-null Oct agreement_agreed_at)
- Result: 5,189 / 5,779 = 89.8% ≈ 88%

**This is WRONG because:**
- We're only looking at 0.7% of the total offer population
- The 96% of offers with NULL agreement_agreed_at are completely excluded
- This subset is highly biased (only customers who actively agreed to offers)

---

## 📝 Data Quality Issue: agreement_agreed_at Field

### Query 2 Sample - Month Misalignment
For business_date = 2025-10-31, agreement_agreed_at dates are scattered:
```
business_date    agreement_agreed_at    customer_count
2025-10          2023-12                43 customers
2025-10          2024-01                61 customers
...
2025-10          2025-09                5,348 customers
2025-10          2025-10                5,763 customers
```

**Observation:** Most October business_date records have agreement_agreed_at from earlier months, indicating:
1. Offers persist across multiple monthly snapshots after initial agreement
2. agreement_agreed_at represents when customer ORIGINALLY agreed, not when offer was given
3. business_date represents when offer was ACTIVE (snapshot state)

### Query 7 Sample Records
```
customer_id       business_date    agreement_date    days_between
XXWJ9ZF0CB        2025-10-31       NULL              NULL
1807401949        2025-10-31       NULL              NULL
ZB0UNNLBKR        2025-10-31       NULL              NULL
2135348170        2025-10-31       2025-07-15        108 days
```

**Most records have NULL agreement_date!**

---

## 🔍 What agreement_agreed_at Actually Means

Based on data patterns:
- **agreement_agreed_at** = Timestamp when customer ACCEPTED/AGREED to the loan offer
- **NOT** the date when the offer was CREATED or GIVEN
- **Sparsely populated** (only 4% of records)
- Possibly only populated when customer explicitly clicks "Accept" in app

**Why it's mostly NULL:**
1. Customer received offer but never clicked "Accept" button
2. System limitation - not all offer types capture agreement timestamp
3. Offers created automatically (system-generated) don't have agreement event
4. Legacy data issue - field not populated historically

---

## ✅ Correct Interpretation of Mentor's Guidance

### Mentor Said:
> "The data must be filtered to include only records where the loan_agreement_at date occurs in the same month as the other key date fields"

### What Mentor Meant (Likely):
**OPTION 1:** Same month constraint applies to offers that actually convert
- If customer disbursed, ensure disbursement happened in same month as offer was active
- This prevents matching offers from January to disbursements in October

**OPTION 2:** Misunderstanding about data availability
- Mentor may not have known agreement_agreed_at is 96% NULL
- Intended logic: "For offers where agreement exists, ensure same month"
- But this filters out 96% of data (not viable)

**OPTION 3:** Use key_date instead of agreement_agreed_at
- key_date was already calculated in base_loan_offer_snapshot
- key_date represents actual offer effective date
- This is likely the correct date field to use for "same month" logic

---

## 🚨 RECOMMENDATION: Clarify with Mentor

**Questions to Ask Pak Subhan:**

1. **"Pak, saya cek agreement_agreed_at field ini 96% nya NULL. Apakah bapak aware tentang ini?"**
   - Make mentor aware of data quality issue

2. **"Untuk 'same month filter', apakah maksudnya:**
   - **A)** Disbursement harus happen di bulan yang sama dengan offer active (business_date)?
   - **B)** Disbursement harus happen di bulan yang sama dengan customer agreement date?
   - **C)** Kita filter hanya offer yang punya agreement_agreed_at (jadi buang 96% data)?"

3. **"Atau mungkin maksud bapak kita pakai key_date instead of agreement_agreed_at?"**
   - key_date already calculated in temp table
   - Represents actual offer effective date
   - Not NULL for any record

---

## 💡 PROPOSED SOLUTIONS

### Solution 1: Remove Same Month Filter (Simplest)
Go back to original logic without same month constraint:
```sql
-- No same month filter
FROM base_loan_offer x
LEFT JOIN base_loan_offer_disburse y
  ON x.customer_id = y.customer_id
  AND y.facility_start_date > x.key_date
```

**Pros:**
- Uses full population (772K Oct customers)
- Gives realistic TUPR (3.13% for October)
- Matches business expectation

**Cons:**
- May include cross-month conversions (offer in Oct, disburse in Nov)

### Solution 2: Same Month Using business_date (Recommended)
Ensure disbursement happens in same month as offer snapshot:
```sql
FROM base_loan_offer x
LEFT JOIN base_loan_offer_disburse y
  ON x.customer_id = y.customer_id
  AND y.facility_start_date > x.key_date
  AND FORMAT_DATE('%Y-%m', y.facility_start_date) = FORMAT_DATE('%Y-%m', x.business_date)
```

**Pros:**
- Uses full population
- Ensures within-month conversion
- Prevents inflated TUPR from delayed disbursements

**Cons:**
- Lower TUPR (0.68% vs 3.13%)
- May be too restrictive

### Solution 3: Same Month Using key_date (Alternative)
Use key_date (offer effective date) for month grouping:
```sql
SELECT
  FORMAT_DATE('%Y-%m', key_date) AS offer_month,  -- Instead of business_date
  ...
FROM base_loan_offer_final
```

**Pros:**
- Uses actual offer creation month, not snapshot month
- Avoids agreement_agreed_at NULL issue
- More accurate attribution

**Cons:**
- Need to recalculate temp tables
- Different from current dashboard logic

---

## 📌 IMMEDIATE NEXT STEP

**DO NOT proceed with code changes until mentor clarifies:**
1. Is agreement_agreed_at 96% NULL acceptable?
2. What is the correct interpretation of "same month" filter?
3. Should we use business_date, key_date, or agreement_agreed_at for month grouping?

**Suggested Communication:**
Send mentor a summary showing:
- Query 1 result (96% NULL)
- Query 6 result (3.28% TUPR without same month filter)
- Query 6 result (0.68% TUPR with same month filter on business_date)
- Query 6 result (88% TUPR with same month filter on agreement_agreed_at)

Ask: "Pak, mana yang benar untuk TUPR calculation?"

---

## 📊 Summary Table: TUPR by Filter Logic

| Filter Logic | October Offers | October Disbursed | TUPR % | Valid? |
|--------------|----------------|-------------------|--------|--------|
| **No same month filter** | 772,333 | 25,312 | **3.28%** | ✅ Realistic |
| **Same month (business_date)** | 772,333 | 5,248 | **0.68%** | ⚠️ Too restrictive? |
| **Same month (agreement_agreed_at)** | 5,779 | 5,189 | **88.18%** | ❌ WRONG (96% data loss) |

---

**Status:** Waiting for mentor clarification before proceeding.