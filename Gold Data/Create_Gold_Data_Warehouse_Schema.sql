-- =====================================================================================
-- DATABASE: Gold_Customer_DW
-- ARCHITECTURE: Star Schema / Fact Constellation (6 Dimensions + 2 Facts)
-- MODEL: Natural Business Keys as Primary Keys for all 6 Dimensions
-- PURPOSE: Customer Behavior, RFM Segmentation, CLV, AOV, Basket Size & Time Trends
-- COMPLIANCE: Problem 1, Problem 2, Problem 3, Problem 4, Problem 5
-- =====================================================================================

USE master;
GO

IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'Gold_Customer_DW')
BEGIN
    CREATE DATABASE Gold_Customer_DW;
END
GO

USE Gold_Customer_DW;
GO

-- =====================================================================================
-- 1. DROP EXISTING TABLES (Xóa bảng Fact trước, Dimension sau)
-- =====================================================================================
IF OBJECT_ID('dbo.Fact_Sales_Order_Items', 'U') IS NOT NULL DROP TABLE dbo.Fact_Sales_Order_Items;
IF OBJECT_ID('dbo.Fact_Customer_Metrics', 'U') IS NOT NULL DROP TABLE dbo.Fact_Customer_Metrics;
IF OBJECT_ID('dbo.Dim_Customer', 'U') IS NOT NULL DROP TABLE dbo.Dim_Customer;
IF OBJECT_ID('dbo.Dim_Product', 'U') IS NOT NULL DROP TABLE dbo.Dim_Product;
IF OBJECT_ID('dbo.Dim_Promotion', 'U') IS NOT NULL DROP TABLE dbo.Dim_Promotion;
IF OBJECT_ID('dbo.Dim_Sales_Employee', 'U') IS NOT NULL DROP TABLE dbo.Dim_Sales_Employee;
IF OBJECT_ID('dbo.Dim_Geography', 'U') IS NOT NULL DROP TABLE dbo.Dim_Geography;
IF OBJECT_ID('dbo.Dim_Date', 'U') IS NOT NULL DROP TABLE dbo.Dim_Date;
GO

-- =====================================================================================
-- 2. CREATE 6 CONFORMED DIMENSION TABLES (DÙNG NATURAL KEY LÀM PK)
-- =====================================================================================

-- 2.1. Dim_Date (Calendar Dimension)
CREATE TABLE dbo.Dim_Date (
    Date_Key INT NOT NULL,                  -- YYYYMMDD (PK)
    Full_Date DATE NOT NULL,                -- YYYY-MM-DD
    Day_Of_Month TINYINT NOT NULL,          -- 1 - 31
    Month_Number TINYINT NOT NULL,          -- 1 - 12
    Month_Name NVARCHAR(20) NOT NULL,       -- January, February...
    Quarter_Number TINYINT NOT NULL,        -- 1 - 4
    Year_Number SMALLINT NOT NULL,          -- 2012, 2013...
    Day_Of_Week TINYINT NOT NULL,           -- 1 (Mon) - 7 (Sun)
    Day_Name NVARCHAR(20) NOT NULL,         -- Monday, Tuesday...
    Is_Weekend BIT NOT NULL,                -- 1: Weekend, 0: Weekday
    CONSTRAINT PK_Dim_Date PRIMARY KEY CLUSTERED (Date_Key)
);
GO

-- 2.2. Dim_Geography (Location Dimension)
CREATE TABLE dbo.Dim_Geography (
    Zip_Code NVARCHAR(50) NOT NULL,         -- Natural PK
    City NVARCHAR(100) NULL,
    District NVARCHAR(100) NULL,
    Region NVARCHAR(100) NULL,
    CONSTRAINT PK_Dim_Geography PRIMARY KEY CLUSTERED (Zip_Code)
);
GO

-- 2.3. Dim_Customer (Customer Dimension)
CREATE TABLE dbo.Dim_Customer (
    Customer_ID INT NOT NULL,               -- Natural PK
    Zip_Code NVARCHAR(50) NULL,
    Signup_Date DATE NULL,
    Gender NVARCHAR(20) NULL,
    Age_Group NVARCHAR(50) NULL,
    Acquisition_Channel NVARCHAR(100) NULL,
    CONSTRAINT PK_Dim_Customer PRIMARY KEY CLUSTERED (Customer_ID),
    CONSTRAINT FK_DimCustomer_DimGeography FOREIGN KEY (Zip_Code) REFERENCES dbo.Dim_Geography(Zip_Code)
);
GO

