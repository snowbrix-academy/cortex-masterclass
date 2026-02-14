# Module 1 Quiz: Set Up Your Snowflake AI Workspace

**Total Questions:** 10
**Passing Score:** 70% (7/10 correct)
**Time Limit:** 15 minutes
**Attempts:** Unlimited

---

## Instructions

- Answer all 10 questions
- You must score 70% or higher to pass
- You can retake the quiz as many times as needed
- Some questions have multiple correct answers
- Read each question carefully

---

## Questions

### Question 1: Cortex Service Availability (Multiple Choice)

**Which AWS regions support Snowflake Cortex services natively without cross-region configuration?**

A) us-east-1 (N. Virginia)
B) eu-west-1 (Ireland)
C) us-west-2 (Oregon)
D) ap-south-1 (Mumbai)

**Select all that apply.**

<details>
<summary>Answer</summary>

**Correct Answers:** A, C

**Explanation:** Cortex Analyst, Agent, and Search are only available in us-east-1 (N. Virginia) and us-west-2 (Oregon) without additional configuration. Other regions require enabling cross-region access with:
```sql
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';
```

**Reference:** Module 1, Section 2 - Verify Cortex Access
</details>

---

### Question 2: Enabling Cross-Region Cortex (True/False)

**True or False: Enabling cross-region Cortex access (`CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION'`) is free and has no performance impact.**

A) True
B) False

<details>
<summary>Answer</summary>

**Correct Answer:** B) False

**Explanation:** Enabling cross-region access incurs **data transfer costs** when data moves between regions for inference. Additionally, there may be increased latency compared to in-region deployment. For production workloads, it's recommended to deploy in us-east-1 or us-west-2 to avoid these costs.

**Reference:** Module 1, Section 2 - Verify Cortex Access
</details>

---

### Question 3: Data Loading (Multiple Choice)

**In Module 1, how many rows total are loaded across all tables when running RUN_ALL_SCRIPTS.sql?**

A) 50,000 rows
B) 217,555 rows
C) 588,000 rows
D) 1,000,000 rows

<details>
<summary>Answer</summary>

**Correct Answer:** C) 588,000 rows

**Explanation:** The setup script loads 588,000 rows across 12 tables:
- CUSTOMERS: 1,000
- PRODUCTS: 500
- ORDERS: 50,000
- ORDER_ITEMS: 150,000
- RETURNS: 5,000
- PRODUCT_REVIEWS: 10,000
- Plus agent tables, document AI tables, etc.

**Reference:** Module 1, Section 3 - Load Data
</details>

---

### Question 4: Semantic Model Storage (Multiple Choice)

**Where must semantic YAML models be stored for Cortex Analyst to access them?**

A) Local filesystem
B) GitHub repository
C) Snowflake internal stage
D) External S3 bucket

<details>
<summary>Answer</summary>

**Correct Answer:** C) Snowflake internal stage

**Explanation:** Cortex Analyst reads semantic models from Snowflake stages. The path format is:
```
@DATABASE.SCHEMA.STAGE_NAME/filename.yaml
```
Example:
```
@DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.CORTEX_ANALYST_STAGE/cortex_analyst_demo.yaml
```

**Reference:** Module 1, Section 5 - Set Up Cortex Analyst Stage
</details>

---

### Question 5: SQL Query Analysis (Multiple Choice)

**You run this query:**
```sql
SELECT
    c.customer_name,
    COUNT(o.order_id) AS order_count
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
GROUP BY c.customer_name
ORDER BY order_count DESC
LIMIT 5;
```

**What does this query return?**

A) Top 5 customers by total revenue
B) Top 5 customers by number of orders
C) Top 5 customers by average order value
D) Top 5 customers who placed orders in the last month

<details>
<summary>Answer</summary>

**Correct Answer:** B) Top 5 customers by number of orders

**Explanation:** The query:
- Joins CUSTOMERS and ORDERS tables
- Counts order_id (number of orders per customer)
- Groups by customer name
- Orders by order_count descending
- Limits to top 5

**Note:** Using LEFT JOIN ensures customers with zero orders are included (they'd show order_count = 0).

**Reference:** Module 1, Part B - Query 4 (Customer Segmentation)
</details>

---

### Question 6: Warehouse Auto-Suspend (Multiple Choice)

**What is the recommended AUTO_SUSPEND setting for the COMPUTE_WH warehouse to optimize costs?**

A) 0 seconds (never suspend)
B) 30 seconds
C) 60 seconds
D) 600 seconds (10 minutes)

<details>
<summary>Answer</summary>

**Correct Answer:** C) 60 seconds

**Explanation:** The course setup uses:
```sql
CREATE WAREHOUSE COMPUTE_WH
  WAREHOUSE_SIZE = 'MEDIUM'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE;
```

60 seconds (1 minute) is aggressive enough to minimize idle time but not so short that it suspends during multi-query workflows. This balances cost optimization with user experience.

**Reference:** Module 1, Section 3 - Infrastructure Setup
</details>

---

### Question 7: Cortex Service Verification (Fill in the Blank)

**Complete this SQL query to check if Cortex Analyst is enabled:**

```sql
SELECT SYSTEM$CORTEX_________() AS status;
```

**Fill in the blank.**

