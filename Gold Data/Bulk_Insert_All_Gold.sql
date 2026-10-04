-- =====================================================================================
-- SCRIPT T-SQL: BULK INSERT TOÀN BỘ 8 BẢNG GOLD VÀO MS SQL SERVER
-- ƯU ĐIỂM: Chạy trực tiếp trong SSMS (SQL Server Management Studio), siêu nhanh, không cần Python
-- =====================================================================================

USE Gold_Customer_DW;
GO

-- 1. Tắt tạm thời các ràng buộc khóa ngoại để nạp dữ liệu siêu tốc
EXEC sp_MSforeachtable "ALTER TABLE ? NOCHECK CONSTRAINT all";
GO

-- 2. Xóa sạch dữ liệu cũ (nếu có)
DELETE FROM dbo.Fact_Sales_Order_Items;
DELETE FROM dbo.Fact_Customer_Metrics;
DELETE FROM dbo.Dim_Customer;
DELETE FROM dbo.Dim_Product;
DELETE FROM dbo.Dim_Promotion;
DELETE FROM dbo.Dim_Sales_Employee;
DELETE FROM dbo.Dim_Geography;
DELETE FROM dbo.Dim_Date;
GO

PRINT '=================================================================';
PRINT '         BẮT ĐẦU BULK INSERT TOÀN BỘ 8 BẢNG GOLD DATA...         ';
PRINT '=================================================================';

-- =============================================================================
-- 3. NẠP 6 BẢNG DIMENSION (NATURAL KEYS)
-- =============================================================================

-- 3.1. Dim_Date
BULK INSERT dbo.Dim_Date
FROM 'C:\Users\Admin\OneDrive\Desktop\DAAI_N2.2\Gold Data\Gold_Dimensions\Dim_Date.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', CODEPAGE = '65001', TABLOCK);
PRINT '✓ 1. Nạp Dim_Date thành công!';

-- 3.2. Dim_Geography
BULK INSERT dbo.Dim_Geography
FROM 'C:\Users\Admin\OneDrive\Desktop\DAAI_N2.2\Gold Data\Gold_Dimensions\Dim_Geography.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', CODEPAGE = '65001', TABLOCK);
PRINT '✓ 2. Nạp Dim_Geography thành công!';

-- 3.3. Dim_Customer
BULK INSERT dbo.Dim_Customer
FROM 'C:\Users\Admin\OneDrive\Desktop\DAAI_N2.2\Gold Data\Gold_Dimensions\Dim_Customer.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', CODEPAGE = '65001', TABLOCK);
PRINT '✓ 3. Nạp Dim_Customer thành công!';

-- 3.4. Dim_Product
BULK INSERT dbo.Dim_Product
FROM 'C:\Users\Admin\OneDrive\Desktop\DAAI_N2.2\Gold Data\Gold_Dimensions\Dim_Product.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', CODEPAGE = '65001', TABLOCK);
PRINT '✓ 4. Nạp Dim_Product thành công!';

-- 3.5. Dim_Promotion
BULK INSERT dbo.Dim_Promotion
FROM 'C:\Users\Admin\OneDrive\Desktop\DAAI_N2.2\Gold Data\Gold_Dimensions\Dim_Promotion.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', CODEPAGE = '65001', TABLOCK);
PRINT '✓ 5. Nạp Dim_Promotion thành công!';

-- 3.6. Dim_Sales_Employee
BULK INSERT dbo.Dim_Sales_Employee
FROM 'C:\Users\Admin\OneDrive\Desktop\DAAI_N2.2\Gold Data\Gold_Dimensions\Dim_Sales_Employee.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', CODEPAGE = '65001', TABLOCK);
PRINT '✓ 6. Nạp Dim_Sales_Employee thành công!';

-- =============================================================================
-- 4. NẠP 2 BẢNG FACT (BẬT KEEPIDENTITY)
-- =============================================================================

-- 4.1. Fact_Sales_Order_Items
BULK INSERT dbo.Fact_Sales_Order_Items
FROM 'C:\Users\Admin\OneDrive\Desktop\DAAI_N2.2\Gold Data\Gold_Facts\Fact_Sales_Order_Items.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', CODEPAGE = '65001', KEEPIDENTITY, TABLOCK);
PRINT '✓ 7. Nạp Fact_Sales_Order_Items thành công!';

-- 4.2. Fact_Customer_Metrics
BULK INSERT dbo.Fact_Customer_Metrics
FROM 'C:\Users\Admin\OneDrive\Desktop\DAAI_N2.2\Gold Data\Gold_Facts\Fact_Customer_Metrics.csv'
WITH (FORMAT = 'CSV', FIRSTROW = 2, FIELDTERMINATOR = ',', ROWTERMINATOR = '0x0a', CODEPAGE = '65001', KEEPIDENTITY, TABLOCK);
PRINT '✓ 8. Nạp Fact_Customer_Metrics thành công!';
GO

-- =============================================================================
-- 5. BẬT LẠI TOÀN BỘ RÀNG BUỘC KHÓA NGOẠI VÀ KIỂM TRA TÍNH TOÀN VẸN
-- =============================================================================
EXEC sp_MSforeachtable "ALTER TABLE ? WITH CHECK CHECK CONSTRAINT all";
GO

PRINT '=================================================================';
PRINT '🎉 TOÀN BỘ 8 BẢNG GOLD DATA WAREHOUSE ĐÃ ĐƯỢC NẠP THÀNH CÔNG!';
PRINT '=================================================================';

-- 6. KIỂM TRA SỐ LƯỢNG BẢN GHI ĐÃ NẠP
SELECT 'Dim_Date' AS Table_Name, COUNT(*) AS Total_Rows FROM dbo.Dim_Date
UNION ALL
SELECT 'Dim_Geography', COUNT(*) FROM dbo.Dim_Geography
UNION ALL
SELECT 'Dim_Customer', COUNT(*) FROM dbo.Dim_Customer
UNION ALL
SELECT 'Dim_Product', COUNT(*) FROM dbo.Dim_Product
UNION ALL
SELECT 'Dim_Promotion', COUNT(*) FROM dbo.Dim_Promotion
UNION ALL
SELECT 'Dim_Sales_Employee', COUNT(*) FROM dbo.Dim_Sales_Employee
UNION ALL
SELECT 'Fact_Sales_Order_Items', COUNT(*) FROM dbo.Fact_Sales_Order_Items
UNION ALL
SELECT 'Fact_Customer_Metrics', COUNT(*) FROM dbo.Fact_Customer_Metrics;
GO
