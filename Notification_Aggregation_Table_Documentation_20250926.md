# [WIKI] Notification Aggregation Table for Propensity Model

**Version**: 1.0
**Date**: September 26, 2025
**Analyst**: Ammar Siregar
**Project**: Propensity Loan Take Up 2025
**Status**: ✅ **COMPLETED**

---

## 1. 🎯 **Objective**

The primary goal was to create a single, comprehensive aggregation table that consolidates various user notification events (App Notifications, WhatsApp, Email) for each customer within their specific offer period. This aggregated data serves as features for a machine learning model to measure notification effectiveness and predict loan take-up propensity.

---

## 2. 📊 **Business Context**

### 2.1 Assessment Phase
- **Initial Phase**: Data flows were understood and stakeholder interviews conducted (with Kak Zaki) to gather business insights
- **Challenge**: Data was fragmented across multiple systems like "puzzle pieces"
- **Discovery**: Two distinct customer types with different communication strategies

### 2.2 Customer Segmentation
Based on previous analysis, customers are categorized into:

#### **New Offer Customers**
- **Definition**: Customers receiving a fresh loan offer in the analysis month
- **Communication Strategy**: Aggressive, multi-channel "burst" campaigns
- **Behavior**: Higher engagement rates, more responsive to notifications
- **Primary Channels**: Push notifications, Bell notifications, InApp messages

#### **Carry-Over Customers**
- **Definition**: Customers with active offers from previous months (via whitelist process)
- **Communication Strategy**: Patient, value-focused "drip" campaigns
- **Behavior**: Lower initial engagement, respond well to specialized offers
- **Primary Channels**: Email retargeting, WhatsApp, specialized InApp campaigns

### 2.3 Business Rules Discovered
- **Whitelist Mechanism**: Monthly process refreshes offer expiration dates based on "GTM customer score"
- **App-less Customers**: WhatsApp is primary channel for customers without Jago app (identifiable via null `token` in profiles table)
- **Email Strategy**: Primarily used for carry-over customer retargeting with `event_date > created_at` filter
- **Time-sensitive Logic**: Different communication timing strategies adapt monthly

---

## 3. 🗂️ **Data Sources & Architecture**

### 3.1 Base Table
**`data-prd-adhoc.temp_ammar.ammar_customer_loan_details`**
- **Purpose**: Master customer offer table
- **Key Fields**:
  - `customer_id`, `business_date`, `created_at`, `expires_at`, `start_date`
  - `flag_has_facility`, `flag_takeup`, `is_new_offer`, `is_carry_over_offer`

### 3.2 Notification Data Sources

#### **App Notifications (CleverTap)**
**Table**: `jago-bank-data-production.jago_clevertap.journey_notifications`
- **Key Fields**: `customer_id`, `event_date`, `event_name`, `campaign_name`, `campaign_type`
- **Channels Covered**: Push, Bell (App Inbox), InApp, Email
- **Event Types**: Different patterns per channel
  - **Push/Bell**: "Notification Sent" → "Notification Clicked"
  - **InApp**: "Notification Viewed" → "Notification Clicked"
  - **Email**: "Notification Viewed" → "Notification Clicked"

#### **WhatsApp Events**
**Table**: `jago-data-sandbox.temp_digital_lending.gtm_whatsapp_blast_result`
- **Key Fields**: `customer_id`, `SentAt`, `ReadAt`, `TemplateName`
- **Structure**: Multiple timestamp columns requiring UNPIVOT
- **Mapping**: `SentAt` → 'Sent', `ReadAt` → 'Click' (for consistency)

---

## 4. ⚙️ **Core Implementation Logic**

### 4.1 Critical Time Window Filtering

This is the **most critical** business rule for accurate feature engineering:

#### **Time Window Definition**
```sql
event_date > offer.created_at
AND event_date < COALESCE(offer.start_date, offer.expires_at)
```

#### **Time Window Logic**
- **Start Boundary**: `event_date > created_at`
  - Only notifications sent **after** the offer was created

