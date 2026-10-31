-- ==============================================================================
-- 🔍 SCRIPT KIỂM TRA ĐẶC TẢ CHI TIẾT: MEASURES, METRICS VÀ KPIS
-- Áp dụng cho: 5 Problem Statements (PS1, PS2, PS3, PS4, PS5)
-- CSDL: Gold_Data_Warehouse (SQL Server / T-SQL)
-- ==============================================================================

USE Gold_Data_Warehouse;
GO

PRINT '==============================================================================';
PRINT '        BẮT ĐẦU KIỂM TRA TOÀN DIỆN 5 BÀI TOÁN (PROBLEM STATEMENTS 1 -> 5)';
PRINT '==============================================================================';
GO

-- ==============================================================================
-- 📋 1. PROBLEM STATEMENT 1: MA TRẬN PHÂN KHÚC KHÁCH HÀNG 2x2 (DOANH THU x TẦN SUẤT)
-- ==============================================================================
PRINT '------------------------------------------------------------------------------';
PRINT '>>> 1. KIỂM TRA PROBLEM STATEMENT 1 (PS1: 2x2 SEGMENTATION)';
PRINT '------------------------------------------------------------------------------';

-- 1.1. Tầng 1: Measures (Số đo gốc)
SELECT 
    'PS1 - Tầng 1: Measures' AS Layer,
    COUNT(DISTINCT customer_id) AS Total_Customers,
    COUNT(DISTINCT order_id) AS Total_Delivered_Orders,
    SUM(quantity) AS Total_Quantity,
    CAST(FORMAT(SUM(Revenue), 'N2') AS VARCHAR(50)) + ' VNĐ' AS Total_Net_Revenue
FROM dbo.Fact_Sales_Order_Items
WHERE order_status = 'delivered';

-- 1.2. Tầng 2 & 3: Bảng KPI Phân Khúc 2x2 (CustomerCount, Share%, SegmentRevenue, RevContribution%, AvgFreq)
WITH Total_Stats AS (
    SELECT 
        COUNT(*) * 1.0 AS Grand_Total_Customers,
        SUM(CustomerRevenue) * 1.0 AS Grand_Total_Revenue
    FROM dbo.Fact_Customer_Metrics
)
SELECT 
    f.Segment AS [Phân Khúc 2x2],
    FORMAT(COUNT(*), 'N0') AS [CustomerCount],
    CAST(FORMAT((COUNT(*) / MAX(t.Grand_Total_Customers)) * 100, 'N2') AS VARCHAR(10)) + '%' AS [CustomerShare_%],
    CAST(FORMAT(SUM(f.CustomerRevenue), 'N2') AS VARCHAR(50)) + ' VNĐ' AS [SegmentRevenue],
    CAST(FORMAT((SUM(f.CustomerRevenue) / MAX(t.Grand_Total_Revenue)) * 100, 'N2') AS VARCHAR(10)) + '%' AS [RevenueContribution_%],
    CAST(FORMAT(AVG(CAST(f.PurchaseFrequency AS FLOAT)), 'N2') AS VARCHAR(10)) AS [AveragePurchaseFrequency]
FROM dbo.Fact_Customer_Metrics f
CROSS JOIN Total_Stats t
GROUP BY f.Segment
ORDER BY SUM(f.CustomerRevenue) DESC;

-- 1.3. Kiểm tra tính toàn vẹn 100% của KPI PS1
WITH Total_Check AS (
    SELECT 
        SUM(CustomerRevenue) * 1.0 AS Sum_Rev,
        COUNT(*) * 1.0 AS Sum_Cust
    FROM dbo.Fact_Customer_Metrics
)
SELECT 
    'Kiểm tra toàn vẹn KPI PS1' AS Audit_Name,
    FORMAT(SUM((CustomerCount / Sum_Cust) * 100), 'N2') + '%' AS [Tổng Tỷ Trọng Khách Hàng (Phải = 100%)],
    FORMAT(SUM((SegmentRevenue / Sum_Rev) * 100), 'N2') + '%' AS [Tổng Tỷ Lệ Doanh Thu (Phải = 100%)]
FROM (
    SELECT Segment, COUNT(*) * 1.0 AS CustomerCount, SUM(CustomerRevenue) * 1.0 AS SegmentRevenue
    FROM dbo.Fact_Customer_Metrics
    GROUP BY Segment
) s
CROSS JOIN Total_Check;
GO


