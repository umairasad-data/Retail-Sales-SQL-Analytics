CREATE OR ALTER VIEW dbo.v_customer_behavior_report AS
/*
===============================================================================
                           Customer Behaviour Report
===============================================================================
Purpose         : Consolidates transactional sales data into a unified, 360-degree
                  customer analytics view. Used by BI dashboards, marketing teams,
                  and management to analyze spend patterns, churn risk, and YoY growth.

Key Business Logic & Highlights:
-------------------------------------------------------------------------------
1. Data Normalization   : Joins Fact Sales with Customer and Product dimensions,
                          handling missing dates and data cleanup.
2. Preference Tracking  : Dynamically determines each customer's top spending 
                          product category using window ranking functions.
3. Metric Defensiveness : Prevents mathematical crashes (divide-by-zero) when
                          calculating AOV, monthly spend, and YoY growth rates.
4. Business Logic Cases : Handles tricky YoY scenarios (New Acquisition or Reactivation, Churn, 
                          and Zero Sales) as explicit business outcomes.
5. Strategic Segmentation: Applies multi-factor CASE rules to segment users into
                           Actionable Lifecycle & Loyalty Tiers (VIP, At-Risk, Lost).


Analytical Anchor Date & Year-over-Year (YoY) Strategy:
-------------------------------------------------------------------------------
* Dataset Snapshot Date ('2013-12-31'):
  This dataset covers historical sales ranging from 2010 to early 2014. To simulate
  a real-world analytical environment, '2013-12-31' is set as the fixed anchor date.
  All recency calculations (months since last purchase) and account ages are evaluated 
  as of this snapshot date.

* YoY Comparison Selection (2012 vs 2013):
  Although partial sales data exists for early 2014, comparing a partial year against 
  a complete 12-month year introduces seasonal skew and misleading growth rates. 
  To maintain mathematical consistency and produce clean year-over-year comparisons, 
  this script strictly compares full-year 2012 against full-year 2013.
===============================================================================
*/

-- -----------------------------------------------------------------------------
-- SECTION 1: Base Layer
-- Combines granular transactional rows with customer demographics and product attributes.
-- Filter out invalid transaction records missing an order date.
-- -----------------------------------------------------------------------------
WITH base_query AS (
    SELECT
        f.order_number,
        f.product_key,
        f.order_date,
        f.sales_amount,
        f.quantity,
        c.customer_key,
        c.customer_number,
        -- Cleanly combine first and last names into a single display string
        CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
        -- Dynamic Age Calculation: Uses fixed anchor date '2013-12-31' to align with snapshot dataset
        DATEDIFF(YEAR, c.birthdate, '2013-12-31') AS age,
        p.category
    FROM fact_sales f
    -- LEFT JOIN FUNCTION: Used LEFT JOINs to keep every sales order record from fact_sales, 
    -- ensuring no sales rows are lost even if customer or product profile details are missing in dimention tables
    LEFT JOIN dim_customers c ON f.customer_key = c.customer_key
    LEFT JOIN dim_products p ON f.product_key = p.product_key
    WHERE f.order_date IS NOT NULL
),

