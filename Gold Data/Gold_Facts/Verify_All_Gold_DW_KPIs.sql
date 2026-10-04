-- =====================================================================================
-- SCRIPT T-SQL: TỔNG HỢP TOÀN BỘ CÁC TRUY VẤN TÍNH TOÁN KPI TRÊN GOLD DATA WAREHOUSE
-- DATABASE: Gold_Customer_DW
-- CÁCH CHẠY: Mở file trong SSMS (SQL Server Management Studio) và nhấn Execute (F5)
-- =====================================================================================

USE Gold_Customer_DW;
GO

PRINT '=================================================================================';
PRINT '        BẮT ĐẦU TÍNH TOÁN VÀ KIỂM TRA TOÀN BỘ CÁC KPI TRÊN GOLD DATA WAREHOUSE   ';
PRINT '=================================================================================';
PRINT '';

-- =====================================================================================
-- NHÓM 1: PHÂN KHÚC KHÁCH HÀNG & GIÁ TRỊ VÒNG ĐỜI (PS1, PS2, PS4)
-- =====================================================================================

PRINT '---------------------------------------------------------------------------------';
PRINT '1. KPI 1: Customer Distribution by Segment (Số lượng & Tỷ lệ % khách hàng)';
PRINT '---------------------------------------------------------------------------------';
SELECT 
    Customer_Tier AS Customer_Segment,
    COUNT(Customer_ID) AS Total_Customers,
    CAST(COUNT(Customer_ID) * 100.0 / SUM(COUNT(Customer_ID)) OVER() AS DECIMAL(5,2)) AS [Customer_Distribution_%]
FROM dbo.Fact_Customer_Metrics
GROUP BY Customer_Tier
ORDER BY Total_Customers DESC;
GO

PRINT '---------------------------------------------------------------------------------';
PRINT '2. KPI 2: Tỷ trọng đóng góp Doanh thu theo Segment (Revenue Contribution %)';
PRINT '---------------------------------------------------------------------------------';
SELECT 
    Customer_Tier AS Customer_Segment,
    SUM(Total_Lifetime_Revenue) AS Segment_Revenue,
    CAST(SUM(Total_Lifetime_Revenue) * 100.0 / SUM(SUM(Total_Lifetime_Revenue)) OVER() AS DECIMAL(5,2)) AS [Revenue_Contribution_%]
FROM dbo.Fact_Customer_Metrics
GROUP BY Customer_Tier
ORDER BY Segment_Revenue DESC;
GO

PRINT '---------------------------------------------------------------------------------';
PRINT '3. KPI 3: Average Purchase Frequency by Segment (Tần suất mua trung bình)';
PRINT '---------------------------------------------------------------------------------';
SELECT 
    Customer_Tier AS Customer_Segment,
    CAST(AVG(CAST(Total_Delivered_Orders AS DECIMAL(10,2))) AS DECIMAL(10,2)) AS Avg_Purchase_Frequency
FROM dbo.Fact_Customer_Metrics
GROUP BY Customer_Tier
ORDER BY Avg_Purchase_Frequency DESC;
GO

PRINT '---------------------------------------------------------------------------------';
PRINT '4. KPI 4: Customer Revenue by Segment (Tổng & Doanh thu bình quân theo khách hàng)';
PRINT '---------------------------------------------------------------------------------';
SELECT 
    Customer_Tier AS Customer_Segment,
    SUM(Total_Lifetime_Revenue) AS Total_Customer_Revenue,
    CAST(AVG(Total_Lifetime_Revenue) AS DECIMAL(18,2)) AS Avg_Customer_Revenue
FROM dbo.Fact_Customer_Metrics
GROUP BY Customer_Tier
ORDER BY Total_Customer_Revenue DESC;
GO

