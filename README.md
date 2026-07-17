# Customer Segmentation — RFM Analysis

**SQL • Power BI**

RFM (Recency, Frequency, Monetary) analysis on **54,728 transaction records** across **6,000 customers**. Identified that the **top 20% of customers drive 68.1% of total revenue** (Pareto Principle).

---

## 📊 Project Overview

This project performs end-to-end customer segmentation using the RFM framework:

1. **Data Generation** — Synthetic e-commerce dataset with realistic purchase patterns
2. **SQL Analysis** — Full RFM scoring, segmentation, and Pareto analysis in T-SQL
3. **Power BI Export** — Pre-processed CSV files ready for dashboard import
4. **Segmentation** — 11 distinct customer segments with actionable labels

### Key Finding
| Metric | Value |
|--------|-------|
| Total Transactions | 54,728 |
| Total Customers | 6,000 |
| Total Revenue | $1,110,972.67 |
| Revenue from Top 20% Customers | **68.1%** |
| Revenue from Bottom 80% | 31.9% |

---

## 📁 Project Structure

```
Customer Segmentation/
│
├── data/                          # Raw data files
│   ├── customers.csv              # 6,000 customer records
│   ├── transactions.csv           # 54,728 transaction records
│   ├── generate_data.py           # Synthetic data generator
│   └── verification.txt           # Data quality verification
│
├── sql/                           # SQL scripts
│   ├── 01_schema.sql              # Database schema (DDL)
│   ├── 02_rfm_analysis.sql        # Full RFM analysis queries
│   ├── 03_data_loading.sql        # BULK INSERT data loading
│   └── 04_powerbi_export.sql      # Power BI views
│
├── python/                        # Python utilities
│   └── export_powerbi_data.py     # Export CSVs for Power BI
│
├── powerbi_data/                  # Power BI-ready CSVs
│   ├── customer_rfm.csv           # Main fact table (6,000 rows)
│   ├── segment_summary.csv        # Segment aggregation (10 rows)
│   ├── monthly_trends.csv         # Monthly KPIs (31 months)
│   ├── category_performance.csv   # Product category analysis
│   ├── payment_analysis.csv       # Payment method breakdown
│   └── pareto_analysis.csv        # Revenue concentration
│
└── README.md                      # This file
```

---

## 🔬 RFM Methodology

### RFM Dimensions

| Dimension | Definition | Scoring (1-5) |
|-----------|-----------|----------------|
| **Recency (R)** | Days since last purchase | 5 = ≤30 days, 1 = >365 days |
| **Frequency (F)** | Total number of transactions | 5 = ≥30, 1 = ≤2 |
| **Monetary (M)** | Total spend | 5 = ≥$2,000, 1 = ≤$200 |

### Customer Segments (11 Types)

| Segment | R Score | F Score | M Score | Description |
|---------|---------|---------|---------|-------------|
| 🏆 **Champions** | ≥4 | ≥4 | ≥4 | Best customers — buy recently, often, and spend big |
| ❤️ **Loyal Customers** | ≥4 | ≥3 | ≥3 | Regular purchasers, high value |
| 🆕 **Recent Customers** | ≥4 | ≤2 | — | Newly acquired, low frequency |
| 🌱 **Potential Loyalists** | ≥3 | ≥3 | ≥3 | Recent medium-frequency buyers |
| 💰 **Big Spenders (At Risk)** | ≥3 | — | ≥4 | High spenders who haven't bought recently |
| 🔮 **Promising** | ≥3 | ≤2 | — | Recent but infrequent — need nurturing |
| ⚠️ **At Risk (High Value)** | ≤2 | ≥4 | ≥4 | Once-loyal high spenders going dormant |
| ⚠️ **At Risk** | ≤2 | ≥3 | ≥3 | Regular customers slipping away |
| 💤 **Hibernating (High Value)** | ≤2 | ≤2 | ≥3 | High spenders who stopped buying |
| ❌ **Lost** | ≤2 | ≤2 | ≤2 | Lowest engagement, likely churned |
| 🔄 **Regular Customers** | ≥3 ∪ ≤2 | ≥3 | ≥2 | Steady customers with moderate activity |
| 🔻 **Low Engagement** | — | — | — | Customers with low activity across all dimensions |

---

## 🗄️ SQL Analysis

### Running the SQL Scripts

1. **Create schema**: Run `sql/01_schema.sql` to create tables
2. **Load data**: Run `sql/03_data_loading.sql` to import CSVs
3. **Run RFM analysis**: Execute `sql/02_rfm_analysis.sql` for full segmentation
4. **Create views**: Run `sql/04_powerbi_export.sql` for Power BI views

