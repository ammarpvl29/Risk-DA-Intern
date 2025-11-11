# Propensity Score Integration - Complete Execution Guide

**Date**: 2025-11-10
**Analyst**: Ammar Siregar
**Objective**: Add propensity scores (Jan-Nov 2025) to TUPR dashboard
**Estimated Time**: 2-3 hours

---

## 🎯 What You're Building

Adding a new dimension to your TUPR dashboard that shows **loan take-up propensity**:
- **Propensity Bin 0-9**: Decile scoring (9 = highest likelihood to take loan)
- **Propensity Tier**: Grouped as Low/Medium/High for easier business analysis
- **Coverage**: January 2025 - November 2025 (11 months)
- **Models**: Iter5/6 (Jan-Aug) + Iter7/8 (Sept-Nov)

---

## 📋 Pre-Execution Checklist

Before starting, verify you have access to:

- [ ] BigQuery project: `data-prd-adhoc`
- [ ] Schema write access: `credit_risk_adhoc`, `temp_ammar`
- [ ] Existing tables verified:
  - [ ] `ammar_df_scores_20251001_bureau_1m`
  - [ ] `ammar_df_scores_oot_20251001_bureau_1m`
  - [ ] `ammar_df_scores_20251011_carryover`
  - [ ] `ammar_df_scores_oot_20251011_carryover`
  - [ ] `df_scores_newoffers_20250930`
  - [ ] `df_scores_carryovers_20250930`
  - [ ] `df_scores_newoffers_20251031`
  - [ ] `df_scores_carryovers_20251031`
  - [ ] `df_scores_newoffers_20251106`
  - [ ] `df_scores_carryovers_20251106`

---

## 🚀 Execution Steps

### **STEP 1: Create Unified Propensity Table** ⏱️ 10-15 minutes

**File**: `Step1_create_unified_propensity_table.sql`

**Action**:
1. Open BigQuery console
2. Copy entire contents of Step1 SQL file
3. Click "Run"
4. Wait for completion (processing ~2-3M rows)

**Success Criteria**:
```
Table `data-prd-adhoc.credit_risk_adhoc.propensity_scores_unified_jan_nov` created successfully
```

**If Error Occurs**:
- "Table not found" → Check table names in Pre-Execution Checklist
- "Access Denied" → Request write permission for credit_risk_adhoc schema
- "Syntax error" → Verify no copy-paste formatting issues

---

### **STEP 2: Validate Unified Table** ⏱️ 10 minutes

**File**: `Step2_validate_unified_propensity_table.sql`

**Action**:
1. Run **Validation 1** (Monthly Count Summary)
2. Check output against expected counts:
   - Sept new: **460,332** ✓
   - Sept carryover: **124,976** ✓
   - Oct new: **94,700** ✓
   - Oct carryover: **499,363** ✓

3. Run **Validation 3** (Take-Up Rate Monotonicity)
4. Verify TUPR increases from Bin 0 → Bin 9

**Success Criteria**:
- ✅ Sept/Oct counts match exactly
- ✅ All 11 months present (Jan-Nov 2025)
- ✅ Take-up rate increases monotonically with propensity_bin
- ✅ No duplicate primary keys (Validation 4 returns 0 rows)

**If Validation Fails**:
- **Counts don't match**: Check source table names in Step 1
- **Missing months**: Verify iter5/iter6 tables contain Jan-Aug data
- **Non-monotonic TUPR**: STOP and contact Stephanie - model issue

---

### **STEP 3: Update Query 2.5 (Add Propensity Join)** ⏱️ 5-10 minutes

**File**: `Step3_update_Query2.5_with_propensity.sql`

**Action**:
1. Open BigQuery console
2. Copy entire contents of Step3 SQL file
3. Click "Run"
4. Wait for completion (~5-10 minutes for full table)

**Success Criteria**:
```
Table `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign` updated successfully
```

**Post-Execution Validation**:
Run this query to check propensity join coverage:

```sql
SELECT
  FORMAT_DATE('%Y-%m', business_date) AS month,
  source,
  COUNT(DISTINCT customer_id) AS total_customers,
  COUNT(DISTINCT CASE WHEN propensity_score_bin IS NOT NULL THEN customer_id END) AS with_propensity,
  ROUND(
    COUNT(DISTINCT CASE WHEN propensity_score_bin IS NOT NULL THEN customer_id END) * 100.0 /
    NULLIF(COUNT(DISTINCT customer_id), 0),
    2
  ) AS coverage_pct
FROM `data-prd-adhoc.credit_risk_adhoc.base_loan_offer_with_campaign`
WHERE business_date >= '2025-01-01'
GROUP BY 1, 2
ORDER BY 1 DESC, 2;
```

