# 📊 Loan Offer Take-Up Rate Analysis

**Analysis Date**: September 17, 2025
**Business Date**: August 31, 2025
**Analyst**: Risk DA Intern
**Status**: ✅ **ANALYSIS COMPLETE**

---

## 🎯 **Executive Summary**

This analysis was conducted to determine the take-up rate of loan offers for customers who opened a new `FJDL` facility in August 2025. After resolving a significant data duplication issue by implementing a robust one-to-one matching logic, the analysis found a strong **take-up rate of approximately 78.3%**.

Out of 1,878 customers who had both a recent offer and a new facility, **1,471 customers** opened their facility within the validity period of their latest offer. This indicates a highly effective conversion from offer to facility for this cohort.

### **Key Findings**:
- **High Conversion Rate**: ~78.3% of customers with a recent offer and new facility opened the facility within the offer period.
- **Successful Deduplication**: A many-to-many join issue was resolved by implementing a `ROW_NUMBER()` strategy to match the latest offer to the latest facility for each customer.
- **Validated Logic**: A sample review of successful take-up cases confirmed the query logic is sound.

---

## 📊 **Final Analysis Results**

### **Overall Take-Up Counts**

The final query produced the following distribution for the `flag_takeup`:

| `flag_takeup` | `total_customers` |
|---------------|-------------------|
| **Y**         | **1,471**         |
| N             | 407               |

### **Calculated Take-Up Rate**

- **Total Customers Analyzed**: 1,471 + 407 = 1,878
- **Calculation**: `(1471 / 1878) * 100`
- **Take-Up Rate**: **~78.3%**

### **Sample of Successful Conversions (`flag_takeup = 'Y'`)**

A review of the positive cases confirms the logic is correct. The `start_date` of the facility consistently falls between the `created_at` and `expires_at` dates of the offer.

```
customer_id_lfsid_numbercreated_atexpires_atstart_dateflag_takeupflag_disburse
K10HT6PDY814080118040200012025-08-05 13:23:32.765000 UTC2025-09-05 23:59:59.000000 UTC2025-08-13Y1
204604546231750724040310022025-08-04 10:24:09.431000 UTC2025-09-05 23:59:59.000000 UTC2025-08-15Y1
3M00VU21M132052001099600032025-08-04 10:17:58.866000 UTC2025-09-05 23:59:59.000000 UTC2025-08-27Y1
X00B2M4XCY32071056089300022025-08-05 10:51:08.628000 UTC2025-09-05 23:59:59.000000 UTC2025-08-13Y1
010889064032131409020200142025-08-04 10:30:14.363000 UTC2025-09-05 23:59:59.000000 UTC2025-08-18Y1
```

---

## ⚙️ **Final Query Logic**

The key to this analysis was resolving a many-to-many join. The final, successful query enforced a **one-to-one join** by ensuring each of the two main CTEs provided only one record per customer.

**1. `snapshot_offer` Deduplication:**
This CTE was modified to select only the most recent offer for each customer within the analysis month.
```sql
-- Selects only the most recent offer per customer in the month
snapshot_offer AS (
    SELECT ...
    ROW_NUMBER() OVER(PARTITION BY c.id_number ORDER BY s.created_at DESC) as rank1
    FROM `data-prd-adhoc.credit_risk_adhoc.intern_loan_offer_daily_snapshot` s
    ...
    QUALIFY rank1 = 1
),
```

**2. `combined_data` Deduplication:**
This CTE was modified to select only the most recent facility for each customer.
```sql
-- Selects only the most recent facility per customer
combined_data AS (
    SELECT ...
    ROW_NUMBER() OVER(PARTITION BY cd.id_number ORDER BY lf.start_date DESC) as rank1
    FROM customer_data cd
    INNER JOIN loan_facilities lf ON cd.id_number = lf.id_number
    QUALIFY rank1 = 1
),
```

---

## 💡 **Business Insights & Recommendations**

### **Insights**
- The loan offer strategy for the `FJDL` facility type appears to be **highly effective**, with over 3 in 4 customers who open a facility doing so within the timeframe of their latest offer.
- The data infrastructure correctly captures the customer journey from offer to facility, but requires careful querying to avoid incorrect analysis due to the one-to-many relationships in the underlying data.

### **Recommendations**
1.  **Present Findings**: Share the ~78.3% take-up rate with your mentor and relevant stakeholders as a key indicator of successful offer conversion.
2.  **Analyze the 'N' Cohort**: Propose a follow-up analysis on the 407 customers who did not convert. Understanding their behavior could reveal opportunities to further improve the offering or customer journey.
3.  **Standardize This Query**: This deduplicated query structure should be saved and used as a standard template for any future analysis involving offer-to-facility conversion to ensure accurate results.

---

## 🏷️ **Tags**

`#loan-analysis` `#take-up-rate` `#sql-debugging` `#deduplication` `#many-to-many` `#data-quality` `#risk-analytics` `#conversion-rate`

---

*Last Updated: September 17, 2025*
*Classification: Internal Analysis, Final Results*