<details>
<summary>Answer</summary>

**Correct Answer:** `ANALYST_STATUS`

**Full query:**
```sql
SELECT SYSTEM$CORTEX_ANALYST_STATUS() AS status;
```

**Expected result:** `ENABLED`

**Related functions:**
- `SYSTEM$CORTEX_AGENT_STATUS()` - Check Cortex Agent
- `SYSTEM$CORTEX_SEARCH_STATUS()` - Check Cortex Search

**Reference:** Module 1, Section 2 - Verify Cortex Access
</details>

---

### Question 8: Data Verification (Multiple Choice)

**You run VERIFY_ALL.sql and see CUSTOMERS has 1,000 rows, but ORDERS has 0 rows. What should you do?**

A) Nothing - this is expected
B) Re-run only 03_sales_fact.sql
C) Re-run the entire RUN_ALL_SCRIPTS.sql
D) Contact Snowflake support

<details>
<summary>Answer</summary>

**Correct Answer:** B) Re-run only 03_sales_fact.sql

**Explanation:** If dimension tables (CUSTOMERS) loaded successfully but fact tables (ORDERS) did not, you can re-run just the sales fact script:
```sql
-- Execute contents of sql_scripts/03_sales_fact.sql
```

This saves time compared to re-running all scripts. However, if multiple tables failed, option C (re-run all) might be simpler.

**Troubleshooting tip:** Check for errors in the execution log to see where the script failed.

**Reference:** Module 1, Section 4 - Verify Data
</details>

---

### Question 9: JOIN Types (Multiple Choice)

**Which JOIN type would you use to find customers who have NEVER placed an order?**

```sql
SELECT c.customer_name
FROM customers c
[???] orders o ON c.customer_id = o.customer_id
WHERE o.order_id IS NULL;
```

A) INNER JOIN
B) LEFT JOIN
C) RIGHT JOIN
D) CROSS JOIN

<details>
<summary>Answer</summary>

**Correct Answer:** B) LEFT JOIN

**Explanation:**
- **LEFT JOIN** returns all rows from the left table (CUSTOMERS) even if there's no match in the right table (ORDERS)
- **WHERE o.order_id IS NULL** filters to only customers with no matching orders
- INNER JOIN would exclude customers without orders entirely

**Full query:**
```sql
SELECT c.customer_name
FROM customers c
LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_id IS NULL;
```

This returns customers with zero orders.

**Reference:** Module 1, Part B - Exploratory Queries
</details>

---

### Question 10: Scenario-Based Troubleshooting (Multiple Choice)

**You're deploying to a client's existing Snowflake account. You run `SELECT SYSTEM$CORTEX_ANALYST_STATUS();` and get an error: "Unknown function SYSTEM$CORTEX_ANALYST_STATUS". What's the most likely cause?**

A) The client's account is in an unsupported region
B) The client doesn't have the Enterprise edition
C) Cortex services haven't been enabled by Snowflake yet
D) You're using the wrong role

<details>
<summary>Answer</summary>

**Correct Answer:** C) Cortex services haven't been enabled by Snowflake yet

**Explanation:** If the function itself is unrecognized (not just returning 'DISABLED'), it means Cortex services are not available on that account at all. This can happen if:
1. The account was created before Cortex was generally available
2. The account is in a cloud/region where Cortex isn't supported (Azure, GCP)
3. The account hasn't been upgraded to include Cortex features

**Solutions:**
- Contact Snowflake support to enable Cortex
- Create a new trial account in AWS us-east-1 or us-west-2
- Use cross-region configuration if available

**Note:** Even unsupported regions would return 'DISABLED', not an unknown function error.

**Reference:** Module 1, Section 2 - Troubleshooting
</details>

---

## Scoring

**Pass:** 7/10 or higher (70%)
**Fail:** 6/10 or lower (below 70%)

**If you fail:**
- Review Module 1 video (12 minutes)
- Re-read Module 1 lab README
- Review the explanation for each incorrect answer
- Retake quiz (unlimited attempts)

---

## Answer Key Summary

1. A, C (Cortex regions)
2. B (Cross-region costs)
3. C (588,000 rows)
4. C (Snowflake stage)
5. B (Top customers by order count)
6. C (60 seconds auto-suspend)
7. ANALYST_STATUS (function name)
8. B (Re-run sales fact script)
9. B (LEFT JOIN)
10. C (Cortex not enabled)

---

## Quiz Implementation Notes

**For Teachable/Thinkific:**
- Use "Multiple Choice" question type
- Enable "Multiple answers" for Q1
- Use "True/False" for Q2
- Use "Fill in the blank" for Q7
- Set passing grade to 70%
- Enable unlimited attempts

**For Google Forms:**
- Use "Multiple choice" for single answer
- Use "Checkboxes" for Q1 (multiple answers)
- Use "Short answer" for Q7 (accept variations: "ANALYST_STATUS", "analyst_status")
- Use Google Forms add-on for auto-grading

**For Quizizz/Kahoot (gamified):**
- Convert to multiple choice only
- Add timer (30 seconds per question)
- Show leaderboard for engagement

---

**Time to complete:** 10-15 minutes
**Difficulty:** Beginner to Intermediate
**Focus:** Practical knowledge, troubleshooting, SQL fundamentals
