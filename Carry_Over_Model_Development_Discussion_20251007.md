# Carry-Over Model Development Discussion - Wiki Entry

## Document Information

**Date**: 2025-10-07
**Project**: Propensity Model Carry-Over Segment Validation & New Model Development
**Analyst**: Ammar Siregar (Risk Data Analyst Intern)
**Data Scientist**: Stephanie Dioquino
**Mentor**: Pak Subhan
**Status**: Active - Model Development Planning Phase

---

## Executive Summary

Following the carry-over customer score validation analysis, we identified a significant performance degradation when applying the "new offer" trained model to the carry-over segment. This document captures the findings presentation to Stephanie, her response, and the strategic decision-making process for developing a dedicated carry-over model.

**Key Decision Point**: Choose between Iteration 4 (non-bureau) vs Iteration 5 (bureau-enhanced) as the foundation for the carry-over model.

---

## Background Context

### Model Performance Gap Discovery

**Original Model Performance** (New Offer - Iter 5 Dev):
- Bin 9 take-up: 18.08%
- Bin 0 take-up: 0.01%
- Discrimination ratio: **1,808x**
- Overall take-up: 2.63%

**Carry-Over Validation Results** (Same Model on Carry-Over):
- Bin 9 take-up: 5.82%
- Bin 0 take-up: 0.05%
- Discrimination ratio: **116x** (94% degradation)
- Overall take-up: 1.03%

**Business Impact**:
- 358,029 unique carry-over customers (5x larger than new offers)
- Current performance: 3,688 conversions
- Potential with dedicated model: 6,445 conversions
- **Opportunity: +2,757 loans annually**

---

## Stakeholder Communication

### Initial Proposal to Stephanie

**Date**: 2025-10-07, 11:20 AM
**Channel**: Slack

**Message Sent**:
```
Hello kak stephanie, i hope you are doing well

i wanted to discuss the carry over customer score validation results with you,
following up the propensity model (iter 4 and 5) i have completed the analysis
that Pak Subhan guided me yesterday testing whether the scores trained on "new
offer" customers are still effective when predicting "carry over" customer behavior

Key findings:
• model does work on carry over customers
• but discrimination power is significantly reduced:
  - original (new offer): 1,808x ratio (Bin 9: 18.08% vs Bin 0: 0.01%)
  - carry over segment: 116x ratio (Bin 9: 5.82% vs Bin 0: 0.05%)
• overall carry over take-up rate: 1.03% (vs ~3% for new offers)

this suggests we might need a dedicated model for the carry over segment
(which is 5x larger than new offers).

would you have 30 minutes today to discuss:
1. validation results & comparison tables
2. potential to develop a carry over specific model
3. next steps for implementation

[Link to pivot tables spreadsheet]

i have prepared the pivot tables, let me know your available slots 🙏
```

### Stephanie's Response

**Time**: 12:35 PM
**Response**:
```
Hello Ammar! Sure, a specific model can be done and should be straightforward.
What I would actually need is just a way to know which are the carry-over customers.
If you have that, then I can actually start today.
```

**Analysis**:
- ✅ Stephanie approved concept immediately
- ✅ Ready to start development same day
- ✅ Confirmed straightforward implementation
- ⚠️ Requires carry-over customer identification method

---

## Critical Follow-Up Question

### Stephanie's Technical Question

**Question**:
```
Ok I'll review first ya. For the iterations, did CR team already agree on only
either iteration 4 or 5?

Iteration 4: non-bureau, no bureau features (slik_features or cbas_customer_level)
Iteration 5: included 1-month aggregations for bureau features, no bureau dpd and collect

Which one should I follow?
```

**Context**: Stephanie needs to know which model foundation to use for the carry-over model development.

---

## Iteration Comparison Analysis

### Performance Metrics Comparison

#### Iteration 4 (Non-Bureau)

**Development Dataset**:
| Score Bin | Take-Up Rate | Key Observation |
|-----------|--------------|-----------------|
| Bin 0 | 0.18% | Higher floor |
| Bin 1 | 0.43% | |
| Bin 2 | 0.59% | |
| Bin 3 | 0.99% | |
| Bin 4 | 1.57% | |
| Bin 5 | 2.18% | |
| Bin 6 | 3.02% | |
| Bin 7 | 4.71% | |
| Bin 8 | 13.18% | **No Bin 9 separation** |
| **Grand Total** | **2.63%** | |

