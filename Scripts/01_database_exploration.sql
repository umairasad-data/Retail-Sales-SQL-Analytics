/*
===============================================================================
         Database Checking, Data Cleaning & Rule Enforcement
===============================================================================
Purpose:        
    - Explores our database layout by looking at lists of tables and column settings.    
    - Fixes data quality risks by turning optional ID columns into strictly required fields.    
    - Enforces formal "Primary Keys" on the customer and product tables so every 
      row in those two tables is guaranteed to be unique.

Highlights:    
    1. Uses built-in system views to inspect the hidden blueprint of our tables.    
    2. Protects data accuracy by banning blank or empty (NULL) values in critical lookup IDs
       across the customer, product, and sales tables.    
    3. Locks down safety rules so no duplicate rows can slip into the customer 
       or product tables. (A similar duplicate check for the sales table is 
       commented out but not turned on yet.)
===============================================================================
*/

-- Tell SQL Server to run all upcoming checks and updates inside our retail database
USE RetailSalesAnalytics;
GO

-- ----------------------------------------------------------------------------- 
-- 1) Database Blueprint Inspection (Checking Table Layouts)
-- ----------------------------------------------------------------------------- 

-- Look at the system dictionary to pull a master list of all tables in this database.
-- This helps us verify that our data loading process successfully created the correct tables.
SELECT 
    TABLE_CATALOG, 
    TABLE_SCHEMA, 
    TABLE_NAME, 
    TABLE_TYPE
FROM INFORMATION_SCHEMA.TABLES;

-- Check the column details (data formats, empty spaces, text limits) for the Customer table.
-- This lets us inspect the current structural rules before we apply any changes.
SELECT 
    COLUMN_NAME, 
    DATA_TYPE, 
    IS_NULLABLE, 
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_customers';

-- Check the column details for the Product table to see its current structural rules.
SELECT 
    COLUMN_NAME, 
    DATA_TYPE, 
    IS_NULLABLE, 
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'dim_products';

-- Check the column details for the Sales table to verify how it connects back to our other tables.
SELECT 
    COLUMN_NAME, 
    DATA_TYPE, 
    IS_NULLABLE, 
    CHARACTER_MAXIMUM_LENGTH
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_NAME = 'fact_sales';


/*===============================================================================
              Fixing Structural Flaws & Enforcing Data Safety Rules
===============================================================================
Why We Are Doing This:    
    - Table inspection showed that critical ID columns were set up as "Nullable" 
      (meaning they could accept completely blank or missing values).    
    - Allowing blank values in these key columns is a major risk. It can break table 
      connections (JOINs), leave sales untracked, and result in highly inaccurate financial reports.

Action Taken:    
    - This section updates the tables to change these key columns to 'NOT NULL' (required).    
    - Enforces formal 'Primary Keys' on our background tables to guarantee that every row 
      is unique, creating a bulletproof environment for reliable reporting.
===============================================================================*/

-- ============================================================================
-- 2. Data Quality Fixes: Customer Table Safety Rules
-- ============================================================================

-- Step A: Make customer ID tracking columns strictly required fields that cannot be left blank.
-- This ensures every customer row has a valid system lookup number and business ID.
ALTER TABLE dim_customers ALTER COLUMN customer_key int NOT NULL;
ALTER TABLE dim_customers ALTER COLUMN customer_id int NOT NULL;

-- Step B: Apply a Primary Key. This forces the database engine to guarantee that
-- every single 'customer_key' value is completely unique across the entire table.
-- This acts as a safety shield, preventing accidental duplicate profiles for the same customer.
ALTER TABLE dim_customers ADD CONSTRAINT PK_dim_customers PRIMARY KEY (customer_key);
GO

-- ============================================================================
-- 3. Data Quality Fixes: Product Table Safety Rules
-- ============================================================================

-- Step A: Make product catalog lookup columns strictly required fields that cannot be left blank.
-- This guarantees our product catalog listings remain perfectly synchronized.
ALTER TABLE dim_products ALTER COLUMN product_key int NOT NULL;
ALTER TABLE dim_products ALTER COLUMN product_id int NOT NULL;

-- Step B: Apply a Primary Key to the product table to officially anchor lookups.
-- This guarantees that every item in our inventory catalog has exactly one unique identifier.
ALTER TABLE dim_products ADD CONSTRAINT PK_dim_products PRIMARY KEY (product_key);
GO

-- ============================================================================
-- 4. Making Sure Every Sale Has the Basic Info It Needs
-- ============================================================================
-- Rule: Every row in the sales table must have an order number, a product,
-- and a customer. None of these three can be left blank.
--
-- Why this matters:
-- 1. A sale with no order number or no product doesn't make sense — we
--    wouldn't know what was sold or which order it belongs to.
-- 2. A sale with no customer listed means we can't tell who bought it.
-- 3. Note: this only blocks blank values. It does not check whether the
--    customer or product actually exists in their own tables — that's a
--    separate check we haven't added here yet.

-- Step A: Make these three columns required (no blanks allowed)
ALTER TABLE fact_sales ALTER COLUMN order_number nvarchar(50) NOT NULL;
ALTER TABLE fact_sales ALTER COLUMN product_key int NOT NULL;
ALTER TABLE fact_sales ALTER COLUMN customer_key int NOT NULL;
GO

-- Step B: Not turned on yet.
-- The idea is to stop the same product from appearing twice under the same
-- order number, so we never accidentally count one item as two sales.
-- Kept commented out for now.
-- ALTER TABLE fact_sales ADD CONSTRAINT PK_fact_sales PRIMARY KEY (order_number, product_key);
-- GO