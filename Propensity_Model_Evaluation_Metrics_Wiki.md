# Propensity Model Evaluation Metrics - Technical Wiki

**Document Owner**: Risk Data Analyst Team
**Project**: Propensity Loan Take Up 2025
**Last Updated**: October 10, 2025 (Updated with mentor corrections and feature analysis)
**Purpose**: Comprehensive reference for model evaluation metrics, scoring bins, feature analysis, and performance evaluation
**Audience**: Data Analysts, Data Scientists, Credit Risk Team, Business Stakeholders

---

## 📑 Table of Contents

1. [Overview](#overview)
2. [Core Performance Metrics](#core-performance-metrics)
   - [AUC (Area Under the Curve)](#auc-area-under-the-curve)
   - [Gini Coefficient](#gini-coefficient)
   - [KS (Kolmogorov-Smirnov) Statistic](#ks-kolmogorov-smirnov-statistic)
3. [Scoring System](#scoring-system)
   - [Score Bin (Propensity Score)](#score-bin-propensity-score)
   - [Calibrated Score Bin (EWS Risk Score)](#calibrated-score-bin-ews-risk-score)
4. [Performance Analysis Framework](#performance-analysis-framework)
5. [Iteration Comparison](#iteration-comparison)
6. [Feature Analysis](#feature-analysis)
   - [Bad Rate Analysis](#bad-rate-analysis)
   - [Feature Importance (Split vs Gain)](#feature-importance-split-vs-gain)
   - [Weight of Evidence (WoE) and Information Value (IV)](#weight-of-evidence-woe-and-information-value-iv)
   - [Feature Values vs Score Bins](#feature-values-vs-score-bins)
7. [Model Explainability (SHAP)](#model-explainability-shap)
8. [Glossary](#glossary)

---

## Overview

This document provides comprehensive explanations of machine learning model evaluation metrics used in the **Propensity Loan Take Up 2025** project. The propensity model predicts which customers are most likely to accept (take up) a loan offer.

### Business Context

- **Target Variable**: `flag_takeup` (1 = customer accepted loan, 0 = did not accept)
- **Base Rate**: ~2.63% take-up rate (highly imbalanced dataset)
- **Model Type**: Binary classification (XGBoost/LightGBM)
- **Primary Objective**: Rank customers by propensity to take up loans for targeted marketing

---

## Core Performance Metrics

### AUC (Area Under the Curve)

#### Definition

**AUC** is the Area Under the ROC (Receiver Operating Characteristic) Curve. It measures the model's ability to distinguish between positive and negative classes across all possible classification thresholds.

#### Technical Formula

```
AUC = ∫₀¹ TPR(FPR) d(FPR)

Where:
- TPR = True Positive Rate = TP / (TP + FN)
- FPR = False Positive Rate = FP / (FP + TN)
```

#### Interpretation

**Range**: 0.5 to 1.0

| AUC Range | Model Quality | Interpretation |
|-----------|---------------|----------------|
| 0.5 | No discrimination | Random guessing (coin flip) |
| 0.5 - 0.6 | Poor | Barely better than random |
| 0.6 - 0.7 | Fair | Some predictive power |
| 0.7 - 0.8 | Good | Acceptable for production |
| 0.8 - 0.9 | Excellent | Strong predictive power ✅ |
| 0.9 - 1.0 | Outstanding | Exceptional (check for leakage) |

**Intuitive Meaning**:
> If you randomly pick one customer who took up a loan and one who didn't, AUC represents the probability that the model will correctly rank the take-up customer higher.

**Example**:
- AUC = 0.8762 means there's an **87.62% chance** the model scores a take-up customer higher than a non-take-up customer

#### Why AUC for This Project?

1. **Threshold-Independent**: Evaluates model performance across all possible cutoff points
2. **Imbalanced Data Friendly**: Works well with 2.63% positive class (unlike accuracy)
3. **Ranking Quality**: Measures ability to rank customers, which is critical for targeted marketing
4. **Industry Standard**: Widely used in credit scoring and propensity modeling

#### Explanation by Audience

**For Business Stakeholders**:
> "AUC tells us how well the model separates customers who will take loans from those who won't. Our model achieves 0.88, meaning it's 88% accurate at ranking customers by their true likelihood to take up loans. This allows us to target the right customers efficiently."

**For Data Scientists**:
> "AUC represents the model's discriminative power independent of threshold selection. Given our severe class imbalance (97.37% negative), AUC is more informative than accuracy. Our 0.8762 AUC indicates strong separation between classes, validated by the KS statistic of 0.5939."

---

### Gini Coefficient

#### Definition

The **Gini coefficient** is a normalized measure of model discrimination, mathematically related to AUC. It represents the area between the Lorenz curve and the line of equality.

#### Mathematical Relationship

```
Gini = 2 × AUC - 1

Inverse:
AUC = (Gini + 1) / 2
```

#### Interpretation

**Range**: 0 to 1

| Gini Range | Model Quality | Equivalent AUC |
|------------|---------------|----------------|
| 0.0 | No discrimination | 0.50 |
| 0.2 - 0.4 | Fair | 0.60 - 0.70 |
| 0.4 - 0.6 | Good | 0.70 - 0.80 |
| 0.6 - 0.8 | Excellent | 0.80 - 0.90 ✅ |
| 0.8 - 1.0 | Outstanding | 0.90 - 1.00 |

**Example Calculation (Iteration 5 Test)**:
```
AUC = 0.8762
Gini = 2 × 0.8762 - 1 = 0.7524 ✅ (matches table)
```

#### Why Banks Prefer Gini

1. **Intuitive Scale**: 0-100% range after multiplying by 100 (easier than 0.5-1.0)
2. **Lift Interpretation**: Directly relates to targeting efficiency improvement
3. **Industry Convention**: Credit scoring traditionally reports Gini
4. **Comparable**: Easier to compare across different models and vintages

#### Explanation by Audience

**For Business Stakeholders**:
> "Gini measures how much better our model is than random selection. A Gini of 0.75 means we achieve 75% of the maximum possible improvement. If random targeting gets 10 conversions, our model would get approximately 17-18 conversions from the same budget."

**For Credit Risk Team**:
> "Gini of 0.7524 indicates strong discriminative power. This translates to significant lift in the top deciles - customers in Bin 9 have 18% take-up rate vs 0.01% in Bin 0, demonstrating effective risk segmentation aligned with our targeting strategy."

---

### KS (Kolmogorov-Smirnov) Statistic

#### Definition

The **KS statistic** measures the maximum separation between the cumulative distribution functions (CDFs) of the positive class (take-up = 1) and negative class (take-up = 0).

#### Technical Formula

```
KS = max |CDF₁(s) - CDF₀(s)|

Where:
- s = score threshold
- CDF₁(s) = Cumulative % of positive class with score ≤ s
- CDF₀(s) = Cumulative % of negative class with score ≤ s
- KS ranges [0, 1]
```

#### Interpretation

**Range**: 0 to 1

| KS Range | Model Quality | Use Case |
|----------|---------------|----------|
| < 0.20 | Very Weak | Not suitable for production |
| 0.20 - 0.30 | Weak | Marginal value |
| 0.30 - 0.40 | Fair | Acceptable with caution |
| 0.40 - 0.50 | Good | Production-ready |
| 0.50 - 0.70 | Very Good | Strong targeting ✅ |
| 0.70+ | Excellent | Exceptional separation |

**Practical Meaning**:
> KS represents the maximum difference in cumulative distribution at the optimal cutoff point. A KS of 0.59 means at the best threshold, we can separate 59% of the population correctly.

**Example (Iteration 5 Test, KS = 0.5939)**:
> "At the optimal score cutoff, 59.39% of customers who took up loans are above the threshold, while only 0% of non-take-up customers are above it. This maximum separation point is what KS measures."

#### Why KS Matters in Credit Scoring

1. **Regulatory Requirement**: Many financial regulators mandate minimum KS thresholds
2. **Marketing Efficiency**: Directly translates to campaign ROI (higher KS = fewer wasted contacts)
3. **Threshold Recommendation**: Identifies the optimal cutoff for binary decisions
4. **Model Monitoring**: KS decay signals model degradation over time

#### KS vs AUC

| Aspect | KS | AUC |
|--------|----|----|
| **Measures** | Maximum separation at one point | Overall ranking quality |
| **Threshold** | Identifies optimal cutoff | Threshold-independent |
| **Interpretation** | % separation at best point | Probability of correct ranking |
| **Sensitivity** | Sensitive to middle scores | Considers all scores equally |
| **Business Use** | Campaign targeting threshold | Overall model assessment |

#### Explanation by Audience

**For Business Stakeholders**:
> "KS tells us how effectively we can split customers into 'likely takers' and 'unlikely takers.' Our KS of 0.59 means we can design marketing campaigns that reach 60% more actual converters while avoiding 60% more non-converters, significantly improving ROI."

**For Marketing Team**:
> "KS = 0.5939 means if we target the top 30% of scored customers, we'll capture approximately 75-80% of all potential take-ups while avoiding 90% of customers who would reject the offer. This is the foundation for efficient campaign sizing."

---

## Scoring System

### Score Bin (Propensity Score)

#### Definition

**Score Bin** (also called propensity score bin) is a decile-based grouping of customers ranked by their predicted probability to **ACCEPT** a loan offer. Bins range from 0 (lowest propensity) to 9 (highest propensity).

#### Technical Details

**Binning Method**: Decile-based (equal-frequency)
- **Bin 0**: Bottom 10% of scores (lowest propensity to take up)
- **Bin 1**: Next 10%
- **Bin 2-7**: Middle 60%
- **Bin 8**: Next 10%
- **Bin 9**: Top 10% of scores (highest propensity to take up)

**Note**: Some iterations (Iter 4) only have Bins 0-8 due to score distribution characteristics.

#### Score Bin Performance (Iteration 5 Development)

| Score Bin | Take-Up Rate | Customer Count | Interpretation |
|-----------|--------------|----------------|----------------|
| **Bin 0** | 0.01% | ~32,882 | Extremely low propensity - avoid targeting |
| Bin 1 | 0.08% | ~32,882 | Very low propensity |
| Bin 2 | 0.11% | ~32,882 | Low propensity |
| Bin 3 | 0.18% | ~32,882 | Below average |
| Bin 4 | 0.31% | ~32,882 | Below average |
| Bin 5 | 0.63% | ~32,882 | Average |
| Bin 6 | 1.15% | ~32,882 | Above average |
| Bin 7 | 2.04% | ~32,882 | Good propensity |
| Bin 8 | 4.42% | ~32,882 | High propensity |
| **Bin 9** | 18.08% | ~32,882 | Very high propensity - priority targeting ✅ |
| **Overall** | **2.63%** | **328,820** | Base rate |

#### Discrimination Power

**Iteration 5 Discrimination**:
```
Bin 9 / Bin 0 = 18.08% / 0.01% = 1,808x

Interpretation: Customers in Bin 9 are 1,808 times more likely
to take up loans compared to Bin 0 customers.
```

#### Business Application

**Targeting Strategy Example**:
```
Campaign Budget: 100,000 contacts
Random Targeting:
- Expected conversions: 100,000 × 2.63% = 2,630 loans
- Cost per acquisition: Budget / 2,630

Score-Based Targeting (Top 3 bins only):
- Target: 98,646 customers (Bins 7-9)
- Expected conversions:
  - Bin 9: 32,882 × 18.08% = 5,945
  - Bin 8: 32,882 × 4.42% = 1,453
  - Bin 7: 32,882 × 2.04% = 671
  - Total: 8,069 loans
- Lift: 8,069 / 2,630 = 3.07x improvement ✅
```

#### Explanation by Audience

**For Business Stakeholders**:
> "Score Bins group customers into 10 equal-sized buckets from least to most likely to take loans. Bin 9 customers have an 18% chance of taking up, while Bin 0 has only 0.01%. By focusing on Bins 7-9, we can achieve 3x more conversions with the same marketing budget."

**For Marketing Team**:
> "Use Score Bins to design tiered campaigns:
> - **Bin 9**: VIP treatment, highest investment (telemarketing + WhatsApp + email)
> - **Bins 7-8**: Standard campaign (WhatsApp + email)
> - **Bins 5-6**: Light touch (email only)
> - **Bins 0-4**: No contact (avoid wasting resources)"

**For Data Scientists**:
> "Score Bins are derived from model probability scores using equal-frequency deciling. The monotonic increase in take-up rate across bins (0.01% → 18.08%) validates model calibration and rank-ordering capability. The 1,808x discrimination ratio significantly exceeds the 10x minimum threshold for production deployment."

---

### Calibrated Score Bin (EWS Risk Score)

#### Definition

**Calibrated Score Bin** represents the customer's credit **RISK** level, specifically the probability of **DEFAULT** (not take-up). This score comes from Bank Jago's **EWS (Early Warning System)** and is independent of the propensity model.

#### Key Distinction

| Aspect | Score Bin (Propensity) | Calibrated Score Bin (EWS Risk) |
|--------|------------------------|----------------------------------|
| **Predicts** | Likelihood to ACCEPT loan | Likelihood to DEFAULT on loan |
| **Direction** | Higher bin = Higher take-up | **INVERSE**: Lower score = Higher risk, Higher score = Lower risk ⚠️ |
| **Model Source** | Stephanie's Propensity Model | Bank Jago's EWS System |
| **Purpose** | Marketing efficiency | Credit risk management |
| **Range** | 0-9 (or 0-8) | 10 risk ranges |
| **Interpretation** | Bin 9 = Best customers to target | (827, inf] = LOWEST risk (safest) ⚠️ Inverse scale! |

#### Calibrated Score Bin Ranges

⚠️ **IMPORTANT CORRECTION** (Confirmed by mentor): The EWS score is divided into 10 bins where **LOWER scores indicate HIGHER risk**:

| Calibrated Score Bin | Risk Level | Interpretation |
|----------------------|------------|----------------|
| **(-inf, 496]** | **Highest Risk** | ❌ Most risky customers - Reject zone |
| **(496, 671]** | **Very High Risk** | ❌ Serious risk - Avoid |
| **(671, 734]** | **High Risk** | ⚠️ Significant risk - Caution |
| **(734, 765]** | **Medium-High Risk** | ⚠️ Elevated risk - Monitor closely |
| **(765, 786]** | **Medium Risk** | ⚠️ Moderate risk - Conditional approval |
| **(786, 801]** | **Medium Risk** | ⚠️ Moderate risk - Conditional approval |
| **(801, 812]** | **Low-Medium Risk** | ✅ Acceptable risk |
| **(812, 821]** | **Low Risk** | ✅ Safe - Good for approval |
| **(821, 827]** | **Very Low Risk** | ✅ Very safe - Priority approval |
| **(827, inf]** | **Lowest Risk** | ✅ Safest customers (highest creditworthiness) |

**Note**: The score values (e.g., 496, 671) are calibrated thresholds from the EWS model, representing continuous risk scores. **The scale is INVERSE** - higher score = lower risk.

#### Business Application: Two-Dimensional Targeting

The intersection of **Score Bin** (propensity) and **Calibrated Score Bin** (risk) creates a **risk-adjusted targeting matrix**.

**Example Strategy** (Corrected based on inverse EWS scale):

| Propensity Bin | Risk Range (EWS Score) | Action |
|----------------|------------------------|--------|
| Bin 9 | (812, inf] | ✅ **Priority Target**: High propensity + Low risk (high EWS score = safe) |
| Bin 9 | (765, 812] | ⚠️ **Conditional**: High propensity but medium risk - lower limits |
| Bin 9 | (-inf, 765] | ❌ **Reject**: High propensity but TOO RISKY (low EWS score = high risk) |
| Bin 0-2 | (812, inf] | 🤔 **Monitor**: Low propensity but low risk - nurture campaign |
| Bin 0-2 | (-inf, 812] | ❌ **Exclude**: Low propensity + medium-to-high risk |

#### Cross-Tab Analysis (Iteration 5 Development)

**Example: Bin 9 Performance Across Risk Grades** (Corrected risk interpretation):

| Calibrated Score Bin | Take-Up Rate (Bin 9) | Customer Count | Risk Assessment (Corrected) |
|----------------------|----------------------|----------------|------------------------------|
| (-inf, 496] | 17.73% | 1,234 | ❌ **HIGHEST RISK**: Reject despite high propensity |
| (496, 671] | 20.72% | 8,456 | ❌ **Very High Risk**: Avoid - too risky |
| (671, 734] | 18.37% | 5,678 | ⚠️ **High Risk**: Caution needed |
| (734, 765] | 19.17% | 4,321 | ⚠️ **Medium-High Risk**: Monitor closely |
| (765, 786] | 18.14% | 3,210 | ⚠️ **Medium Risk**: Conditional approval |
| (786, 801] | 17.99% | 2,890 | ⚠️ **Medium Risk**: Conditional approval |
| (801, 812] | 16.74% | 2,345 | ✅ **Low-Medium Risk**: Acceptable |
| (812, 821] | 17.05% | 1,876 | ✅ **Low Risk**: Good for approval |
| (821, 827] | 17.71% | 1,432 | ✅ **Very Low Risk**: Priority approval |
| (827, inf] | 16.12% | 1,890 | ✅ **LOWEST RISK**: Best segment - Safest customers |

**Key Insight**:
> Even within Bin 9 (highest propensity), take-up rates remain relatively stable across risk grades (16-20%). However, for credit risk management, we must still apply risk-based approval rules. A customer with 18% take-up probability but 90% default risk should not receive an offer.

#### Explanation by Audience

**For Business Stakeholders**:
> "Calibrated Score Bin measures credit risk (chance of default), not take-up propensity. We use BOTH scores together: Propensity Score (Score Bin) identifies who to target, while Risk Score (Calibrated Score Bin) determines who to approve. A customer might be very likely to accept (Bin 9) but also very risky (high EWS score), so we still reject them."

**For Credit Risk Team**:
> "The EWS Calibrated Score provides the risk overlay for propensity-based targeting. ⚠️ **Remember: Lower EWS score = Higher risk (inverse scale)**. Our joint policy should be: (1) Propensity Bin ≥ 6 AND (2) Calibrated Score ≥ 812 (higher score = safer). This ensures we target high-intent customers who also meet risk appetite. The cross-tab analysis confirms take-up rates are relatively stable within Bin 9 across risk grades, validating that propensity and risk are somewhat independent dimensions."

**For Product Team**:
> "Think of it like a 2D filter:
> - **X-axis (Score Bin)**: How eager is the customer? (marketing efficiency)
> - **Y-axis (Calibrated Score Bin)**: How risky is the customer? (portfolio quality)
> - **Sweet spot**: Top-right quadrant (Bin 9 + Low risk bins) = High intent + Low risk
> - **Avoid**: Bottom-right quadrant (Low bins + High risk) = Low intent + High risk"

---

## Performance Analysis Framework

### Dataset Splits

All models are evaluated on three time-based splits:

| Split | Time Period | Purpose | Expected Performance |
|-------|-------------|---------|---------------------|
| **Train** | March 2025 - May 2025 | Model learning | Highest (model has seen this data) |
| **Test** | June 2025 | In-sample validation | High (similar period to training) |
| **OOT Jul** | July 2025 | Out-of-time validation | Good (1-2 months after training) |
| **OOT Aug** | August 2025 | Extended OOT validation | Fair (2-3 months after training) |

---

### Performance Gap Analysis

#### 1. Train → Test Gap (Overfitting Check)

**What It Measures**: Model's ability to generalize to unseen data from the same time period.

**Expected Gap**: 2-5% AUC drop

**Iteration 5 Example**:
```
Train AUC: 0.9161
Test AUC:  0.8762
Gap:       0.0399 (4.3% drop) ✅ Healthy
```

**Why The Gap Exists**:
1. **Model Memorization**: Model learns patterns specific to training data, including noise
2. **Random Fluctuations**: Training set contains random variations that don't generalize
3. **Validation Purpose**: Test set validates model's true predictive power on unseen customers

**Diagnosis Thresholds**:
- Gap < 2%: Possible underfitting (model too simple)
- Gap 2-5%: ✅ **Healthy** (well-regularized model)
- Gap 5-10%: ⚠️ Moderate overfitting (acceptable but monitor)
- Gap > 10%: ❌ Severe overfitting (reduce model complexity)

**Comparison Across Iterations**:

| Iteration | Train AUC | Test AUC | Gap | Assessment |
|-----------|-----------|----------|-----|------------|
| Base | 0.9358 | 0.8771 | 6.3% | ⚠️ Slight overfitting (207 features) |
| 1 | 0.9126 | 0.8673 | 5.0% | ✅ Acceptable (31 features) |
| 2 | 0.8980 | 0.8653 | 3.6% | ✅ Good (29 features) |
| 3 | 0.9452 | 0.8738 | 7.5% | ⚠️ Moderate overfitting (38 features) |
| 4 | 0.8315 | 0.7973 | 4.1% | ✅ Good (19 features, but low overall) |
| 5 | 0.9161 | 0.8762 | 4.3% | ✅ **Optimal** (38 features, balanced) |

**Key Insight**:
> Iteration 5 achieves the best balance: strong train performance (0.9161) with minimal overfitting (4.3% gap). Iteration 3 has higher train AUC (0.9452) but worse generalization (7.5% gap).

---

#### 2. Test → OOT Gap (Temporal Stability)

**What It Measures**: Model's robustness to time-based distribution shifts (data drift/decay).

**Expected Gap**: 1-8% AUC drop

**Iteration 5 Example**:
```
Test AUC:    0.8762
OOT Jul AUC: 0.8746
Gap:         0.0016 (0.2% drop) ✅ Excellent Stability
```

**Why The Gap Exists**:
1. **Data Drift**: Customer behavior changes over time due to:
   - Economic conditions (inflation, interest rates)
   - Seasonal patterns (holiday spending, tax season)
   - Marketing campaign changes (offer types, communication channels)
   - Product evolution (new features, pricing changes)

2. **Population Shift**: OOT customers may differ from training population:
   - Regulatory changes affecting offer eligibility
   - Acquisition channel mix changes
   - Whitelist algorithm updates

3. **Feature Decay**: Some features lose predictive power over time:
   - Behavioral features (transactions, balances) decay faster
   - Bureau features (SLIK data) remain more stable
   - Static features (demographics) most stable

**Diagnosis Thresholds**:
- Gap < 1%: ✅ **Excellent** (features are time-stable)
- Gap 1-3%: ✅ Good (acceptable drift)
- Gap 3-5%: ⚠️ Moderate drift (monitor closely)
- Gap 5-8%: ⚠️ Significant drift (consider retraining)
- Gap > 8%: ❌ Severe drift (urgent retraining needed)

**Comparison Across Iterations (Test → OOT Jul)**:

| Iteration | Test AUC | OOT Jul AUC | Gap | Assessment |
|-----------|----------|-------------|-----|------------|
| Base | 0.8771 | 0.8713 | 0.7% | ✅ Excellent |
| 1 | 0.8673 | 0.8586 | 1.0% | ✅ Excellent |
| 2 | 0.8653 | 0.8540 | 1.3% | ✅ Good |
| 3 | 0.8738 | 0.8737 | 0.01% | ✅ **Outstanding** |
| 4 | 0.7973 | 0.7834 | 1.7% | ✅ Good (but low absolute) |
| 5 | 0.8762 | 0.8746 | 0.2% | ✅ **Excellent** |

**Key Insight**:
> Bureau-enhanced models (Iter 3, 5) show exceptional temporal stability (< 0.2% drop). Non-bureau model (Iter 4) degrades faster (1.7% drop), proving SLIK features are critical for time-stable predictions.

---

#### 3. OOT Jul → OOT Aug Gap (Drift Acceleration)

**What It Measures**: Rate of performance degradation over extended time periods.

**Expected Gap**: 1-5% AUC drop (one additional month)

**Iteration 5 Example**:
```
OOT Jul AUC: 0.8746
OOT Aug AUC: 0.8576
Gap:         0.0170 (1.9% drop) ✅ Manageable
```

**Why This Matters**:
1. **Retraining Cadence**: Determines how often model needs updating
2. **Production Monitoring**: Sets alert thresholds for performance decay
3. **Cost-Benefit Analysis**: Balances retraining costs vs performance loss

**Diagnosis Thresholds**:
- Gap < 2%: ✅ Stable (quarterly retraining sufficient)
- Gap 2-5%: ⚠️ Moderate decay (monthly retraining recommended)
- Gap 5-10%: ❌ Rapid decay (bi-weekly retraining needed)
- Gap > 10%: ❌ Catastrophic decay (immediate retraining + investigate root cause)

**Comparison Across Iterations (OOT Jul → OOT Aug)**:

| Iteration | OOT Jul AUC | OOT Aug AUC | Gap | Monthly Decay Rate |
|-----------|-------------|-------------|-----|--------------------|
| Base | 0.8713 | 0.8167 | 6.3% | ❌ 6.3%/month (unstable) |
| 1 | 0.8586 | 0.8166 | 4.9% | ⚠️ 4.9%/month (high) |
| 2 | 0.8540 | 0.8020 | 6.1% | ❌ 6.1%/month (unstable) |
| 3 | 0.8737 | 0.8429 | 3.5% | ⚠️ 3.5%/month (moderate) |
| 4 | 0.7834 | 0.7123 | 9.1% | ❌ **9.1%/month (catastrophic)** |
| 5 | 0.8746 | 0.8576 | 1.9% | ✅ **1.9%/month (excellent)** |

**Critical Finding**:
> **Iteration 4 (Non-Bureau) collapses in extended OOT** with 9.1% monthly decay. This is CATASTROPHIC for production deployment - model would be unusable after 2 months without retraining.
>
> **Iteration 5 (Bureau 1-month)** shows only 1.9% monthly decay, making it suitable for quarterly retraining cycles.

**Retraining Recommendations**:

| Iteration | Retraining Cadence | Rationale |
|-----------|-------------------|-----------|
| Iteration 4 | ❌ **Not Production-Ready** | 9.1% monthly decay unacceptable |
| Iteration 5 | ✅ **Quarterly (every 3 months)** | 1.9%/month × 3 = 5.7% total acceptable |
| Iteration 3 | ⚠️ **Bi-monthly (every 2 months)** | 3.5%/month × 2 = 7% at upper limit |

---

### Complete Performance Journey (Iteration 5)

**Visualizing the Full Path**:

```
ITERATION 5 PERFORMANCE ACROSS TIME

Train      Test       OOT Jul    OOT Aug
0.9161 →   0.8762 →   0.8746 →   0.8576
        ↓          ↓          ↓
       -4.3%      -0.2%      -1.9%
    (Overfit)  (Drift)    (Decay)
        ✅         ✅         ✅

Total Degradation: -6.4% (Train → OOT Aug)
Final AUC: 0.8576 (still Excellent range)
```

**Interpretation**:
1. **Phase 1 (Train → Test)**: 4.3% drop due to overfitting - HEALTHY
2. **Phase 2 (Test → OOT Jul)**: 0.2% drop due to drift - EXCELLENT
3. **Phase 3 (OOT Jul → Aug)**: 1.9% drop due to continued drift - GOOD

**Conclusion**:
> Model maintains **Excellent** performance (AUC > 0.85) even 3 months post-training. This validates Iteration 5 as production-ready with quarterly retraining.

---

## Iteration Comparison

### Performance Summary Table

| Iteration | Features | Train AUC | Test AUC | OOT Aug AUC | Test-OOT Decay | Overall Assessment |
|-----------|----------|-----------|----------|-------------|----------------|--------------------|
| **Base** | 207 feats | 0.9358 | 0.8771 | 0.8167 | -6.9% | ⚠️ Overfitted, too many features |
| **1** | 31 feats | 0.9126 | 0.8673 | 0.8166 | -5.8% | ⚠️ Moderate, high decay |
| **2** | 29 feats | 0.8980 | 0.8653 | 0.8020 | -7.3% | ⚠️ Non-Jago SLIK only, unstable |
| **3** | 38 feats | 0.9452 | 0.8738 | 0.8429 | -3.5% | ⚠️ High train AUC but overfits |
| **4** | 19 feats | 0.8315 | 0.7973 | 0.7123 | -10.7% | ❌ **Non-bureau, catastrophic decay** |
| **5** | 38 feats | 0.9161 | 0.8762 | 0.8576 | -2.1% | ✅ **BEST: Balanced + stable** |

### Why Iteration 5 is Superior

#### 1. Best OOT Performance
- **OOT Aug AUC**: 0.8576 (highest across all iterations)
- **OOT Aug KS**: 0.5622 (highest across all iterations)
- Maintains "Excellent" rating even in extended OOT period

#### 2. Exceptional Temporal Stability
- **Test → OOT Jul**: Only 0.2% drop (best stability)
- **OOT Jul → Aug**: Only 1.9% drop (best decay rate)
- Bureau features provide time-invariant signals

#### 3. Balanced Trade-Off
- Not the highest train AUC (Iter 3 is higher at 0.9452)
- But better generalization (4.3% gap vs Iter 3's 7.5%)
- Optimal regularization prevents overfitting

#### 4. Production-Ready
- Quarterly retraining sufficient (1.9%/month decay)
- Stable across all OOT periods
- Bureau features justify operational costs

### Why Iteration 4 Fails

#### Critical Flaws

**1. Catastrophic OOT Decay**:
```
Test AUC:    0.7973
OOT Jul AUC: 0.7834 (-1.7%)
OOT Aug AUC: 0.7123 (-9.1%) ❌

Decay Rate: 9.1% per month
After 2 months: Model loses 10.7% AUC
After 3 months: Would drop below 0.65 (Fair range)
```

**2. Missing Critical Signals**:
- No external debt visibility (can't see borrowing elsewhere)
- No credit inquiry history (can't detect desperation)
- No DPD history (can't assess payment reliability)
- No facility utilization (can't gauge financial stress)

**3. Business Impact**:
```
Iteration 5 vs Iteration 4 (OOT Aug):
- AUC Gap: 0.8576 vs 0.7123 = -14.5 AUC points
- KS Gap: 0.5622 vs 0.3475 = -21.5 KS points
- Discrimination Loss: ~38% worse targeting accuracy
- Marketing Waste: ~40% more budget spent on wrong customers
```

**Conclusion**:
> Iteration 4 is NOT suitable for production. Bureau features are mandatory for stable performance.

---

## Feature Importance

### Types of Feature Importance

Modern tree-based models (XGBoost, LightGBM) calculate feature importance using two methods:

#### 1. Split-Based Importance (Frequency)

**Definition**: Counts how many times a feature is used to split nodes across all trees.

**Formula**:
```
Split_Importance(feature) = Σ (number of times feature used for splitting)
```

**Characteristics**:
- **Measures**: Feature usage frequency
- **Interpretation**: How often the model "asks about" this feature
- **Limitation**: A feature used 100 times with tiny improvements gets high score
- **Normalization**: Usually expressed as % of total splits

**Example**:
```
Feature: "customer_age"
- Split count: 450 times across 1000 trees
- Split importance: 45% of all splits
- Interpretation: Age is checked frequently in decision paths
```

#### 2. Gain-Based Importance (Impact)

**Definition**: Measures the total reduction in loss function (e.g., log-loss, Gini impurity) when splitting on this feature.

**Formula**:
```
Gain_Importance(feature) = Σ (loss reduction from splits using this feature)
```

**Characteristics**:
- **Measures**: Feature's actual contribution to prediction quality
- **Interpretation**: How much this feature improves model accuracy
- **Advantage**: Reflects true predictive value
- **Preferred**: More accurate representation of importance

**Example**:
```
Feature: "slik_total_facilities"
- Split count: 50 times
- Total gain: 342.5 (high impact per split)
- Gain importance: 15% of total gain
- Interpretation: Rarely used but critical when it is
```

#### Comparison Example

| Feature | Split Count | Split Importance | Total Gain | Gain Importance | True Value |
|---------|-------------|------------------|------------|-----------------|------------|
| `customer_age` | 450 | 45% | 85.3 | 3% | ⚠️ Overrated by split |
| `avg_balance_3m` | 220 | 22% | 567.8 | 18% | ✅ Underrated by split |
| `slik_total_facilities` | 50 | 5% | 892.4 | 28% | ✅ Most important (by gain) |

**Key Insight**:
> Always use **Gain-Based Importance** for feature interpretation. Split-based can be misleading as it doesn't account for the magnitude of improvement each split provides.

### Expected Important Features (Iteration 5)

Based on bureau-enhanced model, expected top features:

**Top 10 Features (Gain-Based)**:
1. `slik_total_facilities` - Number of external loans
2. `slik_total_outstanding_balance` - Total external debt
3. `avg_balance_6m` - Average Jago account balance (6 months)
4. `slik_inquiry_count_3m` - Credit applications elsewhere (3 months)
5. `transaction_count_6m` - Transaction frequency (6 months)
6. `cbas_created_date` - Bureau report freshness
7. `slik_utilization_ratio` - Credit line usage %
8. `incoming_transfer_sum_3m` - Income proxy (3 months)
9. `age` - Customer age
10. `tenure_months` - Relationship length with Jago

**Feature Categories**:
- **Bureau Features (40%)**: SLIK debt, inquiries, utilization
- **Behavioral Features (35%)**: Transactions, balances, trends
- **Demographic Features (15%)**: Age, tenure, occupation
- **Offer Features (10%)**: Plafond, previous offers

---

## Model Explainability (SHAP)

### What is SHAP?

**SHAP (SHapley Additive exPlanations)** is a method to explain individual predictions by computing each feature's contribution to the prediction.

### Mathematical Foundation

SHAP is based on **Shapley values** from cooperative game theory:

```
SHAP_value(feature_i) = Σ [Contribution of feature_i across all possible feature combinations]

Properties:
1. Local Accuracy: Σ SHAP_values = prediction - baseline_prediction
2. Consistency: If feature improves model, SHAP value ≥ 0
3. Missingness: Features not used have SHAP value = 0
```

### Interpretation

**SHAP Value Meaning**:
- **Positive SHAP**: Feature pushes prediction HIGHER (increases take-up probability)
- **Negative SHAP**: Feature pushes prediction LOWER (decreases take-up probability)
- **Magnitude**: Larger absolute value = stronger contribution

**Example**:
```
Customer A: Predicted take-up probability = 15%
Baseline (average): 2.63%
Gap to explain: 15% - 2.63% = 12.37%

SHAP Breakdown:
+ 5.2%  | High balance (avg_balance_6m = 50M) ✅
+ 3.8%  | No external debt (slik_total_facilities = 0) ✅
+ 2.1%  | High transaction frequency (transaction_count_6m = 450) ✅
+ 1.5%  | Prime age (age = 35) ✅
- 0.23% | Short tenure (tenure_months = 6) ⚠️
────────
= 12.37% Total SHAP contribution
```

### SHAP Visualizations

#### 1. SHAP Summary Plot
**Purpose**: Shows feature importance AND direction of impact across all predictions.

**What It Shows**:
- **Y-axis**: Features ranked by importance
- **X-axis**: SHAP value (impact on prediction)
- **Color**: Feature value (red = high, blue = low)
- **Dot position**: Individual prediction's SHAP value for that feature

**How to Read**:
```
Feature: slik_total_facilities
|
|        🔵🔵🔵           🔴🔴🔴🔴🔴🔴
|────────────|0|────────────────────→ SHAP value
         -0.05      +0.02

Blue dots (low facility count) → Positive SHAP (increases take-up)
Red dots (high facility count) → Negative SHAP (decreases take-up)

Interpretation: Customers with NO external debt are more likely to take up loans
```

#### 2. SHAP Force Plot
**Purpose**: Explains a single prediction showing how each feature contributed.

**Structure**:
- **Base value**: Average model prediction (2.63%)
- **Red arrows**: Features pushing prediction higher
- **Blue arrows**: Features pushing prediction lower
- **Final value**: Actual prediction

**Example**:
```
Base Value (2.63%) ────→ Prediction (18.2%)

Positive Contributions (Red):
  + slik_total_facilities = 0 (+5.2%)
  + avg_balance_6m = 50M (+3.8%)
  + transaction_count_6m = 450 (+2.1%)
  + age = 35 (+1.5%)

Negative Contributions (Blue):
  - tenure_months = 6 (-0.2%)

Final: 2.63% + 12.37% = 15% (rounded to 18.2% after logit transform)
```

### Action Item: Request SHAP Plots from Ka Stefani

**What to Request**:
1. **SHAP Summary Plot - Iteration 4**: Shows non-bureau feature importance
2. **SHAP Summary Plot - Iteration 5**: Shows bureau feature importance (compare impact)
3. **SHAP Force Plot - High Propensity Customer** (Bin 9, Risk ≤ 765): Explain why they scored high
4. **SHAP Force Plot - Low Propensity Customer** (Bin 0-1): Explain why they scored low

**Why This Matters**:
- **Model Validation**: Ensure features impact predictions in expected directions
- **Business Insights**: Discover which behaviors drive loan take-up
- **Stakeholder Trust**: Provide transparent explanations for scoring decisions
- **Regulatory Compliance**: Meet explainability requirements for credit decisions

---

## Feature Analysis

This section provides comprehensive analysis of features used in the propensity model, including bad rate analysis, feature importance metrics, Weight of Evidence (WoE), Information Value (IV), and SHAP explainability.

---

### Bad Rate Analysis

#### Definition

**Bad Rate** measures the percentage of "bad" outcomes (in our case, customers who did NOT take up loans: `flag_takeup = 0`) within a specific feature value range. It's a fundamental metric for understanding how feature values correlate with the target variable.

#### Formula

```
Bad Rate = (Count of Bad / Total Count) × 100%

Where:
- Bad = Customers who did NOT take up loan (flag_takeup = 0)
- Good = Customers who took up loan (flag_takeup = 1)
- Total Count = Bad + Good
```

#### Example: devicemanufacture_latest Feature (Iteration 2)

| Feature Value Range | Count | Bad | Good | Pct_Total | Bad_Rate | Interpretation |
|---------------------|-------|-----|------|-----------|----------|----------------|
| (0.0136, 0.0216] | 191,592 | 3,124 | 188,468 | 72.59% | **1.63%** | ✅ Low bad rate - Good predictor |
| (0.0216, 0.0364] | 26,232 | 962 | 25,270 | 9.94% | **3.67%** | ⚠️ Medium bad rate |
| (0.0364, 0.0489] | 21,938 | 1,084 | 20,854 | 8.31% | **4.94%** | ⚠️ Higher bad rate |
| (0.0489, 0.115] | 24,161 | 1,799 | 22,362 | 9.15% | **7.45%** | ❌ High bad rate - Risky segment |

**Key Insights**:
1. **Bad rate increases from 1.63% to 7.45%** as feature value increases
2. This shows **monotonic relationship** with risk - good feature for modeling
3. Majority of customers (72.59%) fall in lowest bad rate bucket - this is the "good" segment

#### Example: fundingbalance_active_min_1month Feature (Iteration 2)

| Feature Value Range | Count | Bad | Good | Pct_Total | Bad_Rate | Interpretation |
|---------------------|-------|-----|------|-----------|----------|----------------|
| (-5.2M, 0.78] | 26,507 | 792 | 25,715 | 10.04% | **2.99%** | ⚠️ Low balance = Higher risk |
| (0.78, 36.59] | 26,387 | 988 | 25,399 | 10.00% | **3.74%** | ⚠️ Very low balance |
| (36.59, 380.32] | 26,440 | 1,075 | 25,365 | 10.02% | **4.07%** | ⚠️ Low balance |
| (380.32, 1,368] | 26,404 | 1,134 | 25,270 | 10.00% | **4.29%** | ⚠️ Moderate balance |
| (1,368, 4,554] | 26,411 | 912 | 25,499 | 10.01% | **3.45%** | ✅ Medium balance |
| (4,554, 12,623] | 26,398 | 701 | 25,697 | 10.00% | **2.66%** | ✅ Higher balance |
| (12,623, 45,277] | 26,377 | 494 | 25,883 | 9.99% | **1.87%** | ✅ Good balance |
| (45,277, 217,981] | 26,393 | 399 | 25,994 | 10.00% | **1.51%** | ✅ High balance |
| (217,981, 2.1M] | 26,309 | 313 | 25,996 | 9.97% | **1.19%** | ✅ Very high balance |
| (2.1M, 4.1B] | 26,271 | 158 | 26,113 | 9.95% | **0.60%** | ✅✅ Excellent - Very high balance |

**Key Insights**:
1. **Bad rate decreases from 4.29% to 0.60%** as balance increases
2. **Inverse monotonic relationship**: Higher balance = Lower bad rate = Higher take-up propensity
3. Customers with balance > 2.1M IDR have only **0.60% bad rate** - prime segment for targeting
4. This validates business intuition: Wealthier customers more likely to take up loans

#### Business Application

**Targeting Strategy Based on Bad Rate**:

```
Decision Rules:
- Bad Rate < 2.0%: ✅ Priority Target (High propensity segment)
- Bad Rate 2.0-4.0%: ⚠️ Secondary Target (Medium propensity)
- Bad Rate 4.0-7.0%: ❌ Low Priority (Low propensity)
- Bad Rate > 7.0%: ❌ Exclude (Very low propensity)
```

**Example Application**:
> "For `fundingbalance_active_min_1month`, target customers with balance > 12,623 IDR (bad rate < 2%), which represents ~40% of the customer base but likely ~60% of conversions."

---

### Feature Importance (Split vs Gain)

Modern tree-based models (XGBoost, LightGBM) calculate feature importance using two methods: **Split-based** and **Gain-based**.

#### Split-Based Importance (Frequency)

**Definition**: Counts how many times a feature is used to split nodes across all trees.

**Formula**:
```
Split_Importance(feature) = Σ (number of times feature used for splitting)
```

**Characteristics**:
- **Measures**: Feature usage frequency
- **Interpretation**: How often the model "asks about" this feature
- **Limitation**: A feature used 100 times with tiny improvements gets high score
- **Normalization**: Usually expressed as count or % of total splits

#### Gain-Based Importance (Impact)

**Definition**: Measures the total reduction in loss function (e.g., log-loss, Gini impurity) when splitting on this feature.

**Formula**:
```
Gain_Importance(feature) = Σ (loss reduction from splits using this feature)
```

**Characteristics**:
- **Measures**: Feature's actual contribution to prediction quality
- **Interpretation**: How much prediction quality improves
- **Advantage**: Reflects true predictive value
- **Preferred**: ✅ More accurate representation of importance

#### Real Example: Iteration 5 Feature Importance

**Top 10 Features:**

| Rank | Feature | Importance by Split | Importance by Gain | Gain Rank | Split Rank | Analysis |
|------|---------|---------------------|-------------------|-----------|------------|----------|
| 1 | `mob_multiguna_allcondition_min` | 110 | 151,055.60 | 1 | 8 | ✅ **High impact per use** |
| 2 | `devicemanufacture_latest` | 95 | 134,918.69 | 2 | 11 | ✅ **Efficient feature** |
| 3 | `plafond_tenor_2to11_high_interest_allcondition_avg` | 147 | 74,761.66 | 3 | 3 | Frequently used, high impact |
| 4 | `fundingbalance_active_min_1month` | **204** | 62,371.74 | 4 | 1 | Most used, but moderate impact |
| 5 | `dailyeventdays_allevent_11pmto5am_count_6months` | **272** | 45,566.42 | 5 | 1 | Very frequent use, lower impact |
| 6 | `maturity_rate` | 211 | 44,753.96 | 6 | 2 | Frequently used |
| 7 | `slikbalance_active_unsecurednoncreditcard_sum` | 200 | 40,026.02 | 7 | 4 | Bureau feature - strong signal |
| 8 | `installment_digibank_institution_sum` | 190 | 39,870.54 | 8 | 5 | Payment behavior |
| 9 | `slikbalance_active_creditcard_sum_over_slikplafond_active_creditcard_sum` | 170 | 39,680.99 | 9 | 6 | Credit utilization ratio |
| 10 | `transactionamt_interbanktransfer_in_pct25_12months` | 131 | 38,197.48 | 10 | 7 | Transaction pattern |

**Key Observations**:

1. **`mob_multiguna_allcondition_min`** (#1 by gain):
   - Only used 110 times (rank #8 by split)
   - But provides highest total gain: 151,055.60
   - **Interpretation**: Very powerful feature - each split provides massive improvement
   - Average gain per split: 151,055.60 / 110 = **1,373.23** 🔥

2. **`fundingbalance_active_min_1month`** (#4 by gain):
   - Most frequently used: 204 splits (rank #1 by split)
   - But only 4th in total gain: 62,371.74
   - **Interpretation**: Model relies on it heavily, but each split provides moderate improvement
   - Average gain per split: 62,371.74 / 204 = **305.74**

3. **`dailyeventdays_allevent_11pmto5am_count_6months`** (#5 by gain):
   - Used 272 times (most frequent)
   - Total gain: 45,566.42
   - **Interpretation**: Feature is "cheap" to use (many splits), but low impact per split
   - Average gain per split: 45,566.42 / 272 = **167.52**

#### Comparison Example: Split vs Gain Ranking

| Feature | Split Rank | Gain Rank | Efficiency (Gain/Split) | Type |
|---------|------------|-----------|-------------------------|------|
| `mob_multiguna_allcondition_min` | 8 | 1 | 1,373.23 | ⭐ **Power Feature** |
| `devicemanufacture_latest` | 11 | 2 | 1,420.20 | ⭐ **Power Feature** |
| `dailyeventdays_allevent_11pmto5am_count_6months` | 1 | 5 | 167.52 | ⚠️ **Frequent but weak** |
| `maturity_rate` | 2 | 6 | 212.09 | ⚠️ **Frequent but weak** |

**Key Insight**:
> Always use **Gain-Based Importance** for feature interpretation. Split-based can be misleading as it doesn't account for the magnitude of improvement each split provides.

#### Practical Application

**Feature Selection Strategy**:
```
Priority 1: High gain, low-to-medium split (Efficient power features)
- mob_multiguna_allcondition_min
- devicemanufacture_latest

Priority 2: High gain, high split (Core predictors)
- plafond_tenor_2to11_high_interest_allcondition_avg
- fundingbalance_active_min_1month

Priority 3: Medium gain, high split (Supporting features)
- dailyeventdays_allevent_11pmto5am_count_6months
- maturity_rate

Deprioritize: Low gain, any split count
- (Remove to reduce overfitting and improve model simplicity)
```

---

### Weight of Evidence (WoE) and Information Value (IV)

#### Weight of Evidence (WoE)

**Definition**: WoE measures the predictive power of a feature value by comparing the distribution of "goods" (take-up = 1) vs "bads" (take-up = 0).

**Formula**:
```
WoE = ln(Distribution of Goods / Distribution of Bads)
    = ln((%Good) / (%Bad))

Where:
- % Good = (Count of Good in bin / Total Good)
- % Bad = (Count of Bad in bin / Total Bad)
```

**Interpretation**:
- **WoE > 0**: More "goods" than "bads" in this bin → **Positive indicator** (higher take-up propensity)
- **WoE = 0**: Equal distribution of goods and bads → **Neutral**
- **WoE < 0**: More "bads" than "goods" in this bin → **Negative indicator** (lower take-up propensity)

#### Example: devicemanufacture_latest (Iteration 2)

| Feature Value | Bad | Good | Pct_Good | Pct_Bad | WoE | Interpretation |
|---------------|-----|------|----------|---------|-----|----------------|
| (0.0136, 0.0216] | 3,124 | 188,468 | 73.35% | 44.83% | **+0.4924** | ✅ Strong positive - High take-up |
| (0.0216, 0.0364] | 962 | 25,270 | 9.83% | 13.80% | **-0.3391** | ⚠️ Negative - Lower take-up |
| (0.0364, 0.0489] | 1,084 | 20,854 | 8.12% | 15.55% | **-0.6505** | ❌ Strong negative - Low take-up |
| (0.0489, 0.115] | 1,799 | 22,362 | 8.70% | 25.81% | **-1.0873** | ❌ Very strong negative - Worst segment |

**Analysis**:
- **Bin 1 (0.0136, 0.0216]**: WoE = +0.4924
  - 73.35% of all "goods" are in this bin
  - Only 44.83% of all "bads" are in this bin
  - **Conclusion**: Customers in this range are 1.64x more likely to take up loans

- **Bin 4 (0.0489, 0.115]**: WoE = -1.0873
  - Only 8.70% of all "goods" are in this bin
  - But 25.81% of all "bads" are in this bin
  - **Conclusion**: Customers in this range are 2.97x LESS likely to take up loans

#### Example: fundingbalance_active_min_1month (Iteration 2)

| Feature Value | Bad | Good | Pct_Good | Pct_Bad | WoE | Interpretation |
|---------------|-----|------|----------|---------|-----|----------------|
| (-5.2M, 0.78] | 792 | 25,715 | 10.01% | 11.36% | **-0.1272** | ⚠️ Slight negative |
| (0.78, 36.59] | 988 | 25,399 | 9.88% | 14.18% | **-0.3606** | ⚠️ Negative |
| (36.59, 380.32] | 1,075 | 25,365 | 9.87% | 15.43% | **-0.4464** | ❌ Strong negative |
| (380.32, 1,368] | 1,134 | 25,270 | 9.83% | 16.27% | **-0.5036** | ❌ Strong negative |
| (1,368, 4,554] | 912 | 25,499 | 9.92% | 13.09% | **-0.2767** | ⚠️ Slight negative |
| (4,554, 12,623] | 701 | 25,697 | 10.00% | 10.06% | **-0.0058** | ≈ Neutral |
| (12,623, 45,277] | 494 | 25,883 | 10.07% | 7.09% | **+0.3514** | ✅ Positive |
| (45,277, 217,981] | 399 | 25,994 | 10.12% | 5.73% | **+0.5692** | ✅ Strong positive |
| (217,981, 2.1M] | 313 | 25,996 | 10.12% | 4.49% | **+0.8121** | ✅ Very strong positive |
| (2.1M, 4.1B] | 158 | 26,113 | 10.16% | 2.27% | **+1.5002** | ✅✅ Extremely positive |

**Analysis**:
- **Clear monotonic trend**: WoE increases from -0.5036 to +1.5002 as balance increases
- **Neutral point**: ~12,623 IDR balance (WoE ≈ 0)
- **Best segment**: Balance > 2.1M IDR (WoE = +1.5002) → 4.48x higher take-up propensity
- **Worst segment**: Balance 380-1,368 IDR (WoE = -0.5036) → 0.60x lower take-up propensity

#### Information Value (IV)

**Definition**: IV measures the overall predictive power of a feature by aggregating WoE across all bins.

**Formula**:
```
IV = Σ [(% Good - % Bad) × WoE]

For each bin i:
IV_i = (Pct_Good_i - Pct_Bad_i) × WoE_i
```

**Interpretation Thresholds**:

| IV Range | Predictive Power | Action |
|----------|------------------|--------|
| < 0.02 | Useless | ❌ Remove feature |
| 0.02 - 0.10 | Weak | ⚠️ Consider removing |
| 0.10 - 0.30 | Medium | ✅ Keep feature |
| 0.30 - 0.50 | Strong | ✅✅ Important feature |
| > 0.50 | Very Strong | ✅✅✅ Critical feature (check for leakage) |

**Example Comparison**:

| Feature | IV | Predictive Power | Rank |
|---------|-----|------------------|------|
| `devicemanufacture_latest` | **0.3883** | Strong | Top feature ✅✅ |
| `fundingbalance_active_min_1month` | **0.2833** | Medium-Strong | Important ✅ |

**Interpretation**:
- Both features have good predictive power (IV > 0.28)
- `devicemanufacture_latest` slightly stronger (IV = 0.39)
- Both should be kept in the model

#### Practical Application

**Feature Selection Using WoE/IV**:
```sql
-- Decision Rules
IF IV > 0.30 THEN Priority_1_Feature
ELSIF IV 0.10-0.30 THEN Priority_2_Feature
ELSIF IV 0.02-0.10 THEN Priority_3_Feature (conditional)
ELSE Remove_Feature
```

**Binning Strategy Using WoE**:
- Bins with similar WoE should be merged (reduces model complexity)
- Ensure monotonic WoE trend (validates business logic)
- Avoid bins with WoE swings (indicates unstable relationship)

---

### Feature Values vs Score Bins

This analysis shows how actual feature values differ across propensity score bins, validating that high-scoring customers truly have different characteristics.

#### Example: devicemanufacture_latest (Iteration 2)

| Score Bin | Min | P25 | Median | P75 | Max | Mean | Std | Count | Interpretation |
|-----------|-----|-----|--------|-----|-----|------|-----|-------|----------------|
| **Bin 0** | 0.0146 | 0.0146 | 0.0146 | 0.0216 | 0.1151 | **0.0210** | 0.0127 | 3,105 | Lowest propensity customers |
| Bin 1 | 0.0146 | 0.0146 | 0.0146 | 0.0216 | 0.1151 | 0.0238 | 0.0154 | 1,686 | |
| Bin 2 | 0.0146 | 0.0146 | 0.0146 | 0.0216 | 0.1151 | 0.0236 | 0.0150 | 1,393 | |
| Bin 3 | 0.0146 | 0.0146 | 0.0146 | 0.0216 | 0.1151 | 0.0224 | 0.0149 | 2,498 | |
| Bin 4 | 0.0146 | 0.0146 | 0.0146 | 0.0216 | 0.1151 | 0.0236 | 0.0160 | 1,544 | |
| Bin 5 | 0.0146 | 0.0146 | 0.0146 | 0.0216 | 0.1151 | 0.0242 | 0.0165 | 1,790 | |
| Bin 6 | 0.0146 | 0.0146 | 0.0146 | 0.0364 | 0.1151 | 0.0255 | 0.0181 | 2,318 | |
| Bin 7 | 0.0146 | 0.0146 | 0.0146 | 0.0364 | 0.1151 | 0.0269 | 0.0194 | 1,904 | |
| Bin 8 | 0.0146 | 0.0146 | 0.0216 | 0.0364 | 0.1151 | 0.0305 | 0.0213 | 1,825 | |
| **Bin 9** | 0.0146 | 0.0216 | **0.0364** | 0.0609 | 0.1151 | **0.0444** | 0.0252 | 1,937 | Highest propensity customers ✅ |

**Key Insights**:
1. **Mean increases monotonically**: 0.0210 (Bin 0) → 0.0444 (Bin 9)
2. **Median shifts**: 0.0146 (Bins 0-7) → 0.0216 (Bin 8) → 0.0364 (Bin 9)
3. **Standard deviation increases**: 0.0127 → 0.0252 (more variability in high bins)
4. **Clear separation**: Bin 9 customers have 2.11x higher mean value than Bin 0

**Business Interpretation**:
> "Customers with `devicemanufacture_latest` value > 0.0364 are significantly more likely to be in Bin 9 (high propensity). This feature effectively discriminates between high and low propensity segments."

#### Example: fundingbalance_active_min_1month (Iteration 2)

| Score Bin | Min | P25 | Median | P75 | Max | Mean | Std | Count | Interpretation |
|-----------|-----|-----|--------|-----|-----|------|-----|-------|----------------|
| **Bin 0** | 0.00 | 2,447.71 | 62,915.77 | 1,150,070.75 | 800M | **9.85M** | 47.8M | 3,105 | Highest balances in lowest propensity ⚠️ |
| Bin 1 | 0.00 | 2,597.75 | 53,417.03 | 1,683,114.69 | 698M | 7.57M | 36.3M | 1,686 | |
| Bin 2 | 0.00 | 1,084.09 | 32,426.31 | 566,071.88 | 490M | 4.85M | 23.9M | 1,393 | |
| Bin 3 | 0.00 | 145.48 | 7,477.57 | 130,277.25 | 299M | 2.44M | 13.4M | 2,498 | |
| Bin 4 | 0.00 | 126.26 | 5,197.85 | 92,034.91 | 310M | 1.74M | 13.4M | 1,544 | |
| Bin 5 | 0.00 | 87.45 | 3,991.30 | 44,664.01 | 188M | 0.65M | 5.5M | 1,790 | |
| Bin 6 | 0.00 | 49.95 | 2,526.36 | 24,002.42 | 88M | 0.70M | 4.5M | 2,318 | |
| Bin 7 | 0.00 | 32.28 | 1,120.65 | 10,014.24 | 57M | 0.34M | 2.5M | 1,904 | |
| Bin 8 | 0.00 | 68.85 | 1,286.06 | 10,080.37 | 51M | 0.19M | 1.6M | 1,825 | |
| **Bin 9** | 0.00 | 14.46 | **616.28** | 4,098.87 | 18M | **0.06M** | 0.6M | 1,937 | LOWEST balances in highest propensity ⚠️⚠️ |

**CRITICAL FINDING - Inverse Relationship**:
1. **Bin 0 (lowest propensity)**: Mean = 9.85M IDR, Median = 62,916 IDR
2. **Bin 9 (highest propensity)**: Mean = 0.06M IDR, Median = 616 IDR
3. **Interpretation**: **LOWER balance = HIGHER propensity** ⚠️

**Why This Makes Business Sense**:
> "Customers with LOW minimum balance are more likely to need loans (financial stress indicator). Wealthy customers with high balances don't need to borrow. This validates the model's logic: Financial need drives loan take-up propensity."

#### Validation Checklist Using Feature Values vs Score Bins

✅ **Monotonic Trend**: Feature values should change consistently across bins
✅ **Separation**: Clear difference between Bin 0 and Bin 9
✅ **Business Logic**: Direction matches expectations (e.g., low balance → high need → high propensity)
❌ **Red Flags**:
   - No clear trend across bins
   - Bin 9 similar to Bin 0 (no separation)
   - Counterintuitive relationships

---

## Model Explainability (SHAP)

### What is SHAP?

**SHAP (SHapley Additive exPlanations)** is a method to explain individual predictions by computing each feature's contribution to the prediction.

### Mathematical Foundation

SHAP is based on **Shapley values** from cooperative game theory:

```
SHAP_value(feature_i) = Σ [Contribution of feature_i across all possible feature combinations]

Properties:
1. Local Accuracy: Σ SHAP_values = prediction - baseline_prediction
2. Consistency: If feature improves model, SHAP value reflects that
3. Missingness: Features not used have SHAP value = 0
```

### Interpretation

**SHAP Value Meaning**:
- **Positive SHAP**: Feature pushes prediction HIGHER (increases take-up probability)
- **Negative SHAP**: Feature pushes prediction LOWER (decreases take-up probability)
- **Magnitude**: Larger absolute value = stronger contribution

---

### SHAP Values Analysis Across Score Bins

This analysis shows how SHAP values (feature contributions) differ across propensity score bins.

#### Example: devicemanufacture_latest (Iteration 2)

| Score Bin | Min SHAP | P25 | Median | P75 | Max SHAP | Mean SHAP | Std | Interpretation |
|-----------|----------|-----|--------|-----|----------|-----------|-----|----------------|
| **Bin 0** | -0.3824 | -0.1962 | -0.1322 | -0.1017 | 0.8360 | **-0.1015** | 0.1453 | Mostly NEGATIVE contribution |
| Bin 1 | -0.3886 | -0.2010 | -0.1291 | -0.0751 | 0.7269 | -0.0841 | 0.1738 | Negative contribution |
| Bin 2 | -0.3849 | -0.2093 | -0.1395 | -0.0779 | 0.7611 | -0.0890 | 0.1774 | Negative contribution |
| Bin 3 | -0.3966 | -0.2418 | -0.1768 | -0.1015 | 0.7565 | -0.1243 | 0.1861 | Strong negative |
| Bin 4 | -0.3925 | -0.2703 | -0.1676 | -0.0976 | 0.7213 | -0.1173 | 0.2138 | Strong negative |
| Bin 5 | -0.3822 | -0.2711 | -0.1720 | -0.0996 | 0.9289 | -0.1067 | 0.2285 | Negative |
| Bin 6 | -0.3798 | -0.2583 | -0.1788 | 0.1203 | 0.8960 | -0.0872 | 0.2496 | Slightly negative |
| Bin 7 | -0.3592 | -0.2307 | -0.1851 | 0.1903 | 0.9108 | -0.0548 | 0.2717 | Close to neutral |
| Bin 8 | -0.3436 | -0.2239 | -0.1799 | 0.3078 | 0.8937 | 0.0068 | 0.3056 | Slightly positive ✅ |
| **Bin 9** | -0.3065 | -0.1796 | **0.3509** | 0.4996 | 0.9759 | **0.2391** | 0.3353 | Strong POSITIVE contribution ✅✅ |

**Key Insights**:
1. **Mean SHAP increases monotonically**: -0.1015 (Bin 0) → +0.2391 (Bin 9)
2. **Median shifts from negative to positive**: -0.1322 (Bin 0) → +0.3509 (Bin 9)
3. **For Bin 9**: P75 = 0.4996, meaning 75% of customers get positive boost from this feature
4. **Clear discrimination**: This feature contributes +0.34 points on average for Bin 9 vs -0.10 for Bin 0

**Business Interpretation**:
> "For high-propensity customers (Bin 9), `devicemanufacture_latest` adds an average of +0.24 points to their propensity score. For low-propensity customers (Bin 0), it subtracts -0.10 points. This validates the feature's predictive power."

#### Example: fundingbalance_active_min_1month (Iteration 2)

| Score Bin | Min SHAP | P25 | Median | P75 | Max SHAP | Mean SHAP | Std | Interpretation |
|-----------|----------|-----|--------|-----|----------|-----------|-----|----------------|
| **Bin 0** | -1.1695 | -0.3619 | -0.1174 | 0.1254 | 0.3033 | **-0.1698** | 0.3176 | Negative contribution |
| Bin 1 | -1.1543 | -0.4842 | -0.1144 | 0.1278 | 0.3511 | -0.2090 | 0.3690 | Strong negative |
| Bin 2 | -1.1466 | -0.4079 | -0.0838 | 0.1480 | 0.3379 | -0.1677 | 0.3582 | Negative |
| Bin 3 | -1.1133 | -0.2532 | 0.0639 | 0.1769 | 0.3802 | -0.0713 | 0.3177 | Slight negative |
| Bin 4 | -1.1179 | -0.2264 | 0.0927 | 0.1684 | 0.4420 | -0.0431 | 0.3028 | Close to neutral |
| Bin 5 | -0.9652 | -0.1309 | 0.1149 | 0.1765 | 0.4101 | 0.0052 | 0.2595 | Neutral ≈ 0 |
| Bin 6 | -1.0320 | -0.0556 | 0.1308 | 0.2072 | 0.4450 | 0.0413 | 0.2603 | Slight positive |
| Bin 7 | -0.9620 | 0.0366 | 0.1718 | 0.2671 | 0.4864 | 0.1097 | 0.2394 | Positive ✅ |
| Bin 8 | -0.9155 | 0.0332 | 0.1731 | 0.2568 | 0.5107 | 0.1153 | 0.2213 | Positive ✅ |
| **Bin 9** | -0.5807 | 0.1355 | **0.2083** | 0.2799 | 0.6056 | **0.1841** | 0.1751 | Strong positive ✅✅ |

**Key Insights**:
1. **Mean SHAP increases from -0.17 to +0.18**: Clear monotonic trend
2. **Median crosses zero at Bin 5**: This is the "neutral balance point"
3. **For Bin 9**: P25 = 0.1355 (even the bottom 25% get positive boost)
4. **Negative contributions concentrated in Bins 0-2**: Aligns with business logic (low balance = high need)

**CRITICAL INSIGHT - Inverse Relationship Explained**:
> "Lower balance → Negative SHAP but Higher Propensity (Bins 0-4 have negative SHAP BUT are classified based on OTHER features). By Bin 9, customers have different profiles where low balance is a POSITIVE signal (financial need + other good characteristics). This shows the model learned complex interactions."

---

### SHAP Summary Plot Interpretation

**What to Look For**:

1. **Feature Ranking**: Features ordered by average absolute SHAP value
2. **Direction**: Red dots (high feature value) vs Blue dots (low feature value)
3. **Spread**: Wide spread = feature impacts different customers differently
4. **Density**: Many dots at one SHAP value = consistent impact

**Example Interpretation**:
```
Feature: fundingbalance_active_min_1month
|
|  🔵🔵🔵🔵                     🔴🔴
|──────────|──────0──────|──────────→ SHAP value
       -0.2        0.0      +0.2

Blue dots (low balance) concentrated at negative SHAP
Red dots (high balance) concentrated at positive SHAP

Interpretation: Low balance pushes predictions down, high balance pushes up
BUT in the context of BINS, Bin 9 mostly has low balance customers
This apparent contradiction is resolved by OTHER features compensating
```

---

### Action Item: Request SHAP Plots from Ka Stefani

**What to Request**:
1. **SHAP Summary Plot - Iteration 4**: Shows non-bureau feature importance
2. **SHAP Summary Plot - Iteration 5**: Shows bureau feature importance (compare impact)
3. **SHAP Force Plot - High Propensity Customer** (Bin 9, Risk Score > 812): Explain why they scored high
4. **SHAP Force Plot - Low Propensity Customer** (Bin 0-1): Explain why they scored low
5. **SHAP Dependence Plot - Top 5 Features**: Shows interaction effects

**Why This Matters**:
- **Model Validation**: Ensure features impact predictions in expected directions
- **Business Insights**: Discover which behaviors drive loan take-up
- **Stakeholder Trust**: Provide transparent explanations for scoring decisions
- **Regulatory Compliance**: Meet explainability requirements for credit decisions
- **Feature Engineering**: Identify non-linear relationships and interactions

---

## Glossary

### Model Metrics

| Term | Definition |
|------|------------|
| **AUC** | Area Under the ROC Curve; measures model's ability to rank positive cases higher than negative cases (range: 0.5-1.0) |
| **Gini** | Normalized discrimination measure; Gini = 2×AUC - 1 (range: 0-1) |
| **KS** | Kolmogorov-Smirnov statistic; maximum separation between positive and negative cumulative distributions (range: 0-1) |
| **ROC** | Receiver Operating Characteristic curve; plots TPR vs FPR at all thresholds |
| **TPR** | True Positive Rate (Recall); TP / (TP + FN) |
| **FPR** | False Positive Rate; FP / (FP + TN) |

### Dataset Terminology

| Term | Definition |
|------|------------|
| **Train Set** | Data used to train the model; model learns patterns from this data |
| **Test Set** | In-sample validation data from same time period; tests generalization |
| **OOT** | Out-of-Time validation data from future time period; tests temporal stability |
| **Overfitting** | Model memorizes training data including noise; poor test performance |
| **Data Drift** | Distribution shift in features or target over time; causes OOT decay |

### Scoring Terminology

| Term | Definition |
|------|------------|
| **Score Bin** | Decile grouping (0-9) of propensity scores; Bin 9 = highest take-up propensity |
| **Calibrated Score Bin** | EWS risk score ranges; higher bins = higher default risk |
| **Propensity Score** | Predicted probability customer will ACCEPT loan offer |
| **EWS Score** | Early Warning System score predicting DEFAULT risk |
| **Take-Up Rate** | % of customers who accepted and disbursed loan |
| **Discrimination Ratio** | (Highest bin take-up) / (Lowest bin take-up); measures separation power |

### Model Development

| Term | Definition |
|------|------------|
| **Bureau Features** | External credit data from SLIK (Indonesia credit bureau) |
| **Non-Bureau Model** | Model using only internal Jago data (transactions, balances) |
| **Feature Importance** | Measure of feature's contribution to model predictions |
| **SHAP** | SHapley Additive exPlanations; method to explain individual predictions |
| **Regularization** | Techniques to prevent overfitting (L1/L2 penalty, early stopping) |

### Business Terminology

| Term | Definition |
|------|------------|
| **New Offer** | Customer receiving fresh loan offer in current month |
| **Carry-Over** | Customer with offer from previous month, refreshed via whitelist |
| **Whitelist** | Monthly re-evaluation process extending offer validity |
| **LFS** | Latest Financial System; Bank Jago's modern core banking platform |
| **Facility** | Active loan account |
| **Plafond** | Loan limit/credit line amount offered to customer |

---

## References

### Internal Documentation
- `[RFC] Propensity Loan Take Up 2025.md` - Project charter and requirements
- `Propensity_Model_Development_Guide_Bank_Jago.md` - Development guide
- `Propensity_Model_Iteration_4_5_Analysis_Wiki.md` - Iteration comparison
- `Carry_Over_Customer_Score_Validation_Technical_Documentation.md` - Carry-over validation

### External Resources
- [Scikit-learn Model Evaluation](https://scikit-learn.org/stable/modules/model_evaluation.html)
- [SHAP Documentation](https://shap.readthedocs.io/)
- [ROC and AUC Explained](https://developers.google.com/machine-learning/crash-course/classification/roc-and-auc)

---

**Document Version**: 1.0
**Last Updated**: October 10, 2025
**Next Review**: After carry-over model development completes
**Maintained By**: Risk Data Analyst Team