- **End Boundary**: `COALESCE(start_date, expires_at)`
  - **Scenario 1 (Customer Converts)**: If `flag_takeup = 1`, end date = `start_date`
    - **Rationale**: Only count notifications that could have influenced the conversion decision
    - **Excludes**: Post-conversion retention campaigns
  - **Scenario 2 (Customer Doesn't Convert)**: If `flag_takeup = 0`, end date = `expires_at`
    - **Rationale**: Capture all notification interactions during the offer's valid period

#### **Business Justification**
- **Option A (Current)**: Exclude post-conversion notifications - **SELECTED**
  - Better for **predictive modeling** (only pre-conversion signals)
  - Avoids contamination from retention campaigns
- **Option B (Alternative)**: Include all notifications during offer period
  - Better for **engagement analysis** but not suitable for propensity modeling

### 4.2 Event Interaction Mapping

Due to different event naming conventions across channels, standardized mapping was required:

#### **CleverTap Channels**
```sql
CASE
  -- Standard Push/Bell events
  WHEN UPPER(event_name) LIKE '%SENT%' THEN 'Sent'
  WHEN UPPER(event_name) LIKE '%CLICK%' THEN 'Click'

  -- InApp specific events
  WHEN campaign_type = 'InApp' AND UPPER(event_name) LIKE '%VIEWED%' THEN 'Sent'
  WHEN campaign_type = 'InApp' AND UPPER(event_name) LIKE '%CLICKED%' THEN 'Click'

  -- Email specific events
  WHEN campaign_type = 'Email' AND UPPER(event_name) LIKE '%VIEWED%' THEN 'Sent'
  WHEN campaign_type = 'Email' AND UPPER(event_name) LIKE '%CLICKED%' THEN 'Click'
END
```

#### **WhatsApp Events**
```sql
CASE
  WHEN event_name = 'Sent' THEN 'Sent'
  WHEN event_name = 'Read' THEN 'Click'  -- Map Read to Click for consistency
END
```

### 4.3 Performance Optimization

**JOIN ON Clause Filtering** (Mentor's Recommendation):
```sql
INNER JOIN offer o ON n.customer_id = o.customer_id
  -- Move time window filters to JOIN ON for better performance
  AND n.event_date BETWEEN '2025-08-01' AND CURRENT_DATE()
  AND n.event_date > o.created_at
  AND n.event_date < COALESCE(o.start_date, o.expires_at)
```

**Benefits**:
- Filters during join operation rather than after
- Significantly improved query performance
- Reduced intermediate result set size

---

## 5. 📈 **Final Feature Schema**

### 5.1 Customer Attributes
- `customer_id`: Unique customer identifier
- `business_date`: Analysis snapshot date (2025-08-31)
- `created_at`: Offer creation date
- `expires_at`: Offer expiration date
- `start_date`: Facility start date (if converted)
- `flag_has_facility`: Binary flag for facility existence
- `flag_takeup`: **Target variable** for propensity model
- `is_new_offer`: Binary flag for new offer customers
- `is_carry_over_offer`: Binary flag for carry-over customers

### 5.2 Notification Features

#### **Push Notifications**
- `push_sent_count`: Number of push notifications sent
- `push_click_count`: Number of push notification clicks
- `push_first_date`: Date of first push notification
- `push_last_date`: Date of last push notification

#### **Bell Notifications (App Inbox)**
- `bell_sent_count`: Number of bell notifications sent
- `bell_click_count`: Number of bell notification clicks
- `bell_first_date`: Date of first bell notification
- `bell_last_date`: Date of last bell notification

#### **InApp Notifications**
- `inapp_sent_count`: Number of InApp notifications viewed
- `inapp_click_count`: Number of InApp notification clicks
- `inapp_first_date`: Date of first InApp notification
- `inapp_last_date`: Date of last InApp notification

#### **Email Notifications**
- `email_sent_count`: Number of email notifications viewed
- `email_click_count`: Number of email notification clicks
- `email_first_date`: Date of first email notification
- `email_last_date`: Date of last email notification

#### **WhatsApp Notifications**
- `wa_sent_count`: Number of WhatsApp messages sent
- `wa_click_count`: Number of WhatsApp messages read
- `wa_first_date`: Date of first WhatsApp message
- `wa_last_date`: Date of last WhatsApp message

---

## 6. 🔍 **Key Findings & Insights**

### 6.1 Channel Effectiveness Patterns

#### **Click-Through Rates by Channel**
- **InApp**: 60-67% CTR (highest engagement)
- **Push**: 0.7-4% CTR (volume channel)
- **Bell**: 0.7-5% CTR (moderate engagement)
- **Email**: Low click rates, primarily for carry-over customers
- **WhatsApp**: High read rates, effective for app-less customers

#### **Customer Segment Performance**
- **New Offer customers consistently outperform** across all channels:
  - Bell: 5.11% vs 0.71% CTR (7x better)
  - Push: 4.01% vs 0.69% CTR (6x better)
  - InApp: 67.6% vs 62.68% CTR (slightly higher)

### 6.2 Channel Strategy Patterns

#### **New Offer Strategy: "Burst" Campaigns**
- High-density notifications across multiple channels
- Focus on activation and education campaigns
- Primary channels: Push, Bell, InApp
- Timeline: 2-5 days after offer creation

#### **Carry-Over Strategy: "Drip" Campaigns**
- Long-term nurturing over 3+ months
- Focus on retargeting and value enhancement
- Primary channels: Email, specialized InApp, WhatsApp
- Timeline: Extended period with periodic touchpoints

### 6.3 Data Quality Observations
- **Email effectiveness**: Only works for carry-over customers when `event_date > created_at`
- **WhatsApp reach**: Higher coverage with JOIN ON optimization (more historical events captured)
- **App-less customers**: WhatsApp serves as primary channel for customers with null/empty tokens
- **Post-conversion filtering**: Successfully excludes retention campaigns from propensity features

---

## 7. 📊 **Final Dataset Characteristics**

### 7.1 Dataset Statistics
- **Total Customers**: 297,476 customers
- **Complete Universe**: All customers included (with zeros for no notifications)
- **Converted Customers**: Customers with `flag_takeup = 1`
- **Coverage Period**: August 2025 snapshot with historical events from 2025-01-01

### 7.2 Data Validation Results
- **No selection bias**: LEFT JOIN preserves all customers from base table
- **Proper time filtering**: Events correctly bounded by offer periods
- **Channel integration**: All 4 notification channels successfully aggregated
- **Business logic compliance**: Email and WhatsApp patterns match expected behaviors

---

## 8. 🛠️ **Technical Implementation**

### 8.1 Query Structure
```sql
WITH offer AS (...)           -- Base customer offers
, notifications AS (...)      -- CleverTap events with time filtering
, wa_unpivoted AS (...)      -- WhatsApp events with UNPIVOT
, all_notifications AS (...)  -- UNION ALL of both sources
, notification_journeys AS (...) -- Window functions for first/last dates
SELECT ...                   -- Final aggregation with LEFT JOIN
```

### 8.2 Query Performance
- **JOIN ON filtering**: Time window filters applied during join for efficiency
- **Proper indexing**: Utilizes customer_id and event_date indexes
- **Minimal data movement**: Aggregation performed after filtering

### 8.3 Execution Guidelines
- **Business date**: Currently set to '2025-08-31'
- **Event date range**: '2025-08-01' to CURRENT_DATE() for CleverTap partition requirements
- **Memory usage**: Manageable with CTE structure and proper filtering

---

## 9. 🎯 **Business Applications**

### 9.1 Propensity Model Features
The aggregated table provides ready-to-use features for machine learning:

#### **Primary Features**
- **Engagement Volume**: sent_count metrics across channels
- **Engagement Quality**: click_count metrics across channels
- **Timing Features**: first_date, last_date for recency analysis
- **Customer Segmentation**: is_new_offer, is_carry_over_offer flags

#### **Derived Features** (Recommended)
- **Channel CTRs**: click_count / sent_count per channel
- **Multi-channel Engagement**: Binary flags for channel usage
- **Total Engagement**: Sum across all channels
- **Engagement Recency**: Days since last notification

### 9.2 Expected Model Performance
Based on observed patterns, the model should learn:
- **High InApp engagement** → Higher conversion probability
- **New offer customers** → Higher baseline conversion probability
- **Multi-channel engagement** → Stronger conversion signals
- **WhatsApp effectiveness** for specific customer segments

---

## 10. 🔄 **Next Steps & Recommendations**

### 10.1 Model Development
1. **Feature Engineering**: Create derived engagement ratios and flags
2. **Model Training**: Use `flag_takeup` as target variable
3. **Validation**: Ensure temporal validation (train on past months, test on recent)
4. **Segmentation**: Consider separate models for new vs carry-over customers

### 10.2 Additional Features (Future Enhancement)
1. **App Status Flag**: Add `is_appless_customer` from CleverTap profiles table
2. **GTM Score Integration**: Include whitelist score as predictor
3. **Promo Eligibility**: Flag customers eligible for specific campaigns (July 2025+)
4. **Communication Channel Preferences**: Model customer channel responsiveness

### 10.3 Monitoring & Maintenance
1. **Monthly Refresh**: Update business_date for new analysis periods
2. **Data Quality Checks**: Monitor for new campaign types or event patterns
3. **Performance Tracking**: Compare model predictions vs actual outcomes
4. **Business Logic Updates**: Adjust time windows if business rules change

---

## 11. 🏷️ **Tags**

`#propensity-model` `#feature-engineering` `#notification-aggregation` `#machine-learning` `#customer-segmentation` `#data-pipeline` `#risk-analytics` `#loan-take-up`

---

## 12. 📚 **References**

- **Base Analysis**: `Monthly_Loan_Offer_Performance_Report_19_Sept_2025.md`
- **Cohort Definition**: `Propensity_Model_Cohort_Analysis_22_Sept_2025.md`
- **Communication Strategy**: `Loan_Notification_Strategy_Analysis_20250923.md`
- **Multi-channel Insights**: `Notification_Journey_Analysis_20250924.md`
- **Strategy Refinement**: `Post_Meeting_Analysis_And_Strategy_20250925.md`
- **Data Flow Guide**: `Data_Analysis_Flow_Guide_Bank_Jago.md`

---

*Last updated: September 26, 2025*
*Next review: October 26, 2025*