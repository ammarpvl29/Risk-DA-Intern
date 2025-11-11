# Step 5: Update LookML Views with Propensity Dimensions

## File to Update: `tupr_final_dataset.view`

Add the following dimensions **after line 89** (after `limit_tier_sorted`):

```lookml
  # ============================================================================
  # Propensity Score Dimensions
  # ============================================================================

  dimension: propensity_score_bin {
    type: number
    sql: ${TABLE}.propensity_score_bin ;;
    description: "Propensity score decile (0-9, 9=highest propensity to take up loan)"
    order_by_field: propensity_score_bin_sorted
  }

  dimension: propensity_score_bin_sorted {
    hidden: yes
    type: string
    sql: ${TABLE}.propensity_score_bin_sorted ;;
  }

  dimension: propensity_tier {
    type: string
    sql: ${TABLE}.propensity_tier ;;
    description: "Grouped propensity tiers: Low (0-2), Medium (3-6), High (7-9), No Score"
    order_by_field: propensity_tier_sorted
  }

  dimension: propensity_tier_sorted {
    hidden: yes
    type: string
    sql: ${TABLE}.propensity_tier_sorted ;;
  }

  # Label-friendly propensity bin for visualization
  dimension: propensity_bin_label {
    type: string
    sql: CASE
           WHEN ${propensity_score_bin} = 0 THEN 'Bin 0 - Lowest'
           WHEN ${propensity_score_bin} = 1 THEN 'Bin 1'
           WHEN ${propensity_score_bin} = 2 THEN 'Bin 2'
           WHEN ${propensity_score_bin} = 3 THEN 'Bin 3'
           WHEN ${propensity_score_bin} = 4 THEN 'Bin 4'
           WHEN ${propensity_score_bin} = 5 THEN 'Bin 5'
           WHEN ${propensity_score_bin} = 6 THEN 'Bin 6'
           WHEN ${propensity_score_bin} = 7 THEN 'Bin 7'
           WHEN ${propensity_score_bin} = 8 THEN 'Bin 8'
           WHEN ${propensity_score_bin} = 9 THEN 'Bin 9 - Highest'
           ELSE 'No Score'
         END ;;
    description: "Propensity bin with descriptive labels"
    order_by_field: propensity_score_bin_sorted
  }

  # ============================================================================
  # Propensity-Specific Measures
  # ============================================================================

  measure: pct_high_propensity_customers {
    type: number
    sql: SAFE_DIVIDE(
      SUM(CASE WHEN ${propensity_score_bin} >= 7 THEN ${TABLE}.total_customers ELSE 0 END) * 100.0,
      NULLIF(SUM(${TABLE}.total_customers), 0)
    ) ;;
    value_format: "0.00\%"
    description: "% of customers in high propensity bins (7-9)"
  }

  measure: avg_propensity_bin {
    type: average
    sql: ${propensity_score_bin} ;;
    value_format_name: decimal_2
    description: "Average propensity score bin (0-9 scale)"
  }
```

---

## Update `detail` Set (Line 188-201)

**Replace the existing `detail` set** with this expanded version:

```lookml
  set: detail {
    fields: [
      offer_month,
      source,
      campaign_segment,
      product_code,
      risk_bracket,
      limit_tier,
      propensity_tier,              # NEW
      propensity_score_bin,          # NEW
      total_customers,
      total_limit_millions,
      customers_disbursed,
      total_limit_disbursed_millions,
      take_up_rate_pct_by_customer,
      take_up_rate_pct_by_limit
    ]
  }
```

---

## Testing the LookML Changes

After deploying the updated view, test in Looker Studio with these queries:

### Test 1: Propensity Distribution
```
Dimensions: offer_month, propensity_tier
Measures: total_customers, take_up_rate_pct_by_customer
Filters: offer_month >= 2025-09
```

**Expected Result:**
```
2025-09, High (7-9),    ???,  8-12%   ← Highest
2025-09, Medium (3-6),  ???,  2-4%
2025-09, Low (0-2),     ???,  0.5-1%  ← Lowest
2025-09, No Score,      ???,  ???%
```

---

### Test 2: Campaign × Propensity
```
Dimensions: campaign_segment, propensity_tier
Measures: total_customers, take_up_rate_pct_by_customer
Filters: offer_month >= 2025-09, source = 'new'
```

**Expected Pattern:**
- CT campaign may have higher % of High propensity customers
- BAU campaign more evenly distributed
- Open Market may skew toward Low/Medium

---