-- ==============================================================================
-- 📋 2. PROBLEM STATEMENT 2: TỶ LỆ REPEAT CUSTOMERS VS ONE-TIME BUYERS
-- ==============================================================================
PRINT '------------------------------------------------------------------------------';
PRINT '>>> 2. KIỂM TRA PROBLEM STATEMENT 2 (PS2: REPEAT VS ONE-TIME BUYERS)';
PRINT '------------------------------------------------------------------------------';

-- 2.1. KPI 1: Cơ cấu phân bổ khách hàng (Customer Distribution by Segment)
WITH Total_Cust AS (
    SELECT COUNT(*) * 1.0 AS Total_C FROM dbo.Fact_Customer_Metrics
)
SELECT 
    buyer_type AS [Customer Segment],
    FORMAT(COUNT(*), 'N0') AS [Customer Count],
    CAST(FORMAT((COUNT(*) / MAX(t.Total_C)) * 100, 'N2') AS VARCHAR(10)) + '%' AS [Customer Percentage (%)]
FROM dbo.Fact_Customer_Metrics
CROSS JOIN Total_Cust t
GROUP BY buyer_type;

-- 2.2. KPI 2: Tỷ trọng doanh thu đóng góp (Revenue Share by Segment)
WITH Total_Rev AS (
    SELECT SUM(CustomerRevenue) * 1.0 AS Total_R FROM dbo.Fact_Customer_Metrics
)
SELECT 
    buyer_type AS [Customer Segment],
    CAST(FORMAT(SUM(CustomerRevenue), 'N2') AS VARCHAR(50)) + ' VNĐ' AS [Total Revenue],
    CAST(FORMAT((SUM(CustomerRevenue) / MAX(t.Total_R)) * 100, 'N2') AS VARCHAR(10)) + '%' AS [Revenue Share (%)]
FROM dbo.Fact_Customer_Metrics
CROSS JOIN Total_Rev t
GROUP BY buyer_type;

-- 2.3. KPI 3: Tần suất mua sắm trung bình theo nhóm (Average Purchase Frequency)
SELECT 
    buyer_type AS [Customer Segment],
    CAST(FORMAT(AVG(CAST(PurchaseFrequency AS FLOAT)), 'N2') AS VARCHAR(10)) AS [Average Purchase Frequency]
FROM dbo.Fact_Customer_Metrics
GROUP BY buyer_type;

-- 2.4. Độ phủ dữ liệu đơn hàng theo trạng thái order_status
SELECT 
    order_status AS [Order Status],
    FORMAT(COUNT(DISTINCT order_id), 'N0') AS [Total Orders],
    CAST(FORMAT((COUNT(DISTINCT order_id) * 100.0) / SUM(COUNT(DISTINCT order_id)) OVER(), 'N2') AS VARCHAR(10)) + '%' AS [Tỷ Trọng (%)]
FROM dbo.Fact_Sales_Order_Items
GROUP BY order_status
ORDER BY COUNT(DISTINCT order_id) DESC;
GO


-- ==============================================================================
-- 📋 3. PROBLEM STATEMENT 3: QUY MÔ GIỎ HÀNG VÀ GIÁ TRỊ ĐƠN HÀNG (AOV & BASKET SIZE)
-- ==============================================================================
PRINT '------------------------------------------------------------------------------';
PRINT '>>> 3. KIỂM TRA PROBLEM STATEMENT 3 (PS3: AOV & BASKET SIZE)';
PRINT '------------------------------------------------------------------------------';

-- 3.1. Bảng KPI Cốt Lõi Cấp Toàn Sàn (AOV, Basket Size Qty, Basket Size SKUs)
SELECT 
    'KPI Cốt lõi PS3' AS Chi_So,
    FORMAT(COUNT(DISTINCT order_id), 'N0') AS [Tổng Đơn Delivered (516,716)],
    CAST(FORMAT(SUM(Revenue), 'N2') AS VARCHAR(50)) + ' VNĐ' AS [Tổng Doanh Thu Thuần (12.52B)],
    CAST(FORMAT(SUM(Revenue) / COUNT(DISTINCT order_id), 'N2') AS VARCHAR(20)) + ' VNĐ' AS [AOV (24,226.41 VNĐ)],
    CAST(FORMAT(SUM(quantity) * 1.0 / COUNT(DISTINCT order_id), 'N2') AS VARCHAR(10)) + ' sp/đơn' AS [Basket Size - Qty (4.97)],
    CAST(FORMAT(COUNT(*) * 1.0 / COUNT(DISTINCT order_id), 'N2') AS VARCHAR(10)) + ' SKU/đơn' AS [Basket Size - SKUs (1.10)]
