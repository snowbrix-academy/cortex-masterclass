"""
Snowbrix E-Commerce Platform — PostgreSQL Data Seeder

Generates realistic e-commerce data and inserts into the source
PostgreSQL database. Run once after Docker starts.

Usage:
    python ingestion/seed/seed_postgres.py
    python ingestion/seed/seed_postgres.py --customers 50000 --orders 100000
"""

import argparse
import logging
import random
import sys
import time
from datetime import datetime, timedelta

import psycopg2
import psycopg2.extras

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("seed_postgres")

# Attempt to use Faker; fall back to basic generation if not installed
try:
    from faker import Faker
    fake = Faker("en_US")
    HAS_FAKER = True
except ImportError:
    HAS_FAKER = False
    logger.warning("Faker not installed. Using basic data generation.")


# ── Product catalog ──────────────────────────────────────────

CATEGORIES = {
    "Electronics": ["Smartphones", "Laptops", "Headphones", "Tablets", "Cameras"],
    "Clothing": ["Men's Shirts", "Women's Dresses", "Shoes", "Accessories", "Outerwear"],
    "Home & Garden": ["Furniture", "Kitchen", "Bedding", "Lighting", "Tools"],
    "Books": ["Fiction", "Non-Fiction", "Technical", "Children's", "Comics"],
    "Sports": ["Fitness", "Outdoor", "Team Sports", "Water Sports", "Cycling"],
    "Beauty": ["Skincare", "Makeup", "Fragrance", "Hair Care", "Bath & Body"],
    "Food & Drink": ["Coffee", "Snacks", "Supplements", "Beverages", "Gourmet"],
    "Toys": ["Board Games", "Action Figures", "Puzzles", "Educational", "Outdoor Toys"],
    "Office": ["Stationery", "Desk Accessories", "Tech Accessories", "Organization", "Chairs"],
    "Pet Supplies": ["Dog", "Cat", "Fish", "Bird", "Small Animal"],
}

ORDER_STATUSES = ["completed", "shipped", "cancelled", "pending", "pending_review", "refunded"]
ORDER_STATUS_WEIGHTS = [0.55, 0.20, 0.08, 0.10, 0.04, 0.03]

US_STATES = [
    "AL", "AK", "AZ", "AR", "CA", "CO", "CT", "DE", "FL", "GA",
    "HI", "ID", "IL", "IN", "IA", "KS", "KY", "LA", "ME", "MD",
    "MA", "MI", "MN", "MS", "MO", "MT", "NE", "NV", "NH", "NJ",
    "NM", "NY", "NC", "ND", "OH", "OK", "OR", "PA", "RI", "SC",
    "SD", "TN", "TX", "UT", "VT", "VA", "WA", "WV", "WI", "WY",
]

# Intentional messiness: some states as full names (data quality exercise)
MESSY_STATES = US_STATES + ["California", "New York", "Texas", "Florida", "Illinois"]


def generate_customers(n=50000):
    """Generate customer records."""
    logger.info("Generating %d customers...", n)
    customers = []
    emails_seen = set()

    for i in range(n):
        if HAS_FAKER:
            first = fake.first_name()
            last = fake.last_name()
            email = f"{first.lower()}.{last.lower()}.{i}@{fake.free_email_domain()}"
            city = fake.city()
            address = fake.street_address()
            zip_code = fake.zipcode()
        else:
            first = f"First{i}"
            last = f"Last{i}"
            email = f"user{i}@example.com"
            city = f"City{i % 100}"
            address = f"{i} Main St"
            zip_code = f"{10000 + i % 90000}"

        # Intentional: 30% have NULL phone
        phone = fake.phone_number() if HAS_FAKER and random.random() > 0.3 else None

        # Intentional: mixed state formats
        state = random.choice(MESSY_STATES)

        created = datetime.now() - timedelta(days=random.randint(1, 730))
        updated = created + timedelta(days=random.randint(0, 30))

        customers.append((
            email, first, last, phone, address, city,
            state, "US", zip_code, created, updated,
        ))

    return customers


def generate_products(n=200):
    """Generate product catalog."""
    logger.info("Generating %d products...", n)
    products = []

    for i in range(n):
        category = random.choice(list(CATEGORIES.keys()))
        subcategory = random.choice(CATEGORIES[category])
        price = round(random.gauss(65, 40), 2)
        price = max(price, 4.99)  # Floor at $4.99

        # Intentional: some products have negative cost (data entry bug)
        cost = round(price * random.uniform(0.3, 0.7), 2)
        if random.random() < 0.02:  # 2% have negative cost
            cost = -abs(cost)

        weight = round(random.uniform(0.1, 25.0), 2) if random.random() > 0.1 else None

        if HAS_FAKER:
            name = f"{fake.word().title()} {subcategory} {fake.word().title()}"
        else:
            name = f"Product {i} - {subcategory}"

        created = datetime.now() - timedelta(days=random.randint(30, 730))
        updated = created + timedelta(days=random.randint(0, 30))

        products.append((
            name, category, subcategory, price, cost,
            weight, random.random() > 0.05, created, updated,
        ))

    return products


