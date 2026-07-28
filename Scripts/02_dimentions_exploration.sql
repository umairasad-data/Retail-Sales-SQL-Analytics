/*
===============================================================================
                            Dimention Exploration
===============================================================================
Goal:    
    - To review the layout and organization of dimention columns in our customer and product tables.
    - Checks where our customers are located and inspects how our product groupings look.

Key SQL Tools Used:    
    - DISTINCT: Removes duplicate values so we only see a clean, unique list of entries.   
    - ORDER BY: Sorts rows alphabetically or numerically to make the results easy to scan.
===============================================================================
*/

-- Tell SQL Server to run all upcoming checks inside our retail database
USE RetailSalesAnalytics;
GO

-- ---------------------------------------------------------------------------
-- 1) Checking Customer Locations (Countries)
-- ---------------------------------------------------------------------------

-- Extract a clean list of every unique country where our customers live.
-- Using DISTINCT filters out duplicate names, giving us a bird's-eye view of our global footprint.
-- Sorting alphabetically makes it easy for business teams to map out our current market coverage.
SELECT DISTINCT
    country
FROM dim_customers
ORDER BY country;

-- ---------------------------------------------------------------------------
-- 2) Auditing Our Product Groups & Catalog Layout
-- ---------------------------------------------------------------------------

-- Pull a unique list of all categories, subcategories, and product names combined.
-- This acts as a layout check to ensure subcategories match their main categories perfectly, 
-- helping us spot any data entries that might have been sorted into the wrong bucket.
SELECT DISTINCT
    category,
    subcategory,
    product_name
FROM dim_products
ORDER BY
    category,
    subcategory,
    product_name;