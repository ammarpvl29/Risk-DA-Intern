# TUPR Dashboard Implementation Guide - UPDATED
## New Offer Filter Applied

**Date:** 2025-11-05
**Dashboard URL:** https://bankjago.cloud.looker.com/dashboards/461
**Status:** ✅ Ready for Implementation

---

## 📋 Overview

This guide covers the complete implementation of the Take Up Rate (TUPR) Dashboard after applying the NEW OFFER filter (excluding carry-over offers from previous months).

**Key Changes:**
- Now tracking NEW OFFERS only (not carry-over offers)
- Expected customer counts reduced by ~50-70%
- Expected TUPR: 3-5% (realistic range)
- Dashboard restructured with proper KPI boxes and horizontal pivots

---

## 🔧 Step 1: Execute Queries in BigQuery

Run all 4 queries in sequence. Each depends on the previous one.

### Query 1: Base Snapshot (NEW OFFERS)
```sql
-- File: FIXED_Query1_base_loan_offer_snapshot.sql
-- Creates: data-prd-adhoc.temp_ammar.base_loan_offer_snapshot
-- Runtime: ~2-3 minutes
```

**What it does:**
- Filters for NEW OFFERS only using LAG window function
- Excludes carry-over offers (continuous from previous month)
- Creates base temp table for downstream queries

**Validate:**
```sql
SELECT
  FORMAT_DATE('%Y-%m', key_date) AS month,
  COUNT(DISTINCT customer_id) AS customers
FROM `data-prd-adhoc.temp_ammar.base_loan_offer_snapshot`
GROUP BY 1
ORDER BY 1 DESC
LIMIT 5;
```

Expected October 2025: **50K-100K customers**

---

### Query 2: Add Demographics
```sql
-- File: FIXED_Query2_base_loan_offer_with_demo.sql
-- Creates: data-prd-adhoc.temp_ammar.base_loan_offer_with_demo
-- Runtime: ~5-10 minutes
```

**What it does:**
- Joins Query 1 results with customer table
- Adds age_tier dimension for future analysis
- Same row count as Query 1

---

### Query 3: Dimensional Dataset
```sql
-- File: FIXED_Query3_tupr_dashboard_final_dataset.sql
-- Creates: data-prd-adhoc.temp_ammar.tupr_dashboard_final_dataset
-- Runtime: ~3-5 minutes
```

**What it does:**
- Aggregates by Product, Risk Grade, Limit Tier dimensions
- Matches disbursements in same month as offer
- Creates sorting fields for proper pivot ordering

**Validate:**
```sql
SELECT
  offer_month,
  COUNT(*) AS rows,
  SUM(total_customers) AS customers,
  ROUND(SUM(customers_disbursed) * 100.0 / NULLIF(SUM(total_customers), 0), 2) AS tupr_pct
FROM `data-prd-adhoc.temp_ammar.tupr_dashboard_final_dataset`
GROUP BY 1
ORDER BY 1 DESC
LIMIT 5;
```

Expected October 2025 TUPR: **3-5%**

---

### Query 4: Monthly Summary
```sql
-- File: FIXED_Query4_tupr_dashboard_monthly_summary.sql
-- Creates: data-prd-adhoc.temp_ammar.tupr_dashboard_monthly_summary
-- Runtime: ~3-5 minutes
```

**What it does:**
- Creates month-level aggregation (no dimensions)
- Single row per month
- Use this for KPI boxes to prevent inflation

**Validate:**
```sql
SELECT *
FROM `data-prd-adhoc.temp_ammar.tupr_dashboard_monthly_summary`
ORDER BY offer_month DESC
LIMIT 5;
```

---

## 📊 Step 2: Update LookML Views

### View 1: Monthly Summary (for KPI boxes)

**File:** `tupr_dashboard_monthly_summary.view`

