/*
===============================================================================
                             Ranking Analysis
===============================================================================
Purpose:    
    - To generate ranked summaries for our products and customers based on revenue, profit, or order counts.    
    - To easily identify our top-performing assets and find underperforming areas over time.

Key SQL Tools Used:    
    - Ranking Functions: RANK(), DENSE_RANK() (Assigns dynamic list positions based on performance)   
    - Summaries & Sorting: GROUP BY and ORDER BY (Groups data together and arranges the output)
===============================================================================
*/

-- Point our queries to the active retail database
USE RetailSalesAnalytics;
GO

-- ---------------------------------------------------------------------------
-- 1) Customer Revenue Standings (2014)
-- ---------------------------------------------------------------------------

-- Top 10 customers by revenue in 2014 (using RANK to handle ties)
-- Note: RANK() leaves a gap if there's a tie. For example, if two 
-- customers tie for 2nd place, the next customer skips down to 4th place.
SELECT *
FROM (
    SELECT 
        YEAR(f.order_date) AS sales_year,
        c.customer_key,
        c.first_name,
        c.last_name,
        SUM(f.sales_amount) AS total_revenue,
        RANK() OVER (
            PARTITION BY YEAR(f.order_date) -- Resets the ranking standings for each unique calendar year
            ORDER BY SUM(f.sales_amount) DESC -- Ranks highest-spending shoppers first
        ) AS rank_customers
    FROM fact_sales f
    JOIN dim_customers c ON c.customer_key = f.customer_key
    GROUP BY YEAR(f.order_date), c.customer_key, c.first_name, c.last_name
) ranked
-- Because we cannot filter ranking functions directly in a WHERE clause, 
-- we wrap the logic in an outer "subquery" block called 'ranked' to filter for the Top 10.
WHERE rank_customers <= 10
  AND sales_year = 2014;

-- Top 10 customers by revenue in 2014 (using DENSE_RANK to avoid ranking gaps)
-- Note: DENSE_RANK() does NOT leave gaps. If two customers tie 
-- for 2nd place, the very next person is strictly ranked 3rd.
SELECT *
FROM (
    SELECT 
        YEAR(f.order_date) AS sales_year,
        c.customer_key,
        c.first_name,
        c.last_name,
        SUM(f.sales_amount) AS total_revenue,
        DENSE_RANK() OVER (
            PARTITION BY YEAR(f.order_date) 
            ORDER BY SUM(f.sales_amount) DESC
        ) AS dense_rank_customers
    FROM fact_sales f
    JOIN dim_customers c ON c.customer_key = f.customer_key
    GROUP BY YEAR(f.order_date), c.customer_key, c.first_name, c.last_name
) ranked
WHERE dense_rank_customers <= 10
  AND sales_year = 2014;

-- ---------------------------------------------------------------------------
-- 2) Annual Product Profitability Standings
-- ---------------------------------------------------------------------------

-- Top 5 products ranked by net profit per year (using RANK)
-- Business Logic: Subtracted product cost (cost * quantity) from gross sales 
-- to calculate actual net profit. This ensures we rank by what the business keeps, not just what it sells.
SELECT *
FROM (
    SELECT 
        YEAR(f.order_date) AS sales_year,
        p.product_key,
        p.product_name,
        SUM(f.sales_amount) - SUM(p.cost * f.quantity) AS total_profit,
        RANK() OVER (
            PARTITION BY YEAR(f.order_date) 
            ORDER BY SUM(f.sales_amount) - SUM(p.cost * f.quantity) DESC
        ) AS rank_products
    FROM fact_sales f
    JOIN dim_products p ON f.product_key = p.product_key
    GROUP BY YEAR(f.order_date), p.product_key, p.product_name
) ranked
WHERE rank_products <= 5;

-- Top 5 products ranked by net profit per year (using DENSE_RANK)
SELECT *
FROM (
    SELECT 
        YEAR(f.order_date) AS sales_year,
        p.product_key,
        p.product_name,
        SUM(f.sales_amount) - SUM(p.cost * f.quantity) AS total_profit,
        DENSE_RANK() OVER (
            PARTITION BY YEAR(f.order_date) 
            ORDER BY SUM(f.sales_amount) - SUM(p.cost * f.quantity) DESC
        ) AS dense_rank_products
    FROM fact_sales f
    JOIN dim_products p ON f.product_key = p.product_key
    GROUP BY YEAR(f.order_date), p.product_key, p.product_name
) ranked
WHERE dense_rank_products <= 5;

