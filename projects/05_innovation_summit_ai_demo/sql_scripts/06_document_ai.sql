/*
==================================================================
  DEMO AI SUMMIT — DOCUMENT AI TABLES
  Script: 06_document_ai.sql
  Purpose: Schema + sample data for Document AI demo
  Dependencies: 01_infrastructure.sql

  NOTE: The actual PDF files must be uploaded to the stage manually.
  This script creates the tables and pre-populates extracted data
  so the demo works even if Document AI processing is slow.
==================================================================
*/

USE ROLE DEMO_AI_ROLE;
USE WAREHOUSE DEMO_AI_WH;
USE DATABASE DEMO_AI_SUMMIT;
USE SCHEMA DOC_AI_DEMO;

-- ─────────────────────────────────────────────
-- Stage for PDF uploads
-- ─────────────────────────────────────────────
CREATE OR REPLACE STAGE DOCUMENTS_STAGE
    DIRECTORY = (ENABLE = TRUE)
    COMMENT = 'Landing zone for contract PDFs';

-- ─────────────────────────────────────────────
-- Raw extraction output
-- ─────────────────────────────────────────────
CREATE OR REPLACE TABLE DOCUMENTS_RAW (
    doc_id          INTEGER AUTOINCREMENT,
    file_name       VARCHAR(500),
    upload_ts       TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    raw_json        VARIANT,
    processing_status VARCHAR(20) DEFAULT 'PENDING',
    CONSTRAINT pk_documents_raw PRIMARY KEY (doc_id)
);

-- ─────────────────────────────────────────────
-- Structured extracted fields
-- ─────────────────────────────────────────────
CREATE OR REPLACE TABLE DOCUMENTS_EXTRACTED (
    doc_id          INTEGER,
    doc_type        VARCHAR(100),
    party_a         VARCHAR(200),
    party_b         VARCHAR(200),
    effective_date  DATE,
    expiration_date DATE,
    total_value     NUMBER(15,2),
    payment_terms   VARCHAR(100),
    auto_renewal    BOOLEAN,
    governing_law   VARCHAR(100),
    CONSTRAINT pk_documents_extracted PRIMARY KEY (doc_id)
);

-- ─────────────────────────────────────────────
-- Full-text chunks for Cortex Search
-- ─────────────────────────────────────────────
CREATE OR REPLACE TABLE DOCUMENTS_TEXT (
    doc_id          INTEGER,
    chunk_id        INTEGER,
    chunk_text      VARCHAR(4000),
    page_number     INTEGER,
    section_header  VARCHAR(200),
    CONSTRAINT pk_documents_text PRIMARY KEY (doc_id, chunk_id)
);

-- ─────────────────────────────────────────────
-- Pre-populate: MSA_Acme_GlobalTech_2024.pdf
-- (hero document for live demo)
-- ─────────────────────────────────────────────
INSERT INTO DOCUMENTS_RAW (doc_id, file_name, processing_status)
VALUES (1, 'MSA_Acme_GlobalTech_2024.pdf', 'COMPLETED');

INSERT INTO DOCUMENTS_EXTRACTED VALUES (
    1, 'Master Services Agreement',
    'Acme Corp', 'GlobalTech Inc',
    '2024-01-15', '2026-01-14',
    2400000.00, 'Net 30',
    TRUE, 'State of Delaware'
);