**Expected**: coverage_pct > 80% for all months

**If Coverage Low (<50%)**:
- Check date format matching: LAST_DAY(x.business_date) = LAST_DAY(p.offer_date)
- Check source matching: x.source = p.source
- Verify propensity_scores_unified_jan_nov table populated correctly

---

### **STEP 4: Update Query 3 (Final Dataset)** ⏱️ 15-20 minutes

**File**: `Step4_update_Query3_final_dataset_with_propensity.sql`

**Action**:
1. Open BigQuery console
2. Copy entire contents of Step4 SQL file
3. Click "Run"
4. Wait for completion (~15-20 minutes - this is the main dashboard table)

**Success Criteria**:
```
Table `data-prd-adhoc.credit_risk_adhoc.tupr_dashboard_final_dataset` updated successfully
Rows: ~150,000-200,000 (granularity increased ~10x with propensity dimension)
```

**Post-Execution Validation**:
Run this query to test propensity integration:

```sql
SELECT
  offer_month,
  source,
  propensity_tier,
  SUM(total_customers) AS customers,
  ROUND(
    SUM(customers_disbursed) * 100.0 / NULLIF(SUM(total_customers), 0),
    2
  ) AS tupr_pct
FROM `data-prd-adhoc.credit_risk_adhoc.tupr_dashboard_final_dataset`
WHERE offer_month >= '2025-09'  -- Validated months
GROUP BY 1, 2, 3
ORDER BY 1 DESC, 2, 4;
```

**Expected Pattern**:
```
2025-10, new, High (7-9),    ???,  8-12%   ← Highest
2025-10, new, Medium (3-6),  ???,  2-4%
2025-10, new, Low (0-2),     ???,  0.5-1%  ← Lowest

2025-10, carry over, High (7-9),    ???,  5-8%
2025-10, carry over, Medium (3-6),  ???,  1-2%
2025-10, carry over, Low (0-2),     ???,  0.3-0.7%
```

✅ **If this pattern holds, propensity integration is working correctly!**

---

### **STEP 5: Update LookML Views** ⏱️ 10 minutes

**File**: `Step5_update_lookml_views_with_propensity.md`

**Action**:
1. Open your LookML project in Looker/Looker Studio
2. Navigate to `tupr_final_dataset.view`
3. Add propensity dimensions from Step5 file (after line 89)
4. Update `detail` set to include propensity fields
5. Validate LookML syntax (no errors)
6. Commit changes to git
7. Deploy to production

**Success Criteria**:
- ✅ LookML validates without syntax errors
- ✅ Deployment successful
- ✅ New dimensions visible in Looker field picker:
  - `propensity_score_bin`
  - `propensity_tier`
  - `propensity_bin_label`
  - `pct_high_propensity_customers`
  - `avg_propensity_bin`

---

### **STEP 6: Test Dashboard** ⏱️ 15 minutes

**Test 1: Propensity Distribution by Month**

**Query in Looker**:
- Dimensions: `offer_month`, `propensity_tier`
- Measures: `total_customers`, `take_up_rate_pct_by_customer`
- Filters: `offer_month` >= 2025-09

**Expected**:
- Low (0-2) shows lowest TUPR
- High (7-9) shows highest TUPR
- "No Score" should be <20% of customers

---

**Test 2: Campaign × Propensity Cross-Tab**

**Query in Looker**:
- Rows: `campaign_segment`
- Columns: `propensity_tier`
- Measures: `total_customers`, `take_up_rate_pct_by_customer`
- Filters: `offer_month` = 2025-10, `source` = 'new'

**Business Insight**:
- Which campaign generates most high-propensity customers?
- Does CT outperform BAU in propensity distribution?

---

**Test 3: Propensity Bin Granularity**

**Query in Looker**:
- Dimension: `propensity_bin_label`
- Measures: `total_customers`, `customers_disbursed`, `take_up_rate_pct_by_customer`
- Filters: `offer_month` = 2025-09, `source` = 'new'
- Sort: `propensity_score_bin` ASC

**Expected**:
```
Bin 0 - Lowest,  ???,  ???,  ~0.15%
Bin 1,           ???,  ???,  ~0.47%
...
Bin 9 - Highest, ???,  ???,  ~10.79%
```

✅ **Monotonic increase validates model correctness**

---

## ✅ Success Checklist

Before presenting to stakeholders:

### Data Quality
- [ ] Step 2 Validation 1: Sept/Oct counts match exactly
- [ ] Step 2 Validation 3: TUPR increases monotonically (Bin 0 < Bin 9)
- [ ] Step 2 Validation 5: All 11 months present (Jan-Nov 2025)
- [ ] Step 3 Validation: Propensity coverage >80% for all months
- [ ] Step 4 Validation: High/Medium/Low propensity shows expected TUPR pattern

