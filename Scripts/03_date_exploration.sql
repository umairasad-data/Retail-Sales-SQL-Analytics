/*
================================================================================
Date Range Analysis
================================================================================
Objective:
    Examine the time span covered by the dataset and identify key date
    boundaries. This analysis helps assess the historical coverage of sales
    records and understand the age range of customers.

Analysis Performed:
    - Identify the earliest and latest sales transactions.
    - Calculate the overall sales period covered by the dataset.
    - Determine the oldest and youngest customers based on birthdate.
    - Estimate customer age range for demographic analysis.

Functions Applied:
    - MIN()      : Returns the earliest date value.
    - MAX()      : Returns the latest date value.
    - DATEDIFF() : Calculates the difference between two dates.
===============================================================================
*/

-- Direct our exploratory time-series queries into the active retail database container
USE RetailSalesAnalytics;
GO

-- ---------------------------------------------------------------------------
-- 1. Product Lifecycle Boundaries
-- ---------------------------------------------------------------------------
-- 🎯 Goal: Identify the total timespan of catalog expansion.
-- 🧮 Logic: Measures the difference between the first and last product launch dates.
SELECT 
    MIN(start_date) AS first_product_start_date,
    MAX(start_date) AS last_product_start_date,
    DATEDIFF(MONTH, MIN(start_date), MAX(start_date)) AS catalog_expansion_months
FROM dim_products;

-- ---------------------------------------------------------------------------
-- 2. Sales Transaction Timeline
-- ---------------------------------------------------------------------------
-- 🎯 Goal: Define our business history window and total available months of sales data.
-- 🧮 Logic: Finds the exact first and last order dates to measure operational duration.
SELECT 
    MIN(order_date) AS first_order_date,
    MAX(order_date) AS last_order_date,
    DATEDIFF(MONTH, MIN(order_date), MAX(order_date)) AS order_range_months
FROM fact_sales;

-- ---------------------------------------------------------------------------
-- 3. Customer Demographic Age Boundaries (Using Current System Date)
-- ---------------------------------------------------------------------------
-- 🎯 Goal: Find the youngest and oldest customers based strictly on birthdates.
-- ⚠️ Trap: Using GETDATE() skews results because our historical sales data ends in 2014.
-- 🛠️ Fix: Baseline the age calculation against '2014-01-28' to keep metrics accurate.SELECT
    MIN(birthdate) AS oldest_birthdate,
    DATEDIFF(YEAR, MIN(birthdate), '2014-01-28') AS oldest_current_age,
    MAX(birthdate) AS youngest_birthdate,
    DATEDIFF(YEAR, MAX(birthdate), '2014-01-28') AS youngest_current_age
FROM dim_customers;
