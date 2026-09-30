/* E-Commerce RFM Analytics
Database : ecommerce_rfm
Source : UCI Online Retail II */

/* 1. DATABASE SETUP
-- Create database and select */

CREATE DATABASE ecommerce_rfm ;
USE ecommerce_rfm ; 

/* 2. TRANSACTION TABLE 
-- Create the transaction table */

CREATE TABLE transactions (
    Invoice VARCHAR(20),
    StockCode VARCHAR(20),
    Description TEXT,
    Quantity INT,
    InvoiceDate DATETIME,
    Price DECIMAL(12, 4),
    CustomerID INT,
    Country VARCHAR(100),
    TotalAmount DECIMAL(14, 4)
);

/* 3. DATA IMPORT 
-- Import data using LOAD DATA */

LOAD DATA LOCAL INFILE
'C:/Users/Admin/Downloads/Portfolio Projects/E-Commerce-RFM-Analytics/data/online_retail_cleaned.csv'
INTO TABLE transactions
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    Invoice,
    StockCode,
    Description,
    Quantity,
    InvoiceDate,
    Price,
    CustomerID,
    Country,
    TotalAmount
);

/* 4. DATA VALIDATION */

-- Row count and key business dimensions
SELECT 
	COUNT(*) AS transaction_lines, 
    COUNT(DISTINCT Invoice) AS unique_orders, 
    COUNT(DISTINCT CustomerID) AS unique_customers, 
    COUNT(DISTINCT StockCode) AS unique_products, 
    COUNT(DISTINCT Country) AS unique_countries
FROM transactions ;

-- Transaction date coverage
SELECT 
	MIN(InvoiceDate) AS first_transaction_date, 
    MAX(InvoiceDate) AS last_transaction_date 
FROM transactions ; 

-- Validate numerical fields
SELECT 
	MIN(Quantity) AS min_quantity, 
    MAX(Quantity) AS max_quantity, 
    MIN(Price) AS min_price, 
    MAX(Price) AS max_price, 
    MIN(TotalAmount) AS min_total_amount, 
    MAX(TotalAmount) AS max_total_amount 
FROM transactions ; 

/* 5. OVERALL BUSINESS PERFORMANCE */

SELECT 
	COUNT(*) AS transaction_lines, 
    COUNT(DISTINCT Invoice) AS total_orders, 
    COUNT(DISTINCT CustomerID) AS total_customers, 
    COUNT(DISTINCT StockCode) AS total_products, 
    COUNT(DISTINCT Country) AS total_countries, 
    SUM(Quantity) AS total_units_sold, 
    ROUND(SUM(TotalAmount), 2) AS total_revenue, 
    ROUND(AVG(TotalAmount), 2) AS avg_transaction_line_value
FROM transactions ;

/* 6. ORDER PERFORMANCE */

WITH order_summary AS (
	SELECT 
		Invoice, 
        CustomerID, 
        MIN(InvoiceDate) AS order_date, 
        SUM(Quantity) AS units_per_order, 
        SUM(TotalAmount) AS order_value, 
        COUNT(DISTINCT StockCode) AS unique_products
	FROM transactions 
    GROUP BY Invoice, CustomerID 
)

SELECT 
	COUNT(*) AS total_orders, 
    ROUND(AVG(order_value), 2) AS avg_order_value, 
    ROUND(AVG(units_per_order), 2) AS avg_units_per_order, 
	ROUND(AVG(unique_products), 2) AS avg_products_per_order, 
    MAX(order_value) AS largest_order_value
FROM order_summary ;

/* 7. COUNTRY PERFORMANCE */

SELECT 
	Country, 
	COUNT(DISTINCT Invoice) AS total_orders, 
    COUNT(DISTINCT CustomerID) AS total_customers, 
    SUM(Quantity) AS units_sold, 
    ROUND(SUM(TotalAmount), 2) AS total_revenue, 
    ROUND(100.0  * SUM(TotalAmount) / SUM(SUM(TotalAmount)) OVER(), 2) AS revenue_share_pct
FROM transactions 
GROUP BY Country 
ORDER BY total_revenue DESC ; 

/* 8. CUSTOMER PERFORMANCE */

WITH customer_summary AS ( 
	SELECT 
		CustomerID, 
        COUNT(DISTINCT Invoice) AS total_orders, 
        SUM(Quantity) AS total_units, 
        ROUND(SUM(TotalAmount), 2) AS total_revenue, 
        MIN(InvoiceDate) AS first_purchase_date, 
        MAX(InvoiceDate) AS last_purchase_date
	FROM transactions 
    GROUP BY CustomerID
)