FROM dbo.Fact_Sales_Order_Items
WHERE order_status = 'delivered';

-- 3.2. Phân rã AOV và Basket Size theo Kênh bán hàng (Order Source)
SELECT 
    order_source AS [Kênh Bán (Order Source)],
    FORMAT(COUNT(DISTINCT order_id), 'N0') AS [Số Đơn Hàng],
    CAST(FORMAT(SUM(Revenue) / COUNT(DISTINCT order_id), 'N2') AS VARCHAR(20)) + ' VNĐ' AS [AOV],
    CAST(FORMAT(SUM(quantity) * 1.0 / COUNT(DISTINCT order_id), 'N2') AS VARCHAR(10)) AS [Basket Size Qty],
    CAST(FORMAT(COUNT(*) * 1.0 / COUNT(DISTINCT order_id), 'N2') AS VARCHAR(10)) AS [Basket Size SKU]
FROM dbo.Fact_Sales_Order_Items
WHERE order_status = 'delivered'
GROUP BY order_source
ORDER BY SUM(Revenue) / COUNT(DISTINCT order_id) DESC;

-- 3.3. Phân rã AOV và Basket Size theo Nhóm tuổi (Age Group)
SELECT 
    c.age_group AS [Nhóm Tuổi (Age Group)],
    FORMAT(COUNT(DISTINCT f.order_id), 'N0') AS [Số Đơn Hàng],
    CAST(FORMAT(SUM(f.Revenue) / COUNT(DISTINCT f.order_id), 'N2') AS VARCHAR(20)) + ' VNĐ' AS [AOV],
    CAST(FORMAT(SUM(f.quantity) * 1.0 / COUNT(DISTINCT f.order_id), 'N2') AS VARCHAR(10)) AS [Basket Size Qty],
    CAST(FORMAT(COUNT(*) * 1.0 / COUNT(DISTINCT f.order_id), 'N2') AS VARCHAR(10)) AS [Basket Size SKU]
FROM dbo.Fact_Sales_Order_Items f
INNER JOIN dbo.Dim_Customer c ON f.customer_id = c.customer_id
WHERE f.order_status = 'delivered'
GROUP BY c.age_group
ORDER BY c.age_group;
GO


-- ==============================================================================
-- 📋 4. PROBLEM STATEMENT 4: GIÁ TRỊ VÒNG ĐỜI KHÁCH HÀNG (CLV) & PARETO 80/20
-- ==============================================================================
PRINT '------------------------------------------------------------------------------';
PRINT '>>> 4. KIỂM TRA PROBLEM STATEMENT 4 (PS4: CLV, CHURN RISK & PARETO)';
PRINT '------------------------------------------------------------------------------';

-- 4.1. Bảng KPI Phân Khúc CLV & Hành Động CRM
WITH Total_Stats AS (
    SELECT 
        COUNT(*) * 1.0 AS Total_Cust,
        SUM(CustomerRevenue) * 1.0 AS Total_Rev
    FROM dbo.Fact_Customer_Metrics
)
SELECT 
    f.clv_segment AS [CLV Segment],
    FORMAT(COUNT(*), 'N0') AS [Customer Count],
    CAST(FORMAT((COUNT(*) / MAX(t.Total_Cust)) * 100, 'N2') AS VARCHAR(10)) + '%' AS [Customer Share (%)],
    CAST(FORMAT(SUM(f.CustomerRevenue), 'N2') AS VARCHAR(50)) + ' VNĐ' AS [Total Revenue],
    CAST(FORMAT((SUM(f.CustomerRevenue) / MAX(t.Total_Rev)) * 100, 'N2') AS VARCHAR(10)) + '%' AS [Revenue Contribution (%)],
    CAST(FORMAT(AVG(f.CustomerRevenue), 'N0') AS VARCHAR(20)) AS [Average CLV],
    CAST(FORMAT(AVG(CAST(f.is_repeat_customer AS FLOAT)) * 100, 'N2') AS VARCHAR(10)) + '%' AS [Repeat Rate],
    CAST(FORMAT(AVG(CAST(f.PurchaseFrequency AS FLOAT)), 'N2') AS VARCHAR(10)) AS [Avg Freq],
    CAST(FORMAT(AVG(f.customer_aov), 'N0') AS VARCHAR(20)) AS [Avg AOV],
    CAST(FORMAT(AVG(CASE WHEN f.PurchaseFrequency > 1 THEN f.InterPurchaseDays END), 'N1') AS VARCHAR(10)) AS [Inter-purchase (Ngày)]
