# 🧬 Propensity Model - Data Generation Technical Guide

**Author**: Ammar Siregar, Risk Data Analyst Intern
**Status**: ✅ **Baseline - V1.0**
**Date**: September 21, 2025

---

## 1. Objective

This document provides a complete technical specification for the SQL-based ETL process used to generate the training and prediction datasets for the **Loan Take-Up Propensity Model**. Its purpose is to ensure that both Data Analysts and Data Scientists have a clear understanding of the data lineage, feature engineering logic, and business rules embedded in the final dataset.

This process produces a customer-level table for a given offer month, containing the target variable (`flag_takeup`) and a rich set of point-in-time predictor features.

---

## 2. Final Table Schema

The query outputs a flat table where each row represents a unique customer who received a loan offer. The schema is as follows:

### Target Variable
| Column | Data Type | Description | Source |
| :--- | :--- | :--- | :--- |
| `flag_takeup` | `INT64` | The ground truth label. `1` if the customer opened an `FJDL` facility within the offer validity period, `0` otherwise. | Calculated |

### Predictor Features

**Demographics**
| Column | Data Type | Description | Source |
| :--- | :--- | :--- | :--- |
| `age_group` | `STRING` | Customer's age bracket. *(Note: Currently masked in source data).* | `customer` |
| `gender` | `STRING` | Customer's gender (`MALE` / `FEMALE`). | `customer` |
| `occupation`| `STRING` | Customer's self-reported occupation. | `customer` |

**Balance Features (Point-in-Time)**
| Column | Data Type | Description | Source |
| :--- | :--- | :--- | :--- |
| `fundingbalance_active_mainsaving_avg_3months` | `FLOAT64` | Average daily balance in the main savings account over the 3 months prior to the offer. | `funding_balance_features` |
| `fundingbalance_active_mainsaving_stdev_3months`| `FLOAT64` | Standard deviation of the daily balance over the prior 3 months, indicating stability. | `funding_balance_features` |
| `adb_ratio_1m_3m` | `FLOAT64` | Ratio of the 1-month average daily balance to the 3-month average. A value > 1 indicates a recent increase in funds. | `funding_balance_features` |

**Transaction Features (Point-in-Time)**
| Column | Data Type | Description | Source |
| :--- | :--- | :--- | :--- |
| `dailytransaction_bill_count_3months` | `INT64` | Total count of successful bill payment transactions over the 3 months prior to the offer. | `successful_transaction_features` |
| `trx_amt_ratio_1m_3m` | `FLOAT64` | Ratio of the total transaction amount in the last 1 month to the average of the last 3 months. | `successful_transaction_features` |
| `daysgaplatesttransaction_count_bill_3months` | `INT64` | Number of days since the last successful bill payment transaction within the prior 3 months. | `successful_transaction_features` |

---

## 3. Data Source Deep Dive

The final table is a composition of five key production tables in BigQuery.

| Table | Role & Key Columns Used |
| :--- | :--- |
| `dwh_core.loan_offer_daily_snapshot` | **(Offers)** Source of all loan offers. Used for `customer_id`, `created_at`, `expires_at`. |
| `one_reporting_views.master_loan_facility_report` | **(Facilities)** Source of all disbursed loans. Used for `cif` (customer ID), `start_date`, `facility_type`. |
| `data_mart.customer` | **(Demographics & Linking)** Provides customer demographics and the crucial `id_number` to link offers to facilities. |
| `model_features.funding_balance_features` | **(Balance Behaviors)** Pre-aggregated feature store for customer balance metrics. Joined on `customer_id`. |
| `model_features.successful_transaction_features`| **(Transaction Behaviors)** Pre-aggregated feature store for customer transaction metrics. Joined on `customer_id`. |

---

## 4. ETL Query Logic & Methodology

The following query is the complete ETL for generating the model's base table. 

