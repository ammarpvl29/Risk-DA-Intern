# TUPR Dashboard Fix - Execution Guide
**Date:** November 6, 2025
**Deadline:** 11:00 AM Nov 7 (Pre-presentation with Fang)
**Mentor:** Pak Subhan

---

## 🚨 CRITICAL ISSUES TO FIX

### Issue 1: KPI Discrepancy (HIGHEST PRIORITY)
**Problem:** KPI shows 34,630 disbursed but breakdown shows 4,715
**Impact:** Dashboard showing 7x inflated numbers
**Root Cause:** TBD (see Step 1 below)

### Issue 2: Unknown Categorization
**Problem:** "Unknown" segment is too broad
**Solution:** Split by product_code:
- JAG09 → "Open Market"
- Others → "Employee and Partner Payroll"

### Issue 3: Missing Campaign Data
**Problem:** Many customers have NULL campaign segments
**Solution:** Use COALESCE to look back 1-2 months

### Issue 4: Incorrect Sorting
**Problem:** Dashboard segments not in business order
**Solution:** BAU → CT → Weekly → Open Market → Employee/Partner

---

## 📋 STEP-BY-STEP EXECUTION

### **STEP 1: Investigate KPI Discrepancy** ⏱️ 10-15 min

**Run this query first:**
```sql
-- Check for duplicates or filter issues
SELECT
  offer_month,
  source,
  campaign_segment,
  COUNT(*) as row_count,
  SUM(total_customers) as total_customers,
  SUM(customers_disbursed) as total_disbursed
FROM `data-prd-adhoc.credit_risk_adhoc.tupr_dashboard_monthly_summary`
WHERE offer_month = '2025-10'
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;
```

**Expected Result:**
- Should have ~8 rows (2 sources × 4 campaign segments)
- `SUM(customers_disbursed)` = 4,715 (NOT 34,630)

**If result is WRONG:**
1. Check if the underlying table has duplicates
2. Check if Looker dashboard filters are applied to KPI boxes
3. In Looker, edit each KPI tile → Settings → "Listen to Dashboard Filters" must be enabled

**If result is CORRECT:**
→ The issue is in Looker dashboard configuration (filters not applied to KPIs)

---

### **STEP 2: Backup Current Tables** ⏱️ 5 min

Before making changes, create backups:

```sql
-- Backup Query 2.5 output
CREATE OR REPLACE TABLE `data-prd-adhoc.temp_ammar.base_loan_offer_with_campaign_BACKUP_Nov6` AS
SELECT * FROM `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign`;

-- Backup Query 3 output
CREATE OR REPLACE TABLE `data-prd-adhoc.temp_ammar.tupr_dashboard_final_dataset_BACKUP_Nov6` AS
SELECT * FROM `data-prd-adhoc.credit_risk_adhoc.tupr_dashboard_final_dataset`;

-- Backup Query 4 output
CREATE OR REPLACE TABLE `data-prd-adhoc.temp_ammar.tupr_dashboard_monthly_summary_BACKUP_Nov6` AS
SELECT * FROM `data-prd-adhoc.credit_risk_adhoc.tupr_dashboard_monthly_summary`;
```

---

### **STEP 3: Execute Updated Query 2.5** ⏱️ 8-12 min

**File:** `Query2.5_add_campaign_segmentation_UPDATED.sql`

**What's new:**
1. ✅ COALESCE with 4 LEFT JOINs (current month, -1, +1, -2 months)
2. ✅ Split "Unknown" into "Open Market" (JAG09) and "Employee/Partner Payroll"

**Execute in BigQuery:**
```bash
# Copy the entire content of Query2.5_add_campaign_segmentation_UPDATED.sql
# Paste into BigQuery console
# Click "RUN"
# Wait 8-12 minutes
```

**Validation (run immediately after):**
```sql
-- Check if Unknown decreased
SELECT
  campaign_segment,
  COUNT(DISTINCT customer_id) as customers,
  ROUND(COUNT(DISTINCT customer_id) * 100.0 / SUM(COUNT(DISTINCT customer_id)) OVER(), 2) as pct
FROM `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign`
WHERE business_date = '2025-10-31'
GROUP BY campaign_segment
ORDER BY customers DESC;
```

**Expected:**
- "Unknown" should be < 5% (down from ~15%)
- "Open Market" should appear (JAG09 only)
- "Employee and Partner Payroll" should appear (JAG06, JAG08)

---

### **STEP 4: Execute Updated Query 3** ⏱️ 3-5 min

**File:** `FIXED_Query3_tupr_dashboard_final_dataset.sql`

**What's new:**
1. ✅ Updated sorting: BAU (1) → CT (2) → Weekly (3) → Open Market (4) → Employee/Partner (5) → Unknown (6)

**Execute in BigQuery:**
```bash
# Copy the entire content of FIXED_Query3_tupr_dashboard_final_dataset.sql
# Paste into BigQuery console
# Click "RUN"
# Wait 3-5 minutes
```