FROM dbo.Fact_Customer_Metrics f
CROSS JOIN Total_Stats t
GROUP BY f.clv_segment
ORDER BY AVG(f.CustomerRevenue) DESC;

-- 4.2. Kiểm chứng quy luật Pareto: Tỷ lệ Top 20% khách hàng đóng góp doanh thu
WITH Ranked_Customers AS (
    SELECT 
        customer_id,
        CustomerRevenue,
        NTILE(5) OVER (ORDER BY CustomerRevenue DESC) AS Quintile
    FROM dbo.Fact_Customer_Metrics
),
Total_Rev AS (
    SELECT SUM(CustomerRevenue) * 1.0 AS Grand_Rev FROM dbo.Fact_Customer_Metrics
)
SELECT 
    CASE WHEN Quintile = 1 THEN 'Top 20% Khách Hàng Giá Trị Nhất' ELSE '80% Khách Hàng Còn Lại' END AS [Nhóm Khách Hàng],
    FORMAT(COUNT(*), 'N0') AS [Số Khách Hàng],
    CAST(FORMAT(SUM(CustomerRevenue), 'N2') AS VARCHAR(50)) + ' VNĐ' AS [Doanh Thu Đóng Góp],
    CAST(FORMAT((SUM(CustomerRevenue) / MAX(t.Grand_Rev)) * 100, 'N2') AS VARCHAR(10)) + '%' AS [Tỷ Trọng Doanh Thu (%)]
FROM Ranked_Customers
CROSS JOIN Total_Rev t
GROUP BY CASE WHEN Quintile = 1 THEN 'Top 20% Khách Hàng Giá Trị Nhất' ELSE '80% Khách Hàng Còn Lại' END
ORDER BY SUM(CustomerRevenue) DESC;

-- 4.3. Bảng Cảnh Báo Nguy Cơ Rời Bỏ Khách Hàng (Churn Risk Level)
SELECT 
    churn_risk_level AS [Mức Độ Rủi Ro (Churn Risk)],
    FORMAT(COUNT(*), 'N0') AS [Số Khách Hàng],
    CAST(FORMAT((COUNT(*) * 100.0) / SUM(COUNT(*)) OVER(), 'N2') AS VARCHAR(10)) + '%' AS [Tỷ Trọng (%)],
    CAST(FORMAT(AVG(CAST(recency_days AS FLOAT)), 'N1') AS VARCHAR(10)) + ' ngày' AS [Recency Trung Bình]
FROM dbo.Fact_Customer_Metrics
GROUP BY churn_risk_level
ORDER BY AVG(recency_days) ASC;
GO


-- ==============================================================================
-- 📋 5. PROBLEM STATEMENT 5: XU HƯỚNG THEO THÁNG & ĐỘ ƯA CHUỘNG NGÀNH HÀNG (AFFINITY INDEX)
-- ==============================================================================
PRINT '------------------------------------------------------------------------------';
PRINT '>>> 5. KIỂM TRA PROBLEM STATEMENT 5 (PS5: TIME TREND & CATEGORY AFFINITY)';
PRINT '------------------------------------------------------------------------------';