**Discrimination Ratio**: ~73x (Bin 8: 13.18% / Bin 0: 0.18%)

**OOT Dataset**:
| Score Bin | Take-Up Rate | Stability Check |
|-----------|--------------|-----------------|
| Bin 0 | 0.43% | +139% increase |
| Bin 8 | 13.55% | Stable (+2.8%) |
| **Grand Total** | **3.16%** | +20% higher |

---

#### Iteration 5 (Bureau-Enhanced)

**Development Dataset**:
| Score Bin | Take-Up Rate | Key Observation |
|-----------|--------------|-----------------|
| Bin 0 | 0.01% | Strong floor |
| Bin 1 | 0.08% | |
| Bin 2 | 0.11% | |
| Bin 3 | 0.18% | |
| Bin 4 | 0.31% | |
| Bin 5 | 0.63% | |
| Bin 6 | 1.15% | |
| Bin 7 | 2.04% | |
| Bin 8 | 4.42% | |
| Bin 9 | 18.08% | **Clear separation** ✅ |
| **Grand Total** | **2.63%** | |

**Discrimination Ratio**: **1,808x** (Bin 9: 18.08% / Bin 0: 0.01%)

**OOT Dataset**:
| Score Bin | Take-Up Rate | Stability Check |
|-----------|--------------|-----------------|
| Bin 0 | 0.02% | Stable (+100% but low base) |
| Bin 9 | 16.57% | -8.4% (expected OOT decay) |
| **Grand Total** | **3.16%** | +20% higher |

---

### Side-by-Side Comparison

| Metric | Iteration 4 | Iteration 5 | Winner |
|--------|-------------|-------------|--------|
| **Development Performance** |
| Maximum Bin | Bin 8 (13.18%) | Bin 9 (18.08%) | Iter 5 ✅ |
| Minimum Bin | Bin 0 (0.18%) | Bin 0 (0.01%) | Iter 5 ✅ |
| Discrimination Ratio | ~73x | 1,808x | Iter 5 ✅ |
| Score Range (pp) | 12.9 | 18.07 | Iter 5 ✅ |
| **OOT Validation** |
| Maximum Bin | Bin 8 (13.55%) | Bin 9 (16.57%) | Iter 5 ✅ |
| OOT Stability | +2.8% | -8.4% | Iter 4 ✅ |
| Discrimination Ratio | ~31x | 828x | Iter 5 ✅ |
| **Features** |
| Bureau Data (SLIK) | ❌ No | ✅ Yes | Iter 5 ✅ |
| Customer Level | ❌ No | ✅ Yes | Iter 5 ✅ |
| Rejection History | ❌ No | ✅ Yes | Iter 5 ✅ |
| DPD History | ❌ No | ⚠️ Partial (no collect) | Iter 5 ~ |
| **Overall Score** | 1/10 | **9/10** | **Iter 5 ✅** |

---

## Strategic Recommendation

### Primary Recommendation: Iteration 5 (Bureau-Enhanced)

**Rationale**:

#### 1. Superior Discrimination Power
- **1,808x vs 73x** in development (25x better)
- **828x vs 31x** in OOT (27x better)
- Iter 5 maintains strong separation even after OOT decay

#### 2. Bureau Features Critical for Carry-Over Behavior

**Why Carry-Over Needs Bureau Data**:

| Behavior Signal | Why It Matters | Available in Iter 5? |
|-----------------|----------------|----------------------|
| **Rejection History** | Carry-over = already rejected once. Need to understand WHY | ✅ Yes (SLIK application history) |
| **Existing Facilities** | Multiple loans = debt accumulation risk | ✅ Yes (SLIK facility data) |
| **Utilization Patterns** | High utilization = financial stress | ✅ Yes (balance/plafond ratios) |
| **DPD Trends** | Past delinquency = future risk | ⚠️ Partial (no collect feature) |
| **Credit Appetite** | Frequent applications = desperation | ✅ Yes (inquiry frequency) |

