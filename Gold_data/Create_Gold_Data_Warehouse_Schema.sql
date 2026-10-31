-- ==============================================================================
-- 🏛️ SCRIPT: CREATE GOLD DATA WAREHOUSE SCHEMA
-- Dự án: Star Schema Data Warehouse (Sales Performance & CRM Analytics)
-- Hệ quản trị CSDL: Microsoft SQL Server (T-SQL)
-- ==============================================================================

-- 1. TẠO CƠ SỞ DỮ LIỆU (NẾU CHƯA CÓ)
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = N'Gold_Data_Warehouse')
BEGIN
    CREATE DATABASE Gold_Data_Warehouse;
    PRINT N'✅ Đã tạo CSDL: Gold_Data_Warehouse';
END
GO

USE Gold_Data_Warehouse;
GO

-- ==============================================================================
-- 2. XÓA BẢNG CŨ THEO THỨ TỰ RÀNG BUỘC KHÓA NGOẠI (NẾU ĐÃ TỒN TẠI)
-- ==============================================================================
IF OBJECT_ID(N'dbo.Fact_Sales_Order_Items', N'U') IS NOT NULL DROP TABLE dbo.Fact_Sales_Order_Items;
IF OBJECT_ID(N'dbo.Fact_Customer_Metrics', N'U') IS NOT NULL DROP TABLE dbo.Fact_Customer_Metrics;
IF OBJECT_ID(N'dbo.Dim_Customer', N'U') IS NOT NULL DROP TABLE dbo.Dim_Customer;
IF OBJECT_ID(N'dbo.Dim_Product', N'U') IS NOT NULL DROP TABLE dbo.Dim_Product;
IF OBJECT_ID(N'dbo.Dim_Geography', N'U') IS NOT NULL DROP TABLE dbo.Dim_Geography;
IF OBJECT_ID(N'dbo.Dim_Promotion', N'U') IS NOT NULL DROP TABLE dbo.Dim_Promotion;
IF OBJECT_ID(N'dbo.Dim_Date', N'U') IS NOT NULL DROP TABLE dbo.Dim_Date;
PRINT N'✅ Đã dọn dẹp các bảng cũ.';
GO

-- ==============================================================================
-- 3. TẠO CÁC BẢNG DIMENSION (BẢNG CHIỀU - KHÓA TỰ NHIÊN GỐC)
-- ==============================================================================

-- 3.1. BẢNG CHIỀU KHU VỰC ĐỊA LÝ: Dim_Geography (PK: zip)
CREATE TABLE dbo.Dim_Geography (
    zip             VARCHAR(20)     NOT NULL,
    city            NVARCHAR(100)   NULL,
    region          VARCHAR(50)     NULL,
    district        NVARCHAR(100)   NULL,
    CONSTRAINT PK_Dim_Geography PRIMARY KEY CLUSTERED (zip)
);
PRINT N'✅ Đã tạo bảng: Dim_Geography';
GO

-- 3.2. BẢNG CHIỀU KHÁCH HÀNG: Dim_Customer (PK: customer_id)
CREATE TABLE dbo.Dim_Customer (
    customer_id         INT             NOT NULL,
    zip                 VARCHAR(20)     NULL,
    signup_date         DATE            NULL,
    gender              VARCHAR(20)     NULL,
    age_group           VARCHAR(20)     NULL,
    acquisition_channel VARCHAR(50)     NULL,
    CONSTRAINT PK_Dim_Customer PRIMARY KEY CLUSTERED (customer_id),
    CONSTRAINT FK_Dim_Customer_Geography FOREIGN KEY (zip) REFERENCES dbo.Dim_Geography (zip)
);
PRINT N'✅ Đã tạo bảng: Dim_Customer';
GO

-- 3.3. BẢNG CHIỀU SẢN PHẨM: Dim_Product (PK: product_id)
CREATE TABLE dbo.Dim_Product (
    product_id      INT             NOT NULL,
    product_name    NVARCHAR(255)   NULL,
    category        VARCHAR(100)    NULL,
    segment         VARCHAR(50)     NULL,
    size            VARCHAR(20)     NULL,
    color           VARCHAR(30)     NULL,
    price           DECIMAL(18, 2)  NULL,
    cogs            DECIMAL(18, 2)  NULL,
    CONSTRAINT PK_Dim_Product PRIMARY KEY CLUSTERED (product_id)
);
PRINT N'✅ Đã tạo bảng: Dim_Product';
GO