PRINT '---------------------------------------------------------------------------------';
PRINT '5. KPI 3 (Tổng hợp hành vi): AverageCLV, Frequency, Repeat Rate, AOV, Basket Size, Inter-Purchase Days';
PRINT '---------------------------------------------------------------------------------';
SELECT 
    Customer_Tier AS Customer_Segment,
    CAST(AVG(Total_Lifetime_Revenue) AS DECIMAL(18,2)) AS AverageCLV,
    CAST(AVG(CAST(Total_Delivered_Orders AS DECIMAL(10,2))) AS DECIMAL(10,2)) AS AverageFrequency,
    CAST(AVG(CAST(Is_Repeat_Customer AS DECIMAL(5,4))) * 100 AS DECIMAL(5,2)) AS [RepeatCustomerRate_%],
    CAST(AVG(Customer_AOV) AS DECIMAL(18,2)) AS AverageAOV,
    CAST(AVG(Customer_Basket_Size) AS DECIMAL(10,2)) AS AverageBasketSize,
    CAST(AVG(Inter_Purchase_Days) AS DECIMAL(10,2)) AS AverageInterPurchaseDays
FROM dbo.Fact_Customer_Metrics
GROUP BY Customer_Tier
ORDER BY AverageCLV DESC;
GO

-- =====================================================================================
-- NHÓM 2: ĐƠN HÀNG, GIỎ HÀNG & PHÂN TÍCH CHI TIẾT (PS3)
-- =====================================================================================

PRINT '---------------------------------------------------------------------------------';
PRINT '6. Average Order Value (AOV - Giá trị đơn hàng trung bình toàn sàn)';
PRINT '---------------------------------------------------------------------------------';
SELECT 
    COUNT(DISTINCT Order_ID) AS Total_Delivered_Orders,
    SUM(Line_Total) AS Total_Delivered_Revenue,
    CAST(SUM(Line_Total) / COUNT(DISTINCT Order_ID) AS DECIMAL(18,2)) AS Average_Order_Value_AOV
FROM dbo.Fact_Sales_Order_Items
WHERE Order_Status = 'delivered';
GO

PRINT '---------------------------------------------------------------------------------';
PRINT '7. Basket Size: Tổng số sản phẩm / đơn';
PRINT '---------------------------------------------------------------------------------';
SELECT 
    SUM(Quantity) AS Total_Units_Sold,
    COUNT(DISTINCT Order_ID) AS Total_Orders,
    CAST(SUM(Quantity) * 1.0 / COUNT(DISTINCT Order_ID) AS DECIMAL(10,2)) AS [Basket_Size_(Total_Units_Per_Order)]
FROM dbo.Fact_Sales_Order_Items
WHERE Order_Status = 'delivered';
GO

PRINT '---------------------------------------------------------------------------------';
PRINT '8. Basket Size: Số mặt hàng khác nhau / đơn (Distinct SKUs)';
PRINT '---------------------------------------------------------------------------------';
SELECT 
    COUNT(Product_ID) AS Total_Order_Item_Lines,
    COUNT(DISTINCT Order_ID) AS Total_Orders,
    CAST(COUNT(Product_ID) * 1.0 / COUNT(DISTINCT Order_ID) AS DECIMAL(10,2)) AS [Basket_Size_(Distinct_Products_Per_Order)]
FROM dbo.Fact_Sales_Order_Items
WHERE Order_Status = 'delivered';
GO

PRINT '---------------------------------------------------------------------------------';
PRINT '9. Giá trị đơn hàng trung bình (AOV) theo Kênh bán hàng (Order_Source)';
PRINT '---------------------------------------------------------------------------------';
SELECT 
    ISNULL(Order_Source, N'Unknown') AS Order_Source,
    COUNT(DISTINCT Order_ID) AS Total_Orders,
    SUM(Line_Total) AS Total_Revenue,
    CAST(SUM(Line_Total) / COUNT(DISTINCT Order_ID) AS DECIMAL(18,2)) AS AOV_By_Channel
FROM dbo.Fact_Sales_Order_Items
WHERE Order_Status = 'delivered'
GROUP BY Order_Source
ORDER BY Total_Revenue DESC;
GO

PRINT '---------------------------------------------------------------------------------';
PRINT '10. Số lượng sản phẩm bình quân / Đơn (Basket Size) theo Nhóm tuổi (Age_Group)';
PRINT '---------------------------------------------------------------------------------';
SELECT 
    ISNULL(c.Age_Group, N'Unknown') AS Age_Group,
    COUNT(DISTINCT f.Order_ID) AS Total_Orders,
    SUM(f.Quantity) AS Total_Quantity,
    CAST(SUM(f.Quantity) * 1.0 / COUNT(DISTINCT f.Order_ID) AS DECIMAL(10,2)) AS Basket_Size_By_Age_Group