```lkml
view: tupr_dashboard_monthly_summary {
  sql_table_name: `data-prd-adhoc.temp_ammar.tupr_dashboard_monthly_summary` ;;

  dimension: offer_month {
    type: string
    sql: ${TABLE}.offer_month ;;
  }

  measure: total_customers {
    type: max
    sql: ${TABLE}.total_customers ;;
    value_format: "#,##0"
  }

  measure: total_limit {
    type: max
    sql: ${TABLE}.total_limit ;;
    value_format: "#,##0"
  }

  measure: customers_disbursed {
    type: max
    sql: ${TABLE}.customers_disbursed ;;
    value_format: "#,##0"
  }

  measure: total_limit_disbursed {
    type: max
    sql: ${TABLE}.total_limit_disbursed ;;
    value_format: "#,##0"
  }

  measure: take_up_rate_pct_by_customer {
    type: max
    sql: ${TABLE}.take_up_rate_pct_by_customer ;;
    value_format: "0.00\%"
  }

  measure: take_up_rate_pct_by_limit {
    type: max
    sql: ${TABLE}.take_up_rate_pct_by_limit ;;
    value_format: "0.00\%"
  }
}
```

**Key Point:** Use `type: max` (not sum) because each month is a single row

---

### View 2: Dimensional Dataset (for tables and pivots)

**File:** `tupr_dashboard_final_dataset.view`

```lkml
view: tupr_dashboard_final_dataset {
  sql_table_name: `data-prd-adhoc.temp_ammar.tupr_dashboard_final_dataset` ;;

  dimension: offer_month {
    type: string
    sql: ${TABLE}.offer_month ;;
  }

  dimension: product_code {
    type: string
    sql: ${TABLE}.product_code ;;
    order_by_field: product_code_sorted
  }

  dimension: product_code_sorted {
    type: string
    sql: ${TABLE}.product_code_sorted ;;
    hidden: yes
  }

  dimension: risk_bracket {
    type: string
    sql: ${TABLE}.risk_bracket ;;
    order_by_field: risk_bracket_sorted
  }

  dimension: risk_bracket_sorted {
    type: string
    sql: ${TABLE}.risk_bracket_sorted ;;
    hidden: yes
  }

  dimension: limit_tier {
    type: string
    sql: ${TABLE}.limit_tier ;;
    order_by_field: limit_tier_sorted
  }

  dimension: limit_tier_sorted {
    type: string
    sql: ${TABLE}.limit_tier_sorted ;;
    hidden: yes
  }

  measure: total_customers {
    type: sum
    sql: ${TABLE}.total_customers ;;
    value_format: "#,##0"
  }

  measure: total_limit {
    type: sum
    sql: ${TABLE}.total_limit ;;
    value_format: "#,##0"
  }

  measure: customers_disbursed {
    type: sum
    sql: ${TABLE}.customers_disbursed ;;
    value_format: "#,##0"
  }

  measure: total_limit_disbursed {
    type: sum
    sql: ${TABLE}.total_limit_disbursed ;;
    value_format: "#,##0"
  }

  measure: take_up_rate_pct_by_customer {
    type: number
    sql: SAFE_DIVIDE(
      SUM(${TABLE}.customers_disbursed) * 100.0,
      NULLIF(SUM(${TABLE}.total_customers), 0)
    ) ;;
    value_format: "0.00\%"
  }

  measure: take_up_rate_pct_by_limit {
    type: number
    sql: SAFE_DIVIDE(
      SUM(${TABLE}.total_limit_disbursed) * 100.0,
      NULLIF(SUM(${TABLE}.total_limit), 0)
    ) ;;
    value_format: "0.00\%"
  }
}
```

**Key Point:** Use `type: sum` for dimensional data, `type: number` with SAFE_DIVIDE for TUPR calculations

---

## 🎨 Step 3: Dashboard Layout

Go to: https://bankjago.cloud.looker.com/dashboards/461 and click "Edit"

### Section 1: Header Text

**Add Text Box**
- Position: Top center, above all KPI boxes
- Content: `Latest Offer: October 2025`
- Format: Bold, 16px font
- Update monthly as new data arrives

---

### Section 2: KPI Boxes (6 boxes in 3 rows)

**⚠️ CRITICAL:** All KPI boxes use `tupr_dashboard_monthly_summary` view

#### Row 1: Customer Metrics