-- Key text chunks that the demo questions will hit
INSERT INTO DOCUMENTS_TEXT VALUES
    (1, 1, 'This Master Services Agreement ("Agreement") is entered into as of January 15, 2024, by and between Acme Corp, a Delaware corporation ("Client"), and GlobalTech Inc, a California corporation ("Provider").', 1, 'Preamble'),
    (1, 2, 'The term of this Agreement shall commence on the Effective Date and continue for a period of twenty-four (24) months, unless earlier terminated in accordance with Section 8.', 2, 'Section 2 — Term'),
    (1, 3, 'Client shall pay Provider fees as set forth in each Statement of Work. The total aggregate value of this Agreement shall not exceed Two Million Four Hundred Thousand Dollars ($2,400,000). Payment terms are Net 30 days from receipt of invoice.', 3, 'Section 4 — Fees and Payment'),
    (1, 4, 'This Agreement shall automatically renew for successive twelve (12) month periods unless either party provides written notice of non-renewal at least sixty (60) days prior to the end of the then-current term.', 4, 'Section 5 — Renewal'),
    (1, 5, 'Each party agrees to maintain the confidentiality of all Confidential Information disclosed by the other party. Confidential Information shall not include information that is publicly available, independently developed, or rightfully received from a third party.', 5, 'Section 7 — Confidentiality'),
    -- PLANTED: Termination clause (visitor will ask about this)
    (1, 6, 'Either party may terminate this Agreement upon ninety (90) days prior written notice to the other party. Upon termination, Client shall pay for all Services rendered through the termination date. Provider shall return or destroy all Client data within thirty (30) days of termination.', 7, 'Section 8.2 — Termination for Convenience'),
    (1, 7, 'Either party may terminate this Agreement immediately upon written notice if the other party materially breaches any provision and fails to cure such breach within thirty (30) days after receiving written notice of the breach.', 7, 'Section 8.3 — Termination for Cause'),
    -- PLANTED: Liability cap (visitor will ask about this)
    (1, 8, 'IN NO EVENT SHALL EITHER PARTY''S AGGREGATE LIABILITY UNDER THIS AGREEMENT EXCEED FIVE MILLION DOLLARS ($5,000,000). NEITHER PARTY SHALL BE LIABLE FOR ANY INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, OR PUNITIVE DAMAGES.', 9, 'Section 10.1 — Limitation of Liability'),
    (1, 9, 'Provider shall maintain the following insurance coverage: (a) Commercial General Liability of not less than $2,000,000 per occurrence; (b) Professional Liability of not less than $5,000,000 per claim; (c) Cyber Liability of not less than $3,000,000 per occurrence.', 10, 'Section 11 — Insurance'),
    (1, 10, 'This Agreement shall be governed by and construed in accordance with the laws of the State of Delaware, without regard to its conflict of laws principles. Any dispute arising under this Agreement shall be resolved through binding arbitration in Wilmington, Delaware.', 11, 'Section 14 — Governing Law'),
    -- PLANTED: "Early exit provisions" — will NOT match keyword "termination"
    -- but Cortex Search WILL find it (semantic match)
    (1, 11, 'Notwithstanding the foregoing, Client may exercise early exit provisions under this Agreement by providing sixty (60) days notice and paying an early exit fee equal to twenty percent (20%) of the remaining contract value.', 8, 'Section 8.5 — Early Exit Provisions');

-- ─────────────────────────────────────────────
-- Pre-populate: Remaining 4 sample documents
-- (abbreviated — just metadata + key chunks)
-- ─────────────────────────────────────────────
INSERT INTO DOCUMENTS_RAW (doc_id, file_name, processing_status) VALUES
    (2, 'SaaS_Subscription_NovaTech_2024.pdf', 'COMPLETED'),
    (3, 'NDA_Mutual_Acme_Pinnacle_2024.pdf', 'COMPLETED'),
    (4, 'SOW_DataPlatform_Acme_2024.pdf', 'COMPLETED'),
    (5, 'DPA_Acme_CloudVault_2024.pdf', 'COMPLETED');

INSERT INTO DOCUMENTS_EXTRACTED VALUES
    (2, 'SaaS Subscription', 'NovaTech Solutions', 'Acme Corp', '2024-03-01', '2025-02-28', 360000.00, 'Annual Prepaid', TRUE, 'State of California'),
    (3, 'NDA (Mutual)', 'Acme Corp', 'Pinnacle Analytics', '2024-06-01', '2026-05-31', NULL, NULL, FALSE, 'State of New York'),
    (4, 'Statement of Work', 'Acme Corp', 'GlobalTech Inc', '2024-04-01', '2024-12-31', 480000.00, 'Monthly Milestone', FALSE, 'State of Delaware'),
    (5, 'Data Processing Agreement', 'Acme Corp', 'CloudVault Storage', '2024-01-15', '2026-01-14', NULL, NULL, TRUE, 'GDPR — EU Standard Contractual Clauses');

-- ─────────────────────────────────────────────
-- VERIFICATION: Document counts
-- ─────────────────────────────────────────────
SELECT 'DOCUMENTS_RAW' AS tbl, COUNT(*) AS row_count FROM DOCUMENTS_RAW
UNION ALL SELECT 'DOCUMENTS_EXTRACTED', COUNT(*) FROM DOCUMENTS_EXTRACTED
UNION ALL SELECT 'DOCUMENTS_TEXT', COUNT(*) FROM DOCUMENTS_TEXT;