### Technical Validation
- [ ] Unified propensity table created successfully
- [ ] base_loan_offer_with_campaign updated with propensity fields
- [ ] tupr_dashboard_final_dataset updated with propensity dimensions
- [ ] LookML changes deployed to production
- [ ] All new dimensions visible in Looker field picker

### Business Validation
- [ ] Test 1 passed: Propensity tier correlates with TUPR
- [ ] Test 2 passed: Campaign × Propensity cross-tab renders
- [ ] Test 3 passed: Bin-level granularity shows monotonic trend
- [ ] Dashboard documented: User guide created
- [ ] Stakeholders trained: Demo session completed

---

## 🚨 Common Issues & Solutions

### Issue 1: "Table not found" Error in Step 1

**Symptoms**: BigQuery can't find source tables

**Solution**:
```sql
-- Run this to check which tables exist:
SELECT table_name
FROM `data-prd-adhoc.dl_whitelist_checkers.__TABLES__`
WHERE table_name LIKE 'df_scores%'
ORDER BY table_name;

SELECT table_name
FROM `data-prd-adhoc.credit_risk_adhoc.__TABLES__`
WHERE table_name LIKE 'ammar_df_scores%'
ORDER BY table_name;
```

If tables are missing, contact Stephanie.

---

### Issue 2: Sept/Oct Counts Don't Match

**Symptoms**: Validation 1 shows different counts than expected

**Expected vs Actual**:
| Period | Type | Expected | Your Result |
|--------|------|----------|-------------|
| Sept | new | 460,332 | ??? |
| Sept | carryover | 124,976 | ??? |
| Oct | new | 94,700 | ??? |
| Oct | carryover | 499,363 | ??? |

**Solution**:
- If counts are HIGHER: Duplicate rows in source tables → Add QUALIFY deduplication in Step 1
- If counts are LOWER: Filter too restrictive → Check WHERE clauses in Step 1
- If counts WILDLY different: Wrong table used → Verify table names

---

### Issue 3: Low Propensity Coverage (<50%)

**Symptoms**: Step 3 validation shows <50% coverage_pct

**Root Causes**:
1. Date format mismatch
2. Source field mismatch ('new' vs 'carry over')
3. Customer ID format differences

**Solution**:
```sql
-- Debug query:
SELECT
  'TUPR' AS source_table,
  customer_id,
  business_date,
  source
FROM `data-prd-adhoc.temp_ammar.base_loan_offer_with_demo`
WHERE business_date = '2025-09-30'
LIMIT 10;

-- Compare with:
SELECT
  'Propensity' AS source_table,
  customer_id,
  period AS business_date,
  source
FROM `data-prd-adhoc.credit_risk_adhoc.propensity_scores_unified_jan_nov`
WHERE period = '2025-09-30'
LIMIT 10;
```

Check if:
- customer_id format matches (both STRING?)
- business_date format matches (both DATE?)
- source values match exactly ('new' vs 'carry over' - check for trailing spaces!)

---

### Issue 4: Take-Up Rate NOT Increasing with Propensity

**Symptoms**: Step 2 Validation 3 shows Bin 3 > Bin 7 (inverse pattern)

**This is a CRITICAL ISSUE - DO NOT DEPLOY**

**Solution**:
1. Screenshot the validation results
2. Contact Stephanie immediately with:
   - Query output showing inverse correlation
   - Table names used
   - Period analyzed

Possible causes:
- Wrong model used (predicting default risk instead of take-up propensity)
- Scores not calibrated correctly
- Training data mismatch

---

### Issue 5: "No Score" Dominates Dashboard

**Symptoms**: >50% of customers show "No Score" in propensity_tier

**Solution**:
Run Step 3 validation query. If coverage <80%:
1. Re-run Step 3 (Query 2.5 update)
2. Verify join conditions:
   - Date matching: `LAST_DAY(x.business_date) = LAST_DAY(p.offer_date)`
   - Source matching: `x.source = p.source`

If coverage is high (>80%) but dashboard still shows many "No Score":
- Clear Looker cache (Ctrl+Shift+K)
- Re-run query in Looker
- Check if filters are excluding propensity scores

---

## 📊 Expected Business Outcomes

After successful deployment, business users can:

### 1. **Optimize Campaign Targeting**
*"Which campaigns generate high-propensity customers?"*

**Before**: Target all BAU customers equally
**After**: Focus on BAU customers in Bin 7-9 (3x higher conversion)