-- 3.4. BẢNG CHIỀU KHUYẾN MÃI: Dim_Promotion (PK: promo_id)
CREATE TABLE dbo.Dim_Promotion (
    promo_id            VARCHAR(50)     NOT NULL,
    promo_name          NVARCHAR(150)   NULL,
    promo_type          VARCHAR(50)     NULL,
    discount_value      DECIMAL(18, 2)  NULL,
    start_date          DATE            NULL,
    end_date            DATE            NULL,
    applicable_category VARCHAR(100)    NULL,
    promo_channel       VARCHAR(50)     NULL,
    stackable_flag      INT             NULL,
    min_order_value     DECIMAL(18, 2)  NULL,
    CONSTRAINT PK_Dim_Promotion PRIMARY KEY CLUSTERED (promo_id)
);
PRINT N'✅ Đã tạo bảng: Dim_Promotion';
GO

-- 3.5. BẢNG CHIỀU THỜI GIAN: Dim_Date (PK: order_date dạng chuỗi 'YYYY-MM-DD')
CREATE TABLE dbo.Dim_Date (
    order_date      VARCHAR(10)     NOT NULL,
    [year]          INT             NULL,
    [quarter]       VARCHAR(5)      NULL,
    [month]         INT             NULL,
    month_name      VARCHAR(20)     NULL,
    year_month      VARCHAR(10)     NULL,
    [day]           INT             NULL,
    day_name        VARCHAR(20)     NULL,
    day_of_week     INT             NULL,
    is_weekend      INT             NULL,
    CONSTRAINT PK_Dim_Date PRIMARY KEY CLUSTERED (order_date)
);
PRINT N'✅ Đã tạo bảng: Dim_Date';
GO

-- ==============================================================================
-- 4. TẠO CÁC BẢNG FACT (BẢNG SỰ KIỆN & SỐ ĐO)
-- ==============================================================================

-- 4.1. FACT GIAO DỊCH TỪNG DÒNG MẶT HÀNG: Fact_Sales_Order_Items
CREATE TABLE dbo.Fact_Sales_Order_Items (
    order_id            BIGINT          NOT NULL,
    product_id          INT             NOT NULL,
    customer_id         INT             NOT NULL,
    order_date          VARCHAR(10)     NOT NULL,
    zip                 VARCHAR(20)     NULL,
    sales_employee_id   VARCHAR(50)     NULL,
    order_source        VARCHAR(50)     NULL,
    order_status        VARCHAR(30)     NULL,
    device_type         VARCHAR(30)     NULL,
    promo_id            VARCHAR(50)     NULL,
    promo_id_2          VARCHAR(50)     NULL,
    quantity            INT             NOT NULL DEFAULT 1,
    unit_price          DECIMAL(18, 2)  NOT NULL DEFAULT 0.0,
    discount_amount     DECIMAL(18, 2)  NOT NULL DEFAULT 0.0,
    Revenue             DECIMAL(18, 2)  NOT NULL DEFAULT 0.0,
    CONSTRAINT PK_Fact_Sales_Order_Items PRIMARY KEY CLUSTERED (order_id, product_id),
    CONSTRAINT FK_Fact_Sales_Product FOREIGN KEY (product_id) REFERENCES dbo.Dim_Product (product_id),
    CONSTRAINT FK_Fact_Sales_Customer FOREIGN KEY (customer_id) REFERENCES dbo.Dim_Customer (customer_id),
    CONSTRAINT FK_Fact_Sales_Date FOREIGN KEY (order_date) REFERENCES dbo.Dim_Date (order_date),
    CONSTRAINT FK_Fact_Sales_Geography FOREIGN KEY (zip) REFERENCES dbo.Dim_Geography (zip),
    CONSTRAINT FK_Fact_Sales_Promo FOREIGN KEY (promo_id) REFERENCES dbo.Dim_Promotion (promo_id)
);
PRINT N'✅ Đã tạo bảng: Fact_Sales_Order_Items';
GO

