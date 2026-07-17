-- ============================================================
-- RFM (Recency, Frequency, Monetary) Analysis
-- Customer Segmentation Project
-- ============================================================

-- Use a reference date for recency calculation
-- (Typically the last date in the dataset + 1 day)
DECLARE @RefDate DATE = '2026-07-01';

-- ============================================================
-- Step 1: Compute Raw RFM Metrics per Customer
-- ============================================================
WITH rfm_raw AS (
    SELECT 
        c.customer_id,
        c.customer_name,
        c.city,
        c.state,
        c.country,
        
        -- R: Recency - Days since last purchase
        DATEDIFF(day, MAX(t.transaction_date), @RefDate) AS recency_days,
        
        -- F: Frequency - Total number of transactions
        COUNT(t.transaction_id) AS frequency,
        
        -- M: Monetary - Total spend
        SUM(t.amount) AS monetary_total,
        
        -- Additional metrics
        AVG(t.amount) AS avg_order_value,
        MIN(t.transaction_date) AS first_purchase_date,
        MAX(t.transaction_date) AS last_purchase_date
    FROM customers c
    INNER JOIN transactions t ON c.customer_id = t.customer_id
    GROUP BY 
        c.customer_id,
        c.customer_name,
        c.city,
        c.state,
        c.country
)
SELECT * INTO #rfm_raw FROM rfm_raw;

-- ============================================================
-- Step 2: Create RFM Scores (1-5 scale using quintiles)
-- ============================================================
-- Lower recency = better (more recent = score 5)
-- Higher frequency = better (score 5)
-- Higher monetary = better (score 5)

WITH rfm_scores AS (
    SELECT 
        customer_id,
        customer_name,
        city,
        state,
        country,
        recency_days,
        frequency,
        monetary_total,
        avg_order_value,
        first_purchase_date,
        last_purchase_date,
        
        -- R Score: 1=long time ago, 5=purchased recently
        CASE  
            WHEN recency_days <= 30  THEN 5
            WHEN recency_days <= 90  THEN 4
            WHEN recency_days <= 180 THEN 3
            WHEN recency_days <= 365 THEN 2
            ELSE 1
        END AS r_score,
        
        -- F Score: 1=rarely, 5=very frequent  
        CASE  
            WHEN frequency >= 30 THEN 5
            WHEN frequency >= 15 THEN 4
            WHEN frequency >= 8  THEN 3
            WHEN frequency >= 3  THEN 2
            ELSE 1
        END AS f_score,
        
        -- M Score: 1=low spender, 5=high spender
        CASE  
            WHEN monetary_total >= 2000 THEN 5
            WHEN monetary_total >= 1000 THEN 4
            WHEN monetary_total >= 500  THEN 3
            WHEN monetary_total >= 200  THEN 2
            ELSE 1
        END AS m_score
    FROM #rfm_raw
)
SELECT * INTO #rfm_scores FROM rfm_scores;

-- ============================================================
-- Step 3: Calculate RFM Combined Score & Customer Segments
-- ============================================================
SELECT 
    customer_id,
    customer_name,
    city,
    state,
    country,
    recency_days,
    frequency,
    monetary_total,
    avg_order_value,
    r_score,
    f_score,
    m_score,
    -- Combined RFM score (max 15)
    (r_score + f_score + m_score) AS rfm_total,
    
    -- Concatenated score for segment matching (e.g., '555', '311')
    CONCAT(r_score, f_score, m_score) AS rfm_cell,
    
    -- ============================================================
    -- Customer Segmentation based on RFM scores
    -- ============================================================
    CASE  
        -- Top tier: Best customers
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 4 AND f_score >= 3 AND m_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'Recent Customers'
        
        -- Mid tier: Potential / at-risk
        WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'Potential Loyalists'
        WHEN r_score >= 3 AND f_score >= 1 AND m_score >= 4 THEN 'Big Spenders (At Risk)'
        WHEN r_score >= 3 AND f_score <= 2 THEN 'Promising'
        
        -- Low recency tier
        WHEN r_score <= 2 AND f_score >= 4 AND m_score >= 4 THEN 'At Risk (High Value)'
        WHEN r_score <= 2 AND f_score >= 3 AND m_score >= 3 THEN 'At Risk'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score >= 3 THEN 'Hibernating (High Value)'
        WHEN r_score <= 2 AND f_score <= 2 AND m_score <= 2 THEN 'Lost'
        
        -- Additional classifications for edge cases
        WHEN r_score >= 3 AND m_score >= 3 THEN 'Needs Attention'
        WHEN f_score >= 3 AND m_score >= 2 THEN 'Regular Customers'
        
        ELSE 'Low Engagement'
    END AS customer_segment,
    
    first_purchase_date,
    last_purchase_date