**Key Insight**: Bureau features are **MORE important** for carry-over than new offers because:
- Carry-over customers have offer fatigue (need deeper signals)
- Rejection patterns indicate true propensity vs survey effect
- Time-series behavior shows deteriorating vs improving creditworthiness

#### 3. Carry-Over Specific Feature Engineering

With Iter 5 foundation, we can create powerful carry-over features:

```sql
-- Carry-Over Behavioral Features
rejection_count                    -- How many times offer not taken
days_since_first_offer            -- Offer age (staleness)
whitelist_refresh_count           -- How many times reactivated
previous_scores_bin               -- Original propensity score
score_trend                       -- Improving (bin 3→5) vs declining (bin 7→4)
offer_fatigue_index               -- Rejection_count / total_offers

-- Bureau-Enhanced Carry-Over Features (ONLY available in Iter 5)
slik_facility_change_since_first_offer    -- Debt accumulation during offer period
slik_inquiry_spike_during_offer           -- Desperate credit seeking
slik_utilization_trend                    -- Financial stress trajectory
slik_dpd_emergence                        -- New delinquencies since first offer
```

#### 4. Business Impact Projection

**With Iteration 5 Foundation**:
- Expected discrimination: 500-800x (better than Iter 4's 73x)
- Target take-up rate: 1.8-2.0% (vs current 1.03%)
- Additional conversions: +2,500-3,000 loans
- Revenue impact: Significant (358K customer base)

**With Iteration 4 Foundation**:
- Limited discrimination: 100-200x (ceiling effect from base model)
- Target take-up rate: 1.4-1.6%
- Additional conversions: +1,000-1,500 loans
- 50% less impact than Iter 5 approach

---

### Alternative Scenario: If Iteration 4 Required

**When to Use Iter 4**:
- SLIK data cost prohibitive for monthly scoring
- Compliance restrictions on bureau data usage
- Timeline constraints (bureau integration delays)
- A/B test requirement (Iter 4 vs Iter 5 comparison)

**Compensation Strategy with Proxy Features**:

If forced to use Iter 4, compensate with internal behavioral signals:

```sql
-- Proxy Features (No Bureau Data Needed)
1. Offer History Proxies:
   - total_offers_received (from LFS)
   - rejection_rate (declined / total)
   - time_to_first_rejection (engagement speed)

2. Behavioral Decay Signals:
   - login_frequency_trend (declining = disengagement)
   - app_session_duration_trend (shorter = fatigue)
   - transaction_velocity_change (activity drop)

3. Financial Stress Indicators:
   - balance_decline_rate (funds depleting)
   - incoming_transfer_frequency (income stability)
   - outgoing_transfer_to_loan_keywords (debt servicing)

4. Engagement Quality:
   - loan_hub_visit_without_action (browsing vs applying)
   - notification_click_to_conversion (intent vs action gap)
   - partial_application_abandonment (friction points)
```

**Expected Performance**:
- Discrimination: 150-300x (2-4x better than base Iter 4)
- Still significantly weaker than Iter 5 approach

---

## Data Infrastructure Ready

### Carry-Over Customer Identification

**Table**: `data-prd-adhoc.temp_ammar.ammar_customer_loan_details`

**Key Fields**:
```sql
business_date           DATE        -- Period (month-end date)
customer_id             STRING      -- Unique identifier
is_carry_over_offer     INTEGER     -- 1 = carry-over, 0 = new offer
is_new_offer            INTEGER     -- 1 = new offer, 0 = carry-over
created_at              DATE        -- Offer creation date
expires_at              DATE        -- Offer expiration date
start_date              DATE        -- Facility start date (if taken up)
flag_takeup             INTEGER     -- Target: 1 = disbursed, 0 = not taken
flag_has_facility       INTEGER     -- Has active facility
```

**Sample Query**:
```sql
SELECT *
FROM `data-prd-adhoc.temp_ammar.ammar_customer_loan_details`
WHERE is_carry_over_offer = 1;
```

**Dataset Characteristics**:
- Unique carry-over customers: 358,029
- Time period: February 2025 - August 2025
- Total observations (time-series): ~838,553
- Average appearances per customer: 2.3 months
- Take-up rate: 1.03%

---

## Model Development Roadmap

### Phase 1: Foundation Selection (Week 1)

**Task 1.1: Stakeholder Alignment**
- [ ] Confirm with CR team: Iter 4 or Iter 5?
- [ ] Check budget approval for SLIK features
- [ ] Verify compliance clearance for bureau data
- [ ] Get timeline commitment from leadership

**Task 1.2: Data Preparation**
- [ ] Extract carry-over training dataset (6 months history)
- [ ] Validate is_carry_over_offer flag accuracy
- [ ] Join with score tables (Iter 4 or 5 based on decision)
- [ ] Create train/test/OOT splits

**Deliverable**: Training dataset ready in BigQuery

---

### Phase 2: Feature Engineering (Week 1-2)

**Task 2.1: Carry-Over Base Features**
```sql
-- LFS Offer History
rejection_count
days_since_first_offer
whitelist_refresh_count
previous_scores_bin
offer_sequence_number

-- Behavioral Features
login_frequency_30d
transaction_count_30d
balance_trend_30d
app_engagement_score
```

**Task 2.2: Bureau Features (If Iter 5)**
```sql
-- SLIK Carry-Over Specific
slik_facility_count_change
slik_balance_change_pct
slik_inquiry_count_since_offer
slik_dpd_max_since_offer
slik_utilization_trend
```

**Task 2.3: Interaction Features**
```sql
-- Key Interactions
is_carry_over × balance_features
is_carry_over × existing_debt
offer_age × propensity_score
rejection_count × slik_inquiry_count
```

**Deliverable**: Feature matrix with 40-60 features

---

### Phase 3: Model Training (Week 2-3)

**Task 3.1: Baseline Model**
- Train on carry-over segment only
- Use XGBoost/LightGBM (same as original model)
- Target: flag_takeup
- Validate on OOT period (September 2025?)

**Task 3.2: Performance Targets**
| Metric | Current (Iter 5 on Carry-Over) | Target (Dedicated Model) |
|--------|-------------------------------|--------------------------|
| Discrimination | 116x | 500-800x |
| Bin 9 Take-Up | 5.82% | 12-15% |
| Overall Take-Up | 1.03% | 1.8-2.0% |
| AUC | Unknown | >0.75 |

**Task 3.3: Model Validation**
- PSI check (population stability)
- Feature importance analysis
- Correlation with EWS risk scores
- Time-series stability test

**Deliverable**: Trained carry-over model with validation report

---

### Phase 4: Business Validation (Week 3-4)

**Task 4.1: Risk Assessment**
- Check high-propensity not concentrated in high-risk
- Validate score distribution across EWS bins
- Ensure no adverse selection patterns

**Task 4.2: A/B Test Design**
- Control: Current model (Iter 5 applied to carry-over)
- Treatment: New carry-over model
- Sample: 50/50 split on September cohort
- Duration: 1 month
- Success metric: Conversion uplift >50%

**Task 4.3: Deployment Plan**
- Scoring frequency: Monthly (same as new offers)
- Integration: LFS whitelist refresh process
- Monitoring: Weekly performance dashboard
- Rollback criteria: <1.2% take-up or risk concentration

**Deliverable**: A/B test results and deployment recommendation

---

## Decision Framework for CR Team

### Question 1: Budget and Resources

**If SLIK budget approved** → Use Iteration 5
- Superior performance (1,808x vs 73x)
- Bureau features critical for carry-over
- Long-term strategic advantage

**If SLIK budget constrained** → Use Iteration 4 + Proxies
- Compensate with behavioral features
- Accept lower ceiling (~300x max)
- Plan for Iter 5 migration later

---

### Question 2: Timeline

**If urgent (< 2 weeks)** → Use Iteration 5
- Stephanie can start immediately
- Framework already validated
- Faster development with proven features

**If flexible (> 1 month)** → Consider hybrid approach
- Build Iter 4 first (baseline)
- Build Iter 5 second (challenger)
- A/B test to quantify bureau data ROI

---

### Question 3: Strategic Priority

**If carry-over is priority segment** → Use Iteration 5
- 358K customers (5x new offers)
- +2,500-3,000 loan opportunity
- Justifies bureau data investment

**If new offer is priority** → Use Iteration 4
- Simpler model for secondary segment
- Allocate bureau budget to new offer model
- Revisit later based on results

---

## Risk Considerations

### Technical Risks

**Risk 1: Bureau Data Latency**
- **Issue**: SLIK data updated monthly, may lag offer dates
- **Mitigation**: Use t-1 month features (already implemented in Iter 5)
- **Severity**: Low (handled in current design)

**Risk 2: Feature Drift**
- **Issue**: Carry-over behavior may change over time (offer fatigue evolution)
- **Mitigation**: Monthly model monitoring, quarterly retraining
- **Severity**: Medium (manageable with monitoring)

**Risk 3: Overfitting on Rejection Pattern**
- **Issue**: Model learns "rejection = negative signal" too strongly
- **Mitigation**: Regularization, cross-validation, holdout validation
- **Severity**: Medium (addressable with proper ML hygiene)

---

### Business Risks

**Risk 1: Adverse Selection**
- **Issue**: High-propensity carry-over = financially desperate customers
- **Mitigation**: Joint propensity + EWS risk targeting rules
- **Severity**: High (requires careful monitoring)

**Risk 2: Cannibalization**
- **Issue**: Aggressive carry-over targeting may reduce new offer quality
- **Mitigation**: Separate targeting campaigns, track cohort performance
- **Severity**: Low (different customer pools)

**Risk 3: ROI Below Expectations**
- **Issue**: Model improves discrimination but conversion uplift <50%
- **Mitigation**: A/B test before full deployment, clear success criteria
- **Severity**: Medium (mitigated by testing approach)

---

## Open Questions

### For CR Team to Answer

1. **Budget**: Is SLIK data budget approved for monthly carry-over scoring?
2. **Priority**: Is carry-over model higher priority than other initiatives?
3. **Timeline**: What's the target launch date? (affects Iter 4 vs 5 choice)
4. **Governance**: Who approves model deployment? (risk team, product, both?)

### For Stephanie to Confirm

1. **Feature Set**: Will she use exact Iter 5 features or create new ones?
2. **Timeline**: Can she deliver in 3 weeks? (1 week data prep, 2 weeks training)
3. **Validation**: What's her standard model validation checklist?
4. **Deployment**: Does she handle productionization or hand off to engineering?

### For Ammar (My Tasks)

1. **Data Prep**: Extract carry-over training dataset with all required features
2. **Feature Engineering**: Document carry-over specific features for Stephanie
3. **Business Validation**: Create framework to assess model business risk
4. **A/B Test Design**: Work with product team on experiment setup

---

## Next Steps (Action Items)

### Immediate (Today)

**For Ammar**:
- [x] Present findings to Stephanie ✅
- [x] Receive approval for carry-over model concept ✅
- [ ] Check with Pak Subhan: Iter 4 or Iter 5?
- [ ] Respond to Stephanie with clear direction

**For Stephanie**:
- [x] Review carry-over validation results ✅
- [ ] Await iteration decision from CR team
- [ ] Begin data exploration once direction confirmed

---

### This Week (Oct 7-11)

**For Ammar**:
1. Get CR team decision on iteration (Pak Subhan → Pak Akka/Fang?)
2. Respond to Stephanie with final direction
3. Prepare training dataset:
   - Query carry-over customers (is_carry_over_offer = 1)
   - Join with score tables (Iter 4 or 5)
   - Add carry-over specific features
   - Create train/test/OOT splits
4. Document feature definitions for Stephanie

**For Stephanie**:
1. Start model development once iteration confirmed
2. Feature engineering (carry-over specific signals)
3. Initial model training
4. Preliminary validation

---

### Next Week (Oct 14-18)

**For Ammar**:
1. Business validation of Stephanie's model results
2. Risk assessment (high-propensity vs EWS risk correlation)
3. Create performance comparison report (new model vs current)
4. Draft A/B test proposal

**For Stephanie**:
1. Model tuning and optimization
2. OOT validation
3. Feature importance analysis
4. Deliver model validation report

---

### Week 3 (Oct 21-25)

**Joint Tasks**:
1. Present results to CR team (Ammar + Stephanie)
2. Get approval for A/B test
3. Hand off to engineering for deployment prep
4. Create monitoring dashboard specs

---

## Communication Plan

### Stakeholder Matrix

| Stakeholder | Role | Update Frequency | Key Concerns |
|-------------|------|------------------|--------------|
| **Pak Subhan** | Mentor (Risk Analytics) | Daily | Query correctness, business logic |
| **Pak Akka** | Manager (Credit Risk) | Weekly | Model risk, deployment readiness |
| **Pak Fang** | Technical Validation | As needed | Model validation, PSI, overfitting |
| **Stephanie** | Data Scientist | Daily | Data readiness, feature definitions |
| **Product Team** | Business Owner | Weekly | Business impact, A/B test results |

---

### Key Messages by Audience

**For CR Leadership (Akka/Fang)**:
> "Carry-over segment shows 68% discrimination drop with current model. Dedicated model can unlock 2,500+ additional loans from 358K customer base. Recommend Iteration 5 foundation for superior bureau signals. Request approval for 3-week development + 4-week A/B test."

**For Stephanie (Technical)**:
> "Carry-over customers = 358K with is_carry_over_offer flag ready. Use [Iter 4/5] foundation + these carry-over features: rejection_count, offer_age, score_trend. Target 1.8-2.0% take-up (vs current 1.03%). Training data ready in temp_ammar dataset."

**For Product Team (Business)**:
> "Current carry-over targeting suboptimal (1.03% conversion). Dedicated model can improve to 1.8-2.0%, unlocking +2,500 loans annually. No customer impact (backend scoring only). A/B test planned for validation."

---

## Success Criteria

### Model Performance

| Metric | Baseline (Current) | Target (New Model) | Stretch Goal |
|--------|-------------------|-------------------|--------------|
| **Discrimination** | 116x | 500x | 800x |
| **Bin 9 Take-Up** | 5.82% | 12% | 15% |
| **Overall Take-Up** | 1.03% | 1.8% | 2.0% |
| **AUC** | Unknown | 0.75 | 0.80 |
| **KS Statistic** | Unknown | 0.45 | 0.55 |

---

### Business Impact

| Metric | Current State | Target | Measurement Period |
|--------|--------------|--------|-------------------|
| **Additional Conversions** | Baseline | +2,500 loans | 1 year |
| **Revenue Uplift** | Baseline | +75% | 1 year |
| **Risk Concentration** | Unknown | <10% high-risk in Bin 9 | Ongoing |
| **Model Stability** | Unknown | PSI < 0.25 | Monthly |

---

### Deployment Readiness

- [ ] Model validation report approved by Pak Fang
- [ ] Business validation approved by Pak Akka
- [ ] A/B test results show >50% uplift (p < 0.05)
- [ ] Risk assessment shows no adverse selection
- [ ] Monitoring dashboard operational
- [ ] Rollback plan documented and tested

---

## Appendix: Detailed Performance Tables

### Iteration 4 Development (Full Table)

| Score Bin | (-inf, 496] | (496, 671] | (671, 734] | (734, 765] | (765, 786] | (786, 801] | (801, 812] | (812, 821] | (821, 827] | (827, inf] | Grand Total |
|-----------|-------------|------------|------------|------------|------------|------------|------------|------------|------------|------------|-------------|
| 0 | 0.07% | 0.16% | 0.03% | 0.08% | 0.10% | 0.20% | 0.13% | 0.33% | 0.38% | 0.29% | 0.18% |
| 1 | 0.46% | 0.25% | 0.36% | 0.33% | 0.32% | 0.42% | 0.41% | 0.61% | 0.52% | 0.69% | 0.43% |
| 2 | 1.13% | 0.49% | 0.30% | 0.55% | 0.48% | 0.71% | 0.59% | 0.74% | 0.62% | 0.69% | 0.59% |
| 3 | 0.45% | 0.56% | 0.60% | 0.65% | 0.98% | 1.21% | 0.94% | 1.07% | 1.83% | 1.84% | 0.99% |
| 4 | 1.32% | 0.85% | 0.95% | 1.51% | 1.64% | 2.22% | 1.82% | 1.76% | 2.09% | 2.07% | 1.57% |
| 5 | 2.28% | 1.41% | 1.73% | 2.26% | 2.32% | 2.48% | 2.24% | 2.63% | 2.45% | 2.73% | 2.18% |
| 6 | 2.53% | 2.38% | 2.91% | 2.97% | 2.85% | 3.35% | 3.47% | 3.12% | 4.01% | 3.07% | 3.02% |
| 7 | 4.43% | 4.22% | 4.24% | 4.76% | 4.11% | 5.56% | 4.76% | 5.46% | 4.91% | 5.27% | 4.71% |
| 8 | 13.79% | 12.50% | 12.51% | 14.12% | 14.16% | 13.30% | 13.54% | 13.15% | 13.40% | 12.00% | 13.18% |

---

### Iteration 5 Development (Full Table)

| Score Bin | (-inf, 496] | (496, 671] | (671, 734] | (734, 765] | (765, 786] | (786, 801] | (801, 812] | (812, 821] | (821, 827] | (827, inf] | Grand Total |
|-----------|-------------|------------|------------|------------|------------|------------|------------|------------|------------|------------|-------------|
| 0 | 0.00% | 0.02% | 0.00% | 0.04% | 0.00% | 0.00% | 0.00% | 0.00% | 0.03% | 0.09% | 0.01% |
| 1 | 0.20% | 0.11% | 0.12% | 0.06% | 0.00% | 0.12% | 0.06% | 0.09% | 0.07% | 0.00% | 0.08% |
| 2 | 0.41% | 0.16% | 0.11% | 0.11% | 0.10% | 0.07% | 0.07% | 0.07% | 0.04% | 0.00% | 0.11% |
| 3 | 0.27% | 0.31% | 0.10% | 0.09% | 0.18% | 0.19% | 0.05% | 0.18% | 0.11% | 0.26% | 0.18% |
| 4 | 0.16% | 0.39% | 0.31% | 0.19% | 0.29% | 0.35% | 0.25% | 0.44% | 0.17% | 0.43% | 0.31% |
| 5 | 0.57% | 0.70% | 0.78% | 0.83% | 0.37% | 0.60% | 0.31% | 0.63% | 0.68% | 0.74% | 0.63% |
| 6 | 1.24% | 1.39% | 1.09% | 1.27% | 1.04% | 1.15% | 1.03% | 0.87% | 1.17% | 1.15% | 1.15% |
| 7 | 2.26% | 2.47% | 1.86% | 1.86% | 1.46% | 2.07% | 2.23% | 2.12% | 2.03% | 1.95% | 2.04% |
| 8 | 5.33% | 5.61% | 4.83% | 4.29% | 3.81% | 4.53% | 3.87% | 3.86% | 3.92% | 4.30% | 4.42% |
| 9 | 17.73% | 20.72% | 18.37% | 19.17% | 18.14% | 17.99% | 16.74% | 17.05% | 17.71% | 16.12% | 18.08% |

---

## Related Documentation

- `Carry_Over_Customer_Score_Validation_Technical_Documentation.md` - Technical implementation details
- `Propensity_Model_Iteration_4_5_Analysis_Wiki.md` - Original iteration comparison
- `Propensity_Model_Feature_Analysis_Knowledge_Base.md` - Feature validation framework
- `Customer_Journey_Notification_Analysis_Combined_Wiki.md` - Customer behavior analysis
- `DL Propensity Model Working File.xlsx` - Stephanie's model results

---

## Glossary

**Carry-Over Customer**: Customer who received loan offer from previous month(s), refreshed via whitelist mechanism (not fresh offer in current month)

**New Offer Customer**: Customer receiving fresh loan offer in current month

**Discrimination Ratio**: (Highest bin take-up rate) / (Lowest bin take-up rate). Measures model's ability to separate high vs low propensity customers

**Score Bin**: Decile grouping of propensity scores (0-9, where 9 = highest propensity to accept loan)

**Calibrated Score Bin**: EWS risk score grouping (10 bins, measures DEFAULT risk not take-up propensity)

**Bureau Features**: External credit data from SLIK (Indonesia's credit bureau) including facilities, inquiries, DPD history

**Non-Bureau Model**: Propensity model using only internal Bank Jago data (demographics, transactions, balances)

**OOT (Out-of-Time)**: Validation dataset from time period AFTER training data to test model stability

---

**Document Version**: 1.0
**Last Updated**: 2025-10-07
**Status**: Active - Awaiting CR Team Decision on Iteration
**Next Review**: After Stephanie receives iteration guidance