SELECT 
	CustomerID, 
    total_orders, 
    total_units, 
    total_revenue, 
    first_purchase_date, 
    last_purchase_date 
FROM customer_summary 
ORDER BY total_revenue DESC 
LIMIT 20 ; 

/* 9. CUSTOMER PURCHASE FREQUENCY */

WITH customer_orders AS ( 
	SELECT 
		CustomerID, 
        COUNT(DISTINCT Invoice) AS order_count 
	FROM transactions 
    GROUP BY CustomerID 
), 
customer_types AS ( 
	SELECT 
		CustomerID, 
		CASE 
			WHEN order_count = 1 THEN "One-Time Customer" 
			ELSE "Repeat Customer" 
		END AS customer_type 
	FROM customer_orders 
)

SELECT 
	customer_type, 
    COUNT(*) AS customer_count, 
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER(), 2) AS customer_share_pct 
FROM customer_types 
GROUP BY customer_type 
ORDER BY customer_count DESC ; 

/* 10. PRODUCT PERFORMANCE */

WITH product_summary AS ( 
	SELECT 
		StockCode, 
        MAX(Description) AS product_description, 
        SUM(Quantity) AS units_sold, 
        COUNT(DISTINCT Invoice) AS total_orders, 
        COUNT(DISTINCT CustomerID) AS unique_customers, 
        SUM(TotalAmount) AS total_revenue, 
        SUM(TotalAmount) / NULLIF(SUM(Quantity), 0) AS revenue_per_unit
	FROM transactions 
    GROUP BY StockCode 
)

SELECT 
	StockCode, 
    product_description, 
    units_sold, 
    total_orders, 
    unique_customers, 
    ROUND(total_revenue, 2) AS total_revenue, 
    ROUND(revenue_per_unit, 2) AS revenue_per_unit, 
    RANK() OVER(ORDER BY total_revenue DESC) AS revenue_rank, 
    ROUND( 100 * total_revenue / SUM(total_revenue) OVER(), 2) AS revenue_share_pct 
FROM product_summary 
ORDER BY total_revenue DESC ; 

/* 11. MONTHLY SALES PERFORMANCE */

WITH monthly_sales AS ( 
	SELECT 
		CAST(DATE_FORMAT(InvoiceDate, '%Y-%m-01') AS DATE) AS sales_month, 
        COUNT(DISTINCT Invoice) AS total_orders, 
        COUNT(DISTINCT CustomerID) AS unique_customers, 
        SUM(Quantity) AS units_sold, 
        SUM(TotalAmount) AS total_revenue 
	FROM transactions 
    GROUP BY CAST(DATE_FORMAT(InvoiceDate, '%Y-%m-01') AS DATE) 
), 
monthly_with_lag AS ( 
	SELECT 
		*, 
        LAG(total_revenue) OVER(ORDER BY sales_month) AS previous_month_revenue 
	FROM monthly_sales 
) 

SELECT 
	sales_month, 
    total_orders, 
    unique_customers, 
    units_sold, 
    ROUND(total_revenue, 2) AS total_revenue, 
    ROUND(previous_month_revenue, 2) AS previous_month_revenue, 
    ROUND(total_revenue / NULLIF(total_orders, 0), 2) AS avg_order_value, 
    ROUND(100 * total_revenue / SUM(total_revenue) OVER(), 2) AS revenue_share_pct, 
    ROUND(100 * (total_revenue - previous_month_revenue) / NULLIF(previous_month_revenue, 0), 2) AS mom_revenue_growth_pct 
FROM monthly_with_lag 
ORDER BY sales_month ; 

/* 12. CUSTOMER REVENUE CONCENTRATION */ 

WITH customer_revenue AS ( 
	SELECT 
		CustomerID, 
        SUM(TotalAmount) AS total_revenue 
	FROM transactions 
    GROUP BY CustomerID 
), 
customer_ranked AS ( 
	SELECT 
		*, 
        RANK() OVER(ORDER BY total_revenue DESC) AS revenue_rank, 
        SUM(total_revenue) OVER( 
			ORDER BY total_revenue DESC 
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
		) AS cumulative_revenue 
	FROM customer_revenue 
)

SELECT 
	CustomerID, 
    revenue_rank, 
    ROUND(total_revenue, 2) AS total_revenue, 
    ROUND(100 * total_revenue / SUM(total_revenue) OVER(), 2) AS revenue_share_pct, 
    cumulative_revenue, 
    ROUND(100 * cumulative_revenue / SUM(total_revenue) OVER(), 2) AS cumulative_revenue_share_pct 
FROM customer_ranked 
ORDER BY revenue_rank ; 