-- 2.4. Dim_Product (Product Dimension)
CREATE TABLE dbo.Dim_Product (
    Product_ID INT NOT NULL,                -- Natural PK
    Product_Name NVARCHAR(255) NULL,
    Category NVARCHAR(100) NULL,
    Segment NVARCHAR(100) NULL,
    Size NVARCHAR(50) NULL,
    Color NVARCHAR(50) NULL,
    Standard_Price DECIMAL(18, 2) NULL DEFAULT 0.00,
    Standard_Cost DECIMAL(18, 2) NULL DEFAULT 0.00,
    CONSTRAINT PK_Dim_Product PRIMARY KEY CLUSTERED (Product_ID)
);
GO

-- 2.5. Dim_Promotion (Promotion Dimension)
CREATE TABLE dbo.Dim_Promotion (
    Promo_ID NVARCHAR(100) NOT NULL,        -- Natural PK
    Promo_Name NVARCHAR(255) NULL,
    Promo_Type NVARCHAR(100) NULL,
    Discount_Value DECIMAL(18, 2) NULL DEFAULT 0.00,
    Start_Date DATE NULL,
    End_Date DATE NULL,
    Applicable_Category NVARCHAR(100) NULL,
    Promo_Channel NVARCHAR(100) NULL,
    CONSTRAINT PK_Dim_Promotion PRIMARY KEY CLUSTERED (Promo_ID)
);
GO

-- 2.6. Dim_Sales_Employee (Sales Employee Dimension - Natural PK)
CREATE TABLE dbo.Dim_Sales_Employee (
    Sales_Employee_ID NVARCHAR(50) NOT NULL,-- Natural PK (EMP0103, EMP0180...)
    Sales_Employee_Name NVARCHAR(255) NULL, -- Họ tên nhân viên
    Marital_Status NVARCHAR(50) NULL,       -- Tình trạng hôn nhân
    Education_Level NVARCHAR(50) NULL,      -- Trình độ học vấn
    Years_Experience INT NULL,              -- Số năm kinh nghiệm
    CONSTRAINT PK_Dim_Sales_Employee PRIMARY KEY CLUSTERED (Sales_Employee_ID)
);
GO

-- =====================================================================================
-- 3. CREATE 2 FACT TABLES (LIÊN KẾT TRỰC TIẾP QUA NATURAL KEYS)
-- =====================================================================================

-- 3.1. Fact_Sales_Order_Items (Transactional Fact - Phục vụ PS3 & PS5)
CREATE TABLE dbo.Fact_Sales_Order_Items (
    Sales_Item_Key BIGINT IDENTITY(1,1) NOT NULL,
    Order_Date_Key INT NOT NULL,
    Customer_ID INT NOT NULL,
    Product_ID INT NOT NULL,
    Promo_ID NVARCHAR(100) NULL,
    Zip_Code NVARCHAR(50) NULL,
    Sales_Employee_ID NVARCHAR(50) NULL,    -- FK nối Dim_Sales_Employee(Sales_Employee_ID)
    Order_ID INT NOT NULL,
    Order_Source NVARCHAR(50) NULL,
    Order_Status NVARCHAR(50) NULL,
    Device_Type NVARCHAR(50) NULL,
    Quantity INT NOT NULL DEFAULT 1,
    Unit_Price DECIMAL(18,2) NOT NULL,
    Discount_Amount DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    Line_Total DECIMAL(18,2) NOT NULL,
    COGS DECIMAL(18,2) NULL,
    Gross_Profit DECIMAL(18,2) NULL,
    
    CONSTRAINT PK_Fact_Sales_Order_Items PRIMARY KEY CLUSTERED (Sales_Item_Key),
    CONSTRAINT FK_FactSales_DimDate FOREIGN KEY (Order_Date_Key) REFERENCES dbo.Dim_Date(Date_Key),
    CONSTRAINT FK_FactSales_DimCustomer FOREIGN KEY (Customer_ID) REFERENCES dbo.Dim_Customer(Customer_ID),
    CONSTRAINT FK_FactSales_DimProduct FOREIGN KEY (Product_ID) REFERENCES dbo.Dim_Product(Product_ID),
    CONSTRAINT FK_FactSales_DimPromo FOREIGN KEY (Promo_ID) REFERENCES dbo.Dim_Promotion(Promo_ID),
    CONSTRAINT FK_FactSales_DimGeography FOREIGN KEY (Zip_Code) REFERENCES dbo.Dim_Geography(Zip_Code),
    CONSTRAINT FK_FactSales_DimEmployee FOREIGN KEY (Sales_Employee_ID) REFERENCES dbo.Dim_Sales_Employee(Sales_Employee_ID),
    CONSTRAINT CHK_Sales_Quantity CHECK (Quantity > 0)
);
GO

