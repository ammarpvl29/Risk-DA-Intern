# Propensity Score Integration Guide
**Date:** November 7, 2025
**Purpose:** Integrate propensity model scores (iter5, iter6) into TUPR dashboard

---

## 📊 Tables Created

You've created 3 propensity score tables:

1. **`iter5_propensity_scores_combined`** - Iteration 5 (Bureau-enhanced model)
   - Union of dev + oot datasets
   - Trained on March-August 2025

2. **`iter6_propensity_scores_combined`** - Iteration 6 (Latest refinements)
   - Union of dev + oot datasets
   - Same training period

3. **`propensity_scores_all_iterations`** - Master table
   - Contains all iterations in one table

**Table Structure:**
```
- customer_id (STRING)
- appid (STRING)
- business_date (STRING in 'YYYY-MM-DD' format)
- scores_bin (INT64, 0-9 where 9 = highest propensity)
```

---

## 🔑 Key Integration Considerations

### 1. **Date Format Matching**
- **TUPR tables**: Use `DATE` type (e.g., `2025-10-31`)
- **Propensity tables**: Use `STRING` type (e.g., `'2025-10-31'`)
- **Join pattern**: `FORMAT_DATE('%Y-%m-%d', tupr.business_date) = propensity.business_date`

### 2. **Join Keys**
- Primary join: `customer_id` + `business_date`
- Expected match rate: 70-90% for training period (March-August 2025), lower for OOT

### 3. **Expected Coverage**
- High coverage: Customers in training period (March-August 2025)
- Lower coverage: New customers, OOT period (Sept-Oct 2025)
- NULL scores: Expected for customers outside model scope

---

## ✅ Validation Queries Breakdown

### **Group 1: Table Structure & Quality (V1-V3)**

| Query | Purpose | Expected Result | If Failed |
|-------|---------|-----------------|-----------|
| **V1: Table Structure** | Verify row counts, date ranges | Iter5 + Iter6 ≈ All Iterations | Check UNION ALL logic |
| **V2: Score Distribution** | Check decile distribution | Each bin ~10% of customers | Model calibration issue |
| **V3: Primary Key Uniqueness** | Check for duplicates | duplicates = 0 | Remove duplicates with QUALIFY |

**Run these first** to ensure table integrity before testing joins.

---

### **Group 2: TUPR Integration Tests (V4, V13)**

| Query | Purpose | Expected Result | If Failed |
|-------|---------|-----------------|-----------|
| **V4: Join Test with Query 2.5** | Test join at base level | Match rate 70-90% for March-August | Check date format conversion |
| **V13: Integration with Dashboard** | Test join with aggregated data | tupr_total = detail_total | Check GROUP BY dimensions |

**Key metrics:**
- `match_rate_pct`: % of TUPR customers with propensity scores
- `coverage_pct`: Should be high for training period, lower for OOT

---

### **Group 3: Business Validation (V6, V14)**

| Query | Purpose | Expected Result | If Failed |
|-------|---------|-----------------|-----------|
| **V6: Propensity vs TUPR Correlation** | Validate model works | TUPR% increases with scores_bin | Model not predicting correctly |
| **V14: High vs Low Propensity** | Business-level validation | High > Medium > Low propensity TUPR | Model lacks business value |

**Critical validation:** If TUPR% does NOT increase with propensity scores, the model is not working correctly for production use.

**Example expected pattern:**
```
Propensity Bin    TUPR%
      0          0.30%
      1          0.45%
      2          0.60%
      ...
      7          2.50%
      8          3.80%
      9          5.20%
```

---

### **Group 4: Segmentation Analysis (V5, V7, V9, V10)**

| Query | Purpose | Key Insight |
|-------|---------|-------------|
| **V5: By Campaign Segment** | Propensity distribution by BAU/CT/Weekly | CT might have higher propensity |
| **V7: By Source** | Coverage for new vs carry-over | Carry-over should have higher coverage |
| **V9: By Product Code** | Distribution by JAG06/JAG08/JAG09 | Different products = different propensity |
| **V10: NULL Analysis** | Why customers lack scores | Identify data gaps |

---

### **Group 5: Model Comparison (V11, V12)**

