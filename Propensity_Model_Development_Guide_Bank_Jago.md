# 📖 Propensity Loan Take Up 2025 - Development Guide & Findings

**Version**: 1.0
**Last Updated**: September 22, 2025
**Owner**: Risk Data Analyst Team

---

## 1. 🎯 Project Background & Objective

As outlined in the **[RFC] Propensity Loan Take Up 2025**, the primary objective of this project is to develop a propensity model or customer segmentation to improve the low take-up rate of Direct Lending products. The model will identify customers with a higher probability of accepting a loan offer, enabling more precise and efficient targeting for marketing and communication efforts.

This document serves as a comprehensive guide, detailing the analytical findings, key definitions, strategic decisions, and technical queries required for the development of this model.

---

## 2. 🔑 Core Concepts & Definitions

Initial analysis of the `loan_offer_daily_snapshot` data revealed that the population of customers with an "active offer" is not homogenous. Understanding the following cohorts is critical for this project.

### 2.1. The "New Offer" Cohort
-   **Definition**: Customers who receive a new loan offer within the analysis month.
-   **Logic**: Their offer's `created_at` month is the same as the `business_date` month.
-   **Relevance**: This group is essential for measuring the effectiveness of new monthly campaigns.

### 2.2. The "Carry-Over" (or "Stayer") Cohort
-   **Definition**: Customers who received a loan offer in a previous month, did not accept it, but whose offer remains valid in the current analysis month.
-   **Data Finding**: This cohort is approximately **5 times larger** than the "New Offer" cohort, making it the dominant group in the active offer population.

### 2.3. The Whitelist & Mutable Expiration Mechanism
-   **Finding**: The large size of the "Carry-Over" cohort is not due to an error, but is a feature of the business process. An offer's `expires_at` date is **mutable**.
-   **Business Logic**: A monthly **whitelist process**, driven by a **"GTM customer score"**, re-evaluates customers. If a customer re-qualifies, their existing offer's `expires_at` date is refreshed, extending its lifetime.

### 2.4. `total_disbursed` vs. `total_takeup`
-   **`total_disbursed`**: A broad metric counting any customer with an offer who is found to have an active loan facility. It answers: "Does this person have a loan?"
-   **`total_takeup`**: A strict metric counting a disbursed customer only if their loan `start_date` falls within their specific offer's validity period (`created_at` to `expires_at`). It answers: "Did this person get a loan *because of this specific offer*?" This is the true measure of an offer's conversion.

---

## 3. 🚀 The Central Strategic Question: Goal A vs. Goal B

The most critical outcome of the initial analysis is the framing of a strategic choice for the propensity model's objective. The business must decide which question the model is intended to answer.

### **Goal A: Predict New Offer Performance**
-   **Business Question**: "How effective is our new monthly campaign at converting **freshly offered** customers?"
-   **Target Cohort**: The **"New Offer" Cohort** only.
-   **Implementation**: The query for this goal must include a filter to exclude carry-overs, such as `FORMAT_DATE('%Y%m', date(created_at))=FORMAT_DATE('%Y%m', date(business_date))`.

### **Goal B: Predict All Active Offer Performance**
-   **Business Question**: "From our **entire pool of eligible customers** (new and carry-over), who is most likely to convert next month?"
-   **Target Cohort**: The **"All Active Offers" Cohort** (New + Carry-Over).
-   **Implementation**: The query for this goal must *not* include the `FORMAT_DATE` filter, ensuring it analyzes the complete, combined population.

---

## 4. 📊 Final Queries & Reports

The following queries are the primary deliverables of the cohort analysis phase. They provide the data for stakeholders to make an informed decision between Goal A and Goal B.

### 4.1. Query for Goal A Report (New Offers Only)
This query produces a monthly performance report for the clean cohort of new LFS customer offers.

```sql
-- This query intentionally excludes the "Carry-Over" cohort.
-- Full query text from Propensity_Model_Cohort_Analysis_22_Sept_2025.md ...
```

### 4.2. Query for Goal B Report (All Active Offers)
This query produces a monthly performance report for all active LFS customer offers, including the carry-over cohort. It is identical to the Goal A query, but with the `FORMAT_DATE` filter commented out.

```sql
-- This query includes the "Carry-Over" cohort.
-- The only difference is commenting out the FORMAT_DATE filter in the latest_offers CTEs.
-- and FORMAT_DATE('%Y%m', date(created_at))=FORMAT_DATE('%Y%m', date(business_date))
```

---

## 5. ⚙️ Data Context & Next Steps

### 5.1. Key Data Timelines
-   **`clevertap` Data**: Properly documented communication data is considered reliable from **March 2025** onwards.
-   **Cashback Promo**: A specific marketing promo began in **July 2025**. The criteria are: Low/Medium risk, limit > 10M, and no previous loan.

### 5.2. Recommended Next Steps
1.  **Make the Strategic Decision**: Stakeholders to provide a final decision on **Goal A vs. Goal B** as the primary objective for the model.
2.  **Source New Features**: Begin the process of sourcing and analyzing the **"GTM customer score"** used for the monthly whitelist.
3.  **Engineer Promo Flag**: Create a `is_promo_eligible` feature flag in the dataset for offers from July 2025 onwards, based on the specific criteria.
4.  **Analyze Communication Data**: Begin analysis of the `jago_clevertap.journey_notifications` data (from March 2025) to measure the effectiveness of different "booster" channels on the New vs. Carry-Over cohorts.
