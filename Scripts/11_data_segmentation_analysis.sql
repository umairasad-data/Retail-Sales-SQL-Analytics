/*
===============================================================================
                        Data Segmentation Analysis
===============================================================================
Purpose:
    - To organize our data into meaningful groups for targeted insights.
    - Used for profiling types of customers, grouping products, or regional analysis.

Key SQL Tools Used:
    - CASE: Defines custom rules to sort data into buckets.
    - GROUP BY: Summarizes and counts our data based on those groups.
===============================================================================
*/

-- Point our analytical operations to the active retail database
USE RetailSalesAnalytics;
GO

-- ---------------------------------------------------------------------------
-- 1) Product Sorting by Cost Ranges (Price Tiers)
-- ---------------------------------------------------------------------------
-- Business Goal: Classifies our inventory into distinct price tiers to help product 
-- managers analyze our product variety and make sure our pricing is well-balanced.
-- Note: SQL reads CASE WHEN statements from top to bottom. Once a row matches 
-- a condition, it stops checking. Because we check '< 100' first, the next line '<= 500' 
-- automatically handles items that are between 100.01 and 500 without extra code!
WITH product_segments AS (
    SELECT
        product_key,
        product_name,
        cost,
        -- Sorting items step-by-step into clear price groups
        CASE 
            WHEN cost < 100 THEN 'Below 100'
            WHEN cost <= 500 THEN '100-500'   -- Automatically handles 100.00 to 500.00
            WHEN cost <= 1000 THEN '500-1000' -- Automatically handles 500.01 to 1000.00
            ELSE 'Above 1000'
        END AS cost_range
    FROM dim_products
)
SELECT 
    cost_range,
    -- Counts individual catalog items matching each custom price group
    COUNT(product_key) AS total_products
FROM product_segments
GROUP BY cost_range
ORDER BY total_products DESC;


/*
===============================================================================
         Customer Grouping by Spending & Account Activity Status
===============================================================================
Goal:
  - Group customers into practical buckets so marketing teams can take action:
      * VIP     : Long-term buyers (12+ months) who have spent over 5,000 EUR
      * Regular : Long-term buyers (12+ months) who have spent 5,000 EUR or less
      * New     : Fresh sign-ups with less than 12 months of total history
===============================================================================
*/

-- Step 1: Pre-calculate customer shopping habits (total spend, account age, and last purchase timing)
WITH customer_spending AS (
    SELECT 
        c.customer_key,
        -- Finds the exact start date of the customer's shopping relationship with us
        MIN(f.order_date) AS first_order,
        -- Tracks the very last time the customer placed a successful order
        MAX(f.order_date) AS last_order,
        SUM(f.sales_amount) AS total_spending,
        
        -- Note: DATEDIFF calculates the total timeline distance in months.
        -- This tells us how many months elapsed between their very first and very last order.
        DATEDIFF(month, MIN(f.order_date), MAX(f.order_date)) AS lifespan_months,

        -- 1. Account Age: How old is the account? (Used to find truly 'New' shoppers)
        -- Hardcoded Date Note: We use '2014-01-28' as an anchor date because it represents the end 
        -- of this historical dataset, acting like a snapshot taken on that specific day.
        DATEDIFF(month, MIN(f.order_date), '2014-01-28') AS account_age_months, 
        
        -- 2. Inactivity Check: How long has it been since their last order?
        DATEDIFF(month, MAX(f.order_date), '2014-01-28') AS months_since_last_order  

    FROM fact_sales f
    LEFT JOIN dim_customers c ON f.customer_key = c.customer_key
    WHERE f.order_date IS NOT NULL
    GROUP BY c.customer_key
)

-- Step 2: Assign clean business labels and count how many customers fall into each bucket
SELECT 
    detailed_customer_segment,
    -- Compresses thousands of individual buyers into 8 highly actionable marketing segments
    COUNT(customer_key) AS total_customers
FROM 
(
    SELECT 
        customer_key,
        lifespan_months,
        account_age_months,
        months_since_last_order,
        total_spending,

        CASE 
            ---------------------------------------------------------------------------
            -- A) THE TOP SPENDERS (VIP ACCOUNTS)
            ---------------------------------------------------------------------------
            -- 1. Core VIP: Older accounts, actively shopping (bought in last 2 months), spent heavily (>5k)
            WHEN account_age_months >= 12 AND months_since_last_order <= 2 AND total_spending > 5000 
                -- Actionable Insight: Perfect for luxury rewards and exclusive product previews.
                THEN 'Core VIP (Established)'

            -- 2. New VIP / Shooting Star: Brand new account (≤3 months old), bought instantly, spent heavily (>5k)
            WHEN account_age_months <= 3 AND months_since_last_order <= 2 AND total_spending > 5000 
                THEN 'New VIP (Shooting Star)'


            ---------------------------------------------------------------------------
            -- B) THE FRESH SIGN-UPS (Account Age <= 3 Months Old)
            ---------------------------------------------------------------------------
            -- 3. Active New (Mid/High Spender): Fresh account, actively shopping, spent between 1k and 5k
            WHEN account_age_months <= 3 AND months_since_last_order <= 2 AND total_spending >= 1000
                THEN 'New Account (Growth Driver)'

            -- 4. Active New (Low Spender): Fresh account, actively shopping, but spend is under 1,000
            WHEN account_age_months <= 3 AND months_since_last_order <= 2 AND total_spending < 1000
                THEN 'Standard New (Low Spend)'

            -- 5. Cold New Lead: Registered recently (≤3 months old), but hasn't bought anything in 3 full months
            WHEN account_age_months <= 3 AND months_since_last_order = 3
                THEN 'Cold New Lead'


            ---------------------------------------------------------------------------
            -- C) THE INACTIVE & SLIPPING ACCOUNTS
            ---------------------------------------------------------------------------
            -- 6. Lost / Inactive: Total ghost accounts. Haven't made a single purchase in over a year (12+ months)
            WHEN months_since_last_order >= 12 
                -- Actionable Insight: Great targets for automated win-back email discounts.
                THEN 'Lost / Inactive'

            -- 7. At Risk / Slipping: Established accounts that suddenly went quiet, making no purchases for 4 to 11 months
            WHEN months_since_last_order >= 4 
                THEN 'At Risk / Slipping'


            ---------------------------------------------------------------------------
            -- D) THE RELIABLE MAIN BASE
            ---------------------------------------------------------------------------
            -- 8. Regular: Stable account (over 3 months old), shopping consistently with normal spending habits
            ELSE 'Regular'
        END AS detailed_customer_segment

    FROM customer_spending
) AS segmented_customers -- Temporary name for our customer pool with their newly assigned labels
GROUP BY detailed_customer_segment
ORDER BY total_customers DESC;