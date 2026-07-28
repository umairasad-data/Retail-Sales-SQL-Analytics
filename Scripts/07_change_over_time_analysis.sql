/*
===============================================================================
                        Change Over Time Analysis
===============================================================================
Purpose:    
    - To track sales growth, patterns, and performance metrics over time.
    - To identify holiday peaks, seasonal shopping habits, and long-term business growth.
    - To organize our data cleanly by years, months, and custom calendar periods.
    
Key SQL Tools Used:    
    - Date Extraction: YEAR(), MONTH(), DATETRUNC(), FORMAT() (Pulls out specific time parts)
    - Summaries: SUM() (Total money/items), COUNT() (Total orders), AVG() (Averages)
    - Groupings: GROUP BY, ORDER BY
===============================================================================
*/

-- Point our queries to our main retail analytics database
USE RetailSalesAnalytics;
GO

-- ---------------------------------------------------------------------------
-- 1) General Monthly Patterns (All Years Combined)
-- ---------------------------------------------------------------------------
-- Business Goal: Blends all historical data by calendar month to find seasonal patterns 
-- in costs, product variety, and order numbers.
-- Note: Grouping strictly by MONTH(order_date) squashes all years together. 
-- For example, all 'January' data from 2011, 2012, 2013, and 2014 combine into a single row.
SELECT 
    MONTH(f.order_date) AS order_month, 
    AVG(p.cost) AS average_cost, 
    COUNT(DISTINCT f.product_key) AS total_products, -- Counts unique items sold, skipping duplicates
    COUNT(*) AS total_transactions                 -- Tallies the exact number of transaction rows processed
FROM fact_sales f 
LEFT JOIN dim_products p ON p.product_key = f.product_key 
WHERE f.order_date IS NOT NULL 
GROUP BY MONTH(f.order_date) 
ORDER BY order_month;


-- ---------------------------------------------------------------------------
-- 2) Deep-Dive Into a Specific Period (December 2013)
-- ---------------------------------------------------------------------------
-- Business Goal: Isolates a single specific month to see exactly which individual products 
-- sold the most. This helps marketing and supply chain teams review historical holiday 
-- peak seasons to plan inventory levels for future ones.
SELECT 
    MONTH(f.order_date) AS order_month,
    YEAR(f.order_date) AS order_year,
    p.product_key, 
    p.product_name, 
    AVG(p.cost) AS average_cost, 
    COUNT(*) AS total_transactions 
FROM fact_sales f 
LEFT JOIN dim_products p ON p.product_key = f.product_key 
WHERE f.order_date IS NOT NULL 
  AND MONTH(f.order_date) = 12  -- Filters for December only
  AND YEAR(f.order_date) = 2013 -- Filters for 2013 only
GROUP BY 
    MONTH(f.order_date), 
    YEAR(f.order_date), 
    p.product_key, 
    p.product_name 
ORDER BY 
    order_month, 
    p.product_name;


-- ---------------------------------------------------------------------------
-- 3) Step-by-Step Historical Sales Trends
-- ---------------------------------------------------------------------------
-- Business Goal: Tracks total sales month-by-month sequentially over the years to 
-- measure overall growth momentum.
-- Note: Unlike Query 1, adding both YEAR and MONTH to the GROUP BY prevents the data from squashing. 
-- It lets us watch sales change lineally from one month to the next through history.
SELECT 
    YEAR(order_date) AS order_year,
    MONTH(order_date) AS order_month,
    SUM(sales_amount) AS total_sales
FROM fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY order_year, order_month;


-- ---------------------------------------------------------------------------
-- 4) Peak vs. Slowest Months
-- ---------------------------------------------------------------------------

-- Identify our #1 highest-earning calendar month across history
-- Tip: Combines sorting with 'TOP 1' filtering to instantly grab the peak performer.
SELECT TOP 1 
    MONTH(order_date) AS best_month, 
    SUM(sales_amount) AS max_sales
