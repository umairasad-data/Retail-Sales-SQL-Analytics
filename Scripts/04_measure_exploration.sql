/*
===============================================================================
                               Measure Exploration
===============================================================================
Objective:
    - To check our main business performance metrics using summary math.
    - Provides a high-level snapshot of total sales, customer behavior, 
      product variety, and order counts.

Key SQL Tools Used:
    - SUM(): Adds up numeric columns to give us grand business totals.
    - AVG(): Calculates overall mathematical averages (like average price).
    - COUNT(): Tallies up rows or items to find total counts.
===============================================================================
*/

-- Tell SQL Server to run all upcoming checks inside our retail database
USE RetailSalesAnalytics;
GO

-- ---------------------------------------------------------------------------
-- 1) Sales Revenue & Product Quantities
-- ---------------------------------------------------------------------------

-- Calculate the total revenue brought in from sales across our entire company history
SELECT SUM(sales_amount) AS total_sales
FROM fact_sales;

-- Determine the total number of physical product items sold to customers
SELECT SUM(quantity) AS total_quantity
FROM fact_sales;

-- Find the overall average selling price per item line entry across our transactions
SELECT AVG(price) AS avg_price
FROM fact_sales;

-- ---------------------------------------------------------------------------
-- 2) Customer Shopping Patterns & Invoice Volumes
-- ---------------------------------------------------------------------------

-- Count the raw number of rows in our sales data (tallies every single item ordered, including duplicates)
SELECT COUNT(order_number) AS total_orders
FROM fact_sales;

-- Count unique order numbers to find the actual number of completed checkout invoices
-- Note: A customer might buy 3 items on 1 invoice. This query counts that as 1 shopping trip.
SELECT COUNT(DISTINCT order_number) AS total_unique_orders
FROM fact_sales;

-- ---------------------------------------------------------------------------
-- 3) Catalog Size vs. Active Customer Base
-- ---------------------------------------------------------------------------

-- Find the total number of items currently listed in our master inventory catalog
SELECT COUNT(product_id) AS total_products
FROM dim_products;

-- Count the total number of customer accounts registered on our system
SELECT COUNT(customer_id) AS total_customers
FROM dim_customers;

-- Count how many unique customers have actually made a purchase in our sales records
-- This reveals our true "Active Customer" base compared to total account registrations
SELECT COUNT(DISTINCT customer_key) AS total_active_customers
FROM fact_sales;

-- ---------------------------------------------------------------------------
-- 4) Combined Key Performance Indicator (KPI) Report
-- ---------------------------------------------------------------------------
-- Combines all of our individual metrics together using UNION ALL.
-- This creates a single, clean summary table that presents all key numbers side-by-side.
SELECT 'Total Sales' AS metric_name, SUM(sales_amount) AS metric_value
FROM fact_sales
UNION ALL
SELECT 'Total Quantity', SUM(quantity)
FROM fact_sales
UNION ALL
SELECT 'Average Price', AVG(price)
FROM fact_sales
UNION ALL
SELECT 'Total Orders', COUNT(DISTINCT order_number)
FROM fact_sales
UNION ALL
SELECT 'Total Products', COUNT(DISTINCT product_name)
FROM dim_products
UNION ALL
SELECT 'Total Customers', COUNT(customer_key)
FROM dim_customers;