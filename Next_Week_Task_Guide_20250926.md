# 📋 Next Week Task Guide - Propensity Model Analysis

**Week of**: September 30 - October 4, 2025
**Analyst**: Ammar Siregar
**Mentor**: [Mentor Name]
**Project**: Propensity Loan Take Up 2025 - Phase 2

---

## 🎯 **Overview & Context**

Based on your mentor's guidance, you're moving into **Phase 2** of the propensity model project. This phase focuses on understanding carry-over customer behavior and learning to interpret propensity model outputs.

### **Strategic Context**
- **Current State**: Model 1 exists (built by Sefani) for **New customers only**
- **Your Role**: Analyze **Carry-over customers** and their activity patterns
- **Decision Point**: Will your analysis be used for:
  - **Path A**: Descriptive insights/reporting dimensions
  - **Path B**: Feature engineering for ML models

### **Future Model Scenarios**
- **Scenario 2A**: Build separate Model 2 for carry-over customers
- **Scenario 2B**: Build unified model combining both customer types

---

## 📚 **Key Concepts to Master**

Before starting, ensure you understand these definitions from your mentor:

### **Customer Types**
- **New Customer**: First-time offer recipient in current period
- **Carry-over Customer**: Previous period customer who didn't accept, now re-engaged

### **Activities & Performance**
- **Activity**: Proactive company engagement (Email=E, WhatsApp=W, Apps=A)
- **Take Up**: Customer accepts/uses an offer
- **Performance**: Activities measured over time periods

### **Time Window Metrics** (Critical for Analysis)
- **Current**: Activities within single analysis period
- **Last One Month**: Rolling total (current + 1 previous period)
- **Last Two Months**: Rolling total (current + 2 previous periods)
- **Ever/Long Time**: Cumulative total across customer history

---

## 🎯 **Main Tasks for This Week**

### **Task 1: Deliverables Submission** ⭐ **HIGH PRIORITY**
**Deadline**: Early in the week

#### **What to Submit:**
1. **Script 1**: Ad-hoc analysis table creation script (your aggregation query)
2. **Script 2**: Carry-over customer analysis script

#### **Guided Questions:**
- Do you have your final aggregation query properly documented?
- Should you clean up the query and add comprehensive comments?
- What analysis insights about carry-over vs new customers should you include?

---

### **Task 2: The "Ghost" Take-Up Analysis** ⭐ **HIGH PRIORITY**
**Objective**: Solve the mystery of carry-over customers who convert without recent activity

#### **The Problem to Investigate:**
- Carry-over customers who suddenly take up offers
- "No wind, no rain, but taken" phenomenon
- These customers may be influenced by **historical activities** from previous periods

#### **Your Analysis Framework:**
1. **Calculate Time Differences**: For customers who take up offers, measure days between:
   - Take-up date
   - Last activity date (Email/WhatsApp/App)

2. **Segment Analysis**: Calculate separately for:
   - New customers
   - Carry-over customers

3. **Draw Insights**: Compare average time differences
   - Similar times (e.g., ~10 days) = recent activity drives conversion
   - Longer times for carry-over (e.g., ~30 days) = historical activities have cumulative effect

#### **Guided Questions to Explore:**
- Which customers in your dataset have `flag_takeup = 1`?
- How can you calculate the time difference between their facility `start_date` and their last notification date?
- What patterns do you see when comparing New vs Carry-over customers?
- Are there customers who converted with very old last activities? What does this mean?

---

### **Task 3: Time-Window Performance Metrics** ⭐ **MEDIUM PRIORITY**
**Objective**: Build the foundation for understanding activity attribution windows

#### **Start with "Current" Metrics:**
Your mentor specifically said to focus on **Current** first, then expand.

#### **Implementation Approach:**
- You already have activity counts in your aggregation table
- Now you need to understand how to extend this to rolling time windows
- This will help determine the optimal attribution window for activities

#### **Guided Questions:**
- How does your current aggregation table measure the "Current" time window?
- What additional data would you need to calculate "Last One Month" metrics?
- How might you modify your time window filtering logic to support rolling periods?

---

### **Task 4: Propensity Model Interpretation** ⭐ **HIGH PRIORITY**
**Objective**: Learn to read and interpret propensity model outputs

#### **Key Metrics to Master:**
Your mentor wants you to understand:
- **AUC (Area Under the Curve)**
- **Gini coefficient**
- **KS (Kolmogorov-Smirnov) statistic**
- **Score Distribution charts**
- **Feature Importance plots**