-- -----------------------------------------------------------------------------
-- SECTION 2: Preferred Category Layer
-- Identifies the dynamic favorite category per customer based on total lifetime spend.
-- -----------------------------------------------------------------------------
category_spending AS (
    SELECT 
        customer_key,
        category,
        SUM(sales_amount) AS total_category_sales,
        -- Used ROW_NUMBER() OVER (PARTITION BY...) to safely break ties 
        -- (ordered alphabetically by category name if spend is equal
        ROW_NUMBER() OVER (
            PARTITION BY customer_key 
            ORDER BY SUM(sales_amount) DESC, category ASC
        ) AS ranking
    FROM base_query
    WHERE category IS NOT NULL
    GROUP BY customer_key, category
),

preferred_category_lookup AS (
    -- Keeps only the #1 favorite category for each customer where ranking = 1
    SELECT 
        customer_key, 
        category AS preferred_product_category 
    FROM category_spending 
    WHERE ranking = 1
),

-- -----------------------------------------------------------------------------
-- SECTION 3: Timeline & Annual Growth Layer
-- Pivot granular sales into distinct annual buckets (2012 vs 2013) to prepare 
-- for Year-Over-Year growth calculations.
-- -----------------------------------------------------------------------------
customer_yearly_sales AS (
    SELECT 
        customer_key,
        -- Conditional Aggregation: Separates sales volume into distinct annual buckets (2012 vs 2013)
        SUM(CASE WHEN YEAR(order_date) = 2012 THEN sales_amount ELSE 0 END) AS sales_2012,
        SUM(CASE WHEN YEAR(order_date) = 2013 THEN sales_amount ELSE 0 END) AS sales_2013
    FROM base_query
    GROUP BY customer_key
),

-- -----------------------------------------------------------------------------
-- SECTION 4: Customer Lifecycle & Core Summary Aggregation Layer
-- Computes customer-level KPI metrics (Total Spend, Total Orders, Recency, Lifespan).
-- Anchor Date: '2013-12-31' is used to compute Recency and Account Age consistency.
-- -----------------------------------------------------------------------------
customers_aggregations AS (
    SELECT 
        b.customer_key,
        b.customer_number,
        b.customer_name,
        b.age,
        COUNT(DISTINCT b.order_number) AS total_orders,
        COUNT(DISTINCT b.product_key) AS total_products,
        MAX(b.order_date) AS last_order_date,
        SUM(b.sales_amount) AS total_sales,
        SUM(b.quantity) AS total_quantity,
        -- Lifespan: Months between a customer's first purchase and most recent purchase
        DATEDIFF(MONTH, MIN(b.order_date), MAX(b.order_date)) AS lifespan,
        -- Recency: Inactivity in months between last order date and report analysis date
        DATEDIFF(MONTH, MAX(b.order_date), '2013-12-31') AS recency,
        -- Customer Account Tenure: Measures months active since first order 
        -- (used initial purchase date as an estimated baseline due to missing account creation dates and timestamps)
        DATEDIFF(MONTH, MIN(b.order_date), '2013-12-31') AS months_since_first_purchase
    FROM base_query b
    GROUP BY b.customer_key, b.customer_number, b.customer_name, b.age
)

-- -----------------------------------------------------------------------------
-- SECTION 5: Final Output & Business Intelligence Ready Transformations
-- Assembles customer profiles, formatted KPIs, calculated growth, and business segments.
-- -----------------------------------------------------------------------------
SELECT 
    ---------------------------------------------------------------------------
    -- GROUP 1: Demographic Profiling
    ---------------------------------------------------------------------------
    agg.customer_key,
    agg.customer_number,
    agg.customer_name,
    agg.age,
    -- Age Bins: Categorizes continuous numerical age into actionable target demographic groups
    CASE 
        WHEN agg.age IS NULL THEN 'Unknown / Missing Birthdate'
        WHEN agg.age < 20 THEN 'Under 20'
        WHEN agg.age <= 29 THEN '20-29'   
        WHEN agg.age <= 39 THEN '30-39'   
        WHEN agg.age <= 49 THEN '40-49'   
        ELSE '50 and above'
    END AS age_groups,

    ---------------------------------------------------------------------------
    -- GROUP 2: Lifetime Sales & Volume Performance
    ---------------------------------------------------------------------------
    agg.total_sales,
    agg.total_orders,
    agg.total_quantity,
    agg.total_products,
    -- Defensive Math & Type Casting (AOV):
    -- 1. CAST converts integer sales to FLOAT to prevent truncation/integer division and preserve decimal accuracy.
    -- 2. NULLIF prevents divide-by-zero crashes if total_orders = 0.
    -- 3. ISNULL & ROUND ensure clean, presentation-ready 2-decimal currency formatting.
    ROUND(ISNULL(CAST(agg.total_sales AS FLOAT) / NULLIF(agg.total_orders, 0), 0), 2) AS avg_order_value,
    ---------------------------------------------------------------------------
    -- GROUP 3: Timeline & Recency Performance
    ---------------------------------------------------------------------------
    agg.last_order_date,
    agg.lifespan AS lifespan_months,
    -- Defensive Math & Type Casting (Avg Monthly Spend):
    -- 1. CAST converts integer sales to FLOAT to prevent truncation/integer division and preserve decimal accuracy.
    -- 2. Adding +1 to lifespan prevents division-by-zero crashes for single-month or same-day shoppers.
    -- 3. ISNULL & ROUND ensure clean, presentation-ready 2-decimal currency formatting.
    ROUND(ISNULL(CAST(agg.total_sales AS FLOAT) / (agg.lifespan + 1), 0), 2) AS avg_monthly_spend,
    ---------------------------------------------------------------------------
    -- GROUP 4: Financial Growth & YoY Analytics
    -- Uses business-informed rules for edge-case growth scenarios.
    ---------------------------------------------------------------------------
    ISNULL(yoy.sales_2012, 0) AS sales_2012,
    ISNULL(yoy.sales_2013, 0) AS sales_2013,
    CASE
        -- Scenario A: Inactive across both years -> 0% Growth Rate
        WHEN ISNULL(yoy.sales_2012, 0) = 0 AND ISNULL(yoy.sales_2013, 0) = 0 
            THEN 0.0

        -- Scenario B: Acquired in 2013 (New or Reactivated Customer) -> Represents +100% Growth (1.00)
        WHEN ISNULL(yoy.sales_2012, 0) = 0 AND ISNULL(yoy.sales_2013, 0) > 0 
            THEN 1.00

        -- Scenario C: Churned in 2013 (Lost Customer) -> Represents -100% Loss (-1.00)
        WHEN ISNULL(yoy.sales_2012, 0) > 0 AND ISNULL(yoy.sales_2013, 0) = 0 
            THEN -1.00

        -- Scenario D: Standard Mathematical Percentage Growth Formula [(New - Old) / Old]
        ELSE ROUND(CAST(yoy.sales_2013 - yoy.sales_2012 AS FLOAT) / NULLIF(yoy.sales_2012, 0), 4)
    END AS customer_yoy_sales_growth_rate,

    ---------------------------------------------------------------------------
    -- GROUP 5: Category Preference & Strategic Business Segmentation
    -- Classifies users into operational buckets for targeted marketing campaigns.
    ---------------------------------------------------------------------------
    ISNULL(pref.preferred_product_category, 'No Purchases') AS preferred_product_category,

    -- Customer loyalty tier: Categorizes tenure (months since initial purchase) 
    -- into actionable relationship stages for targeted loyalty and onboarding campaigns
    CASE 
        WHEN agg.months_since_first_purchase <= 3 THEN 'New Relationship'
        WHEN agg.months_since_first_purchase <= 11 THEN 'Mid-Stage Relationship'
        ELSE 'Established Relationship'
    END AS customer_loyalty_tier,

    -- Multi-Factor Customer Segmentation: Evaluates Account age + Inactivity Window + Total Spend Volume
    CASE 
        -- 1. Core VIP: Established account, active in the last 2 months, heavy spending footprint (>5k)
        WHEN agg.months_since_first_purchase >= 12 AND agg.recency <= 2 AND agg.total_sales > 5000 
            THEN 'Core VIP (Established)'

        -- 2. New VIP / Shooting Star: Fresh account (under 3 months old), active, fast heavy spender (>5k)
        WHEN agg.months_since_first_purchase <= 3 AND agg.recency <= 2 AND agg.total_sales > 5000 
            THEN 'New VIP (Shooting Star)'

        -- 3. New Account (Growth Driver): Fresh account, active, solid moderate spend ($1k - $5k)
        WHEN agg.months_since_first_purchase <= 3 AND agg.recency <= 2 AND agg.total_sales >= 1000
            THEN 'New Account (Growth Driver)'

        -- 4. Standard New (Low Spend): Fresh account, active, but has small transaction values (<$1k)
        WHEN agg.months_since_first_purchase <= 3 AND agg.recency <= 2 AND agg.total_sales < 1000
            THEN 'Standard New (Low Spend)'

        -- 5. Cold New Lead: Registered recently (<=3 mo), but inactive for a month (recency >= 3)
        WHEN agg.months_since_first_purchase <= 3 AND agg.recency >= 3
            THEN 'Cold New Lead'

        -- 6. Lost / Inactive: Total ghost accounts. No checkout activity for over a full year (12+ months)
        WHEN agg.recency >= 12 
            THEN 'Lost / Inactive'

        -- 7. At Risk / Slipping: Regular account that went completely quiet, making no purchases for 4 to 11 months
        WHEN agg.recency >= 4 
            THEN 'At Risk / Slipping'

        -- High-Value Engagement At-Risk: Captures established top spenders (>5k) with recent activity (<=3mo inactive)
        -- who fall outside strict VIP tenure thresholds (>=12mo age, <=2mo recency) 
        -- to prevent premature classification into default tiers
        WHEN agg.months_since_first_purchase > 3 AND agg.recency <= 3 AND agg.total_sales > 5000
            THEN 'Core VIP (Cooling Down)'

        -- 9. Regular Core Base: Established/mid account, active buyer, standard spending limits (<= $5k)
        WHEN agg.months_since_first_purchase > 3 AND agg.recency <= 3 AND agg.total_sales <= 5000
            THEN 'Regular Core Base'

        -- 10. Safety net only — should now be structurally unreachable except on NULL total_sales
        ELSE 'Review Logic / Unsegmented'
    END AS detailed_customer_segment

FROM customers_aggregations agg
-- LEFT JOIN FUNCTION: Uses LEFT JOINs from customers_aggregations to ensure every 
-- customer remains in the report even if they lack a preferred category or 2012/2013 sales.
LEFT JOIN preferred_category_lookup pref ON agg.customer_key = pref.customer_key
LEFT JOIN customer_yearly_sales yoy ON agg.customer_key = yoy.customer_key;