-- 3.2. Fact_Customer_Metrics (Customer Snapshot Fact - Phục vụ PS1, PS2, PS4)
CREATE TABLE dbo.Fact_Customer_Metrics (
    Customer_Metric_Key BIGINT IDENTITY(1,1) NOT NULL,
    Customer_ID INT NOT NULL,
    Snapshot_Date_Key INT NOT NULL,
    Zip_Code NVARCHAR(50) NULL,
    First_Order_Date DATE NULL,
    Last_Order_Date DATE NULL,
    Total_Delivered_Orders INT NOT NULL DEFAULT 0,
    Total_Lifetime_Revenue DECIMAL(18,2) NOT NULL DEFAULT 0.00,
    Total_Lifetime_Items INT NOT NULL DEFAULT 0,
    Lifespan_Days INT NULL,
    Inter_Purchase_Days DECIMAL(10,2) NULL,
    Customer_AOV DECIMAL(18,2) NULL,
    Customer_Basket_Size DECIMAL(10,2) NULL,
    Is_Repeat_Customer BIT NOT NULL DEFAULT 0,
    Customer_Type NVARCHAR(50) NOT NULL,
    CLV_Rank INT NULL,
    Customer_Tier NVARCHAR(50) NULL,
    
    CONSTRAINT PK_Fact_Customer_Metrics PRIMARY KEY CLUSTERED (Customer_Metric_Key),
    CONSTRAINT UQ_Fact_Customer_Metrics_CustSnapshot UNIQUE (Customer_ID, Snapshot_Date_Key),
    CONSTRAINT FK_FactCustomer_DimCustomer FOREIGN KEY (Customer_ID) REFERENCES dbo.Dim_Customer(Customer_ID),
    CONSTRAINT FK_FactCustomer_DimDate FOREIGN KEY (Snapshot_Date_Key) REFERENCES dbo.Dim_Date(Date_Key),
    CONSTRAINT FK_FactCustomer_DimGeography FOREIGN KEY (Zip_Code) REFERENCES dbo.Dim_Geography(Zip_Code),
    CONSTRAINT CHK_Customer_Tier CHECK (Customer_Tier IN (N'VIP Customers', N'High-value Customers', N'Potential Customers', N'Low-value Customers', N'VIP', N'High-value', N'Potential', N'Low-value') OR Customer_Tier IS NULL)
);
GO

-- =====================================================================================
-- 4. PERFORMANCE INDEXES
-- =====================================================================================
CREATE NONCLUSTERED INDEX IX_FactSales_OrderDate ON dbo.Fact_Sales_Order_Items (Order_Date_Key, Order_Status)
INCLUDE (Line_Total, Quantity, COGS, Gross_Profit);

CREATE NONCLUSTERED INDEX IX_FactSales_Customer ON dbo.Fact_Sales_Order_Items (Customer_ID, Order_Date_Key)
INCLUDE (Line_Total, Order_ID);

CREATE NONCLUSTERED INDEX IX_FactSales_Product ON dbo.Fact_Sales_Order_Items (Product_ID, Order_Date_Key)
INCLUDE (Quantity, Line_Total);

CREATE NONCLUSTERED INDEX IX_FactSales_Employee ON dbo.Fact_Sales_Order_Items (Sales_Employee_ID)
INCLUDE (Line_Total, Order_ID);

CREATE NONCLUSTERED INDEX IX_FactCustomer_Tier ON dbo.Fact_Customer_Metrics (Customer_Tier)
INCLUDE (Total_Lifetime_Revenue, CLV_Rank);

CREATE NONCLUSTERED INDEX IX_FactCustomer_Type ON dbo.Fact_Customer_Metrics (Customer_Type)
INCLUDE (Total_Delivered_Orders, Total_Lifetime_Revenue);
GO

PRINT '🎉 SCRIPT T-SQL KHỞI TẠO GOLD DATA WAREHOUSE (6 DIMS + 2 FACTS - NATURAL KEYS) HOÀN TẤT THÀNH CÔNG!';
GO
