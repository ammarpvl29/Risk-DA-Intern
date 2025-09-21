# 🧬 Propensity Model - Base Table Generation

**Analysis Date**: September 21, 2025
**Analyst**: Risk DA Intern
**Status**: 🟡 **IN PROGRESS**

---

## 🎯 **1. Objective**

This document outlines the methodology for building the foundational base table for the **Propensity Loan Take Up 2025** machine learning model. The goal is to create a clean, reliable, customer-level dataset containing the **target variable** (the "label") and the **predictor variables** (the "features").

This initial version of the query successfully generates the target label (`flag_takeup`) and enriches it with the first set of features: point-in-time customer demographics.

---

## 📊 **2. Base Table Structure**

The query produces a table where each row represents a unique customer who received a loan offer in a given month (e.g., August 2025). The key columns are:

| Column | Description |
| :--- | :--- |
| `id_number` | The unique customer identifier, used to join all data sources. |
| `flag_takeup` | **(Target Label)** `1` if the customer opened a facility within the offer period, `0` otherwise. |
| `age` | Customer's age (masked as 0). |
| `gender` | Customer's gender (`MALE` / `FEMALE`). |
| `occupation` | Customer's stated occupation (e.g., 'Private Sector Employee'). |
| `industry` | The industry the customer works in. |
| `monthly_income_category` | Customer's self-reported monthly income bracket. |
| `education` | Customer's highest level of education. |

---

## ⚙️ **3. Query Methodology**

The base table is constructed using a series of Common Table Expressions (CTEs) that logically build the final dataset. The process for the August 2025 offers is as follows:

1.  **`latest_offers`**: Identifies the single latest, valid loan offer for each customer within August 2025 from `loan_offer_daily_snapshot`.

2.  **`latest_offers_customer`**: Filters the customer base to the `LFS` cohort who received these offers and secures their unique `id_number`.

3.  **`facilities_customer`**: Scans the `master_loan_facility_report` to find the latest `FJDL` facility for each `LP` customer.

4.  **`labels`**: Performs the crucial `LEFT JOIN` between the offer cohort and the facility cohort on `id_number`. It then generates the final `flag_takeup` by checking if the `facility_start_date` falls within the offer's validity window.

5.  **`customer_features`**: **(Point-in-Time Features)** This CTE selects the demographic features for the offer cohort from the `customer` table. Crucially, it uses the snapshot from `business_date = '2025-07-31'` to ensure the features reflect the state of the customer *before* the August offers were made.

6.  **Final `SELECT`**: An `INNER JOIN` combines the `labels` and `customer_features` CTEs on `id_number` to produce the final, enriched base table.

---

## 🔑 **4. Key Concepts Implemented**

This query successfully implements several critical concepts required for building a valid machine learning model:

-   **Target Definition**: The `flag_takeup` logic accurately translates the business goal into a binary outcome for the model to predict.
-   **Point-in-Time Correctness**: By using the previous month's data for features, we prevent data leakage and ensure the model only learns from information that was available at the time of the offer.
-   **Cross-System Linking**: The query correctly uses `id_number` as the master key to connect customer activity across the LFS (offer) and LP (facility) systems.

---

## 🚀 **5. Next Steps**

This base table is the foundation of the model. The next steps will involve enriching this table by joining it with additional feature sources, as outlined in the RFC, including:

-   Funding Balance Features
-   Transaction Behavior Features

---

## 🏷️ **Tags**

`#propensity-model` `#machine-learning` `#feature-engineering` `#sql` `#risk-analytics` `#base-table`
