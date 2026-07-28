/*
===============================================================================
                            Commulative Analysis
===============================================================================
Purpose:        
    - To calculate rolling sums and moving price averages for our sales data.
    - To monitor continuous business growth over chronological time.
    - Helps stakeholders evaluate growth momentum (like Year-to-Date performance).

Key SQL Tools Used:        
    - Window Functions: SUM() OVER(), AVG() OVER() (Calculates continuous accumulations 
      while keeping our individual row details perfectly visible)
    - Date Functions: DATETRUNC(), YEAR()
===============================================================================
*/

-- Point our analytical queries to the active retail database
USE RetailSalesAnalytics;
GO

-- ---------------------------------------------------------------------------
-- 1) Annual Running Sales & Rolling Average Prices (Long-Term Trends)
-- ---------------------------------------------------------------------------
-- Business Goal: Tracks year-over-year revenue accumulation and major price trends.
-- Note: An inner query (the code inside the parentheses) first groups the data by year. 
-- The outer query then uses 'OVER (ORDER BY)' to add up those yearly totals row-by-row down the timeline.
SELECT
    order_year,
    total_sales,
    -- OVER (ORDER BY) tells SQL to calculate a running total, adding each year's sales to the previous total
    SUM(total_sales) OVER (ORDER BY order_year) AS running_total_sales,
    AVG(avg_price) OVER (ORDER BY order_year) AS rolling_average_price
FROM (
    SELECT 
        DATETRUNC(year, order_date) AS order_year,
        SUM(sales_amount) AS total_sales,
        AVG(price) AS avg_price
    FROM fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(year, order_date)
) t; -- 't' is simply a required short nickname (alias) given to our temporary inner subquery table


-- ---------------------------------------------------------------------------
-- 2) Year-to-Date (YTD) Running Sales & Pricing Trends
-- ---------------------------------------------------------------------------
-- Business Goal: Calculates standard Year-to-Date performance milestones.
-- Note: By adding PARTITION BY YEAR(), we tell SQL to put boundaries around 
-- each calendar year. The running calculations automatically reset back to zero every time 
-- a brand new calendar year begins (every January 1st).
SELECT
    order_month,
    total_sales,
    -- PARTITION BY sets up the boundary group, and ORDER BY tells it to accumulate month-by-month
    SUM(total_sales) OVER (PARTITION BY YEAR(order_month) ORDER BY order_month) AS ytd_running_sales,
    AVG(avg_price) OVER (PARTITION BY YEAR(order_month) ORDER BY order_month) AS ytd_rolling_avg_price
FROM (
    SELECT 
        DATETRUNC(month, order_date) AS order_month,
        SUM(sales_amount) AS total_sales,
        AVG(price) AS avg_price
    FROM fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(month, order_date)
) t;


-- ---------------------------------------------------------------------------
-- 3) Monthly Running Sales & Rolling Price (Lifetime Growth)
-- ---------------------------------------------------------------------------
-- Business Goal: Measures the company's continuous, lifetime growth trajectory 
-- by building an uninterrupted month-by-month historical running total.
-- Notice there is no PARTITION BY here, so the running total never resets.
SELECT
    order_month,
    total_sales,
    SUM(total_sales) OVER (ORDER BY order_month) AS running_total_sales,
    AVG(avg_price) OVER (ORDER BY order_month) AS rolling_average_price
FROM (
    SELECT 
        DATETRUNC(month, order_date) AS order_month,
        SUM(sales_amount) AS total_sales,
        AVG(price) AS avg_price
    FROM fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(month, order_date)
) t;


-- ---------------------------------------------------------------------------
-- 4) Monthly Running Analysis (Alternative Lifetime Clean Run)
-- ---------------------------------------------------------------------------
-- Business Goal: Evaluates historical business speed milestones over time.
-- Note: Leaving out a PARTITION BY clause here allows the function to 
-- run completely free from boundary limits, creating a smooth, historical lifetime timeline.
SELECT
    order_month,
    total_sales,
    SUM(total_sales) OVER (ORDER BY order_month) AS running_total_sales,
    AVG(avg_price) OVER (ORDER BY order_month) AS rolling_average_price
FROM (
    SELECT 
        DATETRUNC(month, order_date) AS order_month,
        SUM(sales_amount) AS total_sales,
        AVG(price) AS avg_price
    FROM fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY DATETRUNC(month, order_date)
) t;


-- ---------------------------------------------------------------------------
-- 5) Customer-Level Running Spend (Customer Lifetime Value Timeline)
-- ---------------------------------------------------------------------------
-- Business Goal: Tracks the step-by-step spending journey of individual customers over time. 
-- This helps marketing teams identify exactly when a specific user becomes a high-value VIP shopper.
SELECT 
    customer_key,
    order_date,
    order_number,
    -- PARTITION BY customer_key keeps the running total isolated to each specific customer's profile.
    -- Adding order_number as a tie-breaker ensures that multiple purchases made on the exact 
    -- same day are calculated in a clean, predictable sequence.
    SUM(sales_amount) OVER (
        PARTITION BY customer_key 
        ORDER BY order_date, order_number
    ) AS cumulative_spend
FROM fact_sales
WHERE order_date IS NOT NULL;


-- ---------------------------------------------------------------------------
-- 6) Product-Level Running Quantity Sold
-- ---------------------------------------------------------------------------
-- Business Goal: Monitors lifetime product item volumes month-by-month. 
-- Note: This query uses a clean two-step approach. 
-- It first groups raw transactions into monthly product summaries (Step 1), and then 
-- applies the cumulative running total over those monthly blocks (Step 2) for maximum efficiency.
SELECT 
    product_key,
    order_month,
    monthly_units_sold,
    -- Step 2: Accumulate units sold chronologically within each product's separate history block
    SUM(monthly_units_sold) OVER (
        PARTITION BY product_key 
        ORDER BY order_month
    ) AS cumulative_units_sold
FROM (
    -- Step 1: Group raw transactional sales rows into monthly product buckets
    SELECT 
        product_key,
        DATETRUNC(month, order_date) AS order_month,
        SUM(quantity) AS monthly_units_sold
    FROM fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY product_key, DATETRUNC(month, order_date)
) aggregated_products
ORDER BY product_key, order_month;