-- 4.2. FACT HỒ SƠ & PHÂN KHÚC KHÁCH HÀNG: Fact_Customer_Metrics
CREATE TABLE dbo.Fact_Customer_Metrics (
    customer_id             INT             NOT NULL,
    zip                     VARCHAR(20)     NULL,
    signup_date             DATE            NULL,
    gender                  VARCHAR(20)     NULL,
    age_group               VARCHAR(20)     NULL,
    acquisition_channel     VARCHAR(50)     NULL,
    first_order_date        VARCHAR(10)     NULL,
    last_order_date         VARCHAR(10)     NULL,
    primary_order_source    VARCHAR(50)     NULL,
    PurchaseFrequency       INT             NOT NULL DEFAULT 0,
    CustomerRevenue         DECIMAL(18, 2)  NOT NULL DEFAULT 0.0,
    customer_aov            DECIMAL(18, 2)  NULL DEFAULT 0.0,
    InterPurchaseDays       DECIMAL(10, 2)  NULL DEFAULT 0.0,
    customer_lifespan       INT             NULL DEFAULT 0,
    recency_days            INT             NULL DEFAULT 0,
    Segment                 VARCHAR(50)     NULL,
    buyer_type              VARCHAR(30)     NULL,
    clv_segment             VARCHAR(30)     NULL,
    churn_risk_level        VARCHAR(20)     NULL,
    is_repeat_customer      TINYINT         NOT NULL DEFAULT 0,
    is_onetime_buyer        TINYINT         NOT NULL DEFAULT 0,
    CONSTRAINT PK_Fact_Customer_Metrics PRIMARY KEY CLUSTERED (customer_id),
    CONSTRAINT FK_Fact_CustMetric_Customer FOREIGN KEY (customer_id) REFERENCES dbo.Dim_Customer (customer_id),
    CONSTRAINT FK_Fact_CustMetric_Geography FOREIGN KEY (zip) REFERENCES dbo.Dim_Geography (zip),
    CONSTRAINT FK_Fact_CustMetric_FirstDate FOREIGN KEY (first_order_date) REFERENCES dbo.Dim_Date (order_date),
    CONSTRAINT FK_Fact_CustMetric_LastDate FOREIGN KEY (last_order_date) REFERENCES dbo.Dim_Date (order_date)
);
PRINT N'✅ Đã tạo bảng: Fact_Customer_Metrics';
GO

-- ==============================================================================
-- 5. TẠO INDEXES TỐI ƯU HÓA HIỆU NĂNG TRUY VẤN & OLAP AGGREGATION
-- ==============================================================================
CREATE NONCLUSTERED INDEX IX_FactSales_Customer ON dbo.Fact_Sales_Order_Items (customer_id);
CREATE NONCLUSTERED INDEX IX_FactSales_OrderDate ON dbo.Fact_Sales_Order_Items (order_date);
CREATE NONCLUSTERED INDEX IX_FactSales_Product ON dbo.Fact_Sales_Order_Items (product_id);
CREATE NONCLUSTERED INDEX IX_FactSales_Status ON dbo.Fact_Sales_Order_Items (order_status) INCLUDE (Revenue, quantity);
CREATE NONCLUSTERED INDEX IX_FactSales_Source ON dbo.Fact_Sales_Order_Items (order_source);

CREATE NONCLUSTERED INDEX IX_FactCust_Segment ON dbo.Fact_Customer_Metrics (Segment) INCLUDE (CustomerRevenue, PurchaseFrequency);
CREATE NONCLUSTERED INDEX IX_FactCust_BuyerType ON dbo.Fact_Customer_Metrics (buyer_type) INCLUDE (PurchaseFrequency);
CREATE NONCLUSTERED INDEX IX_FactCust_CLVSegment ON dbo.Fact_Customer_Metrics (clv_segment) INCLUDE (CustomerRevenue);
PRINT N'✅ Đã tạo đầy đủ các Index tối ưu hóa truy vấn!';
GO

PRINT N'🎉 HOÀN TẤT TẠO TOÀN BỘ CẤU TRÚC SCHEMA GOLD DATA WAREHOUSE!';