| Query | Purpose | What to Look For |
|-------|---------|------------------|
| **V11: Iter5 vs Iter6 Distribution** | Compare iterations | Should be similar but not identical |
| **V12: Score Bin Migration** | Track score changes | High diagonal = stable, off-diagonal = changes |

**Migration Matrix Example:**
```
Iter5 → Iter6    Bin 7    Bin 8    Bin 9
    Bin 7         80%      18%      2%     ← Stable
    Bin 8         15%      75%      10%    ← Some movement
    Bin 9         5%       20%      75%    ← Mostly stable
```
If >30% migrate more than 1 bin, investigate model instability.

---

### **Group 6: Data Quality (V8, V15)**

| Query | Purpose | Red Flag |
|-------|---------|----------|
| **V8: Monthly Trend** | Track distribution over time | Sudden shifts in distribution |
| **V15: Date Format Check** | Ensure date compatibility | Non-YYYY-MM-DD format |

---

## 🚀 Execution Order

### **Phase 1: Quick Checks (5 min)**
```sql
-- Run V1, V2, V3 first
-- Validate table structure and data quality
```

### **Phase 2: Integration Tests (10 min)**
```sql
-- Run V4, V13
-- Test joins with TUPR pipeline
```

### **Phase 3: Business Validation (10 min)**
```sql
-- Run V6, V14
-- CRITICAL: Verify propensity correlates with TUPR
```

### **Phase 4: Deep Dive (15 min)**
```sql
-- Run V5, V7, V9, V10, V11, V12
-- Segment analysis and model comparison
```

### **Phase 5: Final Checks (5 min)**
```sql
-- Run V8, V15
-- Data quality validation
```

**Total estimated time:** 45 minutes for all validations

---

## 🎯 Success Criteria

Before adding propensity scores to the dashboard, ensure:

- [ ] **V1**: All 3 tables exist with expected row counts
- [ ] **V2**: Score distribution is ~10% per bin (±3%)
- [ ] **V3**: No duplicate primary keys
- [ ] **V4**: Match rate >70% for training period (March-August 2025)
- [ ] **V6**: ✅ **CRITICAL** - TUPR% increases monotonically with propensity_bin
- [ ] **V13**: Row counts match between aggregated and detail views
- [ ] **V14**: High propensity tier has highest TUPR% across all campaign segments
- [ ] **V15**: All dates in YYYY-MM-DD format

---

## 📈 Dashboard Integration Plan

Once validations pass:

### **Step 1: Add Propensity to Query 2.5 Output**
```sql
-- Add LEFT JOIN to base_loan_offer_with_campaign
LEFT JOIN `data-prd-adhoc.credit_risk_adhoc.iter5_propensity_scores_combined` p
  ON x.customer_id = p.customer_id
  AND FORMAT_DATE('%Y-%m-%d', x.business_date) = p.business_date
```

### **Step 2: Add Propensity Fields to Query 3**
```sql
-- Add to SELECT and GROUP BY
propensity_bin,
CASE
  WHEN propensity_bin IN (0, 1, 2) THEN '1.Low (0-2)'
  WHEN propensity_bin IN (3, 4, 5, 6) THEN '2.Medium (3-6)'
  WHEN propensity_bin IN (7, 8, 9) THEN '3.High (7-9)'
  ELSE '4.No Score'
END AS propensity_tier
```

### **Step 3: Update LookML View**
```lkml
dimension: propensity_bin {
  type: number
  sql: ${TABLE}.propensity_bin ;;
  description: "Propensity score bin (0-9)"
}

dimension: propensity_tier {
  type: string
  sql: ${TABLE}.propensity_tier ;;
  description: "Propensity tier (Low/Medium/High)"
  order_by_field: propensity_tier_sorted
}
```

### **Step 4: Add Dashboard Section**
- Create new pivot table below TUPR metrics
- Rows: Propensity Tier
- Columns: Campaign Segment
- Metrics: Customers, TUPR%, Avg Limit

---

## 🔍 Interpreting Results

### **Good Signs:**
✅ V6 shows TUPR% increasing with propensity_bin
✅ V14 shows High > Medium > Low propensity TUPR
✅ V4 shows match rate >70% for training period
✅ V2 shows balanced distribution (~10% per bin)

### **Warning Signs:**
⚠️ V6 shows flat or decreasing TUPR% with propensity
⚠️ V12 shows >30% of customers changing >1 bin
⚠️ V8 shows sudden distribution shifts month-over-month
⚠️ V10 shows >40% customers with NULL propensity

