# 📊 Loan Offer Validation & Final Summary

**Analysis Date**: September 18, 2025
**Analyst**: Risk DA Intern
**Status**: ✅ **COMPLETED**

---

## 🎯 **Executive Summary**

This analysis was conducted to perform deep validation on the loan offer-to-disbursement process and to generate a final, accurate summary funnel. The investigation revealed several important data quality insights and resulted in a corrected, robust final query.

The final analysis shows that out of **28,917** customers who agreed to an offer, **27,490 (~95.1%)** were disbursed a loan, and of those, **27,480 (~99.9%)** took up the loan within the valid offer period.

### **Key Validation Findings**:
-   **Offer, No Disbursement**: Identified **1,427** customers who agreed to an offer but did not have a matching `FJDL` loan facility on the analysis date.
-   **Data Attribution Issue**: Found **6** customers with a data quality issue where their loan `start_date` was in a month prior to their offer `created_at` date.

### **Key Logic Improvements**:
-   **Same-Day Take-up**: The take-up logic was corrected from `>` to `>=` to properly include customers who convert on the same day an offer is made.
-   **Deduplication for Aggregation**: A one-to-many join bug was fixed by applying a `DENSE_RANK()` window function to the loan facilities data before aggregation, ensuring accurate final counts.

---

## 🔬 **Task 1: Data Validation & Anomaly Detection**

The primary goal was to find and quantify exceptions in the data flow.

### **Finding 1: "Offer Agree, No Disburse"**
-   **Insight**: **1,427** customers agreed to an offer but have no corresponding `FJDL` loan facility record for the `2025-08-31` business date.
-   **Business Impact**: This represents potential drop-off in the funnel between offer agreement and disbursement.
-   **Query to List Customers**:
    ```sql
    -- This query lists the 1,427 customers
    WITH latest_offers AS (
        SELECT customer_id, created_at, expires_at
        FROM `data-prd-adhoc.credit_risk_adhoc.intern_loan_offer_current`
        WHERE agreement_agreed_at >= created_at
        QUALIFY DENSE_RANK() OVER (PARTITION BY customer_id ORDER BY expires_at DESC, created_at DESC) = 1
    ),
    customer_data AS (
      SELECT c.id_number, lo.created_at, lo.expires_at
      FROM `data-prd-adhoc.credit_risk_adhoc.intern_data_mart_customer` c
      INNER JOIN latest_offers lo ON c.customer_id = lo.customer_id
      WHERE c.business_date = '''2025-08-31''' AND c.customer_source = '''LFS'''
    ),
    loan_facilities AS (
        SELECT c.id_number
        FROM `data-prd-adhoc.credit_risk_adhoc.intern_data_mart_customer` c
        INNER JOIN `jago-bank-data-production.one_reporting_views.master_loan_facility_report` mlf ON mlf.cif = c.customer_id
        WHERE c.business_date = '''2025-08-31''' AND c.customer_source = '''LP''' AND mlf.business_date = '''2025-08-31''' AND mlf.facility_type LIKE '''%FJDL%'''
    )
    SELECT cd.*
    FROM customer_data cd
    LEFT JOIN loan_facilities lf ON cd.id_number = lf.id_number
    WHERE lf.id_number IS NULL;
    ```