FROM dbo.Fact_Sales_Order_Items f
JOIN dbo.Dim_Customer c ON f.Customer_ID = c.Customer_ID
WHERE f.Order_Status = 'delivered'
GROUP BY c.Age_Group
ORDER BY Basket_Size_By_Age_Group DESC;
GO

-- =====================================================================================
-- NHÓM 3: XU HƯỚNG THỜI GIAN & TĂNG TRƯỞNG (PS3)
-- =====================================================================================

PRINT '---------------------------------------------------------------------------------';
PRINT '11. Monthly AOV & Doanh thu theo từng tháng';
PRINT '---------------------------------------------------------------------------------';
SELECT 
    d.Year_Number,
    d.Month_Number,
    d.Month_Name,
    SUM(f.Line_Total) AS Monthly_Revenue,
    COUNT(DISTINCT f.Order_ID) AS Monthly_Orders,
    CAST(SUM(f.Line_Total) / COUNT(DISTINCT f.Order_ID) AS DECIMAL(18,2)) AS Monthly_AOV
FROM dbo.Fact_Sales_Order_Items f
JOIN dbo.Dim_Date d ON f.Order_Date_Key = d.Date_Key
WHERE f.Order_Status = 'delivered'
GROUP BY d.Year_Number, d.Month_Number, d.Month_Name
ORDER BY d.Year_Number, d.Month_Number;
GO

PRINT '---------------------------------------------------------------------------------';
PRINT '12. # 20 — Monthly Growth (% Tăng trưởng Doanh thu & Đơn hàng MoM)';
PRINT '---------------------------------------------------------------------------------';
WITH Monthly_Metrics AS (
    SELECT 
        d.Year_Number,
        d.Month_Number,
        d.Month_Name,
        SUM(f.Line_Total) AS Monthly_Revenue,
        COUNT(DISTINCT f.Order_ID) AS Monthly_Orders
    FROM dbo.Fact_Sales_Order_Items f
    JOIN dbo.Dim_Date d ON f.Order_Date_Key = d.Date_Key
    WHERE f.Order_Status = 'delivered'
    GROUP BY d.Year_Number, d.Month_Number, d.Month_Name
)
SELECT 
    Year_Number,
    Month_Number,
    Month_Name,
    Monthly_Revenue,
    CAST((Monthly_Revenue - LAG(Monthly_Revenue) OVER (ORDER BY Year_Number, Month_Number)) * 100.0 /
         NULLIF(LAG(Monthly_Revenue) OVER (ORDER BY Year_Number, Month_Number), 0) AS DECIMAL(10,2)) AS [Revenue_Growth_MoM_%],
    Monthly_Orders,
    CAST((Monthly_Orders - LAG(Monthly_Orders) OVER (ORDER BY Year_Number, Month_Number)) * 100.0 /
         NULLIF(LAG(Monthly_Orders) OVER (ORDER BY Year_Number, Month_Number), 0) AS DECIMAL(10,2)) AS [Orders_Growth_MoM_%]
FROM Monthly_Metrics
ORDER BY Year_Number, Month_Number;
GO

PRINT '---------------------------------------------------------------------------------';
PRINT '13. KPI Tăng trưởng Trung bình Hàng tháng (Average MoM Growth Rate)';
PRINT '---------------------------------------------------------------------------------';
WITH Monthly_Sales AS (
    SELECT 
        d.Year_Number,
        d.Month_Number,
        SUM(f.Line_Total) AS Monthly_Revenue
    FROM dbo.Fact_Sales_Order_Items f
    JOIN dbo.Dim_Date d ON f.Order_Date_Key = d.Date_Key
    WHERE f.Order_Status = 'delivered'
    GROUP BY d.Year_Number, d.Month_Number
),
MoM_Calc AS (
    SELECT 
        CAST((Monthly_Revenue - LAG(Monthly_Revenue) OVER (ORDER BY Year_Number, Month_Number)) * 100.0 /
             NULLIF(LAG(Monthly_Revenue) OVER (ORDER BY Year_Number, Month_Number), 0) AS DECIMAL(10,2)) AS MoM_Growth_Rate_Pct
    FROM Monthly_Sales
)
SELECT 
    CAST(AVG(MoM_Growth_Rate_Pct) AS DECIMAL(10,2)) AS [Avg_Monthly_Growth_Rate_%]
