"""
Export pre-processed data to CSVs ready for Power BI import.
Creates denormalized fact and dimension tables.
"""

import pandas as pd
import numpy as np
from datetime import datetime
import os

OUTPUT_DIR = "powerbi_data"
os.makedirs(OUTPUT_DIR, exist_ok=True)

REFERENCE_DATE = datetime(2026, 7, 1)

print("Loading datasets...")
customers = pd.read_csv("data/customers.csv", dtype={"customer_id": str})
transactions = pd.read_csv(
    "data/transactions.csv",
    dtype={
        "customer_id": str,
        "product_category": str,
        "payment_method": str,
    },
    parse_dates=["transaction_date"],
)

print(f"  Customers:     {len(customers):,}")
print(f"  Transactions:  {len(transactions):,}")

# ==========================================================
# 1. Customer RFM Summary (Main Fact Table)
# ==========================================================
print("\nBuilding Customer RFM Summary...")

# Aggregate per customer
rfm = transactions.groupby("customer_id").agg(
    recency_days=("transaction_date", lambda x: (REFERENCE_DATE - x.max()).days),
    frequency=("transaction_id", "count"),
    monetary_total=("amount", "sum"),
    avg_order_value=("amount", "mean"),
    first_purchase_date=("transaction_date", "min"),
    last_purchase_date=("transaction_date", "max"),
).reset_index()

rfm["customer_lifetime_days"] = (
    rfm["last_purchase_date"] - rfm["first_purchase_date"]
).dt.days

# Merge customer demographics
rfm = rfm.merge(
    customers[["customer_id", "customer_name", "city", "state", "country", "signup_date"]],
    on="customer_id",
    how="left",
)

# Calculate RFM Scores
def r_score(recency):
    if recency <= 30: return 5
    if recency <= 90: return 4
    if recency <= 180: return 3
    if recency <= 365: return 2
    return 1

def f_score(freq):
    if freq >= 30: return 5
    if freq >= 15: return 4
    if freq >= 8: return 3
    if freq >= 3: return 2
    return 1

def m_score(monetary):
    if monetary >= 2000: return 5
    if monetary >= 1000: return 4
    if monetary >= 500: return 3
    if monetary >= 200: return 2
    return 1

rfm["r_score"] = rfm["recency_days"].apply(r_score)
rfm["f_score"] = rfm["frequency"].apply(f_score)
rfm["m_score"] = rfm["monetary_total"].apply(m_score)
rfm["rfm_total"] = rfm["r_score"] + rfm["f_score"] + rfm["m_score"]
rfm["rfm_cell"] = rfm["r_score"].astype(str) + rfm["f_score"].astype(str) + rfm["m_score"].astype(str)

# Segment labels
def assign_segment(row):
    r, f, m = row["r_score"], row["f_score"], row["m_score"]
    # Top tier: Best customers
    if r >= 4 and f >= 4 and m >= 4: return "Champions"
    if r >= 4 and f >= 3 and m >= 3: return "Loyal Customers"
    if r >= 4 and f <= 2: return "Recent Customers"
    # Mid tier: Potential / at-risk
    if r >= 3 and f >= 3 and m >= 3: return "Potential Loyalists"
    if r >= 3 and f >= 1 and m >= 4: return "Big Spenders (At Risk)"
    if r >= 3 and f <= 2: return "Promising"
    # Low recency tier
    if r <= 2 and f >= 4 and m >= 4: return "At Risk (High Value)"
    if r <= 2 and f >= 3 and m >= 3: return "At Risk"
    if r <= 2 and f <= 2 and m >= 3: return "Hibernating (High Value)"
    if r <= 2 and f <= 2 and m <= 2: return "Lost"
    # Additional classifications for edge cases
    if r >= 3 and m >= 3: return "Needs Attention"
    if f >= 3 and m >= 2: return "Regular Customers"
    return "Low Engagement"

rfm["customer_segment"] = rfm.apply(assign_segment, axis=1)

# Sort
rfm = rfm.sort_values("rfm_total", ascending=False).reset_index(drop=True)

# Save
rfm.to_csv(f"{OUTPUT_DIR}/customer_rfm.csv", index=False)
print(f"  -> customer_rfm.csv ({len(rfm):,} records)")

# ==========================================================
# 2. Segment Summary
# ==========================================================
print("Building Segment Summary...")
segment_summary = rfm.groupby("customer_segment").agg(
    customer_count=("customer_id", "count"),
    total_revenue=("monetary_total", "sum"),
    avg_revenue=("monetary_total", "mean"),
    avg_frequency=("frequency", "mean"),
    avg_recency=("recency_days", "mean"),
    avg_order_value=("avg_order_value", "mean"),
).reset_index()

