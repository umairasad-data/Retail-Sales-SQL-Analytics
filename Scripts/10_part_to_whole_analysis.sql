/*
===============================================================================
                            Part to Whole Analysis
===============================================================================
Purpose:    
    - To calculate what percentage each product department contributes to the whole business.
    - To look at the percentage share across sales revenue, invoice volumes, and our customer base.

Key SQL Tools Used:    
    - WITH (Temporary Tables / CTEs): Groups data into a temporary summary before doing percentage math.
    - Window Functions (SUM OVER): Finds the total grand baseline across all items combined.
    - CAST & ROUND: Forces the database to use decimals (instead of rounding whole numbers to zero) 
      so our percentage numbers are highly accurate.
===============================================================================
*/

-- ============================================================================
-- 1. Revenue Contribution by Department (Sales Share)
-- ============================================================================
-- Business Goal: Identifies which product categories bring in the biggest piece of our sales pie.
-- Note: We use SUM OVER() here because revenue is purely additive. Breaking sales down by category 
-- does not create duplicates or artificially inflate our actual financial totals.
WITH category_sales AS (
    SELECT 
        p.category, 
        SUM(f.sales_amount) AS total_sales
    FROM fact_sales f
    LEFT JOIN dim_products p ON f.product_key = p.product_key
    WHERE p.category IS NOT NULL
    GROUP BY p.category
)
SELECT 
    category,
    total_sales,
    -- Leaving the OVER() parentheses empty tells SQL to add up the entire column,
    -- giving us our grand total revenue across all categories combined.
    SUM(total_sales) OVER() AS overall_sales,
    -- Note: Databases do "integer division" by default (e.g., 5 / 10 = 0). 
    -- We use CAST(... AS FLOAT) to force SQL to show decimals, multiply by 100.0, and ROUND to 2 decimal places.
    CONCAT(ROUND((CAST(total_sales AS FLOAT) / SUM(total_sales) OVER()) * 100.0, 2), '%') AS percentage_of_total
FROM category_sales
ORDER BY total_sales DESC;


-- ============================================================================
-- 2. Transaction Volume Share by Category (Order Breakdown)
-- ============================================================================
-- Business Goal: Measures how customer orders are split across product departments.
-- Portfolio Note: Instead of using a window function, we use an independent fallback query '(SELECT COUNT...)' 
-- to grab our true total invoice count. This ensures that "shared invoices" (orders with items from multiple 
-- categories) do not distort or inflate our final percentage calculations.
WITH category_orders AS (
    SELECT 
        p.category, 
        COUNT(DISTINCT f.order_number) AS total_orders
    FROM fact_sales f
    INNER JOIN dim_products p ON f.product_key = p.product_key
    WHERE p.category IS NOT NULL
    GROUP BY p.category
)
SELECT 
    category,
    total_orders,
    -- Bypasses the grouped categories to count the true, absolute independent invoices in the database
    (SELECT COUNT(DISTINCT order_number) FROM fact_sales) AS true_overall_orders,
    CONCAT(
        ROUND(
            (CAST(total_orders AS FLOAT) / (SELECT COUNT(DISTINCT order_number) FROM fact_sales)) * 100.0, 
            2
        ), 
        '%'
    ) AS percentage_of_total
FROM category_orders
ORDER BY total_orders DESC;


/*
-----------------------------------------------------------------------------
ARCHIVED LESSON: The Overcounting Trap (Why the Logic Above Matters)
-----------------------------------------------------------------------------
-- This commented-out block serves as an educational reminder to protect data integrity.
-- Using SUM(total_orders) OVER() fails here because it treats categories as isolated silos.
-- If a single customer order contains a t-shirt (Clothing) AND a mug (Accessories), it gets 
-- counted twice in the total denominator. This inflates our totals and ruins our percentages.

WITH category_orders AS (
    SELECT 
        p.category, 
        COUNT(DISTINCT f.order_number) AS total_orders
    FROM fact_sales f
    INNER JOIN dim_products p ON f.product_key = p.product_key
    WHERE p.category IS NOT NULL
    GROUP BY p.category
)
SELECT 
    category,
    total_orders,
    SUM(total_orders) OVER() AS overall_orders, -- DANGER: Overcounts multi-category checkout trips
    CONCAT(ROUND((CAST(total_orders AS FLOAT) / SUM(total_orders) OVER()) * 100.0, 2), '%') AS percentage_of_total
FROM category_orders
ORDER BY total_orders DESC;
*/


-- ============================================================================
-- 3. Customer Category Penetration Rate (Where Do Our Buyers Shop?)
-- ============================================================================
-- Business Goal: Tracks what percentage of our entire active customer base has bought from each specific department.
-- Portfolio Note: We use a LEFT JOIN starting from our product list. This ensures that even slow-moving 
-- or completely brand-new categories show up in our final report with a clean 0.00% rate, rather than vanishing entirely.
SELECT 
    p.category,
    -- Part: Counts individual unique buyers who purchased from this specific department
    COUNT(DISTINCT f.customer_key) AS unique_category_customers,
    
    -- Whole: Independently looks up the absolute total count of all unique active shoppers across the whole company
    (SELECT COUNT(DISTINCT customer_key) FROM fact_sales) AS total_distinct_store_customers,
    
    -- Ratio: Calculates the precise customer popularity score without rounding bugs
    CONCAT(
        ROUND(
            (CAST(COUNT(DISTINCT f.customer_key) AS FLOAT) / 
              (SELECT COUNT(DISTINCT customer_key) FROM fact_sales)) * 100.0, 
            2
        ), 
        '%'
    ) AS customer_penetration_rate
FROM dim_products p
LEFT JOIN fact_sales f ON p.product_key = f.product_key
WHERE p.category IS NOT NULL
GROUP BY p.category
ORDER BY unique_category_customers DESC;