-- Rank products overall by total profit contribution
-- Creates a master profitability standings list across all available historical sales data combined.
SELECT 
    p.product_name,
    SUM(f.sales_amount) - SUM(p.cost * f.quantity) AS profit,
    RANK() OVER (ORDER BY SUM(f.sales_amount) - SUM(p.cost * f.quantity) DESC) AS rank_profit
FROM fact_sales f
JOIN dim_products p ON f.product_key = p.product_key
GROUP BY p.product_name;

-- ---------------------------------------------------------------------------
-- 3) Catalog Category & Subcategory Performance Breakdowns
-- ---------------------------------------------------------------------------

-- Rank products within each quarter by revenue
-- Identifies seasonal shopping habits by breaking down rankings into distinct calendar quarters (1-4).
SELECT 
    DATEPART(QUARTER, f.order_date) AS quarter,
    p.product_name,
    SUM(f.sales_amount) AS total_revenue,
    RANK() OVER (
        PARTITION BY DATEPART(QUARTER, f.order_date) 
        ORDER BY SUM(f.sales_amount) DESC
    ) AS rank_in_quarter
FROM fact_sales f
JOIN dim_products p ON f.product_key = p.product_key
GROUP BY DATEPART(QUARTER, f.order_date), p.product_name;

-- Rank main categories by total revenue
-- Ranks our primary store departments to evaluate which sections bring in the most money.
SELECT 
    p.category,
    SUM(f.sales_amount) AS total_revenue,
    RANK() OVER (ORDER BY SUM(f.sales_amount) DESC) AS rank_category
FROM fact_sales f
JOIN dim_products p ON f.product_key = p.product_key
GROUP BY p.category;

-- Rank subcategories by total revenue
-- Looks beneath the surface of the main categories to find specific product segments that perform best.
SELECT 
    p.subcategory,
    SUM(f.sales_amount) AS total_revenue,
    RANK() OVER (ORDER BY SUM(f.sales_amount) DESC) AS rank_subcategory
FROM fact_sales f
JOIN dim_products p ON f.product_key = p.product_key
GROUP BY p.subcategory;

-- ---------------------------------------------------------------------------
-- 4) Fast Top / Bottom Slicing (Basic Aggregation & TOP Filters)
-- ---------------------------------------------------------------------------

-- List the 5 products with the highest revenue (simple sorting approach)
-- Using 'TOP 5' with an 'ORDER BY ... DESC' clause is a fast way to get a quick snapshot.
SELECT TOP 5
    p.product_name,
    SUM(f.sales_amount) AS total_revenue
FROM fact_sales f
LEFT JOIN dim_products p ON f.product_key = p.product_key
GROUP BY p.product_name
ORDER BY total_revenue DESC;

-- Rank products by revenue using a ranking function, then filter to top 5
-- A subquery approach that outputs the exact same results as the TOP 5 query above, 
-- but is preferred for advanced data projects because it is much easier to customize later.
SELECT *
FROM (
    SELECT
        p.product_name,
        SUM(f.sales_amount) AS total_revenue,
        RANK() OVER (ORDER BY SUM(f.sales_amount) DESC) AS rank_products
    FROM fact_sales f
    LEFT JOIN dim_products p ON f.product_key = p.product_key
    GROUP BY p.product_name
) AS ranked_products
WHERE rank_products <= 5;

-- Identify the 5 products with the lowest revenue
-- Reverses the sorting order to ascending (ASC) to discover slow-moving items, 
-- clearance candidates, or newly added products that haven't gained sales momentum yet.
SELECT TOP 5
    p.product_name,
    SUM(f.sales_amount) AS total_revenue
FROM fact_sales f
LEFT JOIN dim_products p ON f.product_key = p.product_key
GROUP BY p.product_name
ORDER BY total_revenue ASC;

-- Show the top 10 customers who brought in the highest total revenue
-- Isolates our high-value shoppers to support VIP loyalty programs and customer reward plans.
SELECT TOP 10
    c.customer_key,
    c.first_name,
    c.last_name,
    SUM(f.sales_amount) AS total_revenue
FROM fact_sales f
LEFT JOIN dim_customers c ON c.customer_key = f.customer_key
GROUP BY 
    c.customer_key,
    c.first_name,
    c.last_name
ORDER BY total_revenue DESC;

-- Display the 3 customers who placed the fewest orders
-- Pinpoints low-engagement customer records to highlight targets for re-engagement email or marketing campaigns.
SELECT TOP 3
    c.customer_key,
    c.first_name,
    c.last_name,
    COUNT(DISTINCT order_number) AS total_orders
FROM fact_sales f
LEFT JOIN dim_customers c ON c.customer_key = f.customer_key
GROUP BY 
    c.customer_key,
    c.first_name,
    c.last_name
ORDER BY total_orders ASC;