segment_summary["customer_pct"] = round(
    100 * segment_summary["customer_count"] / segment_summary["customer_count"].sum(), 2
)
segment_summary["revenue_pct"] = round(
    100 * segment_summary["total_revenue"] / segment_summary["total_revenue"].sum(), 2
)
segment_summary = segment_summary.sort_values("total_revenue", ascending=False)

segment_summary.to_csv(f"{OUTPUT_DIR}/segment_summary.csv", index=False)
print(f"  -> segment_summary.csv ({len(segment_summary)} segments)")

# ==========================================================
# 3. Monthly Trends
# ==========================================================
print("Building Monthly Trends...")
transactions["year"] = transactions["transaction_date"].dt.year
transactions["month"] = transactions["transaction_date"].dt.month
transactions["month_name"] = transactions["transaction_date"].dt.month_name()
transactions["month_end"] = transactions["transaction_date"] + pd.offsets.MonthEnd(0)

monthly = transactions.groupby(["year", "month", "month_name", "month_end"]).agg(
    active_customers=("customer_id", "nunique"),
    transaction_count=("transaction_id", "count"),
    total_revenue=("amount", "sum"),
    avg_transaction_value=("amount", "mean"),
    total_items_sold=("quantity", "sum"),
).reset_index().sort_values(["year", "month"])

monthly.to_csv(f"{OUTPUT_DIR}/monthly_trends.csv", index=False)
print(f"  -> monthly_trends.csv ({len(monthly)} months)")

# ==========================================================
# 4. Category Performance
# ==========================================================
print("Building Category Performance...")
category = transactions.groupby("product_category").agg(
    unique_customers=("customer_id", "nunique"),
    transaction_count=("transaction_id", "count"),
    total_revenue=("amount", "sum"),
    avg_transaction_value=("amount", "mean"),
    total_quantity=("quantity", "sum"),
).reset_index().sort_values("total_revenue", ascending=False)

category.to_csv(f"{OUTPUT_DIR}/category_performance.csv", index=False)
print(f"  -> category_performance.csv ({len(category)} categories)")

# ==========================================================
# 5. Payment Method Analysis
# ==========================================================
print("Building Payment Analysis...")
payment = transactions.groupby("payment_method").agg(
    unique_customers=("customer_id", "nunique"),
    transaction_count=("transaction_id", "count"),
    total_revenue=("amount", "sum"),
    avg_transaction_value=("amount", "mean"),
).reset_index().sort_values("total_revenue", ascending=False)

payment.to_csv(f"{OUTPUT_DIR}/payment_analysis.csv", index=False)
print(f"  -> payment_analysis.csv ({len(payment)} methods)")

# ==========================================================
# 6. Pareto Analysis
# ==========================================================
print("Building Pareto Analysis...")
customer_revenue = transactions.groupby("customer_id")["amount"].sum().reset_index()
customer_revenue = customer_revenue.sort_values("amount", ascending=False).reset_index(drop=True)
customer_revenue["revenue_rank"] = range(1, len(customer_revenue) + 1)
customer_revenue["cumulative_revenue"] = customer_revenue["amount"].cumsum()
total_rev = customer_revenue["amount"].sum()
customer_revenue["cumulative_pct"] = round(100 * customer_revenue["cumulative_revenue"] / total_rev, 1)
customer_revenue["customer_pct"] = round(100 * customer_revenue["revenue_rank"] / len(customer_revenue), 1)
customer_revenue["pareto_group"] = np.where(
    customer_revenue["revenue_rank"] <= round(len(customer_revenue) * 0.20),
    "Top 20%", "Bottom 80%"
)

customer_revenue = customer_revenue.merge(
    customers[["customer_id", "customer_name"]], on="customer_id", how="left"
)

pareto = customer_revenue[["revenue_rank", "customer_id", "customer_name",
                           "amount", "customer_pct", "cumulative_pct", "pareto_group"]]
pareto.to_csv(f"{OUTPUT_DIR}/pareto_analysis.csv", index=False)
print(f"  -> pareto_analysis.csv ({len(pareto)} customers)")

# ==========================================================
# Summary
# ==========================================================
print(f"\n{'='*50}")
print(f"✅ Power BI Data Export Complete!")
print(f"{'='*50}")
print("Files exported to 'powerbi_data/' folder:")
for f in sorted(os.listdir(OUTPUT_DIR)):
    size = os.path.getsize(os.path.join(OUTPUT_DIR, f))
    print(f"   - {f} ({size:,} bytes)")
print(f"\nImport these CSVs into Power BI Desktop to build dashboards.")
print(f"{'='*50}")