FROM fact_sales
GROUP BY MONTH(order_date)
ORDER BY SUM(sales_amount) DESC; -- Sorts largest to smallest to put the highest earner at the top

-- Identify our #1 quietest calendar month across history
SELECT TOP 1 
    MONTH(order_date) AS worst_month, 
    SUM(sales_amount) AS min_sales
FROM fact_sales
GROUP BY MONTH(order_date)
ORDER BY SUM(sales_amount) ASC;  -- Sorts smallest to largest to bring the lowest month to the top


-- ---------------------------------------------------------------------------
-- 5) Annual Executive Summary (Yearly Scorecard)
-- ---------------------------------------------------------------------------
-- Business Goal: A high-level yearly scorecard tracking total revenue, customer reach, 
-- and volume sizes. This gives stakeholders a clear annual trajectory of the business.
SELECT 
    YEAR(order_date) AS order_year,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers, -- Ensures each buyer is only counted once per year
    SUM(quantity) AS total_quantity,
    COUNT(DISTINCT product_key) AS total_products
FROM fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date)
ORDER BY order_year;


-- ---------------------------------------------------------------------------
-- 6) Total Monthly Footprint (Warehouse Planning View)
-- ---------------------------------------------------------------------------
-- Business Goal: Totals up our entire history by calendar month to help logistics and 
-- warehouse managers anticipate recurring annual demand spikes and adjust staffing levels.
SELECT 
    MONTH(order_date) AS order_month,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM fact_sales
WHERE order_date IS NOT NULL
GROUP BY MONTH(order_date)
ORDER BY order_month;


-- ---------------------------------------------------------------------------
-- 7) Detailed Timeline Breakdown
-- ---------------------------------------------------------------------------
-- Business Goal: Provides a highly granular timeline view that splits out distinct calendar 
-- slots into separate, clean year and month numbers for standard reporting spreadsheets.
SELECT 
    YEAR(order_date) AS order_year,
    MONTH(order_date) AS order_month,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM fact_sales
WHERE order_date IS NOT NULL
GROUP BY YEAR(order_date), MONTH(order_date)
ORDER BY order_year, order_month;


-- ---------------------------------------------------------------------------
-- 8) Grouping for Charts & Dashboards (DATETRUNC Strategy)
-- ---------------------------------------------------------------------------
-- Business Goal: Rewinds all transaction dates back to the first day of their month 
-- (e.g., '2013-12-15' becomes '2013-12-01'). 
-- Note: This is an excellent database practice because real date datatypes sort 
-- flawlessly and are automatically recognized as a proper timeline by tools like Power BI and Tableau.
SELECT 
    DATETRUNC(month, order_date) AS order_date, -- Resets all days within a month back to day '01'
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM fact_sales
WHERE order_date IS NOT NULL
GROUP BY DATETRUNC(month, order_date)
ORDER BY DATETRUNC(month, order_date);


-- ---------------------------------------------------------------------------
-- 9) Visual Presentation View (Human-Friendly Text Labels)
-- ---------------------------------------------------------------------------
-- Business Goal: Converts raw database dates into clean, presentation-ready text labels 
-- (like '2013-Dec') directly inside the data query for final stakeholder reports.
-- Technical Note: While excellent for readability, avoid using FORMAT over millions of rows 
-- if you are in a rush, as text conversions can require extra system processing time.
SELECT 
    FORMAT(order_date, 'yyyy-MMM') AS order_date_label,
    SUM(sales_amount) AS total_sales,
    COUNT(DISTINCT customer_key) AS total_customers,
    SUM(quantity) AS total_quantity
FROM fact_sales
WHERE order_date IS NOT NULL
-- We include DATETRUNC in the GROUP BY and ORDER BY so that our final text labels 
-- sort chronologically through time, rather than falling into alphabetical confusion!
GROUP BY FORMAT(order_date, 'yyyy-MMM'), DATETRUNC(month, order_date)
ORDER BY DATETRUNC(month, order_date);