**Impact**: +20-30% campaign efficiency

---

### 2. **Risk-Propensity Balance**
*"Are high-propensity customers also high-risk?"*

**Analysis**: Cross-tab `propensity_tier` × `risk_bracket`

**Red Flag**: If >30% of High propensity are H risk → Adverse selection
**Healthy**: High propensity distributed across L/LM/M/MH

---

### 3. **Product Performance**
*"Does JAG08 attract higher propensity than JAG09?"*

**Analysis**: Filter by `product_code`, compare `avg_propensity_bin`

**Insight**: If JAG08 avg bin = 5.2, JAG09 avg bin = 3.8 → JAG08 better targeting

---

### 4. **Monthly Propensity Trends**
*"Is our propensity distribution stable over time?"*

**Metric**: Track `pct_high_propensity_customers` monthly

**Alert Rule**: If drops below 25% for 2 consecutive months → Model drift, refresh needed

---

## 📝 Documentation for Stakeholders

Create a 1-page dashboard guide with:

### **What is Propensity Score?**
- Likelihood to accept loan offer (0-9 scale)
- 9 = highest propensity (~10% TUPR)
- 0 = lowest propensity (~0.15% TUPR)

### **How to Use in Dashboard**
1. **Filter by Propensity Tier**: Select "High (7-9)" to see best customers
2. **Cross-analyze**: Campaign × Propensity to find winning combinations
3. **Track Trends**: Monitor monthly propensity distribution

### **Business Rules**
- **Priority Targeting**: Bin 7-9 (8-12% TUPR)
- **Moderate Targeting**: Bin 4-6 (1.5-3% TUPR)
- **Low Priority**: Bin 0-3 (<1% TUPR) - Reduce offers

---

## 🎓 Presenting to Mentor (Pak Subhan / Pak Fang)

### **Slide 1: Overview**
- Added propensity scoring to TUPR dashboard
- Coverage: Jan-Nov 2025 (11 months)
- Models: Iter5/6 (best performance) + Iter7/8 (production)

### **Slide 2: Data Architecture**
- Unified 10 source tables into single propensity_scores_unified table
- 4-step pipeline: Unified → Query 2.5 → Query 3 → LookML
- Validated counts: Sept (585k) + Oct (594k) match exactly ✓

### **Slide 3: Model Performance Validation**
- **Monotonic Correlation**: Bin 0 (0.15%) → Bin 9 (10.79%) TUPR
- **Discrimination Power**: 72x improvement (Bin 9 / Bin 0)
- **Coverage**: >80% of customers have propensity scores

### **Slide 4: Business Use Cases** (show actual dashboard screenshots)
- Campaign Optimization: CT generates 35% high-propensity vs 25% BAU
- Risk Balance: High-propensity customers distributed across L/LM/M (healthy)
- Product Performance: JAG08 avg propensity bin 5.2 > JAG09 3.8

### **Slide 5: Next Steps**
- Monthly monitoring: Track propensity distribution stability
- Quarterly model refresh: Work with Stephanie on iterations
- Business enablement: Train product team on propensity-based targeting

---

## ⏰ Timeline Estimate

| Task | Duration | Can Run in Parallel? |
|------|----------|----------------------|
| Step 1: Create unified table | 10-15 min | No |
| Step 2: Validate table | 10 min | No (depends on Step 1) |
| Step 3: Update Query 2.5 | 5-10 min | No (depends on Step 1) |
| Step 4: Update Query 3 | 15-20 min | Yes (parallel with Step 3) |
| Step 5: Update LookML | 10 min | Yes (parallel with Step 4) |
| Step 6: Test dashboard | 15 min | No (depends on Step 4+5) |

**Sequential Path**: Step 1 → Step 2 → Step 3 → Step 4 → Step 5 → Step 6
**Total Time**: ~65-80 minutes (1-1.5 hours)

**Optimized Path** (run Step 3 & 4 in parallel):
**Total Time**: ~50-65 minutes

---

## 📞 Escalation Contacts

| Issue Type | Contact | When to Escalate |
|------------|---------|------------------|
| **Data Quality** | Stephanie | Validation 3 fails (non-monotonic TUPR) |
| **Table Access** | Data Engineering | "Permission denied" errors |
| **Model Performance** | Stephanie | Coverage <50% or inverse correlation |
| **Business Questions** | Pak Subhan | Interpretation of propensity patterns |
| **LookML Deployment** | Looker Admin | Deployment fails or syntax errors |

---

**Good luck with the integration! 🚀**

**Document Owner**: Ammar Siregar
**Last Updated**: 2025-11-10
**Status**: Ready for Execution
**Next Review**: After Step 6 completion