INTO #rfm_segmented
FROM #rfm_scores
ORDER BY rfm_total DESC, monetary_total DESC;

-- ============================================================
-- Step 4: Final Output - Full RFM Segmentation Results
-- ============================================================
SELECT 
    customer_id,
    customer_name,
    city,
    state,
    country,
    r_score,
    f_score,
    m_score,
    rfm_total,
    rfm_cell,
    customer_segment,
    recency_days,
    frequency,
    monetary_total,
    avg_order_value,
    first_purchase_date,
    last_purchase_date
FROM #rfm_segmented
ORDER BY 
    CASE customer_segment
        WHEN 'Champions'              THEN 1
        WHEN 'Loyal Customers'        THEN 2
        WHEN 'Potential Loyalists'    THEN 3
        WHEN 'Recent Customers'       THEN 4
        WHEN 'Big Spenders (At Risk)' THEN 5
        WHEN 'Promising'              THEN 6
        WHEN 'At Risk (High Value)'   THEN 7
        WHEN 'At Risk'                THEN 8
        WHEN 'Hibernating (High Value)' THEN 9
        WHEN 'Lost'                   THEN 10
        WHEN 'Regular Customers'      THEN 11
        WHEN 'Low Engagement'         THEN 12
        WHEN 'Needs Attention'        THEN 13
        ELSE 14
    END,
    rfm_total DESC,
    monetary_total DESC;

-- ============================================================
-- Step 5: Segment Summary - Revenue & Customer Count
-- ============================================================
SELECT 
    customer_segment,
    COUNT(*)                           AS customer_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS customer_pct,
    SUM(monetary_total)                AS total_revenue,
    ROUND(100.0 * SUM(monetary_total) / SUM(SUM(monetary_total)) OVER(), 2) AS revenue_pct,
    AVG(monetary_total)                AS avg_revenue_per_customer,
    AVG(frequency)                     AS avg_frequency,
    AVG(recency_days)                  AS avg_recency_days,
    AVG(avg_order_value)               AS avg_order_value
FROM #rfm_segmented
GROUP BY customer_segment
ORDER BY total_revenue DESC;

-- ============================================================
-- Step 6: Pareto Analysis - Revenue Concentration
-- ============================================================
WITH revenue_ranked AS (
    SELECT 
        customer_id,
        customer_name,
        monetary_total,
        ROW_NUMBER() OVER (ORDER BY monetary_total DESC) AS revenue_rank,
        COUNT(*) OVER () AS total_customers,
        SUM(monetary_total) OVER () AS total_revenue
    FROM #rfm_segmented
)
SELECT 
    revenue_rank,
    customer_id,
    customer_name,
    monetary_total,
    ROUND(100.0 * revenue_rank / total_customers, 1) AS customer_percentile,
    ROUND(100.0 * SUM(monetary_total) OVER (ORDER BY revenue_rank) / total_revenue, 1) AS cumulative_revenue_pct
FROM revenue_ranked
WHERE revenue_rank <= ROUND(total_customers * 0.20, 0)  -- Top 20%
ORDER BY revenue_rank;

-- Cleanup temporary tables
-- DROP TABLE #rfm_raw;
-- DROP TABLE #rfm_scores;
-- DROP TABLE #rfm_segmented;