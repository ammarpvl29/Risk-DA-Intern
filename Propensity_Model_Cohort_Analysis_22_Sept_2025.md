# 📊 Propensity Model Cohort Analysis & Definition

**Analysis Date**: September 22, 2025
**Analyst**: Risk DA Intern
**Status**: ✅ **Analysis Complete, Final Decision Pending**

---

## 🎯 **Executive Summary**

This document details the end-to-end analysis performed to clarify and define the target customer cohort for the **Propensity Loan Take Up 2025** project. The analysis progressed from a broad exploration to a deep investigation of data anomalies, and concluded with the establishment of clear business rules and two distinct strategic paths for the propensity model.

### **Key Findings & Outcome**:
-   **"Carry-Over" Cohort Discovery**: A large population of customers exists whose active loan offers were created in months prior. This "carry-over" group is **5 times larger** than the group of customers who receive new offers.
-   **Business Rules Uncovered**: The carry-over phenomenon is not an error, but a feature of a **monthly whitelist process**. Customers who re-qualify have their offer's `expires_at` date refreshed.
-   **Differentiated Treatment Confirmed**: The "New Offer" and "Carry-Over" cohorts receive different communication strategies (e.g., mass WhatsApp vs. selective WhatsApp), validating the need to analyze them separately.
-   **Strategic Choice Defined**: The analysis successfully framed the project's core decision: should the propensity model target **Goal A (New Offer Performance)** or **Goal B (All Active Offer Performance)**? The data and queries necessary to support this decision have been prepared.

---

## 🔬 **Phase 1: Exploratory Analysis & Problem Discovery**

The analysis began with a broad query to understand the entire population of customers with an active offer. This yielded the foundational insight for the entire analysis: the discovery of the massive "carry-over" cohort, which immediately highlighted a critical ambiguity in the project's definition.

| business_date | total_active_offers | new_offers | carry_over_offers |
| :--- | :--- | :--- | :--- |
| 2025-08-31 | **336,775** | 53,103 | **283,672** |


---

## 🔬 **Phase 2: Anomaly Investigation (Explaining the "Why")**

A deep dive was performed to understand the root cause of the large carry-over group.

-   **Finding 1: Long-Duration Offers**: The data contains offers with initial durations of **15 months or more**.
-   **Finding 2: Mutable Expiration Dates**: A data lineage check proved that an offer's `expires_at` date is actively updated over time.

**Initial Insight**: The carry-over cohort is a dynamic population whose offer lifetimes are actively managed and extended.

---

## ✅ **Phase 3: Business Logic Clarification (Meeting with Zaki Nurkholis)**

A meeting with fellow Data Analyst Zaki Nurkholis clarified the business logic behind the data behaviors discovered in the previous phases.

-   **The Whitelist Mechanism**: The mutable `expires_at` date is a feature of a monthly whitelist process. Customers who fail to qualify one month can re-qualify in a subsequent month, which refreshes their offer's expiration date. This process is driven by a **"GTM customer score"**.

-   **Differentiated Communication Strategy**: It was confirmed that "New Offer" and "Carry-Over" cohorts are treated differently. New offers receive a mass WhatsApp introduction, while carry-over customers receive more selective communications.

-   **Marketing & Data Timelines**:
    -   A specific **cashback promo** began in **July 2025** for Low/Medium risk customers with limits > 10M who have not taken a loan before.
    -   Properly documented communication data in `clevertap` is considered reliable from **March 2025** onwards.

---

## 📊 **Phase 4: Final Reports for Strategic Decision**

With the business logic clarified, the analysis concluded by producing two distinct, final reports that correspond to the two strategic goals for the propensity model.

### **The "Goal A" Report: New Offers Only**
This report answers: "What is the monthly performance of **new offers** for our LFS customers?" It is the correct choice if the business wants to measure the effectiveness of new monthly campaigns.

-   **Results (August 2025)**:
    | total_offers | new_offers | carry_over_offers | total_disbursed | total_takeup |
    | :--- | :--- | :--- | :--- | :--- | :--- |
    | **52,929** | 52,929 | **0** | 1,486 | 1,486 |


### **The "Goal B" Report: All Active Offers**
This report answers: "What is the monthly performance of **all active offers** (new and carry-over) for our LFS customers?" It is the correct choice if the business wants to understand the conversion potential of the entire eligible customer base.

-   **Results (August 2025)**:
    | total_offers | new_offers | carry_over_offers | total_disbursed | total_takeup |
    | :--- | :--- | :--- | :--- | :--- | :--- |
    | **303,607** | 52,929 | 250,678 | 8,786 | 8,786 |


---

## 🚀 **Next Steps & Recommendations**

1.  **Make the Strategic Decision**: Present the Goal A and Goal B reports to stakeholders to get a final decision on the primary objective for the propensity model.

2.  **Begin Focused Feature Engineering**: Based on the meeting findings, the following analytical steps can begin:
    *   Source and analyze the **"GTM customer score"** used for the monthly whitelist process.
    *   Engineer a `is_promo_eligible` flag for offers from **July 2025** onwards based on the specific risk and limit criteria.
    *   Begin analysis of the `clevertap` data, focusing on the period from **March 2025** for the most reliable data, and analyze the effectiveness of different channels on the New vs. Carry-Over cohorts.

---

## 🏷️ **Tags**

`#propensity-model` `#cohort-analysis` `#data-strategy` `#data-validation` `#loan-offers` `#business-rules`