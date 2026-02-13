# ============================================================
# SNOWBRIX E-COMMERCE PLATFORM — Custom Airflow Docker Image
# ============================================================
#
# Extends the official Airflow image with project-specific
# dependencies for data ingestion (psycopg2, stripe, requests)
# and transformation (dbt-core, dbt-snowflake).
#
# Build context: ./airflow (set in docker-compose.yml)
# Used by:       airflow-webserver, airflow-scheduler, airflow-init
#
# Rebuild after changing dependencies:
#   docker-compose build --no-cache
# ============================================================

FROM apache/airflow:2.8.1-python3.11

# ──────────────────────────────────────────────
# METADATA
# ──────────────────────────────────────────────
LABEL maintainer="Snowbrix Academy <hello@snowbrix.dev>"
LABEL description="Airflow image with dbt, Snowflake, and ingestion dependencies"
LABEL version="1.0.0"

# ──────────────────────────────────────────────
# INSTALL PYTHON DEPENDENCIES
# ──────────────────────────────────────────────
# Switch to airflow user (required by the base image's security model).
# The official Airflow image does NOT allow pip install as root.
USER airflow

# Copy requirements first for Docker layer caching.
# If requirements don't change, this layer is cached and the build is fast.
COPY requirements-airflow.txt /opt/airflow/requirements-airflow.txt

RUN pip install --no-cache-dir -r /opt/airflow/requirements-airflow.txt

# ──────────────────────────────────────────────
# CONFIGURE AIRFLOW
# ──────────────────────────────────────────────
# Ensure the ingestion package is importable from DAGs.
# The ingestion/ directory is volume-mounted at /opt/airflow/ingestion
# by docker-compose.yml. Adding /opt/airflow to PYTHONPATH lets
# DAGs do: "from ingestion.postgres_extractor import PostgresExtractor"
ENV PYTHONPATH="/opt/airflow:${PYTHONPATH}"

# dbt expects a profiles.yml in ~/.dbt/ by default.
# We override this in the BashOperator with --profiles-dir,
# but set the env var as a fallback.
ENV DBT_PROFILES_DIR="/opt/airflow/dbt_ecommerce"

# ──────────────────────────────────────────────
# HEALTHCHECK
# ──────────────────────────────────────────────
# The webserver and scheduler have their own healthchecks in
# docker-compose.yml. This is a generic fallback.
HEALTHCHECK --interval=30s --timeout=10s --retries=3 \
    CMD python -c "import airflow; print('OK')" || exit 1