#### **Learning Resources:**
- SOP Risk Model document (to be provided by mentor)
- Existing Model 1 report (built by Sefani)

#### **Guided Learning Questions:**
- What does an AUC of 0.75 vs 0.85 mean in business terms?
- How do you interpret a Gini coefficient for loan default prediction?
- What does the KS statistic tell you about model discrimination?
- How do you read feature importance plots to understand which variables drive predictions?
- What makes a "good" score distribution in a propensity model?

#### **Practical Application:**
- Review Model 1's performance on New customers
- Think about how these metrics might change for Carry-over customers
- Consider what "good performance" would look like for your future analysis

---

## 🔄 **Weekly Work Plan**

### **Monday-Tuesday: Foundation & Deliverables**
- [ ] Clean up and document your aggregation query
- [ ] Submit both required scripts to mentor
- [ ] Start reading the SOP Risk Model document
- [ ] Begin "Ghost" take-up analysis data exploration

### **Wednesday-Thursday: Deep Analysis**
- [ ] Complete time difference calculations for take-up customers
- [ ] Segment analysis: New vs Carry-over patterns
- [ ] Start interpreting Model 1 performance metrics
- [ ] Document initial findings on carry-over behavior

### **Friday: Synthesis & Learning**
- [ ] Synthesize insights from "Ghost" take-up analysis
- [ ] Complete propensity model metrics interpretation
- [ ] Prepare questions/discussion points for next mentor session
- [ ] Document learning progress and next steps

---

## 🤔 **Key Questions to Explore This Week**

### **Business Logic Questions:**
1. Why do some carry-over customers convert long after their last activity?
2. What is the optimal attribution window for marketing activities?
3. How different are New vs Carry-over customer behavior patterns?

### **Technical Questions:**
4. How can you modify time windows in your aggregation logic?
5. What additional features might be needed for carry-over customer modeling?
6. How do you interpret the performance of an existing propensity model?

### **Strategic Questions:**
7. Should carry-over customers have a separate model or be combined with new customers?
8. What insights from your analysis would be most valuable for Path A vs Path B?
9. How can you validate that your analysis approach is correct?

---

## 📊 **Success Criteria**

By the end of this week, you should be able to:

### **Analytics Skills**
- [ ] Calculate meaningful time-difference metrics for customer conversions
- [ ] Identify patterns in carry-over vs new customer behavior
- [ ] Explain the "ghost" take-up phenomenon with data evidence

### **Model Interpretation Skills**
- [ ] Read and explain AUC, Gini, and KS statistics
- [ ] Interpret score distribution charts
- [ ] Understand feature importance rankings
- [ ] Assess when a propensity model is performing well vs poorly

### **Business Understanding**
- [ ] Articulate why different customer segments might need different models
- [ ] Explain the business value of your carry-over customer analysis
- [ ] Recommend next steps for model development strategy

---

## 🚨 **Potential Challenges & Tips**

### **Challenge 1: Time Difference Calculations**
- **Tip**: Use your existing aggregation table as the base
- **Tip**: Focus on customers with `flag_takeup = 1` first
- **Tip**: Consider different "last activity" definitions per channel

### **Challenge 2: Model Metrics Interpretation**
- **Tip**: Start with practical business meaning before technical details
- **Tip**: Use concrete examples (e.g., "What does 0.8 AUC mean for loan approval?")
- **Tip**: Connect metrics to business decisions

### **Challenge 3: Data Complexity**
- **Tip**: Start simple with current time window, then add complexity
- **Tip**: Validate your logic with a few customer examples first
- **Tip**: Document assumptions and business rules clearly

---

## 📝 **Documentation Expectations**

### **For Script Deliverables:**
- Clear comments explaining business logic
- Example outputs or validation queries
- Performance notes and optimization details

### **For Analysis Findings:**
- Executive summary of key insights
- Data supporting the "ghost" take-up hypothesis
- Recommendations for attribution windows

### **For Model Learning:**
- Definitions of key metrics in your own words
- Examples of how to interpret model outputs
- Questions or areas needing clarification

---

## 🎯 **Next Week Preview**

Based on this week's findings, next week you'll likely:
- Apply your analysis to inform Path A vs Path B decision
- Begin feature engineering for potential Model 2
- Validate Model 1 performance on carry-over customers
- Design experiments for unified modeling approach

---

**Remember**: This is a learning journey. Focus on understanding the business context behind each technical task. Your mentor wants you to think like a risk analyst, not just a data processor.

Good luck! 🚀

---

*Created: September 26, 2025*
*Next Review: October 4, 2025*