def generate_orders(n=100000, num_customers=50000):
    """Generate orders with seasonal patterns."""
    logger.info("Generating %d orders...", n)
    orders = []

    base_date = datetime.now() - timedelta(days=365)

    for i in range(n):
        customer_id = random.randint(1, num_customers)

        # Seasonal weighting: more orders in Nov-Dec (Black Friday, Christmas)
        day_offset = random.randint(0, 364)
        order_date = base_date + timedelta(days=day_offset)
        month = order_date.month
        if month in (11, 12):
            # 40% chance to keep holiday orders, making them more common
            if random.random() > 0.6:
                day_offset = random.randint(305, 364)  # Nov-Dec
                order_date = base_date + timedelta(days=day_offset)

        status = random.choices(ORDER_STATUSES, weights=ORDER_STATUS_WEIGHTS, k=1)[0]
        total = round(random.gauss(85, 50), 2)
        total = max(total, 9.99)

        if HAS_FAKER:
            addr = fake.street_address()
            city = fake.city()
            zip_code = fake.zipcode()
        else:
            addr = f"{i} Commerce Ave"
            city = f"City{i % 200}"
            zip_code = f"{10000 + i % 90000}"

        state = random.choice(MESSY_STATES)
        created = order_date
        updated = order_date + timedelta(hours=random.randint(1, 168))

        orders.append((
            customer_id, order_date, status, total,
            addr, city, state, "US", zip_code, created, updated,
        ))

    return orders


def generate_order_items(num_orders=100000, num_products=200):
    """Generate order items (2-3 items per order average)."""
    logger.info("Generating order items...")
    items = []

    for order_id in range(1, num_orders + 1):
        num_items = random.choices([1, 2, 3, 4, 5], weights=[20, 35, 25, 15, 5], k=1)[0]

        for _ in range(num_items):
            product_id = random.randint(1, num_products)
            quantity = random.choices([1, 2, 3, 4, 5], weights=[50, 25, 15, 7, 3], k=1)[0]
            unit_price = round(random.gauss(45, 25), 2)
            unit_price = max(unit_price, 4.99)
            discount = round(random.choice([0, 0, 0, 5, 10, 15, 20, 25]), 2)
            line_total = round(quantity * unit_price * (1 - discount / 100), 2)
            created = datetime.now() - timedelta(days=random.randint(0, 365))

            items.append((order_id, product_id, quantity, unit_price, discount, line_total, created))

    logger.info("Generated %d order items", len(items))
    return items


def seed_database(conn, customers, products, orders, order_items):
    """Insert all generated data into PostgreSQL."""
    cursor = conn.cursor()

    # Customers
    logger.info("Inserting %d customers...", len(customers))
    psycopg2.extras.execute_values(
        cursor,
        """INSERT INTO customers (email, first_name, last_name, phone, address, city,
           state, country, zip_code, created_at, updated_at) VALUES %s
           ON CONFLICT (email) DO NOTHING""",
        customers,
        page_size=5000,
    )
    conn.commit()

    # Products
    logger.info("Inserting %d products...", len(products))
    psycopg2.extras.execute_values(
        cursor,
        """INSERT INTO products (name, category, subcategory, price, cost,
           weight_kg, is_active, created_at, updated_at) VALUES %s""",
        products,
        page_size=1000,
    )
    conn.commit()

    # Orders
    logger.info("Inserting %d orders...", len(orders))
    psycopg2.extras.execute_values(
        cursor,
        """INSERT INTO orders (customer_id, order_date, status, total_amount,
           shipping_address, shipping_city, shipping_state, shipping_country,
           shipping_zip, created_at, updated_at) VALUES %s""",
        orders,
        page_size=5000,
    )
    conn.commit()

    # Order Items
    logger.info("Inserting %d order items...", len(order_items))
    psycopg2.extras.execute_values(
        cursor,
        """INSERT INTO order_items (order_id, product_id, quantity, unit_price,
           discount_pct, line_total, created_at) VALUES %s""",
        order_items,
        page_size=10000,
    )
    conn.commit()

    cursor.close()
    logger.info("Seeding complete.")


def main():
    parser = argparse.ArgumentParser(description="Seed PostgreSQL with e-commerce data")
    parser.add_argument("--customers", type=int, default=50000)
    parser.add_argument("--products", type=int, default=200)
    parser.add_argument("--orders", type=int, default=100000)
    parser.add_argument("--host", default="localhost")
    parser.add_argument("--port", type=int, default=5432)
    parser.add_argument("--db", default="ecommerce_source")
    parser.add_argument("--user", default="postgres")
    parser.add_argument("--password", default="postgres")
    args = parser.parse_args()

    start = time.time()

    # Generate data
    customers = generate_customers(args.customers)
    products = generate_products(args.products)
    orders = generate_orders(args.orders, args.customers)
    order_items = generate_order_items(args.orders, args.products)

    # Connect and seed
    conn = psycopg2.connect(
        host=args.host, port=args.port, dbname=args.db,
        user=args.user, password=args.password,
    )
    try:
        seed_database(conn, customers, products, orders, order_items)
    finally:
        conn.close()

    elapsed = time.time() - start
    logger.info("Total seeding time: %.2fs", elapsed)
    logger.info("Rows: %d customers, %d products, %d orders, %d items",
                len(customers), len(products), len(orders), len(order_items))


if __name__ == "__main__":
    main()