FROM MoM_Calc
WHERE MoM_Growth_Rate_Pct IS NOT NULL;
GO

PRINT '---------------------------------------------------------------------------------';
PRINT '14. Peak Revenue & Peak Revenue Month (Tháng đạt doanh thu đỉnh điểm)';
PRINT '---------------------------------------------------------------------------------';
SELECT TOP 1
    d.Year_Number,
    d.Month_Number,
    d.Month_Name,
    CONCAT(d.Month_Name, ' ', d.Year_Number) AS Peak_Revenue_Month,
    SUM(f.Line_Total) AS Peak_Revenue,
    COUNT(DISTINCT f.Order_ID) AS Peak_Orders,
    CAST(SUM(f.Line_Total) / COUNT(DISTINCT f.Order_ID) AS DECIMAL(18,2)) AS Peak_Month_AOV
FROM dbo.Fact_Sales_Order_Items f
JOIN dbo.Dim_Date d ON f.Order_Date_Key = d.Date_Key
WHERE f.Order_Status = 'delivered'
GROUP BY d.Year_Number, d.Month_Number, d.Month_Name
ORDER BY Peak_Revenue DESC;
GO

-- =====================================================================================
-- NHÓM 4: PHÂN TÍCH CATEGORY, AFFINITY INDEX & GỢI Ý ĐỀ XUẤT (PS5)
-- =====================================================================================

PRINT '---------------------------------------------------------------------------------';
PRINT '15. # 25 — Category Revenue Share (Baseline Share % Toàn hệ thống)';
PRINT '---------------------------------------------------------------------------------';
SELECT 
    ISNULL(p.Category, N'Unknown') AS Category,
    COUNT(DISTINCT f.Order_ID) AS Total_Orders,
    SUM(f.Quantity) AS Total_Quantity,
    SUM(f.Line_Total) AS Total_Revenue,
    CAST(SUM(f.Line_Total) * 100.0 / SUM(SUM(f.Line_Total)) OVER () AS DECIMAL(10,2)) AS [Baseline_Share_%]
FROM dbo.Fact_Sales_Order_Items f
JOIN dbo.Dim_Product p ON f.Product_ID = p.Product_ID
WHERE f.Order_Status = 'delivered'
GROUP BY p.Category
ORDER BY Total_Revenue DESC;
GO

PRINT '---------------------------------------------------------------------------------';
PRINT '16. Customer Type Revenue Share (Repeat Customer vs One-time Buyer)';
PRINT '---------------------------------------------------------------------------------';
SELECT 
    Customer_Type,
    COUNT(Customer_ID) AS Customer_Count,
    SUM(Total_Delivered_Orders) AS Order_Count,
    SUM(Total_Lifetime_Revenue) AS Total_Revenue,
    CAST(SUM(Total_Lifetime_Revenue) / NULLIF(SUM(Total_Delivered_Orders), 0) AS DECIMAL(18,2)) AS AOV,
    CAST(SUM(CAST(Total_Lifetime_Items AS DECIMAL(12,2))) / NULLIF(SUM(Total_Delivered_Orders), 0) AS DECIMAL(10,2)) AS Basket_Size,
    CAST(SUM(Total_Lifetime_Revenue) * 100.0 / SUM(SUM(Total_Lifetime_Revenue)) OVER() AS DECIMAL(10,2)) AS [Revenue_Share_%]
FROM dbo.Fact_Customer_Metrics
GROUP BY Customer_Type
ORDER BY Total_Revenue DESC;
GO

PRINT '---------------------------------------------------------------------------------';
PRINT '17. Category Revenue Share trong từng Customer Type';
PRINT '---------------------------------------------------------------------------------';
WITH Sales_Customer_Type AS (
    SELECT 
        m.Customer_Type,
        ISNULL(p.Category, N'Unknown') AS Category,
        COUNT(DISTINCT f.Order_ID) AS Orders,
        SUM(f.Quantity) AS Quantity,
        SUM(f.Line_Total) AS Revenue
    FROM dbo.Fact_Sales_Order_Items f
    JOIN dbo.Fact_Customer_Metrics m ON f.Customer_ID = m.Customer_ID
    JOIN dbo.Dim_Product p ON f.Product_ID = p.Product_ID
    WHERE f.Order_Status = 'delivered'
    GROUP BY m.Customer_Type, p.Category
)
SELECT 
    Customer_Type,
    Category,
    Orders,
    Quantity,
    Revenue,
    CAST(Revenue * 100.0 / SUM(Revenue) OVER(PARTITION BY Customer_Type) AS DECIMAL(10,2)) AS [Category_Revenue_Share_%]
