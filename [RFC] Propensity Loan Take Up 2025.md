# [RFC] Propensity Loan Take Up 2025

Author (^) Jay Liu
Muhammad Subhan
Muhammad Nurkholis
Approver (^) Umakanth Pai Andy Djiwandono
Reviewer (^) Stephen Partono
Status (CR) On Review
Backlog
Estimate Oct 2025
Documents

## Stakeholder

```
D - Decider Stephen Partono
A - Accountable
R - Responsible
C - Consulted
I - Informed
```

### Background

## Background

Since the launch of the **Direct Lending** product in October 2024, Bank Jago has faced the
challenge of a low loan _take-up rate_ from prospective customers who have received loan offers.
Although various acquisition programs have been implemented — such as reminders,
WhatsApp notifications, telemarketing, and marketing promotions — the loan conversion rate
remains suboptimal.
To improve the effectiveness of acquisition strategies, a **propensity model** or **customer
segmentation** is needed to identify groups with a higher probability of taking up loans. With this
model, promotional activities and outreach efforts (e.g., campaigns, notifications, or telecalls)
can be more precisely targeted toward the most potential segments.
This approach is expected to increase marketing efficiency, enhance customer experience
through _personalized targeting_ , and ultimately improve the overall loan _take-up rate_.

### Scope

1. Developing model propensity take up with existing features all
2. Developing model propensity take up with existing features non bureau
_No. 2 is an optional strategy, to be applied if the results in No. 1 show segmentation that is
concentrated or already reflective of a particular risk segment score (EWS Score)._

### Requirement

1. Label / Target
    For every customer who passes underwriting, we will provide a loan offer (uploaded in
    the app). Loan offers are generated at the beginning of each month (on the 4th–5th) and
    remain valid until their expiration date in the following month.


```
The target determination is calculated from the offer date. If the customer makes their
first disbursement (start facility date) any time from Day +1 after the offer date until the
loan offer expires, the customer will be flagged as take-up.
The simplified logic is as follows:
period offer flag_take_up
2025-08-05 If start_facility_date between 2025-08-06 (period offer+1) and
expiry_date (2025-09-05) then 1 else null end
etc
Source :
● jago-bank-data-production.dwh_core.loan_offer
● jago-bank-data-production.data_mart.credit_risk_vintage_account_direct_lending
Backest :
Reference script : ongoing
```
2. Features
    The features to be used are existing ones, namely: demography, funding balance (last
    1–6 months), funding transactions (last 1–6 months), and bureau features (excluding
    collectability and DPD category).
    The connection across variables can be made using id_number or customer_id_lfs,
    while the connection across time periods is determined by ensuring that the latest
    feature period (business_date) precedes the offer period.
    Source :
       ● Jago-bank-data-production.data_mart.customer
       ● Jago-bank-data-production.model_features.successful_transaction_features
       ● Jago-bank-data-production.model_features.funding_balance_features


● Jago-bank-data-production.model_features.slik_features (bureau)
● Jago-bank-data-production.credit_risk.cbas_customer_level (bureau)
Reference script : ongoing