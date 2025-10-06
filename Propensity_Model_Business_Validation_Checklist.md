# Propensity Model Business Validation Checklist

**Date:** 2025-09-29
**Analyst:** Ammar Siregar
**Models to Validate:** Model 1 (with SLIK) vs Model 2 (no SLIK)

## Pre-Model Baseline (COMPLETED)

### Customer Risk Distribution
- ✅ LOW risk: 77.22% (25.1M customers) - Primary target
- ✅ MEDIUM risk: 17.55% (5.7M customers) - Secondary target
- ✅ HIGH risk: 0.09% (30K customers) - AVOID targeting
- ✅ Baseline take-up rate: 2.71%

### Key Baseline Insights
- ✅ Low balance + Active users have higher take-up rates across all risk segments
- ✅ HIGH risk + Low Balance + Active: 0.82% take-up
- ✅ LOW risk + Low Balance + Active: 2.62% take-up
- ⚠️ **Concern**: Financial stress indicators correlate with higher take-up

## Model Validation Checklist (PENDING MODEL RESULTS)

### 1. Risk Concentration Analysis (CRITICAL)
**Target Thresholds:**
- [ ] Decile 10 should have <20% HIGH risk customers
- [ ] Decile 10 should have >50% LOW risk customers
- [ ] Decile 9 should have <15% HIGH risk customers
- [ ] No decile should have >30% HIGH risk customers

**Model 1 (with SLIK) Results:**
- [ ] Decile 10 risk distribution: ___% HIGH, ___% MEDIUM, ___% LOW
- [ ] Passes risk concentration test: YES/NO
- [ ] Safe for deployment: YES/NO

**Model 2 (no SLIK) Results:**
- [ ] Decile 10 risk distribution: ___% HIGH, ___% MEDIUM, ___% LOW
- [ ] Passes risk concentration test: YES/NO
- [ ] Safe for deployment: YES/NO

### 2. Feature Logic Validation
**Financial Stress Indicators:**
- [ ] Check if top deciles have significantly lower avg_balance
- [ ] Validate if "low balance = high propensity" pattern exists
- [ ] Model 1 avg balance in Decile 10: _______
- [ ] Model 2 avg balance in Decile 10: _______
- [ ] Overall population avg balance: _______
- [ ] Red flag if Decile 10 < 50% of population average

**Business Logic Check:**
- [ ] Top 5 features make business sense
- [ ] No obvious inverse relationships (lower income = higher propensity)
- [ ] SLIK features improve business logic vs demographic-only

### 3. Model Performance Comparison
**Model 1 (with SLIK):**
- [ ] AUC: _____
- [ ] Gini: _____
- [ ] KS: _____
- [ ] Top 5 features: _____________

**Model 2 (no SLIK):**
- [ ] AUC: _____
- [ ] Gini: _____
- [ ] KS: _____
- [ ] Top 5 features: _____________

### 4. Deployment Recommendations
**Safe Targeting Segments:**
- [ ] Model 1 - Recommended deciles: _______
- [ ] Model 2 - Recommended deciles: _______
- [ ] Required business rules: _____________
- [ ] Minimum balance threshold: _______
- [ ] Maximum risk concentration: _______

**Risk Mitigation:**
- [ ] Exclude customers with total_balance < 100,000
- [ ] Exclude HIGH risk customers regardless of propensity
- [ ] Monitor actual take-up vs predicted by risk segment
- [ ] Set maximum daily/monthly targeting limits

## Final Recommendation
**Preferred Model:** Model __ because:
- [ ] Better risk concentration
- [ ] More logical feature importance
- [ ] Lower financial stress indicators
- [ ] Better business interpretability

**Deployment Strategy:**
- [ ] Start with Deciles __ to __
- [ ] Implement business rule overlays
- [ ] Monitor performance for 2 weeks before expanding
- [ ] Regular risk concentration monitoring

## Action Items Post-Validation
- [ ] Present findings to working group
- [ ] Document any model concerns for Stephanie
- [ ] Prepare monitoring framework for deployment
- [ ] Create reporting dashboard for ongoing validation

---
**Validation Completed By:** ________________
**Date:** ________________
**Approved for Deployment:** YES/NO
**Comments:** ________________________________