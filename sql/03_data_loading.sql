-- ============================================================
-- Data Loading Script
-- Load CSV data into SQL Server tables
-- ============================================================

-- ============================================================
-- Method 1: BULK INSERT (SQL Server)
-- ============================================================
-- Load Customers
BULK INSERT customers
FROM 'C:\Projects\Customer Segmentation\data\customers.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    TABLOCK
);

-- Load Transactions
BULK INSERT transactions
FROM 'C:\Projects\Customer Segmentation\data\transactions.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    TABLOCK
);

-- ============================================================
-- Method 2: Using OPENROWSET (Alternative)
-- ============================================================
-- SELECT * INTO customers
-- FROM OPENROWSET(
--     BULK 'C:\Projects\Customer Segmentation\data\customers.csv',
--     FORMATFILE = 'C:\Projects\Customer Segmentation\data\customers.fmt'
-- ) AS data;

-- ============================================================
-- Verify Data Integrity
-- ============================================================
-- Check for orphaned transactions
SELECT COUNT(*) AS orphaned_transactions
FROM transactions t
LEFT JOIN customers c ON t.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- Check for NULL amounts
SELECT COUNT(*) AS null_amount_transactions
FROM transactions
WHERE amount IS NULL;

-- Summary
SELECT 
    (SELECT COUNT(*) FROM customers) AS total_customers,
    (SELECT COUNT(*) FROM transactions) AS total_transactions,
    (SELECT ROUND(SUM(amount), 2) FROM transactions) AS total_revenue,
    (SELECT ROUND(AVG(amount), 2) FROM transactions) AS avg_transaction_value;