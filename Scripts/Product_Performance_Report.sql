CREATE OR ALTER VIEW dbo.v_product_performance_report AS
/*
===============================================================================
                           Product Performance Report
===============================================================================
Purpose         : Consolidates product catalog metadata, sales lifespans, commercial
                  profitability metrics, and inventory health statuses into a single 
                  unified view. Used by product managers, supply chain teams, and executive 
                  leadership to monitor product performance, identify dead stock, and evaluate 
                  product-level YoY growth.

Key Business Logic & Highlights:
-------------------------------------------------------------------------------
1. Pre-Aggregation Strategy : Summarizes fact sales prior to outer joining to maintain
                              optimal query execution performance over large datasets.
2. Full Inventory Audit     : Executes a FULL OUTER JOIN between dim_products and sales 
                              aggregations to track both unsold catalog items and sales records
                              missing master product metadata.
3. Profitability & COGS     : Computes total Cost of Goods Sold (COGS) to calculate profit margins,
                              distinguishing high-margin growth drivers from unprofitable products.
4. Metric Defensiveness     : Enforces strict NULL handling and NULLIF wrappers to prevent 
                              divide-by-zero crashes on ASP, average order value, and YoY growth.
5. Strategic Segmentation   : Applies multi-factor CASE structures to classify inventory health,
                              obsolescence risk, margin performance, and sales frequency tiers.


Analytical Anchor Date & Year-over-Year (YoY) Strategy:
-------------------------------------------------------------------------------
* Dataset Snapshot Date ('2013-12-31'):
  This dataset covers historical transactions spanning 2010 to early 2014. To simulate
  a realistic reporting snapshot, '2013-12-31' serves as the fixed anchor date.
  All recency assessments, stock movement risks, and product shelf-life metrics are evaluated 
  relative to this cutoff date.

* YoY Comparison Selection (2012 vs 2013):
  To eliminate partial-year seasonal distortion from early 2014 data, year-over-year annual
  growth rates evaluate complete 12-month periods (full-year 2012 vs full-year 2013).
===============================================================================
*/

-- -----------------------------------------------------------------------------
-- SECTION 1: Pre-Aggregate Sales Summary (High Performance)
-- Pre-aggregates transactional data to 1 row per product prior to joining,
-- dramatically accelerating execution and preventing Cartesian product expansion.
-- -----------------------------------------------------------------------------
WITH sales_summary AS (
    SELECT
        product_key,
        MIN(order_date) AS first_sale_date,
        MAX(order_date) AS last_sale_date,
        COUNT(DISTINCT order_number) AS total_orders,
        COUNT(DISTINCT customer_key) AS total_customers,
        SUM(sales_amount) AS total_sales,
        SUM(quantity) AS total_quantity,
        -- Conditional Aggregation: Separates sales volume into distinct annual buckets (2012 vs 2013)
        SUM(CASE WHEN YEAR(order_date) = 2012 THEN sales_amount ELSE 0 END) AS sales_2012,
        SUM(CASE WHEN YEAR(order_date) = 2013 THEN sales_amount ELSE 0 END) AS sales_2013
    FROM fact_sales
    WHERE order_date IS NOT NULL
    GROUP BY product_key
),

