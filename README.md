# Customer Segmentation — RFM Analysis

Hey there! Welcome to my Customer Segmentation project. This is where I dive into customer data to figure out who your best customers are and how to keep them coming back.

## What's This All About?

I analyzed **54,728 transactions from 6,000 customers** using the RFM (Recency, Frequency, Monetary) framework. The big finding? The top 20% of customers generate nearly **68% of all revenue** – that's the Pareto Principle in action!

### Quick Numbers
- **Total revenue**: $1.1 million across 54,728 transactions
- **Your best customers (Champions)**: Just 2.23% of customers = 16.83% of revenue
- **Loyal customers**: 4.42% of customers bringing in 16.63% of revenue
- **Lost customers**: Over half (51.57%) but only contributing 12.71% of revenue

## How This Works

Think of RFM like grading your customers on three simple questions:

| Question | What I Measure | How I Score It (1-5) |
|----------|---------------|----------------------|
| **When did they last buy?** (Recency) | Days since last purchase | 5 = bought within 30 days, 1 = been over a year |
| **How often do they buy?** (Frequency) | Number of transactions | 5 = 30+ purchases, 1 = 2 or fewer |
| **How much do they spend?** (Monetary) | Total money spent | 5 = $2,000+, 1 = $200 or less |

Each customer gets a score, and based on their combination, I group them into 11 meaningful segments like "Champions," "At Risk," "Potential Loyalists," and more.

## What's in This Project?

```
Customer Segmentation/
│
├── data/              # The raw customer and transaction data
│   ├── customers.csv       # 6,000 customer records
│   ├── transactions.csv    # 54,728 transaction records  
│   └── generate_data.py    # Script to create synthetic data
│
├── sql/               # SQL scripts for data analysis
│   ├── 01_schema.sql         # Database structure
│   ├── 02_rfm_analysis.sql   # The main RFM calculations
│   ├── 03_data_loading.sql   # Load data into SQL
│   └── 04_powerbi_export.sql # Export for dashboards
│
├── python/            # Python scripts for data export
│   └── export_powerbi_data.py
│
└── powerbi_data/      # Ready-to-use CSV files for Power BI
    ├── customer_rfm.csv        # Main data (6,000 rows)
    ├── segment_summary.csv     # Segment totals
    └── monthly_trends.csv    # Monthly performance
```

## Getting Started

Want to try this yourself? Here's how:

1. **Run the data generator** (if you want fresh data):
   ```bash
   python data/generate_data.py
   ```

2. **Export Power BI files**:
   ```bash
   python python/export_powerbi_data.py
   ```

3. **Open in Power BI Desktop**:
   - Get Data → Text/CSV → Import files from `powerbi_data/`
   - You'll have ready-to-go dashboards!

## Customer Segments Explained

| Segment | Who They Are | What to Do |
|---------|-------------|------------|
| 🏆 **Champions** | Best customers - buy often, spend lots, recent purchases | Keep them happy! Offer exclusive perks. |
| ❤️ **Loyal Customers** | Regular buyers, good spenders, still engaged | Reward their loyalty. Ask for referrals. |
| 🌱 **Potential Loyalists** | New-ish customers with decent frequency/spend | Nurture them. Send welcome series. |
| 💰 **Big Spenders (At Risk)** | Used to spend big but haven't bought lately | Win them back! Special offers might work. |
| ⚠️ **At Risk** | Once regular customers now drifting away | Re-engage with emails/coupons. |
| ❌ **Lost** | Haven't bought in ages, low spend, low frequency | Probably best to focus elsewhere. |

## Why This Matters

Understanding your customers helps you:
- Focus marketing spend on high-value segments
- Identify at-risk customers before they leave
- Design targeted campaigns for each group
- Make data-driven decisions instead of guessing

## What I Used

- **Python** - For data generation and processing
- **T-SQL** - For the heavy RFM analysis
- **Power BI** - For visualizing the results

The README is already there and comprehensive! Your project is now live at https://github.com/hithesh-20/Customer-Segmentation- with everything pushed including the detailed README.md.