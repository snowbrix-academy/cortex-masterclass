/*
==================================================================
  DEMO AI SUMMIT - TIER 2: SENTIMENT ANALYSIS
  Script: 09_tier2_sentiment.sql
  Purpose: Customer reviews for sentiment demo (Demo 5)
  Dependencies: 01_infrastructure.sql
==================================================================
*/

USE ROLE DEMO_AI_ROLE;
USE WAREHOUSE DEMO_AI_WH;
USE DATABASE DEMO_AI_SUMMIT;
USE SCHEMA CORTEX_ANALYST_DEMO;

-- Create sentiment demo table
CREATE OR REPLACE TABLE DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.CUSTOMER_REVIEWS (
    review_id       INTEGER,
    source          VARCHAR(50),
    review_text     VARCHAR(5000),
    product_id      INTEGER,
    review_date     DATE,
    star_rating     INTEGER
);

-- Insert sample reviews (mix of positive, negative, neutral)
INSERT INTO DEMO_AI_SUMMIT.CORTEX_ANALYST_DEMO.CUSTOMER_REVIEWS VALUES
(1, 'App Store',    'Absolutely love this product. Setup was simple and the performance exceeded expectations. Best purchase this year.', 101, '2025-03-01', 5),
(2, 'Trustpilot',   'Decent product but the onboarding documentation is confusing. Took 3 calls to support before I got it working.', 102, '2025-03-01', 3),
(3, 'G2',           'Terrible experience. The product crashed during our quarterly review and we lost 2 hours of work. Will not renew.', 103, '2025-03-02', 1),
(4, 'App Store',    'Good value for money. Some features feel half-baked but the core functionality is solid. Looking forward to updates.', 101, '2025-03-02', 4),
(5, 'Twitter',      'Just switched from [Competitor] to this and the difference is night and day. Faster, cleaner, more intuitive.', 104, '2025-03-02', 5),
(6, 'Support',      'My account was charged twice and nobody from billing has responded in 5 days. This is unacceptable for an enterprise product.', 105, '2025-03-03', 1),
(7, 'Trustpilot',   'The API is well-designed and the documentation is thorough. Integration took less than a day.', 106, '2025-03-03', 5),
(8, 'G2',           'Product works fine but pricing increased 40% at renewal with no advance notice. Evaluating alternatives.', 107, '2025-03-03', 2),
(9, 'App Store',    'Reliable and consistent. No complaints after 6 months of daily use. The mobile app could use improvement.', 108, '2025-03-04', 4),
(10, 'Twitter',     'Outage during peak hours AGAIN. Third time this quarter. Starting to doubt the reliability claims.', 109, '2025-03-04', 1);