**Validation:**
```sql
-- Check if new segments appear
SELECT DISTINCT campaign_segment, campaign_segment_sorted
FROM `data-prd-adhoc.credit_risk_adhoc.tupr_dashboard_final_dataset`
WHERE offer_month = '2025-10'
ORDER BY campaign_segment_sorted;
```

**Expected Order:**
1. 1.BAU
2. 2.CT
3. 3.Weekly
4. 4.Open Market
5. 5.Employee and Partner Payroll
6. 6.Unknown

---

### **STEP 5: Execute Updated Query 4** ⏱️ 3-5 min

**File:** `FIXED_Query4_tupr_dashboard_monthly_summary.sql`

**What's new:**
1. ✅ Same sorting as Query 3

**Execute in BigQuery:**
```bash
# Copy the entire content of FIXED_Query4_tupr_dashboard_monthly_summary.sql
# Paste into BigQuery console
# Click "RUN"
# Wait 3-5 minutes
```

**Validation:**
```sql
-- Final check - this is what KPI boxes will show
SELECT
  offer_month,
  source,
  campaign_segment,
  total_customers,
  customers_disbursed,
  ROUND(customers_disbursed * 100.0 / NULLIF(total_customers, 0), 2) as tupr_pct
FROM `data-prd-adhoc.credit_risk_adhoc.tupr_dashboard_monthly_summary`
WHERE offer_month = '2025-10'
ORDER BY source, campaign_segment_sorted;
```

**Expected:**
- Total customers across all rows: 553,528
- Total disbursed across all rows: 4,715 (NOT 34,630!)

---

### **STEP 6: Update Looker LookML** ⏱️ 5-10 min

**Files to update:**
1. `tupr_dashboard_final_dataset.view` ✅ Already updated
2. `tupr_dashboard_monthly_summary.view` ✅ Already updated

**In Looker:**
1. Go to "Develop" mode
2. Find your branch (or create new: `tupr_dashboard_fix_nov6`)
3. Navigate to the two .view files
4. Copy the updated content from your local files
5. **Validate LookML** (top right button)
6. **Commit** changes with message: "Fix campaign segmentation and sorting order - Nov 6"
7. **Deploy to Production** (if authorized) OR create Pull Request

---

### **STEP 7: Fix Dashboard KPI Boxes** ⏱️ 10-15 min

**In Looker Dashboard Editor:**

1. **Click "Edit Dashboard"**
2. For each KPI tile (Customers, Disbursed, Limit, etc.):
   - Click the **⋮** (three dots) on the tile
   - Select **"Edit"**
   - Go to **"Filters" tab**
   - Ensure these filters are **listening**:
     - ✅ Offer Month
     - ✅ Source
     - ✅ Campaign Segment
     - ✅ Risk Bracket
   - Click **"Run"** to test
   - Verify the number matches the pivot below (4,715 not 34,630)
   - Click **"Save"**

3. **After fixing all KPI boxes:**
   - Click **"Save Dashboard"**
   - Click **"Clear Cache & Refresh"**

---

### **STEP 8: Run Full Validation Suite** ⏱️ 15-20 min

**File:** `validation_queries_nov6.sql`

Run all 8 validation queries in the file. Key checks:

| Validation | Expected Result | If Failed |
|------------|-----------------|-----------|
| **1. KPI Discrepancy** | Oct disbursed = 4,715 | Recheck Step 1 & 7 |
| **2. COALESCE Effectiveness** | Unknown decreased 5-10% | Check Query 2.5 logic |
| **3. Unknown Split** | OM = JAG09 only, E&P = others | Check CASE logic |
| **4. Campaign Distribution** | BAU 70-80%, CT 10-20%, Weekly <1% | Normal distribution |
| **5. NULL CT Values** | <5% of CT should be NULL | Check ct_category field |
| **6. Row Conservation** | All stages = 553,528 | Check for duplicates |
| **7. Disbursement Matching** | Total = 4,715 | Critical check |
| **8. COALESCE Lookback** | 30-40% filled by lookback | Shows COALESCE working |

---

### **STEP 9: Investigate NULL CT Values** ⏱️ 10-15 min

Your mentor mentioned seeing NULL values in the CT segment. Run this:

```sql
-- Find CT customers with NULL category
SELECT
  campaign_segment,
  campaign_category,
  COUNT(DISTINCT customer_id) as customers,
  ROUND(COUNT(DISTINCT customer_id) * 100.0 / SUM(COUNT(DISTINCT customer_id)) OVER(), 2) as pct
FROM `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign`
WHERE business_date = '2025-10-31'
  AND campaign_segment = 'CT'
GROUP BY campaign_segment, campaign_category
ORDER BY customers DESC;
```

