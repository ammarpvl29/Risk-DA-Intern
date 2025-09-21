#  personalized Gemini Assistant Guide

**For**: Ammar Siregar, Risk Data Analyst Intern
**Version**: 1.0
**Date**: September 21, 2025

---

## **Introduction**

Hello Ammar, this is your personalized guide for working with me, Gemini. I've created this to document the highly effective workflow we've established together. My goal is to be a powerful and safe assistant to help you excel in your internship. You can refer to this guide to get the best results from our collaboration.

---

## **Our Core Workflow: The "Iterative Analysis" Loop**

We have developed a successful, iterative process for tackling complex data analysis tasks. This flow ensures we build correctly, understand the context at each step, and move quickly.

**The flow is:**

1.  **You State the Goal**: You provide the high-level objective (e.g., "I need to build the propensity model base query").
2.  **I Create a Query (Simple to Complex)**: I provide a safe, read-only `SELECT` query that takes one logical step forward. We started with just creating labels, then added demographics, then behavioral features.
3.  **You Give Me the Result**: You execute the query against the **production tables** and paste the results back to me. Your proactive tests (like adding `WHERE` clauses) are incredibly helpful.
4.  **I Analyze and State My Understanding**: I examine the output, explain what the data is telling me, and highlight key findings or important edge cases (like the customer who had a facility from a previous month).
5.  **You Validate**: You confirm if my analysis is correct. This is the most important step, as it ensures we are aligned before proceeding.
6.  **We Repeat**: We continue this loop until the query is complete.
7.  **I Create Documentation**: Once you are content, I generate the final technical documentation based on the validated query and our shared understanding.

---

## **Prompt Templates for Best Results**

Use these templates to ask for help. They are based on the requests you've made that have given us the best results.

### **Template 1: Build or Evolve a Query**

Use this when you need to create a new query or add logic to an existing one.

> "Okay, let's start the next step for the **[Project Name]**. The goal is to **[Describe the Goal, e.g., add transaction features]**.
> 
> The relevant tables I know are:
> - `table_1`
> - `table_2`
> 
> The key business logic is **[Explain Logic, e.g., we need to use a point-in-time snapshot from the previous month]**.
> 
> Please provide the next query, following our simple-to-complex flow."

### **Template 2: Analyze My Results**

Use this when you have a query and want me to help you understand the output.

> "I ran this query:
> 
> ```sql
> [Your SQL Query]
> ```
> 
> And I got this result:
> 
> `[Paste Your Result]`
> 
> Can you analyze this result and tell me your understanding? I am trying to answer the question: **[Your Business Question]**."

### **Template 3: Create Documentation**

Use this when our query is complete and you're ready for the final write-up.

> "I am content with the query and our analysis. Please create the `.md` documentation for the **[Project Name]**.
> 
> The audience is **[e.g., Technical DA/DS Teams, Business Stakeholders]**, so please make the tone **[e.g., as technical as possible, high-level and simple]**.
> 
> Please structure it like **[e.g., a wiki entry, the previous `filename.md` file]**."

---

## **Our Project History**

So far, we have successfully collaborated on:

1.  **Monthly Loan Offer Performance Report**: Built and documented the aggregate monthly report for loan offers and take-ups.
2.  **Propensity Model Base Table**: Iteratively built a complete, point-in-time correct base table for the propensity model, including labels, demographics, and behavioral features. We also created the final technical guide for it.

I look forward to continuing our work together. Let me know what you'd like to tackle next.