### **Finding 2: "Disbursed in Previous Month"**
-   **Insight**: **6** customers were found where their loan `start_date` was in a month prior to their offer `created_at` date.
-   **Business Impact**: This highlights a data attribution quality issue, where existing loans may be incorrectly associated with new offers.
-   **Query to List Customers**:
    ```sql
    -- This query lists the 6 customers
    WITH latest_offers AS (
        SELECT customer_id, created_at, expires_at
        FROM `data-prd-adhoc.credit_risk_adhoc.intern_loan_offer_current`
        WHERE agreement_agreed_at >= created_at
        QUALIFY DENSE_RANK() OVER (PARTITION BY customer_id ORDER BY expires_at DESC, created_at DESC) = 1
    ),
    customer_data AS (
      SELECT c.id_number, lo.created_at, lo.expires_at
      FROM `data-prd-adhoc.credit_risk_adhoc.intern_data_mart_customer` c
      INNER JOIN latest_offers lo ON c.customer_id = lo.customer_id
      WHERE c.business_date = '''2025-08-31''' AND c.customer_source = '''LFS'''
    ),
    deduplicated_loan_facilities AS (
        SELECT c.id_number, mlf.start_date
        FROM `data-prd-adhoc.credit_risk_adhoc.intern_data_mart_customer` c
        INNER JOIN `jago-bank-data-production.one_reporting_views.master_loan_facility_report` mlf ON mlf.cif = c.customer_id
        WHERE c.business_date = '''2025-08-31''' AND c.customer_source = '''LP''' AND mlf.business_date = '''2025-08-31''' AND mlf.facility_type LIKE '''%FJDL%'''
        QUALIFY DENSE_RANK() OVER(PARTITION BY c.id_number ORDER BY mlf.start_date DESC) = 1
    )
    SELECT
        cd.id_number,
        cd.created_at AS offer_created_at,
        lf.start_date AS loan_start_date
    FROM customer_data cd
    INNER JOIN deduplicated_loan_facilities lf ON cd.id_number = lf.id_number
    WHERE DATE_TRUNC(lf.start_date, MONTH) < DATE_TRUNC(cd.created_at, MONTH);
    ```

---

## 📈 **Task 2: Final Summary Report**

After validating the data and correcting the logic, a final, accurate summary report was generated.

### **Final Funnel Metrics**:

| Metric | Count |
| :--- | :--- |
| Total Agreed Offers | **28,917** |
| Total Disbursed Loans | **27,490** |
| Total Successful Take-ups | **27,480** |

### **Derived Rates**:
-   **Disbursement Rate**: ~95.1% of customers who agreed to an offer received a loan.
-   **Take-up Rate**: ~99.9% of disbursed customers activated their loan within the valid offer period.

### **Final Summary Query**:
This standalone query produces the final, correct report.
```sql
WITH latest_offers AS (
    SELECT
        customer_id,
        expires_at,
        created_at
    FROM `data-prd-adhoc.credit_risk_adhoc.intern_loan_offer_current`
    WHERE agreement_agreed_at >= created_at
    QUALIFY DENSE_RANK() OVER (PARTITION BY customer_id ORDER BY expires_at DESC, created_at DESC) = 1
),
customer_data AS (
  SELECT
      c.id_number,
      lo.created_at,
      lo.expires_at
  FROM `data-prd-adhoc.credit_risk_adhoc.intern_data_mart_customer` c
  INNER JOIN latest_offers lo ON c.customer_id = lo.customer_id
  WHERE c.business_date = '''2025-08-31'''
    AND c.customer_source = '''LFS'''
),
deduplicated_loan_facilities AS (
    SELECT
        c.id_number,
        mlf.start_date
    FROM `data-prd-adhoc.credit_risk_adhoc.intern_data_mart_customer` c
    INNER JOIN `jago-bank-data-production.one_reporting_views.master_loan_facility_report` mlf
    ON mlf.cif = c.customer_id
    WHERE c.business_date = '''2025-08-31'''
      AND c.customer_source = '''LP'''
      AND mlf.business_date = '''2025-08-31'''
      AND mlf.facility_type LIKE '''%FJDL%'''
    QUALIFY DENSE_RANK() OVER(PARTITION BY c.id_number ORDER BY mlf.start_date DESC) = 1
),
summary_cte AS (
    SELECT
        1 AS flag_offer,
        CASE WHEN lf.id_number IS NOT NULL THEN 1 ELSE 0 END AS flag_disburse,
        CASE WHEN lf.start_date >= DATE(cd.created_at) AND lf.start_date <= DATE(cd.expires_at) THEN 1 ELSE 0 END AS flag_takeup
    FROM customer_data cd
    LEFT JOIN deduplicated_loan_facilities lf ON cd.id_number = lf.id_number
)
SELECT
    SUM(flag_offer) as total_offers,
    SUM(flag_disburse) as total_disbursed,
    SUM(flag_takeup) as total_takeup
FROM summary_cte;
```

---

## 🏷️ **Tags**

`#data-validation` `#data-quality` `#funnel-analysis` `#sql-logic` `#risk-analytics` `#loan-offers`