### Test 3: Propensity Bin Granularity
```
Dimensions: propensity_bin_label
Measures: total_customers, customers_disbursed, take_up_rate_pct_by_customer
Filters: offer_month = 2025-09, source = 'new'
Sort: propensity_score_bin ASC
```

**Expected Result:**
```
Bin 0 - Lowest,  ???,  ???,  0.15%
Bin 1,           ???,  ???,  0.47%
Bin 2,           ???,  ???,  0.49%
...
Bin 8,           ???,  ???,  4.92%
Bin 9 - Highest, ???,  ???,  10.79%
```

✅ **Monotonic increase validates model is working correctly**

---

## Visualization Recommendations

### 1. **Propensity vs TUPR Trend Line**
- **Type**: Line chart
- **X-axis**: propensity_score_bin (0-9)
- **Y-axis**: take_up_rate_pct_by_customer
- **Color**: source (new vs carry over)
- **Use Case**: Validate model performance

### 2. **Campaign Performance by Propensity Heatmap**
- **Type**: Pivot table / Heatmap
- **Rows**: campaign_segment
- **Columns**: propensity_tier
- **Values**: total_customers (size) + take_up_rate_pct_by_customer (color)
- **Use Case**: Identify which campaigns generate high-propensity customers

### 3. **Monthly Propensity Distribution**
- **Type**: Stacked bar chart
- **X-axis**: offer_month
- **Stacks**: propensity_tier (Low/Medium/High/No Score)
- **Y-axis**: total_customers
- **Use Case**: Monitor propensity distribution stability over time

### 4. **Risk × Propensity Matrix**
- **Type**: Pivot table
- **Rows**: risk_bracket
- **Columns**: propensity_tier
- **Values**: total_customers + take_up_rate_pct_by_customer
- **Use Case**: Ensure high-propensity customers aren't all high-risk

---

## Common Issues & Troubleshooting

### Issue 1: "No Score" Dominates Results

**Symptom**: >50% of customers show "No Score" in propensity_tier

**Causes**:
1. Propensity join in Query 2.5 not working
2. Date format mismatch between TUPR and propensity tables
3. Source mismatch ('new' vs 'carry over')

**Fix**: Run validation query from Step 3:
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

---

### Issue 2: Take-Up Rate Doesn't Increase with Propensity

**Symptom**: Bin 3 has higher TUPR than Bin 7

**Causes**:
1. Wrong model used (predicting default instead of take-up)
2. Propensity scores not properly joined
3. Data mismatch (training vs production population)

**Fix**: Contact Stephanie - model may need recalibration

---

### Issue 3: Propensity Dimensions Not Showing in Looker

**Symptom**: New dimensions don't appear in field picker

**Causes**:
1. LookML not deployed to production
2. Syntax error in LookML file
3. Table not refreshed after Query 3 execution

**Fix**:
1. Validate LookML syntax (no trailing commas, proper indentation)
2. Deploy to production branch
3. Re-run Query 3 to refresh underlying table
4. Clear Looker cache (Ctrl+Shift+K in Looker Studio)

---

## Deployment Checklist

Before rolling out to stakeholders:

- [ ] Query 1 executed: Unified propensity table created
- [ ] Query 2 validated: Sept/Oct counts match (460k + 125k / 95k + 499k)
- [ ] Query 3 executed: base_loan_offer_with_campaign updated
- [ ] Query 4 executed: tupr_dashboard_final_dataset updated
- [ ] LookML updated: Propensity dimensions added to view
- [ ] LookML deployed: Changes pushed to production
- [ ] Test 1 passed: Propensity tier shows Low < Medium < High TUPR
- [ ] Test 2 passed: Campaign × Propensity matrix renders correctly
- [ ] Test 3 passed: Bin 0-9 shows monotonic TUPR increase
- [ ] Coverage validated: >80% of customers have propensity scores
- [ ] Dashboard documented: User guide created for stakeholders

---

## Next Steps After Deployment

1. **Monitor Propensity Stability**
   - Track propensity distribution monthly (should remain ~10% per bin)
   - Alert if Bin 9 TUPR drops below 8% for 2 consecutive months

2. **Business Enablement**
   - Train business users on propensity filtering
   - Create pre-built dashboards for common use cases
   - Set up automated alerts for propensity anomalies

3. **Model Iteration Planning**
   - Schedule quarterly review with Stephanie
   - Track model drift metrics (AUC, KS over time)
   - Plan for model refresh if performance degrades

---

**Document Owner**: Ammar Siregar
**Last Updated**: 2025-11-10
**Status**: Ready for Deployment