```sql
-- Propensity Model Base Table ETL V1.0
-- This query generates a training set for a given offer month.
-- To change the offer month, update the two date parameters in the WHERE clauses.

WITH
latest_offers AS (
  -- Step 1: Isolate the latest valid offer for each customer in the target month (e.g., August).
  SELECT
    customer_id,
    date(expires_at) as expires_at,
    date(created_at) as created_at
  FROM
    `jago-bank-data-production.dwh_core.loan_offer_daily_snapshot`
  WHERE
    business_date = '2025-08-31' -- Param 1: Offer Month
    AND (agreement_agreed_at >= created_at OR agreement_agreed_at IS NULL)
    AND FORMAT_DATE('%Y%m', date(created_at)) = FORMAT_DATE('%Y%m', date(business_date))
  QUALIFY DENSE_RANK() OVER (PARTITION BY customer_id ORDER BY expires_at DESC, created_at DESC) = 1
),
latest_offers_customer AS (
  -- Step 2: Get the master customer identifier (id_number) for the offer cohort.
  SELECT
    c.id_number,
    lo.customer_id,
    lo.created_at,
    lo.expires_at
  FROM
    `jago-bank-data-production.data_mart.customer` c
  INNER JOIN
    latest_offers lo ON c.customer_id = lo.customer_id AND c.business_date = '2025-08-31' -- Param 1: Offer Month
  WHERE
    c.business_date = '2025-08-31' -- Param 1: Offer Month
    AND c.customer_source = 'LFS'
),
facilities_customer AS (
  -- Step 3: Find the latest relevant loan facility for each customer.
  SELECT
    c.id_number,
    mlf.start_date
  FROM
    `jago-bank-data-production.data_mart.customer` c
  INNER JOIN
    `jago-bank-data-production.one_reporting_views.master_loan_facility_report` mlf ON mlf.cif = c.customer_id AND mlf.business_date = c.business_date
  WHERE
    c.business_date = '2025-08-31' -- Param 1: Offer Month
    AND c.customer_source = 'LP'
    AND mlf.facility_type LIKE '%FJDL%'
  QUALIFY DENSE_RANK() OVER(PARTITION BY c.id_number ORDER BY mlf.start_date DESC) = 1
),
labels AS (
  -- Step 4: Generate the ground truth label by comparing the offer and facility dates.
  SELECT
    x.id_number,
    x.customer_id,
    x.created_at,
    x.expires_at,
    CASE
      WHEN y.start_date >= x.created_at AND y.start_date <= x.expires_at THEN 1
      ELSE 0
    END AS flag_takeup
  FROM
    latest_offers_customer x
  LEFT JOIN
    facilities_customer y ON x.id_number = y.id_number
),
customer_features AS (
  -- Step 5: Select point-in-time demographic features from the PRIOR month.
  SELECT
    id_number,
    customer_id,
    age_group,
    gender,
    occupation
  FROM
    `jago-bank-data-production.data_mart.customer`
  WHERE
    business_date = '2025-07-31' -- Param 2: Feature Month (Offer Month - 1)
),
balance_features AS (
  -- Step 6: Select a subset of point-in-time balance features.
  SELECT
    customer_id,
    fundingbalance_active_mainsaving_avg_3months,
    fundingbalance_active_mainsaving_stdev_3months,
    fundingbalance_active_avg_1month_over_fundingbalance_active_avg_3months AS adb_ratio_1m_3m
  FROM
    `jago-bank-data-production.model_features.funding_balance_features`
  WHERE
    business_month = '2025-07-31' -- Param 2: Feature Month (Offer Month - 1)
),
transaction_features AS (
  -- Step 7: Select a subset of point-in-time transaction features.
  SELECT
    customer_id,
    dailytransaction_bill_count_3months,
    transactionamt_bill_sum_1month_over_transactionamt_bill_avg_3months AS trx_amt_ratio_1m_3m,
    daysgaplatesttransaction_count_bill_3months
  FROM
    `jago-bank-data-production.model_features.successful_transaction_features`
  WHERE
    business_month = '2025-07-31' -- Param 2: Feature Month (Offer Month - 1)
)
-- Final Step: Join the labels with all features to create the final table.
SELECT
  l.flag_takeup,
  -- Demographics
  cf.age_group,
  cf.gender,
  cf.occupation,
  -- Balances
  bf.fundingbalance_active_mainsaving_avg_3months,
  bf.fundingbalance_active_mainsaving_stdev_3months,
  bf.adb_ratio_1m_3m,
  -- Transactions
  tf.dailytransaction_bill_count_3months,
  tf.trx_amt_ratio_1m_3m,
  tf.daysgaplatesttransaction_count_bill_3months
FROM
  labels l
INNER JOIN
  customer_features cf ON l.id_number = cf.id_number
LEFT JOIN
  balance_features bf ON l.customer_id = bf.customer_id
LEFT JOIN
  transaction_features tf ON l.customer_id = tf.customer_id;
```

---

## 5. Key Principles & Business Rules

-   **Target Definition**: The `flag_takeup` is strictly defined as a new facility (`FJDL`) being opened *after* the offer was created and *before* it expired. This correctly attributes the new facility to the offer.
-   **Point-in-Time (PIT) Correctness**: This is the most critical principle for avoiding data leakage. All predictor features are taken from a snapshot of the month *prior* to the offer month. This simulates the information that would have been available at the time of prediction.
-   **Handling of Nulls**: The query uses `LEFT JOIN` for behavioral feature tables (`balance_features`, `transaction_features`). If a customer has no record in these tables (e.g., they are new or inactive), their feature values will be `NULL`. This is the desired behavior, as the absence of activity is itself a feature the model can learn from.
-   **Masked Data**: The `age` and `age_group` columns are masked in the source and will be excluded from the final model feature list.

---

## 6. How to Use

To generate a dataset for a different offer period, two date parameters in the query must be updated:

1.  **Offer Month (`Param 1`)**: In the `WHERE` clauses of the `latest_offers`, `latest_offers_customer`, and `facilities_customer` CTEs, update the `business_date` to the end-of-month date for the desired offer period (e.g., `'2025-09-30'` for September offers).
2.  **Feature Month (`Param 2`)**: In the `WHERE` clauses of the `customer_features`, `balance_features`, and `transaction_features` CTEs, update the date to the end of the month *prior* to the new offer month (e.g., `'2025-08-31'` for September offers).

---

## 🏷️ **Tags**

`#propensity-model` `#machine-learning` `#feature-engineering` `#etl` `#sql` `#technical-guide` `#risk-analytics`
