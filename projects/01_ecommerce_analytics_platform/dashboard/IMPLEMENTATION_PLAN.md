# MODULE 5: DASHBOARD

## Streamlit Analytics Dashboard

**Video Segment:** 2:45 - 3:12 (27 minutes)
**Git Tag:** `v0.7-dashboard`

---

## OVERVIEW

We build a Streamlit dashboard — not Tableau, not Looker, not Power BI. Why?

1. **It's code.** Version controlled, peer-reviewed, deployed like any other application.
2. **It's free.** No per-seat licensing that scales to $50K/year.
3. **It ships in 20 minutes.** No drag-and-drop learning curve.
4. **It connects directly to Snowflake.** No intermediate caching layer needed.

This dashboard is NOT a replacement for a full BI tool. It's a proof-of-concept that demonstrates: the data is clean, the models work, and the platform delivers value. For the video, it's the visual payoff after 2.5 hours of infrastructure and SQL.

---

## SUBMODULE 5.1: SNOWFLAKE CONNECTION

**File:** `snowflake_connection.py`

### What Gets Built

A cached Snowflake connection optimized for Streamlit:
- Uses `@st.cache_resource` to avoid reconnecting on every page refresh
- Connects with the ECOMMERCE_ANALYST role (read-only to ANALYTICS database)
- Uses the REPORTING_WH warehouse
- Parameterized queries to prevent SQL injection

### Key Design Decision

Streamlit re-runs the entire script on every user interaction. Without caching, every button click opens a new Snowflake connection. `@st.cache_resource` ensures ONE connection is shared across all reruns.

```python
@st.cache_resource
def get_snowflake_connection():
    return snowflake.connector.connect(
        account=os.getenv("SNOWFLAKE_ACCOUNT"),
        user=os.getenv("SNOWFLAKE_USER"),
        password=os.getenv("SNOWFLAKE_PASSWORD"),
        role="ECOMMERCE_ANALYST",
        warehouse="REPORTING_WH",
        database="ECOMMERCE_ANALYTICS",
        schema="MARTS",
    )
```

---

## SUBMODULE 5.2: QUERY LAYER

**Files:** `queries/revenue.sql`, `queries/customers.sql`, `queries/products.sql`, `queries/kpis.sql`

### Queries

| File | Purpose | Source Table |
|------|---------|-------------|
| `kpis.sql` | Total revenue, order count, avg order value, active customers | fct_daily_revenue, dim_customers |
| `revenue.sql` | Daily revenue time series (last 90 days) | fct_daily_revenue |
| `customers.sql` | Customer LTV distribution, top customers | dim_customers via int_customer_lifetime |
| `products.sql` | Top 10 products by revenue, category breakdown | fct_orders + dim_products |

### Why Separate SQL Files?

1. SQL in Python strings is unreadable, untestable, and un-lintable.
2. Separate `.sql` files can be tested independently against Snowflake.
3. Analysts can modify queries without touching Python code.

---

## SUBMODULE 5.3: DASHBOARD LAYOUT

**File:** `streamlit_app.py`

### Page Layout

```
┌─────────────────────────────────────────────────────────────────────┐
│                    SNOWBRIX E-COMMERCE DASHBOARD                     │
│  [Date Range Picker: Last 7d | 30d | 90d | Custom]                 │
├──────────────┬──────────────┬──────────────┬────────────────────────┤
│  Total       │  Orders      │  Avg Order   │  Active                │
│  Revenue     │  Today       │  Value       │  Customers             │
│  $2.4M  +12% │  1,247  +8% │  $68.42 +3%  │  12,847  +15%         │
│  (vs prior)  │  (vs prior)  │  (vs prior)  │  (vs prior)           │
├──────────────┴──────────────┴──────────────┴────────────────────────┤
│                                                                      │
│  📈 Revenue Over Time (Line Chart — Plotly)                         │
│  ████████████████████████████████████████████████████                │
│  [Toggle: Daily | Weekly | Monthly]                                  │
│                                                                      │
├──────────────────────────────┬───────────────────────────────────────┤
│                              │                                       │
│  📊 Customer LTV             │  📊 Top 10 Products by Revenue        │
│  Distribution (Histogram)    │  (Horizontal Bar Chart)               │
│                              │                                       │
│  Median: $245                │  1. Product X — $124K                 │
│  Mean: $312                  │  2. Product Y — $98K                  │
│  P90: $680                   │  ...                                  │
│                              │                                       │
├──────────────────────────────┼───────────────────────────────────────┤
│                              │                                       │
│  🍩 Revenue by Category      │  📈 Daily Order Count (Area Chart)    │
│  (Donut Chart)               │                                       │
│                              │                                       │
├──────────────────────────────┴───────────────────────────────────────┤
│                                                                      │
│  📋 Recent Orders Table (last 50 orders, sortable, filterable)       │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

### Interactive Features

| Feature | Implementation |
|---------|---------------|
| Date range picker | `st.date_input()` — filters all queries via WHERE clause |
| Period comparison | Calculate vs. same period prior (e.g., last 30d vs. 30d before that) |
| Auto-refresh | `st.rerun()` every 5 minutes via `time.sleep()` + config toggle |
| Category filter | `st.multiselect()` — filter revenue chart by product category |
| Export | `st.download_button()` — download filtered data as CSV |

### Chart Library: Plotly

We use Plotly (via `st.plotly_chart()`) instead of Streamlit's built-in charts because:
- Better formatting control (colors matching brand palette)
- Interactive hover tooltips
- Professional appearance for video recording

### Brand Colors in Charts

```python
BRAND_COLORS = {
    "primary": "#1A1A2E",      # Deep Charcoal
    "cyan": "#00D4FF",         # Snowflake blue
    "orange": "#FF6B35",       # Databricks orange
    "gray": "#B0A8A0",         # Neutral
    "red": "#E63946",          # Alert
    "green": "#2ECC71",        # Success
}
```

---

## FILES IN THIS MODULE

```
dashboard/
├── IMPLEMENTATION_PLAN.md      ← You are here
├── streamlit_app.py            ← Main dashboard application
├── snowflake_connection.py     ← Cached Snowflake connection
└── queries/
    ├── kpis.sql                ← KPI card queries
    ├── revenue.sql             ← Revenue time series
    ├── customers.sql           ← Customer LTV analysis
    └── products.sql            ← Product performance
```

---

## VERIFICATION CHECKLIST

- [ ] Dashboard launches at `localhost:8501`
- [ ] All 4 KPI cards show real numbers (not zero, not error)
- [ ] Revenue chart renders with correct date range
- [ ] Date range picker filters all charts correctly
- [ ] Period-over-period comparison shows correct delta
- [ ] Page load time < 3 seconds (check Streamlit profiler)
- [ ] Auto-refresh works when enabled
- [ ] CSV export downloads correctly
- [ ] Dashboard works with ECOMMERCE_ANALYST role (no elevated permissions)