FROM Sales_Customer_Type
ORDER BY Customer_Type, Revenue DESC;
GO

PRINT '---------------------------------------------------------------------------------';
PRINT '18. AFFINITY INDEX & Category ưu tiên của từng Customer Type';
PRINT '---------------------------------------------------------------------------------';
WITH Total_Category AS (
    SELECT 
        ISNULL(p.Category, N'Unknown') AS Category,
        CAST(SUM(f.Line_Total) * 100.0 / SUM(SUM(f.Line_Total)) OVER () AS DECIMAL(10,4)) AS Baseline_Share_Pct
    FROM dbo.Fact_Sales_Order_Items f
    JOIN dbo.Dim_Product p ON f.Product_ID = p.Product_ID
    WHERE f.Order_Status = 'delivered'
    GROUP BY p.Category
),
CustomerType_Category AS (
    SELECT 
        m.Customer_Type,
        ISNULL(p.Category, N'Unknown') AS Category,
        COUNT(DISTINCT f.Order_ID) AS Orders,
        SUM(f.Quantity) AS Quantity,
        SUM(f.Line_Total) AS Revenue,
        CAST(SUM(f.Line_Total) * 100.0 / SUM(SUM(f.Line_Total)) OVER (PARTITION BY m.Customer_Type) AS DECIMAL(10,4)) AS Category_Revenue_Share_Pct
    FROM dbo.Fact_Sales_Order_Items f
    JOIN dbo.Fact_Customer_Metrics m ON f.Customer_ID = m.Customer_ID
    JOIN dbo.Dim_Product p ON f.Product_ID = p.Product_ID
    WHERE f.Order_Status = 'delivered'
    GROUP BY m.Customer_Type, p.Category
),
Affinity_Calc AS (
    SELECT 
        c.Customer_Type,
        c.Category,
        c.Orders,
        c.Quantity,
        c.Revenue,
        CAST(c.Category_Revenue_Share_Pct AS DECIMAL(10,2)) AS [Category_Revenue_Share_%],
        CAST(t.Baseline_Share_Pct AS DECIMAL(10,2)) AS [Baseline_Share_%],
        CAST((c.Category_Revenue_Share_Pct / NULLIF(t.Baseline_Share_Pct, 0)) * 100 AS DECIMAL(10,2)) AS Affinity_Index
    FROM CustomerType_Category c
    JOIN Total_Category t ON c.Category = t.Category
)
SELECT 
    Customer_Type,
    Category,
    Orders,
    Quantity,
    Revenue,
    [Category_Revenue_Share_%],
    [Baseline_Share_%],
    Affinity_Index
FROM Affinity_Calc
WHERE [Category_Revenue_Share_%] >= 2.0
ORDER BY Customer_Type, Affinity_Index DESC;
GO

