/*
===============================================================================
                        Database Setup & Data Loading Process
===============================================================================
Project Objective:
    This script builds the foundation for our retail analytics project. 
    It wipes the slate clean by removing any old versions of the database, 
    creates a brand-new database structure, sets up our reporting tables, 
    and automatically loads our raw business data from CSV files.

CRITICAL NOTICE:
    Running this script completely resets the database. Any data currently inside 
    will be permanently erased and replaced. Make sure to back up previous work first!
===============================================================================
*/

-- Switch to the system 'master' database before deleting or creating our database.
-- This safely disconnects us from the retail database so SQL Server allows us to drop it.
USE master;
GO

-- ----------------------------------------------------------------------------- 
-- 1) Safe Environment Reset (Delete Old Database)
-- ----------------------------------------------------------------------------- 
-- Check if a database named 'RetailSalesAnalytics' already exists in the system files.
IF EXISTS (SELECT 1 FROM sys.databases WHERE name = 'RetailSalesAnalytics')
BEGIN
    -- Forcefully disconnect any active users or connected applications right now.
    -- This prevents the delete command from getting stuck or failing due to open connections.
    ALTER DATABASE RetailSalesAnalytics SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    
    -- Permanently delete the old database to guarantee a 100% fresh start.
    DROP DATABASE RetailSalesAnalytics;
END;
GO

-- ----------------------------------------------------------------------------- 
-- 2) Creating a Fresh Database
-- ----------------------------------------------------------------------------- 
-- Creates a brand-new, empty database to hold our business data.
CREATE DATABASE RetailSalesAnalytics;
GO

-- Tell SQL Server to run all upcoming table-creation commands inside our new database.
USE RetailSalesAnalytics;
GO

-- ----------------------------------------------------------------------------- 
-- 3) Setting Up Our Core Tables (Database Structure)
-- ----------------------------------------------------------------------------- 

-- Create Customer Table (Stores descriptive customer profiles)
CREATE TABLE dim_customers(
    customer_key int,         -- Surrogate Key: A clean, sequential number created purely for fast table lookups
    customer_id int,          -- Natural Key: The original tracking ID used in the primary business software
    customer_number nvarchar(50),
    first_name nvarchar(50),
    last_name nvarchar(50),
    country nvarchar(50),
    marital_status nvarchar(50),
    gender nvarchar(50),
    birthdate date,
    create_date date
);
GO

-- Create Product Table (Stores master catalog details and descriptions)
CREATE TABLE dim_products(
    product_key int,          -- Surrogate Key: Synthetic primary key generated for fast star-schema joins and history tracking
    product_id int,           -- Natural Key: Business-assigned product tracking ID from the operational catalog
    product_number nvarchar(50),
    product_name nvarchar(50),
    category_id nvarchar(50),
    category nvarchar(50),
    subcategory nvarchar(50),
    maintenance nvarchar(50),
    cost int,
    product_line nvarchar(50),
    start_date date 
);
GO

-- Create Sales Table (Stores measurable, numerical transaction metrics)
CREATE TABLE fact_sales(
    order_number nvarchar(50),
    product_key int,          -- Foreign Key: Relates fact records directly to the Product dimension
    customer_key int,         -- Foreign Key: Relates fact records directly to the Customer dimension
    order_date date,
    shipping_date date,
    due_date date,
    sales_amount int,         -- Financial metric representing the money made from the sale (Revenue)
    quantity tinyint,         -- Keeps file size tiny since customers usually buy small whole numbers per item
    price int 
);
GO

-- ----------------------------------------------------------------------------- 
-- 4) Importing Raw Data from CSV Files
-- ----------------------------------------------------------------------------- 

-- Clear out any existing rows first to prevent duplicate data if this script is run again.
TRUNCATE TABLE dim_customers;
GO

-- Informs SQL Server to read dates as Day/Month/Year from the CSV to prevent import errors.
SET DATEFORMAT dmy;  

-- Load data straight from the local customer CSV file into our customer table.
BULK INSERT dim_customers
FROM 'C:\sql\Retail_Sales_Analytics\Datasets_for_DB_Tables\dim_customers.csv'
WITH (
    FIRSTROW = 2,           -- Skips the very first row of the file because it contains column headers
    FIELDTERMINATOR = ',',  -- Tells the database engine that values are separated by standard commas
    TABLOCK                 -- Locks the table temporarily to maximize file import speeds
);
GO

TRUNCATE TABLE dim_products;
GO

-- Load data straight from the local product CSV file into our product table.
BULK INSERT dim_products
FROM 'C:\sql\Retail_Sales_Analytics\Datasets_for_DB_Tables\dim_products.csv'
WITH (
    FIRSTROW = 2,           -- Skips the header row
    FIELDTERMINATOR = ',',  -- Values are separated by commas
    TABLOCK                 -- Optimizes file processing speed
);
GO

TRUNCATE TABLE fact_sales;
GO

-- Load data straight from the local sales spreadsheet CSV into our sales metrics table.
BULK INSERT fact_sales
FROM 'C:\sql\Retail_Sales_Analytics\Datasets_for_DB_Tables\fact_sales.csv'
WITH (
    FIRSTROW = 2,           -- Skips the header row
    FIELDTERMINATOR = ',',  -- Values are separated by commas
    TABLOCK                 -- Optimizes file processing speed
);
GO