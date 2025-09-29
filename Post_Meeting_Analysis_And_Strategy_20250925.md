# Post-Meeting Analysis & Refined Strategy

**Version**: 3.0
**Date**: 2025-09-25
**Author**: Ammar Siregar (via Gemini Assistant)
**Status**: Final

---

## 1. Objective

This document summarizes the refined analysis and new strategic directions for the propensity model feature engineering, based on the feedback session with Mr. Zaki. The goal is to pivot our analytical approach based on his expert business context and to provide a comprehensive summary of customer behavior across all communication channels.

---

## 2. Key Directives from Mr. Zaki

The meeting yielded several crucial directives that guided the analysis:

1.  **Simplify Interactions**: Ignore `View`/`Delivered` events and focus only on **`Sent`** and **`Click`**/**`Read`**.
2.  **Deprecate Time-Difference Features**: Discard `diff_notif` features as notification timing is dynamic and not a stable predictor.
3.  **Refine Email Channel Logic**: For emails, only analyze events where `event_date > created_at` to exclude pre-acquisition surveys.
4.  **Define WhatsApp Strategy**: Recognize WhatsApp as a primary channel for customers who do not have the Jago app installed, identifiable by a `NULL` or empty `token` in the `jago_clevertap.profiles` table.

---

## 3. Multi-Channel Behavioral Summary

Our analysis reveals two very different customer profiles, each with a unique marketing strategy tailored to their position in the customer lifecycle.

### **Profile of a "New Offer" Customer**

This customer is being actively courted for a new conversion. The strategy is an aggressive, multi-channel push to convert their initial interest into an activated loan.

*   **In-App (Push, Bell, Pop-up):**
    *   This is the **primary and most effective channel**. They receive a high volume of notifications focused on **activation and education** (e.g., `New_MaxLimitCicilan`).
    *   This is where they show the highest intent, with data showing they **`Click`** on In-App notifications.

*   **Email:**
    *   This channel is used for **"pre-acquisition" or warming up**. Emails are consistently sent **before** the offer is officially created.
    *   Engagement is low; they may `View` the email, but they **do not click**.

*   **WhatsApp:**
    *   This is a strong secondary channel. They are highly responsive, showing a full `Sent` -> `Read` funnel regardless of whether they have the app or not.

### **Profile of a "Carry-over Offer" Customer**

This customer has had an offer for a while but has not converted. The strategy is a more patient, value-focused effort to re-activate their dormant offer.

*   **In-App (Push, Bell, Pop-up):**
    *   This is a consistent re-engagement channel. Campaigns focus on **retargeting and value enhancement** with new incentives (e.g., `BetterOffer_Retargeting`, `RetargetingNeverDrawdown`).
    *   They also **`Click`** on these notifications, especially when a new incentive is presented.

*   **Email:**
    *   This is a key **long-term retargeting channel**. Emails are sent **long after** the initial offer was created.
    *   Engagement is surprisingly **high**. This is the segment most likely to **`Click`** an email, especially for `PromoCashback` or `BetterOffer` campaigns.

*   **WhatsApp:**
    *   This channel is also highly effective for re-engaging this segment. They consistently `Read` messages, especially for campaigns focused on a `limit_up` or `better_offer`.

---

## 4. Final Recommendations for Propensity Model Features

Based on this complete analysis, we can recommend a robust feature engineering strategy:

1.  **Primary Behavioral Features**: Create counts of `Sent` and `Click`/`Read` interactions for each distinct channel (Push, Bell, In-App, Email, WhatsApp).

2.  **Key Segmentation Flags**: The binary flags `is_new_offer` and `is_appless_customer` are critical features that define the context of customer behavior.

3.  **Interaction Features**: The analysis proves that the most powerful predictors will be **interaction features**. The model needs to learn from combinations of features. Examples include:
    *   `is_carry_over * count_email_clicks`: Captures the high engagement of carry-over customers on email.
    *   `is_appless_customer * count_whatsapp_reads`: Captures the behavior of the critical app-less segment on their primary channel.
    *   `is_new_offer * count_inapp_clicks`: Captures the primary conversion path for new users.

4.  **Deprecated Features**: All `diff_notif` features based on time differences should be discarded as they are not reliable predictors according to business logic.
