# Feature Analysis Section - TO BE INSERTED INTO MAIN WIKI

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

**END OF FEATURE ANALYSIS SECTION UPDATE**