PRINT '---------------------------------------------------------------------------------';
PRINT '19. BƯỚC 33 — Promotion & Product Recommendation (Đề xuất Khuyến mãi & Sản phẩm)';
PRINT '---------------------------------------------------------------------------------';
WITH Baseline_Cat AS (
    SELECT 
        ISNULL(p.Category, N'Unknown') AS Category,
        CAST(SUM(f.Line_Total) * 100.0 / SUM(SUM(f.Line_Total)) OVER () AS DECIMAL(10,4)) AS Baseline_Share_Pct
    FROM dbo.Fact_Sales_Order_Items f
    JOIN dbo.Dim_Product p ON f.Product_ID = p.Product_ID
    WHERE f.Order_Status = 'delivered'
    GROUP BY p.Category
),
CustType_Summary AS (
    SELECT 
        Customer_Type,
        COUNT(Customer_ID) AS Customer_Count,
        SUM(Total_Delivered_Orders) AS Order_Count,
        SUM(Total_Lifetime_Revenue) AS Revenue_CustomerType,
        CAST(SUM(Total_Lifetime_Revenue) / NULLIF(SUM(Total_Delivered_Orders), 0) AS DECIMAL(18,2)) AS AOV,
        CAST(SUM(CAST(Total_Lifetime_Items AS DECIMAL(12,2))) / NULLIF(SUM(Total_Delivered_Orders), 0) AS DECIMAL(10,2)) AS Basket_Size,
        CAST(SUM(Total_Lifetime_Revenue) * 100.0 / SUM(SUM(Total_Lifetime_Revenue)) OVER() AS DECIMAL(10,2)) AS Revenue_Share_Pct
    FROM dbo.Fact_Customer_Metrics
    GROUP BY Customer_Type
),
CustType_Cat AS (
    SELECT 
        m.Customer_Type,
        ISNULL(p.Category, N'Unknown') AS Category,
        COUNT(DISTINCT f.Order_ID) AS Orders,
        SUM(f.Quantity) AS Quantity,
        SUM(f.Line_Total) AS Revenue_Category,
        CAST(SUM(f.Line_Total) * 100.0 / SUM(SUM(f.Line_Total)) OVER (PARTITION BY m.Customer_Type) AS DECIMAL(10,4)) AS Cat_Share_Pct
    FROM dbo.Fact_Sales_Order_Items f
    JOIN dbo.Fact_Customer_Metrics m ON f.Customer_ID = m.Customer_ID
    JOIN dbo.Dim_Product p ON f.Product_ID = p.Product_ID
    WHERE f.Order_Status = 'delivered'
    GROUP BY m.Customer_Type, p.Category
),
Affinity_Ranked AS (
    SELECT 
        c.Customer_Type,
        c.Category,
        c.Orders,
        c.Quantity,
        c.Revenue_Category,
        CAST(c.Cat_Share_Pct AS DECIMAL(10,2)) AS [Category_Revenue_Share_%],
        CAST(b.Baseline_Share_Pct AS DECIMAL(10,2)) AS [Baseline_Share_%],
        CAST((c.Cat_Share_Pct / NULLIF(b.Baseline_Share_Pct, 0)) * 100 AS DECIMAL(10,2)) AS Affinity_Index,
        ROW_NUMBER() OVER (PARTITION BY c.Customer_Type ORDER BY (c.Cat_Share_Pct / NULLIF(b.Baseline_Share_Pct, 0)) DESC) AS Rank_Affinity
    FROM CustType_Cat c
    JOIN Baseline_Cat b ON c.Category = b.Category
    WHERE c.Cat_Share_Pct >= 2.0
)
SELECT 
    a.Customer_Type,
    a.Category,
    a.Orders,
    a.Quantity,
    a.Revenue_Category,
    a.[Category_Revenue_Share_%],
    a.[Baseline_Share_%],
    a.Affinity_Index,
    s.Customer_Count,
    s.Order_Count,
    s.Revenue_CustomerType,
    s.AOV,
    s.Basket_Size,
    s.Revenue_Share_Pct,
    CASE 
        WHEN a.Customer_Type = 'One-time Buyer' THEN CONCAT(N'Khuyến mãi kích thích mua lại đối với nhóm sản phẩm ', a.Category, N' (Voucher giảm giá 10% cho đơn tiếp theo)')
        ELSE CONCAT(N'Ưu đãi tri ân đối với nhóm sản phẩm ', a.Category, N' (Tích điểm VIP / Quà tặng kèm)')
    END AS Promotion_Recommendation,
    CASE 
        WHEN a.Customer_Type = 'One-time Buyer' THEN CONCAT(N'Gợi ý sản phẩm thuộc danh mục ', a.Category, N' để khuyến khích quay lại')
        ELSE CONCAT(N'Gợi ý sản phẩm thuộc danh mục ', a.Category, N' và các sản phẩm bán chạy/bổ trợ liên quan')
    END AS Product_Recommendation
FROM Affinity_Ranked a
JOIN CustType_Summary s ON a.Customer_Type = s.Customer_Type
WHERE a.Rank_Affinity <= 2
ORDER BY a.Customer_Type, a.Affinity_Index DESC;
GO

PRINT '=================================================================================';
PRINT '🎉 TOÀN BỘ 19 TRUY VẤN TÍNH TOÁN KPI ĐÃ ĐƯỢC THỰC THI THÀNH CÔNG!';
PRINT '=================================================================================';
GO
