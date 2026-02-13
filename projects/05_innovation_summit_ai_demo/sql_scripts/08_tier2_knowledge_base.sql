/*
==================================================================
  DEMO AI SUMMIT - TIER 2: KNOWLEDGE BASE
  Script: 08_tier2_knowledge_base.sql
  Purpose: Add policy text chunks for RAG demo (Demo 4)
  Dependencies: 06_document_ai.sql
==================================================================
*/

USE ROLE DEMO_AI_ROLE;
USE WAREHOUSE DEMO_AI_WH;
USE DATABASE DEMO_AI_SUMMIT;
USE SCHEMA DOC_AI_DEMO;

-- Insert enterprise knowledge base content
INSERT INTO DEMO_AI_SUMMIT.DOC_AI_DEMO.DOCUMENTS_TEXT VALUES
-- Discount policy
(100, 1, 'Discounts above 15% require manager approval. Discounts above 20% require VP of Sales approval and must be documented in Salesforce with a justification note. No discount above 30% is permitted without CFO sign-off.', NULL, 'Discount Approval Policy'),
(100, 2, 'Standard discount tiers: 0-10% (rep discretion), 10-15% (manager approval), 15-20% (VP approval), 20-30% (VP + CFO), 30%+ (not permitted). All discounts above 10% must include a competitive justification.', NULL, 'Discount Approval Policy'),

-- Expense policy
(101, 1, 'Travel expenses must be submitted within 14 days of travel completion. Domestic flights under $500 do not require pre-approval. International travel requires VP approval regardless of cost. Hotel per-diem is capped at $250/night in tier-1 cities and $175/night elsewhere.', NULL, 'Travel & Expense Policy'),

-- Data retention
(102, 1, 'Customer PII must be retained for a minimum of 7 years per regulatory requirements. After the retention period, data must be purged using the approved deletion workflow. Backup copies follow the same retention schedule.', NULL, 'Data Retention Policy'),
(102, 2, 'Anonymization is accepted as an alternative to deletion for analytics use cases. Anonymized data is not subject to the 7-year retention limit. The Data Governance team must approve all anonymization requests.', NULL, 'Data Retention Policy'),

-- SLA definitions
(103, 1, 'Tier 1 (Enterprise) customers receive 99.9% uptime SLA with 4-hour response time for critical issues and 24-hour response for non-critical. Tier 2 (Mid-Market) customers receive 99.5% uptime with 8-hour critical response. Tier 3 (SMB) customers receive best-effort support.', NULL, 'Customer SLA Definitions'),

-- Security policy
(104, 1, 'All production database access requires MFA. Service accounts must rotate credentials every 90 days. No production credentials may be stored in source code repositories. Secrets must be managed via the approved vault service.', NULL, 'Security Access Policy');