-- -----------------------------------------------------------------------------
-- SECTION 2: Master Catalog & Sales Summary Unification Layer
-- Executes a FULL OUTER JOIN to combine catalog attributes with transactional summary.
-- Preserves zero-sales inventory items alongside unmapped sales transactions.
-- -----------------------------------------------------------------------------
combined_catalog AS (
    SELECT
        -- Defensive Data Cleansing: Merges keys and enforces fallback defaults to eliminate 
        -- NULL values in master attributes, ensuring clean grouping in BI reporting layers
        ISNULL(p.product_key, s.product_key) AS product_key,
        ISNULL(p.product_name, 'Unmapped / Unknown Product') AS product_name,
        ISNULL(p.category, 'Unassigned') AS category,
        ISNULL(p.subcategory, 'Unassigned') AS subcategory,
        ISNULL(p.cost, 0) AS cost,
        
        -- Metric Normalization: Converts NULL transactional aggregates to 0 for catalog items 
        -- with missing activity, preventing downstream calculation and BI reporting errors
        ISNULL(s.total_sales, 0) AS total_sales,
        ISNULL(s.total_quantity, 0) AS total_quantity,
        ISNULL(s.total_orders, 0) AS total_orders,
        ISNULL(s.total_customers, 0) AS total_customers,
        ISNULL(s.sales_2012, 0) AS sales_2012,
        ISNULL(s.sales_2013, 0) AS sales_2013,
        s.first_sale_date,
        s.last_sale_date,
        
        -- Financial Metric (COGS): Calculates total wholesale cost based on unit volume, defaulting unsold items to 0
        ISNULL(p.cost * s.total_quantity, 0) AS total_cost,

        -- Lifespan: Active duration in months between initial and most recent product sale
        DATEDIFF(MONTH, s.first_sale_date, s.last_sale_date) AS lifespan,

        -- Inactivity & Turnover Risk: Measures months elapsed from last sale to the fixed analysis reporting date ('2013-12-31')
        DATEDIFF(MONTH, s.last_sale_date, '2013-12-31') AS recency_months,

        -- Catalog Presence Flag: Identifies whether the transaction maps to an active product dimension record
        CASE WHEN p.product_key IS NOT NULL THEN 1 ELSE 0 END AS exists_in_catalog
    FROM dim_products p
    -- FULL OUTER JOIN FUNCTION: Preserves all rows from both datasets—capturing unsold catalog items 
    -- as well as historical sales transactions missing matching metadata in dim_products
    FULL OUTER JOIN sales_summary s ON p.product_key = s.product_key
)

