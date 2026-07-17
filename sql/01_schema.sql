-- ============================================================
-- Customer Segmentation - Database Schema
-- SQL Server / Azure SQL Database compatible
-- ============================================================

-- Create Database (if needed)
-- CREATE DATABASE CustomerSegmentation;
-- USE CustomerSegmentation;

-- ============================================================
-- 1. Customers Table
-- ============================================================
CREATE TABLE customers (
    customer_id     VARCHAR(20)     PRIMARY KEY,
    customer_name   VARCHAR(100)    NOT NULL,
    email           VARCHAR(150),
    city            VARCHAR(100),
    state           VARCHAR(100),
    country         VARCHAR(100),
    signup_date     DATE
);

-- ============================================================
-- 2. Transactions Table
-- ============================================================
CREATE TABLE transactions (
    transaction_id      VARCHAR(20)     PRIMARY KEY,
    customer_id         VARCHAR(20)     NOT NULL,
    transaction_date    DATE            NOT NULL,
    amount              DECIMAL(10, 2)  NOT NULL,
    product_category    VARCHAR(50),
    payment_method      VARCHAR(30),
    quantity            INT             DEFAULT 1,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- ============================================================
-- 3. Create Indexes for Performance
-- ============================================================
CREATE INDEX idx_transactions_customer 
    ON transactions(customer_id);
CREATE INDEX idx_transactions_date 
    ON transactions(transaction_date);
CREATE INDEX idx_transactions_customer_date 
    ON transactions(customer_id, transaction_date);
CREATE INDEX idx_customers_signup 
    ON customers(signup_date);

-- ============================================================
-- 4. Verify Data Load
-- ============================================================
-- Check record counts
SELECT 'customers' AS table_name, COUNT(*) AS record_count FROM customers
UNION ALL
SELECT 'transactions', COUNT(*) FROM transactions;

-- Check date range
SELECT 
    MIN(transaction_date) AS earliest_date,
    MAX(transaction_date) AS latest_date,
    DATEDIFF(day, MIN(transaction_date), MAX(transaction_date)) AS date_span_days
FROM transactions;