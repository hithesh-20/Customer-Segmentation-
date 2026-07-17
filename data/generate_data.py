"""
Generate synthetic e-commerce transaction data for Customer Segmentation / RFM Analysis.
Produces 50K+ transaction records with customers, products, and transactions.
"""

import pandas as pd
import numpy as np
from faker import Faker
import random
from datetime import datetime, timedelta
import os

# Configuration
NUM_CUSTOMERS = 6000
START_DATE = datetime(2023, 1, 1)
END_DATE = datetime(2026, 6, 30)
OUTPUT_DIR = "data"

fake = Faker()
np.random.seed(42)
random.seed(42)

# Ensure output directory exists
os.makedirs(OUTPUT_DIR, exist_ok=True)

print("Generating customer data...")

# --- Generate Customers ---
customer_ids = [f"C{str(i).zfill(6)}" for i in range(1, NUM_CUSTOMERS + 1)]
customers = pd.DataFrame({
    "customer_id": customer_ids,
    "customer_name": [fake.name() for _ in range(NUM_CUSTOMERS)],
    "email": [fake.email() for _ in range(NUM_CUSTOMERS)],
    "city": [fake.city() for _ in range(NUM_CUSTOMERS)],
    "state": [fake.state() for _ in range(NUM_CUSTOMERS)],
    "country": [fake.country() for _ in range(NUM_CUSTOMERS)],
    "signup_date": [fake.date_between(start_date="-3y", end_date="-1d") for _ in range(NUM_CUSTOMERS)],
})
customers.to_csv(f"{OUTPUT_DIR}/customers.csv", index=False)
print(f"  Created {len(customers)} customers")

# --- Product Categories & Pricing ---
categories = {
    "Electronics": (20, 1500),
    "Clothing": (10, 200),
    "Home & Garden": (15, 500),
    "Books": (5, 80),
    "Sports & Outdoors": (10, 400),
    "Beauty": (8, 150),
    "Toys & Games": (5, 100),
    "Food & Grocery": (2, 60),
    "Automotive": (15, 600),
    "Office Supplies": (3, 120),
}

# --- Generate Transactions with RFM-friendly distribution ---
print("Generating transaction data...")

# Assign each customer a "value tier" to create realistic Pareto distribution
# Top 20% customers = high value, will contribute ~68% revenue
# Adjusted probabilities: lower the high-value concentration
customer_tiers = np.random.choice(
    ["high", "medium", "low"],
    size=NUM_CUSTOMERS,
    p=[0.17, 0.28, 0.55]  # Adjusted: fewer high-value, more low-value
)

transactions = []
transaction_id = 1

# Customer-level parameters - tuned for ~68% from top 20%
# We'll dynamically adjust spend based on a power-law distribution
# Using Pareto principle: Zipf-like distribution

# Generate customer base value using exponential/power law
customer_base_values = np.random.exponential(scale=50, size=NUM_CUSTOMERS)
customer_base_values = np.clip(customer_base_values, 5, 300)

# Sort so top 20% get highest base values - but not too extreme
customer_base_values = np.sort(customer_base_values)[::-1]

# Apply a power-law dampener: sqrt makes distribution less extreme
# This helps target ~68% instead of ~80%
customer_base_values = customer_base_values ** 0.7

for i, cid in enumerate(customer_ids):
    tier = customer_tiers[i]
    base_value = customer_base_values[i]

    if tier == "high":
        freq_base = np.random.randint(14, 40)
        spend_mult = np.random.uniform(0.8, 1.5)
        recency_days = np.random.randint(1, 90)
    elif tier == "medium":
        freq_base = np.random.randint(5, 16)
        spend_mult = np.random.uniform(0.5, 1.0)
        recency_days = np.random.randint(30, 200)
    else:
        freq_base = np.random.randint(1, 6)
        spend_mult = np.random.uniform(0.3, 0.7)
        recency_days = np.random.randint(90, 700)

    avg_spend = base_value * spend_mult
    last_purchase = END_DATE - timedelta(days=recency_days)
    span_days = min(730, max(30, int(365 * (freq_base / 8))))

    if freq_base > 0:
        purchase_dates = sorted([
            last_purchase - timedelta(days=random.randint(0, span_days))
            for _ in range(freq_base)
        ], reverse=False)

        for pdate in purchase_dates:
            if pdate < START_DATE or pdate > END_DATE:
                continue
            category = random.choice(list(categories.keys()))
            price_range = categories[category]
            # Log-normal distribution for spend amounts
            amount = round(np.random.lognormal(mean=np.log(max(avg_spend, 1)), sigma=0.8), 2)
            amount = min(max(amount, price_range[0]), price_range[1] * 2.5)

            transactions.append({
                "transaction_id": f"T{str(transaction_id).zfill(7)}",
                "customer_id": cid,
                "transaction_date": pdate.strftime("%Y-%m-%d"),
                "amount": amount,
                "product_category": category,
                "payment_method": random.choice(["Credit Card", "Debit Card", "UPI", "Net Banking", "Cash on Delivery"]),
                "quantity": random.randint(1, 5),
            })
            transaction_id += 1

