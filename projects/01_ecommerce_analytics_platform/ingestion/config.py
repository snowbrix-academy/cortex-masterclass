"""
Snowbrix E-Commerce Platform — Centralized Configuration
Loads all settings from environment variables with validation.
"""

import os
import sys
from dataclasses import dataclass, field
from pathlib import Path

from dotenv import load_dotenv

# Load .env from project root
PROJECT_ROOT = Path(__file__).parent.parent
load_dotenv(PROJECT_ROOT / ".env")


@dataclass
class SnowflakeConfig:
    """Snowflake connection settings."""

    account: str = ""
    user: str = ""
    password: str = ""
    role: str = "ECOMMERCE_LOADER"
    warehouse: str = "LOADING_WH"
    database: str = "ECOMMERCE_RAW"
    schema: str = "POSTGRES"

    def __post_init__(self):
        self.account = os.getenv("SNOWFLAKE_ACCOUNT", self.account)
        self.user = os.getenv("SNOWFLAKE_USER", self.user)
        self.password = os.getenv("SNOWFLAKE_PASSWORD", self.password)
        self.role = os.getenv("SNOWFLAKE_ROLE", self.role)
        self.warehouse = os.getenv("SNOWFLAKE_WAREHOUSE", self.warehouse)
        self.database = os.getenv("SNOWFLAKE_DATABASE", self.database)

    def validate(self):
        missing = []
        if not self.account:
            missing.append("SNOWFLAKE_ACCOUNT")
        if not self.user:
            missing.append("SNOWFLAKE_USER")
        if not self.password:
            missing.append("SNOWFLAKE_PASSWORD")
        if missing:
            print(f"ERROR: Missing environment variables: {', '.join(missing)}")
            print("Copy .env.example to .env and fill in your credentials.")
            sys.exit(1)


@dataclass
class PostgresConfig:
    """Source PostgreSQL connection settings."""

    host: str = "localhost"
    port: int = 5432
    database: str = "ecommerce_source"
    user: str = "postgres"
    password: str = "postgres"

    def __post_init__(self):
        self.host = os.getenv("POSTGRES_HOST", self.host)
        self.port = int(os.getenv("POSTGRES_PORT", str(self.port)))
        self.database = os.getenv("POSTGRES_DB", self.database)
        self.user = os.getenv("POSTGRES_USER", self.user)
        self.password = os.getenv("POSTGRES_PASSWORD", self.password)


@dataclass
class StripeConfig:
    """Stripe API settings."""

    api_key: str = ""
    base_url: str = "https://api.stripe.com/v1"
    requests_per_second: int = 25  # Conservative rate limit

    def __post_init__(self):
        self.api_key = os.getenv("STRIPE_API_KEY", self.api_key)
        self.base_url = os.getenv("STRIPE_API_BASE_URL", self.base_url)


@dataclass
class IngestionConfig:
    """Master configuration combining all sources."""

    snowflake: SnowflakeConfig = field(default_factory=SnowflakeConfig)
    postgres: PostgresConfig = field(default_factory=PostgresConfig)
    stripe: StripeConfig = field(default_factory=StripeConfig)

    # Runtime settings
    batch_size: int = 10_000
    temp_dir: str = str(PROJECT_ROOT / "tmp")
    log_level: str = "INFO"

    def __post_init__(self):
        self.log_level = os.getenv("LOG_LEVEL", self.log_level)
        # Ensure temp directory exists
        Path(self.temp_dir).mkdir(parents=True, exist_ok=True)


# Tables to extract from PostgreSQL
POSTGRES_TABLES = [
    {
        "source_table": "orders",
        "target_schema": "POSTGRES",
        "target_table": "RAW_ORDERS",
        "incremental_column": "updated_at",
        "primary_key": "order_id",
    },
    {
        "source_table": "customers",
        "target_schema": "POSTGRES",
        "target_table": "RAW_CUSTOMERS",
        "incremental_column": "updated_at",
        "primary_key": "customer_id",
    },
    {
        "source_table": "products",
        "target_schema": "POSTGRES",
        "target_table": "RAW_PRODUCTS",
        "incremental_column": "updated_at",
        "primary_key": "product_id",
    },
    {
        "source_table": "order_items",
        "target_schema": "POSTGRES",
        "target_table": "RAW_ORDER_ITEMS",
        "incremental_column": "created_at",  # Append-only — no updates
        "primary_key": "order_item_id",
    },
]