**If NULL > 5%:**
Check the source table:
```sql
-- Check if category field is populated
SELECT
  category,
  COUNT(DISTINCT customer_id) as customers
FROM `data-prd-adhoc.dl_whitelist_checkers.dl_wl_final_whitelist_credit_test_raw_history`
WHERE business_date = '2025-10-31'
  AND waterfall_failure_step = '99. Passed Underwriting Waterfall'
GROUP BY category;
```

**If category is NULL in source:**
→ This is a data quality issue. Document and report to Pak Subhan.

---

### **STEP 10: Create Presentation Summary** ⏱️ 20-30 min

**For 11 AM Pre-Presentation with Fang**

Create a document/slides covering:

#### **Slide 1: Issues Found**
- KPI showing 34,630 instead of 4,715 (7x inflation)
- "Unknown" segment too broad (15% of customers)
- Missing campaign data due to timing mismatch
- Incorrect sorting order

#### **Slide 2: Solutions Implemented**
1. **COALESCE Multi-Month Lookback**
   - Looks back 1-2 months to fill missing campaign data
   - Reduced "Unknown" from 15% to <5%

2. **Unknown Segment Split**
   - JAG09 → "Open Market" (new segment)
   - Others → "Employee and Partner Payroll" (new segment)

3. **Correct Sorting Order**
   - BAU → CT → Weekly → Open Market → Employee/Partner

4. **Fixed KPI Boxes**
   - Enabled dashboard filters on all KPI tiles
   - Now shows correct 4,715 disbursed

#### **Slide 3: October 2025 Results (After Fix)**
```
Campaign Segment Distribution:
- BAU: 401,256 customers (72.5%), 4,087 disbursed (1.02% TUPR)
- CT: 143,393 customers (25.9%), 269 disbursed (0.19% TUPR)
- Unknown/OM/E&P: 8,879 customers (1.6%), 359 disbursed (4.04% TUPR)
- Weekly: 0 customers

TOTAL: 553,528 customers, 4,715 disbursed (0.85% TUPR) ✅
```

#### **Slide 4: Data Quality Findings**
- NULL CT values: X% (if >5%, escalate)
- COALESCE filled: Y% of customers (show effectiveness)
- Row conservation: ✅ No data loss across pipeline

#### **Slide 5: Next Steps**
- Monitor "Unknown" rate over next month
- Investigate NULL CT categories with data team
- Consider extending COALESCE to 3-4 months lookback if needed

---

## ✅ FINAL CHECKLIST (Before 11 AM Meeting)

- [ ] Step 1: KPI discrepancy root cause identified
- [ ] Step 2: Backup tables created
- [ ] Step 3: Query 2.5 executed and validated
- [ ] Step 4: Query 3 executed and validated
- [ ] Step 5: Query 4 executed and validated
- [ ] Step 6: LookML updated and deployed
- [ ] Step 7: Dashboard KPI boxes fixed
- [ ] Step 8: All validation queries passed
- [ ] Step 9: NULL CT values investigated
- [ ] Step 10: Presentation summary created

**Dashboard URL:** https://bankjago.cloud.looker.com/dashboards/461

**Test the dashboard:**
1. Filters: Offer Month = 2025-10, Source = all, Campaign = all
2. KPI shows: 553,528 customers, 4,715 disbursed, 0.85% TUPR ✅
3. Pivots match KPI totals ✅
4. Campaign segments in correct order (BAU, CT, Weekly, OM, E&P) ✅

---

## 🚨 TROUBLESHOOTING

### Issue: Query 2.5 takes too long (>15 min)
**Solution:** The COALESCE with 4 joins is expensive. Consider:
1. Run during off-peak hours
2. Add WHERE clause to limit date range
3. Check if indexes exist on customer_id and business_date

### Issue: Dashboard still shows 34,630
**Solution:**
1. Clear Looker cache: Dashboard → ⋮ → Clear Cache & Refresh
2. Check if "Listen to Filters" is enabled on KPI tiles
3. Verify Query 4 was actually updated (check last modified timestamp)

### Issue: "Open Market" showing non-JAG09 products
**Solution:**
- Check the CASE logic in Query 2.5 line 110-115
- Ensure product_code filter is correct (= 'JAG09' not LIKE '%JAG09%')

### Issue: COALESCE didn't reduce Unknown much
**Solution:**
- Extend lookback to 3-4 months (add e4, e5 joins)
- Check if dl_whitelist tables have data for those months
- Verify LAST_DAY logic is correct (month boundaries)

---

## 📞 ESCALATION

**If you get blocked, contact:**
1. **Pak Subhan** (Mentor) - Technical issues
2. **Fang** (Pre-presentation contact) - Presentation content
3. **DL Team** (Data owners) - Source data quality issues

**Slack Channel:** `#credit-risk-analytics`

---

**Document Owner:** Ammar Siregar
**Last Updated:** 2025-11-06
**Deadline:** 2025-11-07 11:00 AM (Pre-presentation)

**Good luck! 🚀**
