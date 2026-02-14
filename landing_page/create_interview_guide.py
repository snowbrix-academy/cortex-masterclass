"""
50 Snowflake Cortex Interview Questions - Lead Magnet PDF Generator
Creates a professional interview guide for course waitlist subscribers
"""

from reportlab.lib.pagesizes import letter
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.lib.colors import HexColor
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle
from reportlab.lib.enums import TA_LEFT, TA_CENTER, TA_JUSTIFY

def create_interview_guide():
    """Generate the 50 Snowflake Cortex Interview Questions PDF"""

    doc = SimpleDocTemplate(
        "50_Snowflake_Cortex_Interview_Questions.pdf",
        pagesize=letter,
        rightMargin=0.75*inch,
        leftMargin=0.75*inch,
        topMargin=0.75*inch,
        bottomMargin=0.75*inch
    )

    # Styles
    styles = getSampleStyleSheet()

    # Custom styles
    title_style = ParagraphStyle(
        'CustomTitle',
        parent=styles['Heading1'],
        fontSize=24,
        textColor=HexColor('#1e40af'),
        spaceAfter=12,
        alignment=TA_CENTER,
        fontName='Helvetica-Bold'
    )

    subtitle_style = ParagraphStyle(
        'CustomSubtitle',
        parent=styles['Normal'],
        fontSize=14,
        textColor=HexColor('#4b5563'),
        spaceAfter=30,
        alignment=TA_CENTER,
        fontName='Helvetica'
    )

    section_style = ParagraphStyle(
        'SectionHeader',
        parent=styles['Heading2'],
        fontSize=16,
        textColor=HexColor('#1e40af'),
        spaceAfter=12,
        spaceBefore=20,
        fontName='Helvetica-Bold'
    )

    question_style = ParagraphStyle(
        'Question',
        parent=styles['Normal'],
        fontSize=11,
        textColor=HexColor('#1a1a1a'),
        spaceAfter=6,
        fontName='Helvetica-Bold',
        leftIndent=20
    )

    answer_style = ParagraphStyle(
        'Answer',
        parent=styles['Normal'],
        fontSize=10,
        textColor=HexColor('#4b5563'),
        spaceAfter=18,
        alignment=TA_JUSTIFY,
        leftIndent=20,
        fontName='Helvetica'
    )

    story = []

    # Title Page
    story.append(Spacer(1, 1*inch))
    story.append(Paragraph("50 Snowflake Cortex", title_style))
    story.append(Paragraph("Interview Questions", title_style))
    story.append(Spacer(1, 0.3*inch))
    story.append(Paragraph("Production-Grade Data Engineering. No Fluff.", subtitle_style))
    story.append(Spacer(1, 0.5*inch))

    intro = """This guide contains 50 interview questions and answers covering Snowflake Cortex
    (Analyst, Agent, Document AI), Streamlit in Snowflake compatibility, and production patterns.
    Perfect for data engineers preparing for Snowflake AI interviews."""
    story.append(Paragraph(intro, styles['Normal']))
    story.append(Spacer(1, 0.3*inch))

    footer = """<b>Snowbrix Academy</b><br/>
    Join the Snowflake Cortex Masterclass: snowbrix.academy/cortex-masterclass<br/>
    Launching February 20, 2026"""
    story.append(Paragraph(footer, subtitle_style))

    story.append(PageBreak())

    # Questions organized by category
    questions = [
        # Section 1: Snowflake Cortex Fundamentals (Q1-10)
        {
            "section": "Section 1: Snowflake Cortex Fundamentals",
            "questions": [
                {
                    "q": "Q1: What is Snowflake Cortex and what are its three main components?",
                    "a": """Snowflake Cortex is Snowflake's intelligent, fully-managed AI/ML service. The three main components are:

(1) <b>Cortex Analyst</b> — Natural language to SQL interface using semantic YAML models. Allows business users to query data in plain English without writing SQL.

(2) <b>Cortex Agent</b> — Autonomous multi-step investigation agent with tool orchestration capabilities. Can perform root cause analysis across multiple tables.

(3) <b>Cortex Search</b> — Hybrid search service (keyword + semantic) for RAG pipelines. Used for Document AI and semantic search over unstructured data.

All three are serverless (no infrastructure management), governed by Snowflake's security model, and billed on consumption."""
                },
                {
                    "q": "Q2: How does Cortex Analyst differ from traditional BI tools?",
                    "a": """Traditional BI tools require users to navigate pre-built dashboards, filters, and visualizations. Cortex Analyst enables <b>conversational analytics</b> where users ask questions in natural language.

Key differences:
- <b>No dashboard navigation</b> — Users type questions directly
- <b>Semantic layer</b> — YAML defines relationships, metrics, verified queries
- <b>Dynamic SQL generation</b> — Analyst generates SQL on-the-fly
- <b>Multi-table joins</b> — Semantic model enables complex joins without explicit SQL
- <b>Verified queries</b> — Pre-validated SQL patterns for common questions

Example: "What are the top 5 products by revenue in Q4?" → Cortex Analyst generates SQL across PRODUCTS, ORDERS, ORDER_ITEMS tables automatically."""
                },
                {
                    "q": "Q3: What is a semantic YAML model and why is it required for Cortex Analyst?",
                    "a": """A semantic YAML model is a structured metadata file that defines:
- <b>Tables</b>: Which Snowflake tables to query
- <b>Columns</b>: Data types, descriptions, synonyms
- <b>Relationships</b>: Foreign key joins between tables
- <b>Verified queries</b>: Pre-validated SQL patterns

Why required? Cortex Analyst needs context to generate correct SQL:
- Without semantic model: "revenue" is ambiguous (which table? SUM or AVG?)
- With semantic model: "revenue" maps to SUM(ORDER_ITEMS.QUANTITY * ORDER_ITEMS.PRICE)

The YAML acts as a <b>contract</b> between your data and the LLM, ensuring generated SQL is valid and accurate."""
                },
                {
                    "q": "Q4: How do you enable Cortex services in a Snowflake account?",
                    "a": """Cortex services are region-specific. Two options:

<b>Option 1: Use supported region</b> (us-east-1 or us-west-2):
CREATE DATABASE in these regions automatically has Cortex access.

<b>Option 2: Enable cross-region access</b>:
<font name="Courier">
USE ROLE ACCOUNTADMIN;
ALTER ACCOUNT SET CORTEX_ENABLED_CROSS_REGION = 'ANY_REGION';
</font>

<b>Verify access</b>:
<font name="Courier">
SELECT SYSTEM$CORTEX_ANALYST_STATUS();  -- Returns 'ENABLED'
SELECT SYSTEM$CORTEX_AGENT_STATUS();    -- Returns 'ENABLED'
SELECT SYSTEM$CORTEX_SEARCH_STATUS();   -- Returns 'ENABLED'
</font>

Note: Cross-region incurs data transfer costs. Production deployments should use supported regions."""
                },
                {
                    "q": "Q5: What are the pricing models for Snowflake Cortex services?",
                    "a": """Cortex uses <b>consumption-based pricing</b>:

<b>Cortex Analyst</b>:
- Charged per API call + tokens processed
- ~$0.01-0.03 per query (depending on complexity)

<b>Cortex Agent</b>:
- Charged per agent run + tool calls
- Multi-step runs cost more (tool orchestration)

<b>Cortex Search</b>:
- Storage: Per GB of indexed data
- Queries: Per search request
- TARGETLAG impacts cost (lower = fresher index = higher cost)

<b>Cost optimization tips</b>:
- Use warehouse suspend (AUTO_SUSPEND = 60) to avoid idle compute
- Cache semantic models in Streamlit to reduce API calls
- Set TARGETLAG appropriately (not every use case needs 1-minute freshness)"""
                },
                {
                    "q": "Q6: What is the difference between Cortex LLM Functions (like COMPLETE) and Cortex Analyst?",
                    "a": """Both are Snowflake Cortex services, but serve different purposes:

<b>Cortex LLM Functions (COMPLETE, SUMMARIZE, TRANSLATE)</b>:
- SQL functions called directly in queries
- General-purpose text generation/transformation
- Example: SELECT SNOWFLAKE.CORTEX.COMPLETE('mistral-large', 'Write a haiku')

<b>Cortex Analyst</b>:
- Specialized for data analytics (natural language → SQL)
- Requires semantic YAML model
- REST API-based (not SQL function)
- Maintains conversation context across multi-turn queries

Use COMPLETE for: Text generation, summarization, sentiment analysis
Use Analyst for: Business intelligence, ad-hoc analytics, conversational data exploration"""
                },
                {
                    "q": "Q7: Can Cortex Analyst query real-time data or only historical data?",
                    "a": """Cortex Analyst queries <b>real-time data</b> (as fresh as your Snowflake tables). It generates SQL that runs against current table state.

Key points:
- No data replication — Queries execute directly on Snowflake tables
- Latency depends on table size and warehouse compute
- Streams + Tasks can keep tables near real-time
- Use materialized views for frequently queried aggregations

Example scenario:
- E-commerce orders land via Snowpipe (seconds latency)
- Cortex Analyst query "Show today's revenue" runs live query against ORDERS table
- Result reflects orders that landed 10 seconds ago

For <b>true streaming analytics</b> (sub-second), consider Snowflake Streams + Dynamic Tables."""
                },
                {
                    "q": "Q8: How many tables can a semantic YAML model include?",
                    "a": """No hard limit, but practical considerations:

<b>Recommended range</b>: 3-12 tables
- Small model (3-5 tables): Faster SQL generation, easier to debug
- Medium model (5-8 tables): Balanced complexity
- Large model (8-12 tables): Comprehensive coverage, slower generation

<b>Best practices</b>:
- Start small (5 tables), expand as needed
- Use <b>star schema</b> (fact + dimensions) for optimal joins
- Limit relationships to avoid cartesian products
- Test verified queries as you add tables

<b>Interview trap</b>: "Can I put 50 tables in one YAML?"
Yes, technically. But SQL generation becomes unreliable and slow. Better: Multiple semantic models (one per domain)."""
                },
                {
                    "q": "Q9: What happens if Cortex Analyst generates incorrect SQL?",
                    "a": """Three levels of handling:

<b>Level 1: Validation errors (compile-time)</b>:
- Syntax errors caught before execution
- User sees: "Unable to generate valid SQL"
- Fix: Update semantic YAML (clarify relationships, add synonyms)

<b>Level 2: Runtime errors</b>:
- SQL executes but fails (e.g., column doesn't exist)
- User sees: Error message + option to rephrase
- Fix: Add verified query for this pattern

<b>Level 3: Incorrect results (logic error)</b>:
- SQL runs but returns wrong data
- User doesn't know result is wrong (most dangerous!)
- Fix: Add <b>verified queries</b> with expected results for validation

<b>Prevention strategy</b>: Start with 5-10 verified queries covering common use cases. Expand based on user feedback."""
                },
                {
                    "q": "Q10: Can Cortex Analyst handle time-series analysis and trend detection?",
                    "a": """Yes, with proper semantic model configuration:

<b>Requirements</b>:
- DATE/TIMESTAMP column defined in YAML
- Time-grain synonyms (daily, weekly, monthly, YoY)
- Verified queries for common time patterns

<b>Example verified query</b>:
<font name="Courier">
verified_queries:
  - name: monthly_revenue_trend
    question: "Show monthly revenue trend for 2024"
    sql: |
      SELECT
        DATE_TRUNC('month', order_date) AS month,
        SUM(revenue) AS total_revenue
      FROM ORDERS
      WHERE YEAR(order_date) = 2024
      GROUP BY month
      ORDER BY month;
</font>

<b>Cortex Analyst can then handle</b>:
- "What's the revenue trend over the last 6 months?"
- "Show me year-over-year sales growth"
- "Which months had declining revenue?"

For <b>advanced forecasting</b> (ARIMA, Prophet), use Cortex ML Functions separately."""
                }
            ]
        },

        # Section 2: Cortex Agent & Tool Orchestration (Q11-20)
        {
            "section": "Section 2: Cortex Agent & Tool Orchestration",
            "questions": [
                {
                    "q": "Q11: What is Cortex Agent and how does it differ from Cortex Analyst?",
                    "a": """<b>Cortex Agent</b> is an autonomous reasoning system that performs <b>multi-step investigations</b> using tools.

Key differences from Cortex Analyst:

<b>Cortex Analyst</b>:
- Single-turn: User asks → Generates SQL → Returns result
- Constrained to semantic model
- Best for: Ad-hoc queries, dashboards

<b>Cortex Agent</b>:
- Multi-turn: Plans → Executes tools → Analyzes → Iterates
- Flexible tool set (SQL queries, APIs, calculations)
- Best for: Root cause analysis, investigations, complex workflows

Example: "Why did revenue drop 15% last week?"
- Analyst: Returns SQL showing the drop
- Agent: (1) Confirms drop, (2) Checks regional breakdown, (3) Identifies spike in returns, (4) Queries return reasons, (5) Concludes: Product defect batch"""
                },
                {
                    "q": "Q12: What is a 'tool' in the context of Cortex Agent?",
                    "a": """A <b>tool</b> is a function the agent can call to gather information or take action.

<b>Tool definition structure</b>:
<font name="Courier">
{
  "type": "FUNCTION",
  "function": {
    "name": "get_regional_sales",
    "description": "Returns sales by region for date range",
    "parameters": {
      "type": "object",
      "properties": {
        "start_date": {"type": "string"},
        "end_date": {"type": "string"}
      },
      "required": ["start_date", "end_date"]
    }
  }
}
</font>

<b>Common tool types</b>:
- SQL query tools (pre-defined queries)
- API call tools (external data)
- Calculation tools (Python functions)
- Notification tools (send alerts)

Agent <b>autonomously decides</b> which tools to call and in what order."""
                },
                {
                    "q": "Q13: How does Cortex Agent decide which tools to call?",
                    "a": """Agent uses <b>ReAct (Reasoning + Acting) pattern</b>:

<b>Step 1: Reasoning</b>
- Analyze user question + current context
- Identify information gaps
- Plan next action

<b>Step 2: Acting</b>
- Select most relevant tool based on descriptions
- Execute tool with appropriate parameters
- Receive tool result

<b>Step 3: Observation</b>
- Analyze tool output
- Update internal state
- Decide: Done or continue?

<b>Example flow</b>:
User: "Why did Q4 revenue miss target?"
1. Reason: "Need Q4 actuals and target"
2. Act: Call get_quarterly_revenue(quarter=4)
3. Observe: "Actual: $2.1M, Target: $2.5M, -16% gap"
4. Reason: "Gap is significant. Check regional breakdown"
5. Act: Call get_regional_sales(quarter=4)
...and so on until root cause identified."""
                },
                {
                    "q": "Q14: What are best practices for tool descriptions in Cortex Agent?",
                    "a": """Tool descriptions are <b>critical</b> — the agent uses them to decide which tool to call.

<b>Best practices</b>:

<b>1. Be specific about tool purpose</b>:
❌ "Gets sales data"
✅ "Returns daily sales aggregated by region for a date range. Use for regional performance analysis."

<b>2. Include when to use (and not use)</b>:
"Use when investigating regional performance. Do NOT use for product-level analysis (use get_product_sales instead)."

<b>3. Specify output format</b>:
"Returns: list of {region: str, sales: float, pct_change: float}"

<b>4. Mention constraints</b>:
"Date range cannot exceed 90 days. For longer periods, use get_monthly_sales."

<b>5. Provide examples in description</b>:
"Example: get_regional_sales('2024-01-01', '2024-03-31') for Q1 analysis"

Clear descriptions = fewer hallucinated tool calls."""
                },
                {
                    "q": "Q15: How do you handle Cortex Agent timeout (60 seconds)?",
                    "a": """Agent timeout happens when investigation takes too long. Solutions:

<b>1. Optimize tool queries</b>:
- Add WHERE filters (don't scan full tables)
- Use aggregated views (not raw fact tables)
- Add LIMIT clauses

<b>2. Increase warehouse size</b>:
<font name="Courier">
ALTER WAREHOUSE COMPUTE_WH SET WAREHOUSE_SIZE = 'LARGE';
</font>

<b>3. Reduce tool complexity</b>:
- Break complex tools into smaller, focused tools
- Example: Instead of get_all_metrics → get_revenue_metrics + get_operational_metrics

<b>4. Limit max tool calls</b>:
Set max_iterations in agent config to prevent infinite loops

<b>5. Use async pattern</b>:
For long investigations, return "Investigation started" immediately, then poll for results

<b>Interview answer</b>: "Timeout indicates tool queries are too expensive. Optimize SQL first, then scale warehouse if needed."" "
                },
                {
                    "q": "Q16: Can Cortex Agent call external APIs (non-Snowflake)?",
                    "a": """Yes, via <b>External Functions</b> or <b>Snowpark Python</b>:

<b>Option 1: External Functions</b> (AWS Lambda, Azure Functions):
<font name="Courier">
CREATE EXTERNAL FUNCTION get_weather(city STRING)
  RETURNS VARIANT
  API_INTEGRATION = my_api_integration
  AS 'https://api.weather.com/forecast';
</font>

Agent can then call get_weather tool.

<b>Option 2: Snowpark Python UDFs</b>:
<font name="Courier">
import requests
def call_external_api(param):
    resp = requests.post('https://api.example.com', json=param)
    return resp.json()
</font>

<b>Use cases</b>:
- Enrich Snowflake data with external sources
- Trigger workflows (send Slack alert, create Jira ticket)
- Fetch real-time pricing, weather, stock data

<b>Security note</b>: Use Snowflake Secrets for API keys, never hardcode."""
                },
                {
                    "q": "Q17: How do you debug a Cortex Agent that's not calling the right tools?",
                    "a": """Debugging strategy:

<b>1. Check tool descriptions</b>:
- Are they clear and specific?
- Do they explain <b>when</b> to use the tool?
- Test: Ask GPT-4 "Which tool would you call for X?" with your descriptions

<b>2. Review agent logs</b>:
Agent returns reasoning trace showing:
- Which tools were considered
- Why each tool was/wasn't selected
- Parameters passed to tools

<b>3. Test tools individually</b>:
Execute each tool manually with sample inputs — does it return expected output?

<b>4. Simplify tool set</b>:
Start with 2-3 tools, add more once working

<b>5. Add explicit routing hints</b>:
In system prompt: "For regional analysis questions, ALWAYS start with get_regional_sales tool"

<b>Common issue</b>: Agent calls wrong tool because descriptions are ambiguous or overlap."""
                },
                {
                    "q": "Q18: What is the difference between Cortex Agent 'tools' and 'functions'?",
                    "a": """In Snowflake Cortex Agent context, they're interchangeable (both refer to callable operations).

However, in broader AI terminology:

<b>Tool</b>: High-level capability (e.g., "get_regional_sales")
- Defined in agent config
- Has description, parameters, return type
- Agent decides when to call

<b>Function</b>: Implementation of tool (e.g., SQL query, Python UDF)
- Executes when tool is called
- Can be Snowflake SQL, External Function, Snowpark UDF

<b>Example</b>:
Tool: "get_customer_churn_risk"
Function implementation:
<font name="Courier">
SELECT customer_id, churn_score
FROM ML_PREDICTIONS
WHERE churn_score > 0.7;
</font>

<b>Interview answer</b>: "Tool is the interface (what the agent sees), function is the implementation (what executes)."""
                },
                {
                    "q": "Q19: How do you handle errors when a Cortex Agent tool call fails?",
                    "a": """Multi-level error handling:

<b>Level 1: Tool-level try-catch</b>:
Wrap tool implementation in error handling:
<font name="Courier">
CREATE FUNCTION safe_get_sales(...)
RETURNS VARIANT
AS $$
  BEGIN
    RETURN (SELECT ... FROM SALES WHERE ...);
  EXCEPTION
    WHEN NO_DATA_FOUND THEN RETURN {'error': 'No data found'};
    WHEN OTHERS THEN RETURN {'error': 'Query failed'};
  END;
$$;
</font>

<b>Level 2: Agent resilience</b>:
Agent should:
- Detect error in tool response
- Try alternative approach
- Report error to user if unrecoverable

<b>Level 3: User-facing error messages</b>:
Return helpful errors:
❌ "SQL compilation error line 47"
✅ "Unable to calculate regional sales: Date range exceeds 90-day limit"

<b>Best practice</b>: Log all tool errors to Snowflake table for debugging."""
                },
                {
                    "q": "Q20: Can Cortex Agent maintain state across multiple user sessions?",
                    "a": """Not natively — each agent run is stateless. To maintain state:

<b>Option 1: Conversation history in Snowflake table</b>:
<font name="Courier">
CREATE TABLE agent_conversations (
  session_id STRING,
  turn_number INT,
  user_message STRING,
  agent_response STRING,
  timestamp TIMESTAMP
);
</font>

Load previous turns into agent context for each new query.

<b>Option 2: Session store in Streamlit</b>:
<font name="Courier">
if 'agent_history' not in st.session_state:
    st.session_state.agent_history = []
</font>

<b>Option 3: External session management</b>:
Store state in Redis/DynamoDB, load on each agent invocation

<b>Tradeoff</b>: More context = better continuity, but slower + more expensive (more tokens processed)

<b>Production pattern</b>: Store last 5-10 turns, summarize older history."""
                }
            ]
        },

        # Section 3: Document AI & Cortex Search (Q21-30)
        {
            "section": "Section 3: Document AI & Cortex Search",
            "questions": [
                {
                    "q": "Q21: What is Cortex Search and how does it differ from traditional keyword search?",
                    "a": """<b>Cortex Search</b> is a <b>hybrid search service</b> combining keyword (BM25) and semantic (vector embeddings) search.

<b>Traditional keyword search (e.g., Elasticsearch)</b>:
- Exact/fuzzy term matching
- Misses: Synonyms, paraphrases, semantic meaning
- Example: "refund" won't match "money back guarantee"

<b>Cortex Search (hybrid)</b>:
- Keyword: Matches exact terms (fast, precise)
- Semantic: Matches meaning (synonyms, paraphrases)
- Combined scoring for best results

<b>Example</b>:
Query: "How do I return a defective product?"
- Keyword match: "return policy"
- Semantic match: "exchange damaged items", "refund process"

<b>When to use</b>: RAG pipelines, document Q&A, customer support knowledge bases."""
                },
                {
                    "q": "Q22: How do you create a Cortex Search service?",
                    "a": """<b>Step 1: Create stage with documents</b>:
<font name="Courier">
CREATE STAGE docs_stage;
PUT file:///path/to/docs/*.pdf @docs_stage AUTO_COMPRESS=FALSE;
</font>

<b>Step 2: Create search service</b>:
<font name="Courier">
CREATE CORTEX SEARCH SERVICE doc_search_service
  ON document_text
  ATTRIBUTES product_id, category
  WAREHOUSE = COMPUTE_WH
  TARGET_LAG = '1 hour'
  AS (
    SELECT
      document_id,
      document_text,  -- Text to index
      product_id,     -- Filterable attribute
      category        -- Filterable attribute
    FROM DOCUMENTS_TABLE
  );
</font>

<b>Step 3: Query search service</b>:
<font name="Courier">
SELECT * FROM TABLE(
  doc_search_service!SEARCH(
    query => 'product warranty policy',
    limit => 5
  )
);
</font>

<b>Key parameters</b>:
- TARGET_LAG: Index freshness (1 min to 24 hours)
- ATTRIBUTES: Filterable fields for pre-filtering"""
                },
                {
                    "q": "Q23: What is TARGET_LAG in Cortex Search and how does it impact cost?",
                    "a": """<b>TARGET_LAG</b> controls how fresh the search index is.

<b>Options</b>:
- '1 minute': Near real-time (index updates every 60 sec)
- '1 hour': Moderate freshness (updates hourly)
- '24 hours': Daily refresh (lowest cost)

<b>Cost impact</b>:
Lower TARGET_LAG = More frequent indexing = Higher compute cost

<b>When to use each</b>:

<b>1 minute</b>: Live customer support (tickets updated constantly)
<b>1 hour</b>: Product catalog (updates hourly)
<b>24 hours</b>: Static documentation (rarely changes)

<b>Interview answer</b>: "TARGET_LAG is a cost vs. freshness tradeoff. For most RAG use cases, 1 hour is sufficient."

<b>How to tune</b>:
<font name="Courier">
ALTER CORTEX SEARCH SERVICE doc_search_service
  SET TARGET_LAG = '1 hour';
</font>"""
                },
                {
                    "q": "Q24: How does Cortex Search handle PDF documents?",
                    "a": """Cortex Search requires <b>extracted text</b> (doesn't parse PDFs natively). Two-step process:

<b>Step 1: Extract text from PDFs</b>:

<b>Option A: Snowflake PARSE_DOCUMENT function</b>:
<font name="Courier">
SELECT
  relative_path AS file_name,
  SNOWFLAKE.CORTEX.PARSE_DOCUMENT(
    @docs_stage, relative_path
  ) AS parsed_content
FROM DIRECTORY(@docs_stage);
</font>

<b>Option B: External tools (Python + pypdf)</b>:
Extract text, upload to Snowflake table

<b>Step 2: Index extracted text</b>:
<font name="Courier">
CREATE CORTEX SEARCH SERVICE pdf_search
  ON extracted_text
  AS (
    SELECT document_id, extracted_text, file_name
    FROM PDF_DOCUMENTS_TABLE
  );
</font>

<b>Pro tip</b>: Store both raw PDFs (in stage) and extracted text (in table) for traceability."""
                },
                {
                    "q": "Q25: What is a RAG (Retrieval-Augmented Generation) pipeline?",
                    "a": """<b>RAG</b> combines search + LLM generation to answer questions using external knowledge.

<b>Architecture</b>:
1. <b>Retrieval</b>: Search relevant documents (Cortex Search)
2. <b>Augmentation</b>: Add retrieved docs to LLM context
3. <b>Generation</b>: LLM generates answer citing sources

<b>Example RAG pipeline</b>:
User: "What's our return policy for defective products?"
1. Cortex Search retrieves: ["return_policy.pdf", "warranty_guide.pdf"]
2. Augment prompt: "Given these documents: [docs], answer: [question]"
3. LLM (COMPLETE function) generates: "Per our return policy (page 3), defective products can be returned within 30 days..."

<b>Why RAG?</b>
- LLMs have knowledge cutoff (can't answer about your company)
- RAG provides up-to-date, company-specific answers
- Cites sources (user can verify)

<b>Snowflake RAG stack</b>: Cortex Search + COMPLETE function + Streamlit UI"""
                },
                {
                    "q": "Q26: How do you filter Cortex Search results by attributes?",
                    "a": """Use <b>ATTRIBUTES</b> parameter in search service definition, then filter in query.

<b>Define filterable attributes</b>:
<font name="Courier">
CREATE CORTEX SEARCH SERVICE doc_search
  ATTRIBUTES product_category, doc_type, published_year
  AS (
    SELECT
      document_text,
      product_category,  -- e.g., 'Electronics', 'Clothing'
      doc_type,          -- e.g., 'Manual', 'Policy'
      published_year     -- e.g., 2024
    FROM DOCUMENTS
  );
</font>

<b>Query with filters</b>:
<font name="Courier">
SELECT * FROM TABLE(
  doc_search!SEARCH(
    query => 'warranty information',
    filter => {'product_category': 'Electronics', 'doc_type': 'Manual'},
    limit => 10
  )
);
</font>

<b>Use case</b>: "Find warranty info for electronics" → Only searches electronics manuals (not clothing docs).

<b>Performance</b>: Pre-filtering reduces search space → faster queries."""
                },
                {
                    "q": "Q27: What embedding model does Cortex Search use?",
                    "a": """Cortex Search uses <b>snowflake-arctic-embed-m</b> by default (768-dimensional embeddings).

<b>Model options</b>:
- <b>snowflake-arctic-embed-m</b> (default): Balanced speed/quality
- <b>snowflake-arctic-embed-l</b>: Higher quality, slower (1024-dim)
- Custom: Bring your own embeddings (e.g., OpenAI, Cohere)

<b>To specify model</b>:
<font name="Courier">
CREATE CORTEX SEARCH SERVICE doc_search
  ON document_text
  EMBEDDING_MODEL = 'snowflake-arctic-embed-l'
  ...
</font>

<b>When to use each</b>:
- <b>Default (m)</b>: Most use cases
- <b>Large (l)</b>: Highly technical docs (medical, legal)
- <b>Custom</b>: Domain-specific models (e.g., biomedical embeddings)

<b>Interview tip</b>: "Default model is sufficient for 95% of RAG use cases. Only tune if accuracy issues."" "
                },
                {
                    "q": "Q28: How do you handle multi-language documents in Cortex Search?",
                    "a": """Cortex Search's embedding models support <b>100+ languages</b> natively.

<b>Approach 1: Single multilingual index</b>:
<font name="Courier">
CREATE CORTEX SEARCH SERVICE global_docs
  ON document_text
  ATTRIBUTES language
  AS (
    SELECT document_text, language
    FROM DOCUMENTS
    WHERE language IN ('en', 'es', 'fr', 'de', 'hi')
  );
</font>

Query in any language:
<font name="Courier">
-- Query in English, matches Spanish/French docs too
SELECT * FROM TABLE(global_docs!SEARCH(
  query => 'return policy', limit => 5
));
</font>

<b>Approach 2: Language-specific indices</b>:
Create separate search services per language for better precision.

<b>Approach 3: Translate on-the-fly</b>:
<font name="Courier">
SELECT SNOWFLAKE.CORTEX.TRANSLATE(document_text, 'es', 'en')
FROM DOCUMENTS WHERE language = 'es';
</font>

<b>Best practice</b>: Store original language + English translation for maximum coverage."""
                },
                {
                    "q": "Q29: What's the difference between Cortex Search and vector databases (Pinecone, Weaviate)?",
                    "a": """<b>Cortex Search</b> (Snowflake-native):
- ✅ Integrated with Snowflake (no ETL)
- ✅ Governed by Snowflake RBAC
- ✅ Hybrid search (keyword + semantic)
- ❌ Limited customization (managed service)

<b>External vector DBs (Pinecone, Weaviate)</b>:
- ✅ Highly customizable (distance metrics, indexing algorithms)
- ✅ Optimized for vector search (faster for large-scale)
- ❌ Data replication required (security/compliance risk)
- ❌ Separate auth/governance

<b>When to use Cortex Search</b>:
- Data already in Snowflake
- Need Snowflake governance
- RAG use case (hybrid search preferred)

<b>When to use external vector DB</b>:
- Multi-cloud deployment
- Need advanced vector ops (ANN, HNSW tuning)
- Non-Snowflake data sources

<b>Interview answer</b>: "Cortex Search is ideal for Snowflake-native RAG pipelines. Use external DBs only if specific requirements."" "
                },
                {
                    "q": "Q30: How do you monitor Cortex Search performance and cost?",
                    "a": """<b>Performance monitoring</b>:

<b>1. Query latency</b>:
<font name="Courier">
SELECT
  query_text,
  execution_time_ms,
  rows_returned
FROM TABLE(INFORMATION_SCHEMA.CORTEX_SEARCH_HISTORY(
  SERVICE_NAME => 'doc_search',
  TIME_RANGE_START => DATEADD(day, -7, CURRENT_TIMESTAMP())
));
</font>

<b>2. Index lag</b>:
<font name="Courier">
SHOW CORTEX SEARCH SERVICES;
-- Check CURRENT_LAG vs TARGET_LAG
</font>

<b>Cost monitoring</b>:

<b>1. Storage cost</b>:
<font name="Courier">
SELECT
  service_name,
  index_size_bytes / POW(1024, 3) AS index_size_gb
FROM INFORMATION_SCHEMA.CORTEX_SEARCH_SERVICES;
</font>

<b>2. Compute cost</b>:
Cortex Search uses warehouse compute for indexing. Monitor warehouse usage:
<font name="Courier">
SELECT * FROM TABLE(INFORMATION_SCHEMA.WAREHOUSE_METERING_HISTORY(
  WAREHOUSE_NAME => 'COMPUTE_WH',
  DATE_RANGE_START => DATEADD(day, -7, CURRENT_TIMESTAMP())
));
</font>

<b>Optimization</b>: Increase TARGET_LAG if index lag consistently meets target (over-provisioned)."""
                }
            ]
        },

        # Section 4: Streamlit in Snowflake (SiS) Compatibility (Q31-40)
        {
            "section": "Section 4: Streamlit in Snowflake (SiS) Compatibility",
            "questions": [
                {
                    "q": "Q31: What is Streamlit in Snowflake (SiS) and how does it differ from local Streamlit?",
                    "a": """<b>Streamlit in Snowflake (SiS)</b> is a managed Streamlit runtime hosted within Snowflake.

<b>Key differences from local Streamlit</b>:

<b>1. API limitations</b>:
- No st.chat_input, st.chat_message, st.toggle (use alternatives)
- No file uploaders (use Snowflake stages)

<b>2. Pandas columns are UPPERCASE</b>:
- df.columns returns ['REVENUE', 'PRODUCT_NAME'] (not lowercase)
- Must normalize: df.columns = [c.lower() for c in df.columns]

<b>3. API calls use _snowflake.send_snow_api_request()</b>:
- Not requests library

<b>4. Authentication handled automatically</b>:
- st.connection("snowflake") uses current session

<b>Advantages</b>:
- No infrastructure management
- Snowflake RBAC integration
- Access to Snowflake data without credentials"""
                },
                {
                    "q": "Q32: How do you handle chat interfaces in Streamlit in Snowflake?",
                    "a": """SiS doesn't support st.chat_input. Use <b>st.text_input + st.button</b> pattern:

<b>❌ Doesn't work in SiS</b>:
<font name="Courier">
user_query = st.chat_input("Ask a question")
if user_query:
    st.chat_message("user").write(user_query)
    st.chat_message("assistant").write(response)
</font>

<b>✅ SiS-compatible pattern</b>:
<font name="Courier">
user_query = st.text_input("Ask a question", key="query_input")
if st.button("Submit"):
    if user_query:
        st.write(f"**You:** {user_query}")
        # Call Cortex API
        response = get_cortex_response(user_query)
        st.write(f"**Assistant:** {response}")
</font>

<b>Chat history</b>:
<font name="Courier">
if 'messages' not in st.session_state:
    st.session_state.messages = []

st.session_state.messages.append({"role": "user", "content": user_query})
st.session_state.messages.append({"role": "assistant", "content": response})

# Display history
for msg in st.session_state.messages:
    st.write(f"**{msg['role']}:** {msg['content']}")
</font>"""
                },
                {
                    "q": "Q33: Why do Snowflake Pandas DataFrames return UPPERCASE column names?",
                    "a": """Snowflake's SQL layer is <b>case-insensitive by default</b> and stores all identifiers as UPPERCASE.

<b>Example</b>:
<font name="Courier">
CREATE TABLE products (product_name STRING, price FLOAT);
-- Snowflake stores as: PRODUCT_NAME, PRICE
</font>

When you query via Snowpark:
<font name="Courier">
df = session.sql("SELECT product_name, price FROM products").to_pandas()
print(df.columns)  # ['PRODUCT_NAME', 'PRICE'] (not lowercase!)
</font>

<b>Problem</b>:
<font name="Courier">
df['product_name']  # ❌ KeyError!
df['PRODUCT_NAME']  # ✅ Works
</font>

<b>Solution</b> (always normalize):
<font name="Courier">
df.columns = [c.lower() for c in df.columns]
df['product_name']  # ✅ Now works
</font>

<b>Interview trap</b>: "App works in Snowflake Worksheets but fails in Streamlit with KeyError" → Forgot to normalize columns."""
                },
                {
                    "q": "Q34: How do you call Cortex APIs from Streamlit in Snowflake?",
                    "a": """Use <b>_snowflake.send_snow_api_request()</b> (not requests library):

<b>Cortex Analyst example</b>:
<font name="Courier">
from _snowflake import send_snow_api_request

def query_cortex_analyst(question, semantic_model_path):
    endpoint = "/api/v2/cortex/analyst/message"

    body = {
        "messages": [{"role": "user", "content": [{"type": "text", "text": question}]}],
        "semantic_model_file": semantic_model_path
    }

    response = send_snow_api_request(
        method="POST",
        url=endpoint,
        body=body
    )

    return response['message']['content']
</font>

<b>Cortex Agent example</b>:
<font name="Courier">
endpoint = "/api/v2/cortex/agent:run"
body = {
    "query": "Why did sales drop?",
    "tools": [...]  # Tool definitions
}
response = send_snow_api_request("POST", endpoint, body)
</font>

<b>Key point</b>: Authentication is automatic (uses current Snowflake session)."""
                },
                {
                    "q": "Q35: What Streamlit components are NOT supported in Streamlit in Snowflake?",
                    "a": """<b>Unsupported components</b> (as of 2026):

<b>Chat components</b>:
- st.chat_input() → Use st.text_input() + st.button()
- st.chat_message() → Use st.write() with role labels

<b>Newer components</b>:
- st.toggle() → Use st.checkbox()
- st.rerun() → Use st.experimental_rerun()
- st.divider() → Use st.markdown("---")

<b>File operations</b>:
- st.file_uploader() limitations (use Snowflake stages instead)

<b>Button parameters</b>:
- type="primary" not supported → Omit parameter

<b>DataFrame parameters</b>:
- hide_index not supported → Use df.to_html(index=False)

<b>Best practice</b>: Test locally first, then deploy to SiS. Fix compatibility issues using substitutions above.

<b>Check SiS version</b>:
<font name="Courier">
import streamlit as st
st.write(st.__version__)
</font>"""
                },
                {
                    "q": "Q36: How do you debug Streamlit apps in Snowflake?",
                    "a": """Debugging strategy:

<b>1. Use st.write() for logging</b>:
<font name="Courier">
st.write("Debug: DataFrame columns:", df.columns.tolist())
st.write("Debug: API response:", response)
</font>

<b>2. Try-except blocks with user-friendly errors</b>:
<font name="Courier">
try:
    df = session.sql(query).to_pandas()
except Exception as e:
    st.error(f"Query failed: {str(e)}")
    st.write("Debug info:", query)
</font>

<b>3. Check browser console</b>:
- Open DevTools (F12)
- Look for JavaScript errors

<b>4. Test locally first</b>:
<font name="Courier">
# Create local session
from snowflake.snowpark import Session
session = Session.builder.configs({
    "account": "xxx",
    "user": "xxx",
    "password": "xxx",
    ...
}).create()

# Run Streamlit locally
streamlit run app.py
</font>

<b>5. Use st.session_state for debugging state</b>:
<font name="Courier">
st.write("Session state:", st.session_state)
</font>

<b>Common issue</b>: UPPERCASE column KeyError → Add df.columns = [c.lower() for c in df.columns]"""
                },
                {
                    "q": "Q37: How do you handle Streamlit session state in Snowflake?",
                    "a": """Session state works the same in SiS as local Streamlit:

<b>Initialize state</b>:
<font name="Courier">
if 'counter' not in st.session_state:
    st.session_state.counter = 0

if 'messages' not in st.session_state:
    st.session_state.messages = []
</font>

<b>Update state</b>:
<font name="Courier">
if st.button("Increment"):
    st.session_state.counter += 1
    st.experimental_rerun()  # Use experimental_rerun in SiS
</font>

<b>Access state</b>:
<font name="Courier">
st.write(f"Count: {st.session_state.counter}")
</font>

<b>Common pattern: Chat history</b>:
<font name="Courier">
if 'chat_history' not in st.session_state:
    st.session_state.chat_history = []

# Add message
st.session_state.chat_history.append({
    "role": "user",
    "content": user_query
})

# Display history
for msg in st.session_state.chat_history:
    st.write(f"{msg['role']}: {msg['content']}")
</font>

<b>Note</b>: Session state is per-user, per-session (not shared across users)."""
                },
                {
                    "q": "Q38: How do you deploy a Streamlit app to Snowflake?",
                    "a": """<b>Step 1: Create app file</b>:
Save as app.py with SiS-compatible code.

<b>Step 2: Upload to Snowflake stage</b>:
<font name="Courier">
-- Create stage
CREATE STAGE streamlit_apps;

-- Upload file (via Snowsight or PUT command)
PUT file:///path/to/app.py @streamlit_apps AUTO_COMPRESS=FALSE;
</font>

<b>Step 3: Create Streamlit app</b>:
<font name="Courier">
CREATE STREAMLIT cortex_analyst_app
  ROOT_LOCATION = '@streamlit_apps'
  MAIN_FILE = '/app.py'
  QUERY_WAREHOUSE = COMPUTE_WH;
</font>

<b>Step 4: Access app</b>:
In Snowsight: Projects > Streamlit > cortex_analyst_app

<b>Step 5: Grant access</b>:
<font name="Courier">
GRANT USAGE ON STREAMLIT cortex_analyst_app TO ROLE analyst_role;
</font>

<b>Update app</b>:
Re-upload file to stage, then:
<font name="Courier">
ALTER STREAMLIT cortex_analyst_app SET MAIN_FILE = '/app.py';
</font>"""
                },
                {
                    "q": "Q39: What's the best way to cache Cortex API calls in Streamlit?",
                    "a": """Use <b>@st.cache_data</b> for API responses:

<b>Cache semantic model</b>:
<font name="Courier">
@st.cache_data(ttl=3600)  # Cache 1 hour
def load_semantic_model(model_path):
    # Load YAML from stage
    return yaml_content
</font>

<b>Cache Cortex Analyst responses</b>:
<font name="Courier">
@st.cache_data(ttl=300)  # Cache 5 minutes
def query_cortex_analyst(question, semantic_model):
    response = send_snow_api_request(...)
    return response
</font>

<b>Don't cache</b>:
- User-specific data (violates privacy)
- Real-time data (defeats purpose)
- Large objects (>100MB)

<b>Benefits</b>:
- Reduces API costs (fewer calls)
- Faster user experience
- Avoids rate limits

<b>Cache invalidation</b>:
<font name="Courier">
if st.button("Clear cache"):
    st.cache_data.clear()
    st.experimental_rerun()
</font>

<b>Interview tip</b>: "Caching is critical for production Streamlit apps to control costs and improve UX."" "
                },
                {
                    "q": "Q40: How do you handle large result sets in Streamlit in Snowflake?",
                    "a": """Large DataFrames (>10k rows) can crash Streamlit. Strategies:

<b>1. Pagination</b>:
<font name="Courier">
page_size = 100
page = st.number_input("Page", min_value=1, value=1)

offset = (page - 1) * page_size
query = f"SELECT * FROM orders LIMIT {page_size} OFFSET {offset}"
df = session.sql(query).to_pandas()
st.dataframe(df)
</font>

<b>2. Lazy loading with LIMIT</b>:
<font name="Courier">
st.write("Showing first 1000 rows. Use filters to narrow results.")
query = "SELECT * FROM orders LIMIT 1000"
df = session.sql(query).to_pandas()
</font>

<b>3. Aggregation instead of raw data</b>:
<font name="Courier">
# ❌ Don't: Load 1M rows
df = session.sql("SELECT * FROM orders").to_pandas()

# ✅ Do: Aggregate first
df = session.sql("""
  SELECT DATE_TRUNC('day', order_date) AS day,
         COUNT(*) AS orders,
         SUM(revenue) AS revenue
  FROM orders
  GROUP BY day
""").to_pandas()
</font>

<b>4. Download option for full data</b>:
<font name="Courier">
st.download_button(
    "Download full results (CSV)",
    df.to_csv(index=False),
    "results.csv"
)
</font>"""
                }
            ]
        },

        # Section 5: Production Patterns & Interview Questions (Q41-50)
        {
            "section": "Section 5: Production Patterns & Interview Questions",
            "questions": [
                {
                    "q": "Q41: How do you implement error handling for Cortex API calls in production?",
                    "a": """Multi-layer error handling:

<b>Layer 1: Network/API errors</b>:
<font name="Courier">
def safe_cortex_call(endpoint, body, max_retries=3):
    for attempt in range(max_retries):
        try:
            response = send_snow_api_request("POST", endpoint, body)
            return response
        except Exception as e:
            if attempt < max_retries - 1:
                time.sleep(2 ** attempt)  # Exponential backoff
                continue
            else:
                return {"error": f"API call failed after {max_retries} attempts"}
</font>

<b>Layer 2: Validation errors</b>:
<font name="Courier">
if "error" in response:
    st.error(f"Query failed: {response['error']}")
    return None
</font>

<b>Layer 3: Logging</b>:
<font name="Courier">
INSERT INTO cortex_api_logs (timestamp, endpoint, error, user)
VALUES (CURRENT_TIMESTAMP(), :endpoint, :error, CURRENT_USER());
</font>

<b>Layer 4: User fallback</b>:
"Unable to generate answer. Please rephrase your question or contact support."""
                },
                {
                    "q": "Q42: What are best practices for semantic YAML version control?",
                    "a": """<b>1. Git version control</b>:
Store YAML in Git repository with:
- Meaningful commit messages
- Branch per semantic model version
- PR review before deploying

<b>2. Semantic versioning in YAML</b>:
<font name="Courier">
# semantic_model_v1.2.0.yaml
metadata:
  version: "1.2.0"
  last_updated: "2024-01-15"
  author: "data-team"
</font>

<b>3. Automated validation</b>:
<font name="Courier">
# .github/workflows/validate-yaml.yml
- name: Validate YAML
  run: yamllint semantic_models/*.yaml
</font>

<b>4. Test suite for verified queries</b>:
<font name="Courier">
-- test_verified_queries.sql
-- Run all verified queries, assert results match expected
</font>

<b>5. Rollback plan</b>:
Keep previous version in stage:
<font name="Courier">
@semantic_models/cortex_analyst_v1.1.0.yaml  -- Previous (rollback)
@semantic_models/cortex_analyst_v1.2.0.yaml  -- Current
</font>"""
                },
                {
                    "q": "Q43: How do you optimize Snowflake warehouse costs for Cortex workloads?",
                    "a": """<b>1. Right-size warehouses</b>:
- Analyst queries: X-SMALL to SMALL
- Agent investigations: SMALL to MEDIUM
- Search indexing: MEDIUM to LARGE

<b>2. Auto-suspend aggressively</b>:
<font name="Courier">
ALTER WAREHOUSE COMPUTE_WH SET AUTO_SUSPEND = 60;  -- 1 minute
</font>

<b>3. Use multi-cluster for concurrency</b>:
<font name="Courier">
ALTER WAREHOUSE COMPUTE_WH SET
  MIN_CLUSTER_COUNT = 1,
  MAX_CLUSTER_COUNT = 3,
  SCALING_POLICY = 'ECONOMY';
</font>

<b>4. Cache semantic models</b> (avoid re-reading from stage):
<font name="Courier">
@st.cache_data(ttl=3600)
def load_semantic_model(): ...
</font>

<b>5. Monitor with cost dashboard</b>:
<font name="Courier">
SELECT
  warehouse_name,
  SUM(credits_used) AS total_credits,
  SUM(credits_used * 3.0) AS estimated_cost_usd  -- Adjust rate
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE start_time >= DATEADD(day, -30, CURRENT_TIMESTAMP())
GROUP BY warehouse_name;
</font>"""
                },
                {
                    "q": "Q44: How do you implement role-based access control (RBAC) for Cortex apps?",
                    "a": """<b>1. Create roles per user type</b>:
<font name="Courier">
CREATE ROLE analyst_role;
CREATE ROLE executive_role;
</font>

<b>2. Grant access to tables</b>:
<font name="Courier">
GRANT SELECT ON TABLE sales_data TO ROLE analyst_role;
GRANT SELECT ON ALL TABLES IN SCHEMA analytics TO ROLE executive_role;
</font>

<b>3. Grant access to Streamlit apps</b>:
<font name="Courier">
GRANT USAGE ON STREAMLIT cortex_analyst_app TO ROLE analyst_role;
</font>

<b>4. Limit semantic model scope by role</b>:
<font name="Courier">
# analyst_semantic_model.yaml (limited tables)
tables:
  - SALES_DATA
  - PRODUCTS

# executive_semantic_model.yaml (all tables)
tables:
  - SALES_DATA
  - PRODUCTS
  - FINANCIAL_METRICS
</font>

<b>5. Row-level security</b>:
<font name="Courier">
CREATE ROW ACCESS POLICY region_policy AS (region STRING)
RETURNS BOOLEAN ->
  CURRENT_ROLE() = 'GLOBAL_ADMIN' OR region = CURRENT_USER_REGION();

ALTER TABLE sales_data ADD ROW ACCESS POLICY region_policy ON (region);
</font>"""
                },
                {
                    "q": "Q45: What metrics should you monitor for production Cortex Analyst apps?",
                    "a": """<b>1. Query success rate</b>:
<font name="Courier">
SELECT
  DATE_TRUNC('hour', timestamp) AS hour,
  COUNT(*) AS total_queries,
  SUM(CASE WHEN status = 'success' THEN 1 ELSE 0 END) AS successful,
  (successful / total_queries * 100) AS success_rate
FROM cortex_analyst_logs
GROUP BY hour;
</font>

<b>2. Query latency (p50, p95, p99)</b>:
<font name="Courier">
SELECT
  APPROX_PERCENTILE(response_time_ms, 0.5) AS p50,
  APPROX_PERCENTILE(response_time_ms, 0.95) AS p95,
  APPROX_PERCENTILE(response_time_ms, 0.99) AS p99
FROM cortex_analyst_logs;
</font>

<b>3. Cost per query</b>:
<font name="Courier">
SELECT
  AVG(credits_used) AS avg_credits_per_query,
  AVG(credits_used * 3.0) AS avg_cost_usd
FROM cortex_analyst_logs
JOIN warehouse_metering ON ...;
</font>

<b>4. Top failing queries</b> (for semantic model improvements):
<font name="Courier">
SELECT question, COUNT(*) AS fail_count
FROM cortex_analyst_logs
WHERE status = 'error'
GROUP BY question
ORDER BY fail_count DESC
LIMIT 10;
</font>

<b>5. User adoption</b>:
Daily active users, queries per user, retention"""
                },
                {
                    "q": "Q46: How do you test Cortex Analyst semantic models before deploying to production?",
                    "a": """<b>1. Unit tests for verified queries</b>:
<font name="Courier">
-- test_verified_queries.sql
-- Run each verified query, assert row count > 0
SELECT * FROM TABLE(cortex_analyst!query('top products by revenue'));
-- Assert: Returns 5 rows
</font>

<b>2. Integration tests with sample questions</b>:
<font name="Courier">
test_questions = [
    "What is total revenue?",
    "Top 5 products by sales",
    "Revenue by region"
]

for question in test_questions:
    response = query_cortex_analyst(question, semantic_model)
    assert "error" not in response
    assert len(response['data']) > 0
</font>

<b>3. Schema validation</b>:
<font name="Courier">
import yaml
schema = yaml.safe_load(open("semantic_model.yaml"))

# Validate all tables exist
for table in schema['tables']:
    result = session.sql(f"SELECT COUNT(*) FROM {table['name']}").collect()
    assert result[0][0] > 0, f"Table {table['name']} is empty"
</font>

<b>4. Load testing</b>:
<font name="Courier">
# Simulate 100 concurrent users
import concurrent.futures

def send_query():
    return query_cortex_analyst("What is total revenue?", model)

with concurrent.futures.ThreadPoolExecutor(max_workers=100) as executor:
    results = list(executor.map(lambda _: send_query(), range(100)))
</font>"""
                },
                {
                    "q": "Q47: How do you handle schema evolution when tables change?",
                    "a": """<b>1. Detect schema changes</b>:
<font name="Courier">
-- Compare current schema to semantic model
SELECT column_name, data_type
FROM INFORMATION_SCHEMA.COLUMNS
WHERE table_name = 'SALES_DATA'
  AND column_name NOT IN (
    -- Columns listed in semantic YAML
    'ORDER_ID', 'REVENUE', 'ORDER_DATE'
  );
</font>

<b>2. Backward-compatible changes</b>:
- Adding columns: Safe (update YAML to include)
- Renaming columns: Create view with old name
<font name="Courier">
CREATE VIEW sales_data_v2 AS
SELECT new_column_name AS old_column_name, ...
FROM sales_data;
</font>

<b>3. Breaking changes</b>:
- Dropping columns: Version semantic model
<font name="Courier">
@semantic_models/analyst_v1.yaml  -- Uses old schema
@semantic_models/analyst_v2.yaml  -- Uses new schema
</font>

<b>4. Automated sync</b>:
<font name="Courier">
-- Stored procedure to regenerate YAML from current schema
CREATE PROCEDURE sync_semantic_model()
RETURNS STRING
AS $$
  -- Read INFORMATION_SCHEMA
  -- Generate YAML
  -- Upload to stage
$$;
</font>

<b>5. Testing</b>:
Run verified query test suite after schema changes."""
                },
                {
                    "q": "Q48: What's the difference between synchronous and asynchronous agent execution?",
                    "a": """<b>Synchronous (blocking)</b>:
<font name="Courier">
# User waits for agent to complete
response = send_snow_api_request("POST", "/api/v2/cortex/agent:run", body)
st.write(response['result'])
</font>

Pros: Simple, immediate result
Cons: User blocked during long investigations (30-60 sec)

<b>Asynchronous (non-blocking)</b>:
<font name="Courier">
# Step 1: Start agent run
response = send_snow_api_request("POST", "/api/v2/cortex/agent:run", body)
run_id = response['run_id']

# Step 2: Poll for completion
while True:
    status = send_snow_api_request("GET", f"/api/v2/cortex/agent/runs/{run_id}")
    if status['state'] == 'COMPLETED':
        break
    time.sleep(2)  # Poll every 2 seconds

# Step 3: Get result
result = status['result']
</font>

Pros: User can do other things, better UX for long runs
Cons: More complex, requires polling or webhooks

<b>When to use each</b>:
- Sync: Simple queries (<10 sec)
- Async: Complex investigations (>10 sec)"""
                },
                {
                    "q": "Q49: How do you implement A/B testing for Cortex Analyst semantic models?",
                    "a": """<b>1. Deploy multiple semantic model versions</b>:
<font name="Courier">
@semantic_models/analyst_v1.yaml  -- Control (5 tables)
@semantic_models/analyst_v2.yaml  -- Variant (7 tables, new relationships)
</font>

<b>2. Random assignment</b>:
<font name="Courier">
import random

def get_semantic_model(user_id):
    variant = random.choice(['v1', 'v2']) if hash(user_id) % 2 == 0 else 'v1'
    return f"@semantic_models/analyst_{variant}.yaml"
</font>

<b>3. Log variant with queries</b>:
<font name="Courier">
INSERT INTO cortex_analyst_logs (
  user_id, question, variant, response_time, success
)
VALUES (:user_id, :question, :variant, :response_time, :success);
</font>

<b>4. Analyze results</b>:
<font name="Courier">
SELECT
  variant,
  AVG(response_time) AS avg_latency,
  SUM(CASE WHEN success THEN 1 ELSE 0 END) / COUNT(*) AS success_rate
FROM cortex_analyst_logs
GROUP BY variant;
</font>

<b>5. Rollout winner</b>:
If v2 has higher success rate + acceptable latency → promote to default"""
                },
                {
                    "q": "Q50: What's your approach to building a production Cortex app from scratch?",
                    "a": """<b>Step 1: Requirements (1 day)</b>:
- Who are users? (analysts, executives, support)
- What questions do they ask? (top 10 use cases)
- Which tables/data sources?
- Latency/cost constraints?

<b>Step 2: Data modeling (2 days)</b>:
- Design star schema (fact + dimensions)
- Create views for complex joins
- Load sample data
- Validate with SQL queries

<b>Step 3: Semantic model (2 days)</b>:
- Start with 3-5 tables
- Define relationships
- Add 5-10 verified queries
- Test with sample questions

<b>Step 4: Streamlit app (2 days)</b>:
- Build SiS-compatible UI
- Implement Cortex API calls
- Add error handling, caching
- Test locally, deploy to Snowflake

<b>Step 5: Testing & iteration (3 days)</b>:
- User acceptance testing
- Fix edge cases
- Optimize performance
- Add monitoring

<b>Total: 10 days for MVP</b>

<b>Post-launch</b>:
- Monitor query logs
- Expand semantic model based on failed queries
- A/B test improvements
- Scale infrastructure as usage grows"""
                }
            ]
        }
    ]

    # Build content
    for section in questions:
        # Section header
        story.append(Paragraph(section["section"], section_style))
        story.append(Spacer(1, 0.2*inch))

        # Questions in section
        for qa in section["questions"]:
            story.append(Paragraph(qa["q"], question_style))
            story.append(Paragraph(qa["a"], answer_style))

    # Footer page
    story.append(PageBreak())
    story.append(Spacer(1, 2*inch))

    outro = Paragraph(
        "<b>Want to master Snowflake Cortex in 12 hours?</b>",
        title_style
    )
    story.append(outro)
    story.append(Spacer(1, 0.3*inch))

    cta_text = """Join the <b>Snowflake Cortex Masterclass</b> launching February 20, 2026.<br/><br/>

    Build 3 production AI apps:<br/>
    - Cortex Analyst (natural language to SQL)<br/>
    - Data Agent (autonomous root cause analysis)<br/>
    - Document AI + RAG pipeline<br/><br/>

    <b>Early Bird: ₹4,999</b> (₹2,000 savings, first 50 students)<br/>
    <b>Regular: ₹6,999</b><br/><br/>

    <b>Join waitlist:</b> snowbrix.academy/cortex-masterclass<br/>
    <b>GitHub:</b> github.com/snowbrix-academy/cortex-masterclass<br/><br/>

    Production-Grade Data Engineering. No Fluff."""

    story.append(Paragraph(cta_text, subtitle_style))

    # Build PDF
    doc.build(story)
    print("✅ PDF created: 50_Snowflake_Cortex_Interview_Questions.pdf")

if __name__ == "__main__":
    create_interview_guide()