# Build DataFrame
df_transactions = pd.DataFrame(transactions)

# Sort by date
df_transactions = df_transactions.sort_values("transaction_date").reset_index(drop=True)

# Save transactions
df_transactions.to_csv(f"{OUTPUT_DIR}/transactions.csv", index=False)
print(f"  Created {len(df_transactions)} transactions")

# --- Verify Pareto Principle ---
customer_revenue = df_transactions.groupby("customer_id")["amount"].sum().reset_index()
customer_revenue = customer_revenue.sort_values("amount", ascending=False).reset_index(drop=True)
customer_revenue["cumulative_pct"] = customer_revenue["amount"].cumsum() / customer_revenue["amount"].sum()
customer_revenue["customer_pct"] = (customer_revenue.index + 1) / len(customer_revenue)

top_20_mask = customer_revenue["customer_pct"] <= 0.20
revenue_from_top20 = customer_revenue.loc[top_20_mask, "amount"].sum()
total_rev = customer_revenue["amount"].sum()
pct_revenue = (revenue_from_top20 / total_rev) * 100

print(f"\n{'='*50}")
print(f"VERIFICATION: Revenue Analysis")
print(f"{'='*50}")
print(f"  Total Transactions:       {len(df_transactions):,}")
print(f"  Total Customers:          {len(customers):,}")
print(f"  Total Revenue:            ${total_rev:,.2f}")
print(f"  Revenue from Top 20%:     ${revenue_from_top20:,.2f}")
print(f"  Percentage from Top 20%:  {pct_revenue:.1f}%")
print(f"  Target:                   ~68%")
print(f"{'='*50}")

# Iterative adjustment - re-run if not close enough
adjustments = 0
while (pct_revenue < 64 or pct_revenue > 72) and adjustments < 5:
    adjustments += 1
    print(f"\n  Adjustment #{adjustments}: scaling high-value customer spend...")

    # Scale high-value customer spend
    scale_factor = 0.68 / (pct_revenue / 100)
    high_value_customers = customer_revenue.head(int(len(customer_revenue) * 0.20))["customer_id"]

    # Adjust transactions for high-value customers
    mask = df_transactions["customer_id"].isin(high_value_customers)
    df_transactions.loc[mask, "amount"] = df_transactions.loc[mask, "amount"] * scale_factor

    # Re-check
    customer_revenue = df_transactions.groupby("customer_id")["amount"].sum().reset_index()
    customer_revenue = customer_revenue.sort_values("amount", ascending=False).reset_index(drop=True)
    customer_revenue["cumulative_pct"] = customer_revenue["amount"].cumsum() / customer_revenue["amount"].sum()
    customer_revenue["customer_pct"] = (customer_revenue.index + 1) / len(customer_revenue)

    top_20_mask = customer_revenue["customer_pct"] <= 0.20
    revenue_from_top20 = customer_revenue.loc[top_20_mask, "amount"].sum()
    total_rev = customer_revenue["amount"].sum()
    pct_revenue = (revenue_from_top20 / total_rev) * 100

    print(f"  Adjusted Percentage:      {pct_revenue:.1f}%")

# Round amounts to 2 decimal places
df_transactions["amount"] = df_transactions["amount"].round(2)

# Final save after adjustments
df_transactions.to_csv(f"{OUTPUT_DIR}/transactions.csv", index=False)

# Save verification
with open(f"{OUTPUT_DIR}/verification.txt", "w") as f:
    f.write(f"Total Transactions: {len(df_transactions)}\n")
    f.write(f"Total Customers: {len(customers)}\n")
    f.write(f"Total Revenue: ${total_rev:,.2f}\n")
    f.write(f"Revenue from Top 20% Customers: ${revenue_from_top20:,.2f}\n")
    f.write(f"Percentage from Top 20%: {pct_revenue:.1f}%\n")

print(f"\n{'='*50}")
print(f"✅ FINAL DATA GENERATION COMPLETE")
print(f"{'='*50}")
print(f"   - customers.csv    ({len(customers):,} records)")
print(f"   - transactions.csv ({len(df_transactions):,} records)")
print(f"   - Top 20% customers drive {pct_revenue:.1f}% of revenue")
print(f"{'='*50}")