-- 5.1. Bảng Doanh thu theo Ngành Hàng (Revenue by Category - Top -> Bottom)
WITH Total_Cat_Rev AS (
    SELECT SUM(Revenue) * 1.0 AS Total_Rev 
    FROM dbo.Fact_Sales_Order_Items f
    INNER JOIN dbo.Dim_Product p ON f.product_id = p.product_id
    WHERE f.order_status = 'delivered'
)
SELECT 
    p.category AS [Ngành Hàng (Category)],
    CAST(FORMAT(SUM(f.Revenue) / 1000000.0, 'N2') AS VARCHAR(30)) + ' M VNĐ' AS [Doanh Thu (Triệu VNĐ)],
    CAST(FORMAT((SUM(f.Revenue) / MAX(t.Total_Rev)) * 100, 'N2') AS VARCHAR(10)) + '%' AS [Tỷ Trọng Doanh Thu (%)]
FROM dbo.Fact_Sales_Order_Items f
INNER JOIN dbo.Dim_Product p ON f.product_id = p.product_id
CROSS JOIN Total_Cat_Rev t
WHERE f.order_status = 'delivered'
GROUP BY p.category
ORDER BY SUM(f.Revenue) DESC;

-- 5.2. Ma trận Category Affinity Index (Độ Ưa Chuộng Ngành Hàng theo Nhóm Khách Hàng)
WITH Segment_Category_Sales AS (
    SELECT 
        c.buyer_type,
        p.category,
        SUM(f.Revenue) AS Cat_Rev
    FROM dbo.Fact_Sales_Order_Items f
    INNER JOIN dbo.Dim_Product p ON f.product_id = p.product_id
    INNER JOIN dbo.Fact_Customer_Metrics c ON f.customer_id = c.customer_id
    WHERE f.order_status = 'delivered'
    GROUP BY c.buyer_type, p.category
),
Segment_Total_Sales AS (
    SELECT buyer_type, SUM(Cat_Rev) AS Seg_Total_Rev
    FROM Segment_Category_Sales
    GROUP BY buyer_type
),
Global_Category_Sales AS (
    SELECT category, SUM(Cat_Rev) AS Glob_Cat_Rev
    FROM Segment_Category_Sales
    GROUP BY category
),
Global_Total AS (
    SELECT SUM(Cat_Rev) AS Total_Market_Rev
    FROM Segment_Category_Sales
)
SELECT 
    sc.buyer_type AS [Nhóm Khách Hàng],
    sc.category AS [Ngành Hàng],
    CAST(FORMAT((sc.Cat_Rev / st.Seg_Total_Rev) * 100, 'N1') AS VARCHAR(10)) + '%' AS [Penetration trong nhóm (%)],
    CAST(FORMAT((gc.Glob_Cat_Rev / gt.Total_Market_Rev) * 100, 'N1') AS VARCHAR(10)) + '%' AS [Penetration toàn sàn (%)],
    CAST(FORMAT(
        ((sc.Cat_Rev / st.Seg_Total_Rev) / (gc.Glob_Cat_Rev / gt.Total_Market_Rev)) * 100,
        'N1'
    ) AS VARCHAR(10)) AS [Affinity Index]
FROM Segment_Category_Sales sc
INNER JOIN Segment_Total_Sales st ON sc.buyer_type = st.buyer_type
INNER JOIN Global_Category_Sales gc ON sc.category = gc.category
CROSS JOIN Global_Total gt
ORDER BY sc.buyer_type, sc.category;

-- 5.3. Xu hướng Doanh Thu & Số Đơn Hàng theo Tháng (Top 12 Tháng Tiêu Biểu)
SELECT TOP 12
    d.year_month AS [Năm-Tháng],
    FORMAT(COUNT(DISTINCT f.order_id), 'N0') AS [Monthly Orders],
    CAST(FORMAT(SUM(f.Revenue) / 1000000.0, 'N2') AS VARCHAR(30)) + ' M VNĐ' AS [Monthly Revenue (Triệu VNĐ)],
    CAST(FORMAT(SUM(f.Revenue) / COUNT(DISTINCT f.order_id), 'N2') AS VARCHAR(20)) + ' VNĐ' AS [Monthly AOV]
FROM dbo.Fact_Sales_Order_Items f
INNER JOIN dbo.Dim_Date d ON f.order_date = d.order_date
WHERE f.order_status = 'delivered'
GROUP BY d.year_month
ORDER BY d.year_month ASC;
GO

PRINT '==============================================================================';
PRINT '🎉 HOÀN TẤT KIỂM TRA ĐỐI SOÁT TOÀN DIỆN TẤT CẢ MEASURES, METRICS & KPIS!';
PRINT '==============================================================================';
