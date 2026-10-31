-- ==============================================================================
-- 🚀 SCRIPT: BULK INSERT TOÀN BỘ CÁC BẢNG GOLD VÀO SQL SERVER
-- Dự án: Star Schema Data Warehouse
-- Hệ quản trị CSDL: Microsoft SQL Server (T-SQL)
-- ==============================================================================

USE Gold_Data_Warehouse;
GO

PRINT '===============================================================';
PRINT '         BẮT ĐẦU QUÁ TRÌNH NẠP DỮ LIỆU TẦNG GOLD';
PRINT '===============================================================';
GO

-- ==============================================================================
-- 1. NẠP DỮ LIỆU CÁC BẢNG DIMENSION (THEO THỨ TỰ RÀNG BUỘC KHÓA)
-- ==============================================================================

-- 1.1. Dim_Geography
BULK INSERT dbo.Dim_Geography
FROM 'C:\Users\Admin\Downloads\StarSchema\Dim_Geography.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);
PRINT '✓ 1. Nạp Dim_Geography thành công!';
GO

-- 1.2. Dim_Customer
BULK INSERT dbo.Dim_Customer
FROM 'C:\Users\Admin\Downloads\StarSchema\Dim_Customer.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);
PRINT '✓ 2. Nạp Dim_Customer thành công!';
GO

-- 1.3. Dim_Product
BULK INSERT dbo.Dim_Product
FROM 'C:\Users\Admin\Downloads\StarSchema\Dim_Product.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);
PRINT '✓ 3. Nạp Dim_Product thành công!';
GO

-- 1.4. Dim_Promotion
BULK INSERT dbo.Dim_Promotion
FROM 'C:\Users\Admin\Downloads\StarSchema\Dim_Promotion.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);
PRINT '✓ 4. Nạp Dim_Promotion thành công!';
GO

-- 1.5. Dim_Date
BULK INSERT dbo.Dim_Date
FROM 'C:\Users\Admin\Downloads\StarSchema\Dim_Date.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);
PRINT '✓ 5. Nạp Dim_Date thành công!';
GO

-- ==============================================================================
-- 2. NẠP DỮ LIỆU CÁC BẢNG FACT
-- ==============================================================================

-- 2.1. Fact_Sales_Order_Items
BULK INSERT dbo.Fact_Sales_Order_Items
FROM 'C:\Users\Admin\Downloads\StarSchema\Fact_Sales_Order_Items.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);
PRINT '✓ 6. Nạp Fact_Sales_Order_Items thành công!';
GO

-- 2.2. Fact_Customer_Metrics
BULK INSERT dbo.Fact_Customer_Metrics
FROM 'C:\Users\Admin\Downloads\StarSchema\Fact_Customer_Metrics.csv'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);
PRINT '✓ 7. Nạp Fact_Customer_Metrics thành công!';
GO

PRINT '---------------------------------------------------------------';
PRINT '🎉 HOÀN TẤT NẠP TOÀN BỘ 7 BẢNG GOLD VÀO SQL SERVER!';
PRINT '---------------------------------------------------------------';
GO

-- ==============================================================================
-- 3. BÁO CÁO KIỂM TRA SỐ LƯỢNG DÒNG (RECORD COUNT AUDIT)
-- ==============================================================================
SELECT 'Dim_Geography' AS Table_Name, COUNT(*) AS Total_Rows FROM dbo.Dim_Geography
UNION ALL
SELECT 'Dim_Customer', COUNT(*) FROM dbo.Dim_Customer
UNION ALL
SELECT 'Dim_Product', COUNT(*) FROM dbo.Dim_Product
UNION ALL
SELECT 'Dim_Promotion', COUNT(*) FROM dbo.Dim_Promotion
UNION ALL
SELECT 'Dim_Date', COUNT(*) FROM dbo.Dim_Date
UNION ALL
SELECT 'Fact_Sales_Order_Items', COUNT(*) FROM dbo.Fact_Sales_Order_Items
UNION ALL
SELECT 'Fact_Customer_Metrics', COUNT(*) FROM dbo.Fact_Customer_Metrics;
GO

-- ==============================================================================
-- 4. BÁO CÁO ĐỐI SOÁT CHỈ SỐ VỚI 5 DASHBOARDS PROTOTYPE
-- ==============================================================================
SELECT 
    '1. Tổng Khách Hàng (Delivered)' AS Chi_So,
    CAST(FORMAT(COUNT(*), 'N0') AS VARCHAR(50)) AS Gia_Tri_Thuc_Te,
    '85,115' AS Chuan_Prototype
FROM dbo.Fact_Customer_Metrics
UNION ALL
SELECT 
    '2. Tổng Doanh Thu Thuần',
    CAST(FORMAT(SUM(CustomerRevenue), 'N2') AS VARCHAR(50)) + ' VNĐ',
    '12,518,175,747.20 VNĐ (12.52B)'
FROM dbo.Fact_Customer_Metrics
UNION ALL
SELECT 
    '3. Số Lượng Repeat Customers',
    CAST(FORMAT(SUM(CAST(is_repeat_customer AS INT)), 'N0') AS VARCHAR(50)) + ' KH (' + 
    CAST(FORMAT((SUM(CAST(is_repeat_customer AS FLOAT)) / COUNT(*)) * 100, 'N2') AS VARCHAR(10)) + '%)',
    '62,272 KH (73.16%)'
FROM dbo.Fact_Customer_Metrics
UNION ALL
SELECT 
    '4. Số Lượng One-time Buyers',
    CAST(FORMAT(SUM(CAST(is_onetime_buyer AS INT)), 'N0') AS VARCHAR(50)) + ' KH (' + 
    CAST(FORMAT((SUM(CAST(is_onetime_buyer AS FLOAT)) / COUNT(*)) * 100, 'N2') AS VARCHAR(10)) + '%)',
    '22,843 KH (26.84%)'
FROM dbo.Fact_Customer_Metrics
UNION ALL
SELECT 
    '5. Tần Suất Mua TB (Repeat Customer)',
    CAST(FORMAT(AVG(CASE WHEN buyer_type = 'Repeat Customer' THEN CAST(PurchaseFrequency AS FLOAT) END), 'N2') AS VARCHAR(50)) + ' đơn/KH',
    '7.93 đơn/KH'
FROM dbo.Fact_Customer_Metrics
UNION ALL
SELECT 
    '6. Tổng Đơn Hàng Thành Công',
    CAST(FORMAT(COUNT(DISTINCT order_id), 'N0') AS VARCHAR(50)) + ' đơn',
    '516,716 đơn'
FROM dbo.Fact_Sales_Order_Items
WHERE order_status = 'delivered'
UNION ALL
SELECT 
    '7. AOV (Giá Trị Đơn Trung Bình)',
    CAST(FORMAT(SUM(Revenue) / COUNT(DISTINCT order_id), 'N2') AS VARCHAR(50)) + ' VNĐ',
    '24,226.41 VNĐ'
FROM dbo.Fact_Sales_Order_Items
WHERE order_status = 'delivered';
GO