**Box 1 - Left Side**
- Title: "Customers Offered"
- View: `tupr_dashboard_monthly_summary`
- Measure: `total_customers`
- Visualization: Single Value
- Format: Number (#,##0)

**Box 2 - Right Side**
- Title: "Customers Disbursed"
- View: `tupr_dashboard_monthly_summary`
- Measure: `customers_disbursed`
- Visualization: Single Value
- Format: Number (#,##0)

#### Row 2: Limit Metrics

**Box 3 - Left Side**
- Title: "Limit Offered (IDR)"
- View: `tupr_dashboard_monthly_summary`
- Measure: `total_limit`
- Visualization: Single Value
- Format: Number (#,##0)

**Box 4 - Right Side**
- Title: "Limit Disbursed (IDR)"
- View: `tupr_dashboard_monthly_summary`
- Measure: `total_limit_disbursed`
- Visualization: Single Value
- Format: Number (#,##0)

#### Row 3: TUPR Metrics

**Box 5 - Left Side**
- Title: "TUPR (by Customer %)"
- View: `tupr_dashboard_monthly_summary`
- Measure: `take_up_rate_pct_by_customer`
- Visualization: Single Value
- Format: Percentage (0.00%)

**Box 6 - Right Side**
- Title: "TUPR (by Limit %)"
- View: `tupr_dashboard_monthly_summary`
- Measure: `take_up_rate_pct_by_limit`
- Visualization: Single Value
- Format: Percentage (0.00%)

---

### Section 3: Tables and Pivots

**⚠️ CRITICAL:** All tables/pivots use `tupr_dashboard_final_dataset` view

#### Table 1: Overall Monthly Summary

**Configuration:**
- View: `tupr_dashboard_final_dataset`
- Visualization: Table
- Dimensions: `offer_month`
- Measures: All 6 (total_customers, total_limit, customers_disbursed, total_limit_disbursed, take_up_rate_pct_by_customer, take_up_rate_pct_by_limit)
- Sort: `offer_month` DESC
- Width: Full width

**Column Order:**
1. Offer Month
2. Total Customers
3. Total Limit
4. Customers Disbursed
5. Total Limit Disbursed
6. TUPR (by Customer %)
7. TUPR (by Limit %)

---

#### Pivot 1: TUPR by Risk Grade (Horizontal)

**Configuration:**
- View: `tupr_dashboard_final_dataset`
- Visualization: Pivot Table
- Rows: `offer_month`
- Columns: `risk_bracket`
- Values: `take_up_rate_pct_by_customer`
- Sort: Use `risk_bracket_sorted` field
- Width: Full width

**Expected Column Order:**
- Rows: 2025-10, 2025-09, 2025-08...
- Columns: L, LM, M, MH, H, NO_BUREAU

---

#### Pivot 2: TUPR by Product (Horizontal)

**Configuration:**
- View: `tupr_dashboard_final_dataset`
- Visualization: Pivot Table
- Rows: `offer_month`
- Columns: `product_code`
- Values: `take_up_rate_pct_by_customer`
- Sort: Use `product_code_sorted` field
- Width: Full width

**Expected Column Order:**
- Rows: 2025-10, 2025-09, 2025-08...
- Columns: JAG08, JAG06, JAG09

---

#### Pivot 3: TUPR by Limit Tier (Horizontal)

**Configuration:**
- View: `tupr_dashboard_final_dataset`
- Visualization: Pivot Table
- Rows: `offer_month`
- Columns: `limit_tier`
- Values: `take_up_rate_pct_by_customer`
- Sort: Use `limit_tier_sorted` field
- Width: Full width

**Expected Column Order:**
- Rows: 2025-10, 2025-09, 2025-08...
- Columns: <5M, 5-10M, 10-20M, >20M

---

## 🔍 Step 4: Validation

### Test 1: Filter October Only

**Steps:**
1. Apply dashboard filter: `Offer Month = 2025-10`
2. Check KPI boxes
3. Check Overall Monthly table (should have 1 row)
4. Compare numbers

**Expected Result:**
- KPI boxes and table show SAME numbers
- Example: Both show ~50K-100K customers
- No inflation (no 6,352 vs 531,404 issue)

### Test 2: Check TUPR Values

**Expected Ranges:**
- TUPR by Customer: 3-5%
- TUPR by Limit: 2-4%
- All months should be in similar range

**Red Flags:**
- TUPR > 10% (too high, check queries)
- TUPR < 1% (too low, check filters)
- TUPR = 88% (wrong, old queries still in use)

### Test 3: Check Product Distribution

**Expected:**
- All three products appear: JAG08, JAG06, JAG09
- Product pivot shows all three columns

**Red Flag:**
- Only JAG01 appears → temp tables not recreated

### Test 4: Check Pivot Orientation

**Expected:**
- All pivots are HORIZONTAL
- Months as rows (vertical)
- Dimensions as columns (horizontal)

**Example:**
```
Offer Month | L    | LM   | M    | MH   | H    | NO_BUREAU
2025-10     | 4.2% | 3.8% | 3.5% | 2.9% | 2.1% | 5.1%
2025-09     | 4.1% | 3.7% | 3.4% | 2.8% | 2.0% | 5.0%
```

---

## ⚠️ Troubleshooting

### Issue 1: KPI boxes show different numbers than table

**Symptom:** KPI = 6,352, Table = 50,000
**Cause:** KPI boxes using wrong view
**Fix:** Edit each KPI box → Change view to `tupr_dashboard_monthly_summary`

---

### Issue 2: TUPR still showing 88%

**Symptom:** October TUPR = 88%
**Cause:** Old temp tables not recreated
**Fix:**
1. Go to BigQuery
2. Re-run all 4 queries in sequence
3. Wait for completion
4. Refresh dashboard

---

### Issue 3: Only JAG01 product appears

**Symptom:** Product pivot only shows JAG01
**Cause:** Query 3 has old data
**Fix:**
1. Re-run Query 1 (base snapshot)
2. Re-run Query 2 (demographics)
3. Re-run Query 3 (dimensional)
4. Refresh dashboard

---

### Issue 4: Pivots are vertical not horizontal

**Symptom:** Risk grades as rows, months as columns
**Fix:**
1. Edit pivot visualization
2. Switch rows/columns settings
3. Rows = offer_month
4. Columns = dimension (risk_bracket, product_code, limit_tier)

---

## 📊 Expected Dashboard Numbers (October 2025)

| Metric | Expected Range | Notes |
|--------|----------------|-------|
| **Total Customers** | 50K - 100K | Reduced from 772K (carry-overs excluded) |
| **Customers Disbursed** | 2K - 5K | ~3-5% conversion |
| **Total Limit** | 500B - 1T IDR | Varies by product mix |
| **Total Limit Disbursed** | 20B - 50B IDR | Lower than customer-based TUPR |
| **TUPR (by Customer)** | 3% - 5% | Main metric to track |
| **TUPR (by Limit)** | 2% - 4% | Usually lower than customer-based |

---

## 📝 Final Checklist

Before presenting to mentor:

- [ ] All 4 queries executed successfully
- [ ] Both LookML views updated and committed
- [ ] Latest Offer Date text box added
- [ ] 6 KPI boxes configured (using monthly summary view)
- [ ] KPI boxes arranged in 3 rows (2 boxes per row)
- [ ] Overall Monthly table added
- [ ] Risk Grade pivot added (horizontal)
- [ ] Product pivot added (horizontal)
- [ ] Limit Tier pivot added (horizontal)
- [ ] Tested with October filter (KPI matches table)
- [ ] TUPR in expected range (3-5%)
- [ ] All products appear (JAG08, JAG06, JAG09)
- [ ] Dashboard saved

---

## 🎯 Summary

**What Changed:**
- Switched from ALL OFFERS to NEW OFFERS only
- Excluded carry-over offers using LAG window function
- Created separate monthly summary table for KPI boxes
- Restructured dashboard with proper layout

**Business Impact:**
- More accurate measurement of fresh offer conversion
- TUPR now shows realistic 3-5% range
- Prevents double-counting of persistent offers
- Cleaner dimensional analysis

**Next Steps:**
1. Execute all 4 queries
2. Update LookML views
3. Restructure dashboard
4. Validate results
5. Present to mentor

---

**Document Version:** 2.0
**Last Updated:** 2025-11-05
**Status:** ✅ Ready for Implementation
