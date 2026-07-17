-- ============================================================
-- Power BI Export Views
-- Pre-processed data for Power BI dashboards
-- ============================================================

-- ============================================================
-- View 1: Customer RFM Summary (Main Fact Table for Power BI)
-- ============================================================
CREATE OR ALTER VIEW vw_customer_rfm AS
WITH rfm_base AS (
    SELECT 
        c.customer_id,
        c.customer_name,
        c.city,
        c.state,
        c.country,
        c.signup_date,
        DATEDIFF(day, MAX(t.transaction_date), '2026-07-01') AS recency_days,
        COUNT(t.transaction_id) AS frequency,
        SUM(t.amount) AS monetary_total,
        AVG(t.amount) AS avg_order_value,
        MIN(t.transaction_date) AS first_purchase_date,
        MAX(t.transaction_date) AS last_purchase_date
    FROM customers c
    INNER JOIN transactions t ON c.customer_id = t.customer_id
    GROUP BY c.customer_id, c.customer_name, c.city, c.state, c.country, c.signup_date
)
SELECT 
    customer_id,
    customer_name,
    city,
    state,
    country,
    signup_date,
    recency_days,
    frequency,
    monetary_total,
    avg_order_value,
    first_purchase_date,
    last_purchase_date,
    DATEDIFF(day, first_purchase_date, last_purchase_date) AS customer_lifetime_days,
    
    -- R Score
    CASE WHEN recency_days <= 30  THEN 5
         WHEN recency_days <= 90  THEN 4
         WHEN recency_days <= 180 THEN 3
         WHEN recency_days <= 365 THEN 2
         ELSE 1 END AS r_score,
    
    -- F Score
    CASE WHEN frequency >= 30 THEN 5
         WHEN frequency >= 15 THEN 4
         WHEN frequency >= 8  THEN 3
         WHEN frequency >= 3  THEN 2
         ELSE 1 END AS f_score,
    
    -- M Score
    CASE WHEN monetary_total >= 2000 THEN 5
         WHEN monetary_total >= 1000 THEN 4
         WHEN monetary_total >= 500  THEN 3
         WHEN monetary_total >= 200  THEN 2
         ELSE 1 END AS m_score
FROM rfm_base;
GO

-- ============================================================
-- View 2: Customer Segments with Labels
-- ============================================================
CREATE OR ALTER VIEW vw_customer_segments AS
SELECT 
    *,
    (r_score + f_score + m_score) AS rfm_total,
    CONCAT(r_score, f_score, m_score) AS rfm_cell,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 4 AND f_score >= 3 AND m_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'Recent Customers'
        WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'Potential Loyalists'
        WHEN r_score >= 3 AND f_score >= 1 AND m_score >= 4 THEN 'Big Spenders (At Risk)'
        WHEN r_score >= 3 AND f_score <= 2 THEN 'Promising'
        WHEN r_score <= 2 AND f_score >= 4 AND m_score >= 4 THEN 'At Risk (High Value)'
        WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3 THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score >= 3 THEN 'Hibernating (High Value)'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'Lost'
        ELSE 'Needs Analysis'
    END AS customer_segment
FROM vw_customer_rfm;
GO

-- ============================================================
-- View 3: Monthly Transaction Trends
-- ============================================================
CREATE OR ALTER VIEW vw_monthly_trends AS
SELECT 
    YEAR(t.transaction_date) AS year,
    MONTH(t.transaction_date) AS month,
    DATENAME(month, t.transaction_date) AS month_name,
    EOMONTH(t.transaction_date) AS month_end_date,
    COUNT(DISTINCT t.customer_id) AS active_customers,
    COUNT(t.transaction_id) AS transaction_count,
    SUM(t.amount) AS total_revenue,
    AVG(t.amount) AS avg_transaction_value,
    SUM(t.quantity) AS total_items_sold
FROM transactions t
GROUP BY 
    YEAR(t.transaction_date),
    MONTH(t.transaction_date),
    DATENAME(month, t.transaction_date),
    EOMONTH(t.transaction_date)
GO

-- ============================================================
-- View 4: Category Performance
-- ============================================================
CREATE OR ALTER VIEW vw_category_performance AS
SELECT 
    t.product_category,
    COUNT(DISTINCT t.customer_id) AS unique_customers,
    COUNT(t.transaction_id) AS transaction_count,
    SUM(t.amount) AS total_revenue,
    AVG(t.amount) AS avg_transaction_value,
    SUM(t.quantity) AS total_quantity
FROM transactions t
GROUP BY t.product_category
GO

-- ============================================================
-- View 5: Payment Method Analysis
-- ============================================================
CREATE OR ALTER VIEW vw_payment_analysis AS
SELECT 
    t.payment_method,
    COUNT(DISTINCT t.customer_id) AS unique_customers,
    COUNT(t.transaction_id) AS transaction_count,
    SUM(t.amount) AS total_revenue,
    AVG(t.amount) AS avg_transaction_value
FROM transactions t
GROUP BY t.payment_method
GO

-- ============================================================
-- View 6: Pareto / RFM Distribution
-- ============================================================
CREATE OR ALTER VIEW vw_pareto_analysis AS
WITH customer_revenue AS (
    SELECT 
        customer_id,
        customer_name,
        SUM(amount) AS total_revenue
    FROM transactions
    GROUP BY customer_id, customer_name
),
ranked AS (
    SELECT 
        customer_id,
        customer_name,
        total_revenue,
        ROW_NUMBER() OVER (ORDER BY total_revenue DESC) AS revenue_rank,
        COUNT(*) OVER () AS total_customers,
        SUM(total_revenue) OVER () AS grand_total_revenue
    FROM customer_revenue
)
SELECT 
    revenue_rank,
    customer_id,
    customer_name,
    total_revenue,
    ROUND(100.0 * revenue_rank / total_customers, 1) AS customer_percentile,
    ROUND(100.0 * SUM(total_revenue) OVER (ORDER BY revenue_rank) / grand_total_revenue, 1) AS cumulative_revenue_pct,
    CASE WHEN revenue_rank <= ROUND(total_customers * 0.20, 0) THEN 'Top 20%'
         ELSE 'Bottom 80%' 
    END AS pareto_group
FROM ranked
GO