### Key SQL Queries

**RFM Scoring:**
```sql
SELECT 
    customer_id,
    DATEDIFF(day, MAX(transaction_date), '2026-07-01') AS recency_days,
    COUNT(transaction_id) AS frequency,
    SUM(amount) AS monetary_total,
    CASE WHEN recency_days <= 30  THEN 5 ... END AS r_score,
    CASE WHEN frequency >= 30 THEN 5 ... END AS f_score,
    CASE WHEN monetary_total >= 2000 THEN 5 ... END AS m_score
FROM transactions
GROUP BY customer_id;
```

**Pareto Analysis:**
```sql
WITH revenue_ranked AS (
    SELECT customer_id, SUM(amount) AS total_revenue,
           ROW_NUMBER() OVER (ORDER BY SUM(amount) DESC) AS revenue_rank
    FROM transactions GROUP BY customer_id
)
SELECT revenue_rank, total_revenue,
       ROUND(100.0 * SUM(total_revenue) OVER (ORDER BY revenue_rank) / 
             SUM(total_revenue) OVER (), 1) AS cumulative_revenue_pct
FROM revenue_ranked;
```

---

## 📈 Power BI Dashboard

### Importing Data

1. Open Power BI Desktop
2. Click **Get Data → Text/CSV**
3. Import all 6 files from the `powerbi_data/` folder
4. Create relationships:
   - `customer_rfm[customer_id]` → `pareto_analysis[customer_id]`
   - `customer_rfm[customer_segment]` → `segment_summary[customer_segment]`

### Suggested Dashboard Pages

| Page | Visuals |
|------|---------|
| **Executive Summary** | KPI cards (Revenue, Customers, Transactions), Pareto chart |
| **RFM Segmentation** | Segment donut chart, RFM scatter plot, segment table |
| **Customer Deep Dive** | Top customers table, RFM score distribution |
| **Trends** | Monthly revenue line chart, active customers trend |
| **Product Analysis** | Category bar chart, payment method breakdown |

### Key DAX Measures

```dax
Total Revenue = SUM(customer_rfm[monetary_total])
Total Customers = COUNTROWS(customer_rfm)
Avg Order Value = AVERAGE(customer_rfm[avg_order_value])
Champions Revenue = 
    CALCULATE(
        [Total Revenue],
        customer_rfm[customer_segment] = "Champions"
    )
Top20Revenue% = 
    VAR Top20 = TOPN(0.2 * COUNTROWS(customer_rfm), customer_rfm, [monetary_total], DESC)
    VAR Top20Rev = SUMX(Top20, [monetary_total])
    RETURN DIVIDE(Top20Rev, [Total Revenue], 0)
```

---

## 🚀 Getting Started

### Prerequisites
- Python 3.8+ (for data generation & export)
- SQL Server / Azure SQL Database (for SQL analysis)
- Power BI Desktop (for dashboards)

### Quick Start

```bash
# 1. Generate synthetic data
python data/generate_data.py

# 2. Export Power BI CSVs
python python/export_powerbi_data.py

# 3. Import CSVs into Power BI Desktop
# 4. Run SQL scripts in your database (optional)
```

---

## 📋 Results Summary

### Segment Distribution

| Segment | Customers | % of Customers | Revenue | % of Revenue |
|---------|-----------|----------------|---------|--------------|
| Champions | 134 | 2.23% | $187,013.64 | 16.83% |
| Loyal Customers | 265 | 4.42% | $184,715.86 | 16.63% |
| Potential Loyalists | 163 | 2.72% | $152,000.50 | 13.68% |
| Regular Customers | 854 | 14.23% | $273,004.54 | 24.57% |
| Low Engagement | 856 | 14.27% | $118,323.31 | 10.65% |
| Lost | 3,094 | 51.57% | $141,151.91 | 12.71% |
| Promising | 537 | 8.95% | $36,972.99 | 3.33% |
| Recent Customers | 83 | 1.38% | $8,421.78 | 0.76% |
| At Risk (High Value) | 1 | 0.02% | $1,860.15 | 0.17% |
| At Risk | 12 | 0.20% | $6,940.09 | 0.62% |
| Hibernating (High Value) | 1 | 0.02% | $567.90 | 0.05% |

*Data from 6,000 customers and 54,728 transactions*

### Pareto Principle Validation

- **Top 20% of customers** → **68.1% of revenue** ✅
- **Bottom 80% of customers** → **31.9% of revenue**

---

## 📝 License

This project is for educational and demonstration purposes.