### **Red Flags (Do NOT Deploy):**
🚨 V3 shows duplicate primary keys
🚨 V6 shows inverse correlation (high propensity = lower TUPR)
🚨 V14 shows Low propensity outperforms High propensity
🚨 V15 shows invalid date formats

---

## 📊 Sample Expected Results

### **V6: Propensity vs TUPR (Ideal Pattern)**
```
propensity_bin    total_customers    tupr_pct
      0                50,000          0.28%
      1                49,500          0.41%
      2                48,800          0.56%
      3                47,900          0.73%
      4                47,200          0.94%
      5                46,500          1.18%
      6                45,800          1.51%
      7                44,900          1.97%
      8                42,100          2.68%
      9                39,300          3.85%
```

### **V14: Propensity Tier vs TUPR**
```
propensity_tier       campaign_segment    tupr_pct
Low (0-2)                  BAU              0.42%
Low (0-2)                  CT               0.15%
Medium (3-6)               BAU              1.08%
Medium (3-6)               CT               0.24%
High (7-9)                 BAU              2.73%
High (7-9)                 CT               0.51%
```

---

## 🚨 Troubleshooting

### **Issue: Low match rate in V4 (<50%)**
**Causes:**
1. Date format mismatch
2. Customer IDs not matching (format differences)
3. Propensity table missing training data

**Fix:**
```sql
-- Check date format conversion
SELECT
  FORMAT_DATE('%Y-%m-%d', DATE '2025-10-31') as tupr_format,
  '2025-10-31' as propensity_format;
-- Both should be identical: '2025-10-31'

-- Check customer_id format
SELECT DISTINCT customer_id FROM tupr_table LIMIT 10;
SELECT DISTINCT customer_id FROM propensity_table LIMIT 10;
-- Formats should match (both STRING or both INT)
```

---

### **Issue: V6 shows no correlation or inverse correlation**
**Causes:**
1. Wrong model used (predicting default instead of take-up)
2. Propensity scores not calibrated correctly
3. Data mismatch (training on different population)

**Fix:**
- Verify you're using the **take-up propensity model** (not default/risk model)
- Check model documentation to confirm scores_bin 9 = highest take-up propensity
- Re-run model training if necessary

---

### **Issue: V2 shows skewed distribution (not ~10% per bin)**
**Causes:**
1. Model not properly calibrated to deciles
2. Union of dev + oot not balanced
3. Missing data in some bins

**Fix:**
```sql
-- Check dev vs oot distribution separately
SELECT
  'dev' as dataset,
  scores_bin,
  COUNT(*) as customers,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as pct
FROM iter5_dev
GROUP BY scores_bin

UNION ALL

SELECT
  'oot' as dataset,
  scores_bin,
  COUNT(*) as customers,
  ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER(), 2) as pct
FROM iter5_oot
GROUP BY scores_bin;
```

---

## 📞 Escalation

**If validation queries fail:**
1. **V1-V3 (Table structure)**: Check your UNION ALL queries
2. **V4, V13 (Join issues)**: Escalate to data engineering (date format issues)
3. **V6, V14 (Model not working)**: Escalate to data science team (model calibration)
4. **V11, V12 (Iter5 vs Iter6)**: Expected differences, document and proceed

---

## 📝 Documentation Checklist

Before presenting to Fang:

- [ ] Run all 15 validation queries
- [ ] Document match rates by month (V4, V13)
- [ ] Create visualization of V6 (Propensity vs TUPR trend)
- [ ] Prepare explanation for NULL propensity scores (V10)
- [ ] Compare Iter5 vs Iter6 performance (if both will be used)
- [ ] Calculate expected lift from targeting high propensity customers

**Sample calculation:**
```
Current BAU TUPR: 1.02%
High Propensity (7-9) TUPR: 2.73%
Lift = (2.73 - 1.02) / 1.02 = 168% improvement

If we target 100,000 high-propensity customers:
- Expected conversions: 2,730 (vs 1,020 with random targeting)
- Additional conversions: 1,710
```

---

**Document Owner:** Ammar Siregar
**Last Updated:** 2025-11-07
**Next Steps:** Run validation queries → Review results → Integrate into dashboard

Good luck! 🚀