-- -----------------------------------------------------------------------------
-- SECTION 3: Final Output & Business Intelligence Ready Transformations
-- Assembles product profiles, stock movement health, profitability tiers, and financial growth KPIs.
-- -----------------------------------------------------------------------------
SELECT 
    ---------------------------------------------------------------------------
    -- GROUP 1: Product Master Metadata
    ---------------------------------------------------------------------------
    c.product_key,
    c.product_name,
    c.category,
    c.subcategory,
    c.cost,

    ---------------------------------------------------------------------------
    -- GROUP 2: Current Inventory Health & Risk (Real-Time Operational Status)
    ---------------------------------------------------------------------------
    c.last_sale_date,
    c.recency_months AS recency_in_months,
    
    -- Real-Time Obsolescence Rules: Classifies inventory by movement velocity and turnover risk
    CASE
        WHEN c.exists_in_catalog = 1 AND c.total_sales = 0 
            THEN 'Dead Stock (Zero Lifetime Sales)'
        WHEN c.recency_months <= 2 THEN 'Active / Fast-Moving'
        WHEN c.recency_months BETWEEN 3 AND 6 THEN 'Slow-Moving (Watch List)'
        WHEN c.recency_months BETWEEN 7 AND 12 THEN 'At Risk / Approaching Obsolete'
        WHEN c.recency_months > 12 THEN 'Obsolete / Dead Stock (12+ Months Inactive)'
        ELSE 'Unmapped Sales Transaction'
    END AS product_obsolescence_status,

    ---------------------------------------------------------------------------
    -- GROUP 3: Historical Performance & Profitability Tiers (Lifetime Scope)
    ---------------------------------------------------------------------------
    -- Lifetime Revenue Volume Tiering: Categorizes total dollar sales into high, medium, and low revenue buckets
    CASE
        WHEN ISNULL(c.total_sales, 0) > 50000 THEN 'High-Performer (Lifetime)'
        WHEN ISNULL(c.total_sales, 0) >= 10000 THEN 'Mid-Range (Lifetime)' 
        ELSE 'Low-Performer (Lifetime)'
    END AS lifetime_sales_tier,

    -- Product Shelf-Life Duration Tiers: Classifies product shelf-life based on active selling duration
    CASE 
        WHEN c.total_sales = 0 THEN 'Unsold Catalog Item'
        WHEN ISNULL(c.lifespan, 0) = 0 AND c.total_orders > 1 THEN 'Single-Month Burst'
        WHEN c.lifespan <= 6 THEN 'Short Run (1-6 Months Active)'
        WHEN c.lifespan <= 12 THEN 'Standard Run (7-12 Months Active)'
        ELSE 'Extended Run (12+ Months Active)'
    END AS active_lifespan_tier,

    -- Strategic Margin Segmentation: Evaluates gross margin percentage [(Sales - COGS) / Sales] 
    -- while handling zero-sales edge cases and unmapped catalog items to prevent calculation errors
    CASE
        WHEN c.total_sales = 0 THEN 'No Sales Activity'
        WHEN c.exists_in_catalog = 0 THEN 'Cost Data Missing (Unmapped Product)'
        WHEN (c.total_sales - c.total_cost) / CAST(c.total_sales AS FLOAT) > 0.40 THEN 'High Margin Driver (40%+)'
        WHEN (c.total_sales - c.total_cost) / CAST(c.total_sales AS FLOAT) >= 0.15 THEN 'Stable Margin Core (15%-40%)'
        WHEN (c.total_sales - c.total_cost) / CAST(c.total_sales AS FLOAT) > 0.00 THEN 'Low Margin / Volume Driver (0%-15%)'
        ELSE 'Unprofitable Loss Leader (<0%)'
    END AS product_margin_segment,

    -- Net Profit & Cash Volume Segmentation: Measures absolute dollar contribution (Sales - COGS)
    -- to highlight top cash drivers while gracefully handling missing catalog cost data
    CASE
        WHEN c.exists_in_catalog = 0 THEN 'Cost Data Missing (Unmapped Product)'
        WHEN (c.total_sales - c.total_cost) > 20000 THEN 'Massive Cash Generator (>$20k)'
        WHEN (c.total_sales - c.total_cost) >= 5000 THEN 'Steady Cash Contributor ($5k-$20k)'
        WHEN (c.total_sales - c.total_cost) >= 0 THEN 'Low Cash / Minor Contributor ($0-$5k)' 
        ELSE 'Negative Cash Drain (<$0)'
    END AS product_profit_volume_segment,

    -- Customer Re-order Velocity Tiers: Classifies products by purchasing frequency 
    -- to distinguish high-repeat staples from single-transaction or unpurchased catalog items
    CASE 
        WHEN c.total_orders = 0 THEN 'No Purchases'
        WHEN c.total_orders = 1 THEN 'One-Time Sale'
        WHEN c.total_orders <= 5 THEN 'Occasional Purchase'
        ELSE 'Repeat Purchase'
    END AS purchase_frequency_tier,

    ---------------------------------------------------------------------------
    -- GROUP 4: Volume & Financial Aggregates
    ---------------------------------------------------------------------------
    c.total_sales,
    c.total_quantity,
    c.total_orders,
    c.total_customers,
    c.lifespan AS lifespan_months,

    ---------------------------------------------------------------------------
    -- GROUP 5: Unit Pricing, Monthly Trends & YoY Growth
    ---------------------------------------------------------------------------
    -- 1. CAST(..., AS FLOAT) ensures explicit floating-point division to prevent integer truncation.
    -- 2. NULLIF(..., 0) dynamically converts zero denominators to NULL, preventing divide-by-zero crashes.
    -- Average Selling Price (ASP): Calculates average revenue generated per physical unit sold
    ROUND(CAST(c.total_sales AS FLOAT) / NULLIF(c.total_quantity, 0), 1) AS avg_selling_price,

    -- Average Order Value (AOV): Revenue per transaction; measures average spend generated per customer order
    ROUND(ISNULL(CAST(c.total_sales AS FLOAT) / NULLIF(c.total_orders, 0), 0), 2) AS avg_order_revenue,

    -- Monthly Run-Rate Revenue: Evaluates average monthly sales over active shelf-life
    -- adding +1 to lifespan prevents zero division for single-month or same-day launches
    ROUND(ISNULL(CAST(c.total_sales AS FLOAT) / NULLIF(ISNULL(c.lifespan, 0) + 1, 0), c.total_sales), 2) AS avg_monthly_revenue,

    sales_2012, 
    sales_2013,

    -- YoY Financial Growth Analytics: Applies business-informed rules for edge-case growth scenarios
    CASE
        -- Scenario A: Inactive across both comparison years -> 0% Growth Rate
        WHEN c.sales_2012 = 0 AND c.sales_2013 = 0 THEN 0.0

        -- Scenario B: Newly launched or reactivated product in 2013 -> Represents +100% Growth (1.00)
        WHEN c.sales_2012 = 0 AND c.sales_2013 > 0 THEN 1.00  

        -- Scenario C: Discontinued or inactive product in 2013 -> Represents -100% Loss (-1.00)
        WHEN c.sales_2012 > 0 AND c.sales_2013 = 0 THEN -1.00 

        -- Scenario D: Standard Mathematical Growth Formula [(New - Old) / Old]
        ELSE ROUND((CAST(c.sales_2013 - c.sales_2012 AS FLOAT) / NULLIF(c.sales_2012, 0)), 4)
    END AS product_yoy_sales_growth_rate

FROM combined_catalog c;