import csv
import os
import subprocess
import sys

# ==============================================================================
# 1. CẤU HÌNH SQL SERVER VÀ ĐƯỜNG DẪN FILE
# ==============================================================================
SERVER_NAME = r"PRIME\MSSQLSERVER01"
DATABASE_NAME = "Gold_Data_Warehouse"   # đúng tên CSDL trong Create_Gold_Data_Warehouse_Schema.sql
USERNAME = "sa"
PASSWORD = "123456"

# Thư mục chứa toàn bộ file CSV và file SQL
DATA_DIR = r"C:\Users\Admin\OneDrive\Desktop\DAAI_N2.2\Gold_data"

# File SQL tạo schema (script sẽ chạy file này trước: DROP + CREATE toàn bộ bảng, index)
SCHEMA_SQL_FILE = os.path.join(DATA_DIR, "Create_Gold_Data_Warehouse_Schema.sql")

# Đường dẫn các file CSV (BULK INSERT đọc file từ máy chạy SQL Server)
FILES = {name: os.path.join(DATA_DIR, name + ".csv") for name in [
    "Dim_Geography",
    "Dim_Product",
    "Dim_Promotion",
    "Dim_Date",
    "Dim_Customer",
    "Fact_Sales_Order_Items",
    "Fact_Customer_Metrics",
]}

# ==============================================================================
# 2. KHAI BÁO CẤU TRÚC TỪNG BẢNG (THỨ TỰ CỘT = THỨ TỰ CỘT TRONG FILE CSV)
#    (tên_cột, kiểu_SQL)  -  kiểu None = giữ nguyên chuỗi
#    NONE_TO_NULL: cột có giá trị 'NONE' trong CSV sẽ được chuyển thành NULL
# ==============================================================================
DEC = "DECIMAL(18, 2)"

TABLES = [
    # --- Dimension: nạp trước ---
    ("Dim_Geography", [
        ("zip", None), ("city", None), ("region", None), ("district", None),
    ], []),
    ("Dim_Product", [
        ("product_id", "INT"), ("product_name", None), ("category", None),
        ("segment", None), ("size", None), ("color", None),
        ("price", DEC), ("cogs", DEC),
    ], []),
    ("Dim_Promotion", [
        ("promo_id", None), ("promo_name", None), ("promo_type", None),
        ("discount_value", DEC), ("start_date", "DATE"), ("end_date", "DATE"),
        ("applicable_category", None), ("promo_channel", None),
        ("stackable_flag", "INT"), ("min_order_value", DEC),
    ], []),
    ("Dim_Date", [
        ("order_date", None), ("year", "INT"), ("quarter", None), ("month", "INT"),
        ("month_name", None), ("year_month", None), ("day", "INT"),
        ("day_name", None), ("day_of_week", "INT"), ("is_weekend", "INT"),
    ], []),
    ("Dim_Customer", [
        ("customer_id", "INT"), ("zip", None), ("signup_date", "DATE"),
        ("gender", None), ("age_group", None), ("acquisition_channel", None),
    ], []),
    # --- Fact: nạp sau cùng ---
    ("Fact_Sales_Order_Items", [
        ("order_id", "BIGINT"), ("product_id", "INT"), ("customer_id", "INT"),
        ("order_date", None), ("zip", None), ("sales_employee_id", None),
        ("order_source", None), ("order_status", None), ("device_type", None),
        ("promo_id", None), ("promo_id_2", None),
        ("quantity", "INT"), ("unit_price", DEC), ("discount_amount", DEC),
        ("Revenue", DEC),
    ], ["promo_id", "promo_id_2"]),
    ("Fact_Customer_Metrics", [
        ("customer_id", "INT"), ("zip", None), ("signup_date", "DATE"),
        ("gender", None), ("age_group", None), ("acquisition_channel", None),
        ("first_order_date", None), ("last_order_date", None),
        ("primary_order_source", None),
        ("PurchaseFrequency", "INT"), ("CustomerRevenue", DEC),
        ("customer_aov", DEC), ("InterPurchaseDays", "DECIMAL(10, 2)"),
        ("customer_lifespan", "INT"), ("recency_days", "INT"),
        ("Segment", None), ("buyer_type", None), ("clv_segment", None),
        ("churn_risk_level", None),
        ("is_repeat_customer", "TINYINT"), ("is_onetime_buyer", "TINYINT"),
    ], []),
]


# ==============================================================================
# 3. SINH SCRIPT SQL NẠP DỮ LIỆU (STAGING -> BẢNG ĐÍCH)
#    - BULK INSERT vào bảng staging toàn NVARCHAR, tránh lỗi kiểu dữ liệu/ngắt dòng
#    - INSERT ... SELECT có ép kiểu, đổi chuỗi rỗng/'NONE' thành NULL
# ==============================================================================
def build_load_script():
    parts = [f"USE {DATABASE_NAME};\nGO\nSET NOCOUNT ON;\nSET XACT_ABORT ON;\nGO\n"]

    for table, cols, none_cols in TABLES:
        stg = f"stg_{table}"
        stg_cols = ",\n    ".join(f"[{c}] NVARCHAR(500) NULL" for c, _ in cols)

        select_exprs = []
        for c, t in cols:
            # bỏ ký tự CR thừa (nếu file CRLF), cắt khoảng trắng, chuỗi rỗng -> NULL
            expr = f"NULLIF(LTRIM(RTRIM(REPLACE([{c}], CHAR(13), ''))), '')"
            if c in none_cols:
                expr = f"NULLIF({expr}, 'NONE')"
            if t:
                expr = f"CAST({expr} AS {t})"
            select_exprs.append(f"    {expr} AS [{c}]")
        select_sql = ",\n".join(select_exprs)
        insert_cols = ", ".join(f"[{c}]" for c, _ in cols)

        parts.append(f"""
-- -----------------------------------------------------------------------------
-- {table}
-- -----------------------------------------------------------------------------
PRINT N'-> Dang nap {table}...';
IF OBJECT_ID(N'dbo.{stg}', N'U') IS NOT NULL DROP TABLE dbo.{stg};
CREATE TABLE dbo.{stg} (
    {stg_cols}
);

BULK INSERT dbo.{stg}
FROM '{FILES[table]}'
WITH (
    FORMAT = 'CSV',
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '0x0a',
    CODEPAGE = '65001',
    TABLOCK
);

INSERT INTO dbo.{table} ({insert_cols})
SELECT
{select_sql}
FROM dbo.{stg};

DROP TABLE dbo.{stg};
GO
""")
    return "".join(parts)


# ==============================================================================
# 4. CÁC HÀM HỖ TRỢ
# ==============================================================================
def run_sqlcmd(extra_args):
    cmd = ["sqlcmd", "-S", SERVER_NAME, "-U", USERNAME, "-P", PASSWORD,
           "-f", "65001", "-b"] + extra_args
    return subprocess.run(cmd, capture_output=True, text=True,
                          encoding="utf-8", errors="replace")


def count_csv_rows(path):
    with open(path, "r", encoding="utf-8-sig", newline="") as f:
        return sum(1 for _ in csv.reader(f)) - 1  # trừ dòng tiêu đề


def check_files():
    missing = [p for p in [SCHEMA_SQL_FILE, *FILES.values()] if not os.path.exists(p)]
    if missing:
        print("❌ KHÔNG TÌM THẤY CÁC FILE SAU, HÃY SỬA ĐƯỜNG DẪN Ở PHẦN CẤU HÌNH:")
        for p in missing:
            print("   -", p)
        sys.exit(1)


def verify_counts():
    query = "SET NOCOUNT ON; " + " UNION ALL ".join(
        f"SELECT '{t}', COUNT(*) FROM dbo.{t}" for t, _, _ in TABLES)
    result = run_sqlcmd(["-d", DATABASE_NAME, "-h", "-1", "-W", "-s", ",", "-Q", query])
    actual = {}
    for line in result.stdout.splitlines():
        if "," in line:
            name, _, num = line.partition(",")
            if num.strip().isdigit():
                actual[name.strip()] = int(num)

    print(f"{'Bang':<26}{'CSV':>12}{'SQL':>12}   Ket qua")
    all_ok = True
    for table, _, _ in TABLES:
        expected = count_csv_rows(FILES[table])
        got = actual.get(table)
        ok = got == expected
        all_ok &= ok
        print(f"{table:<26}{expected:>12,}{(got if got is not None else -1):>12,}   {'OK' if ok else 'LECH'}")
    return all_ok


# ==============================================================================
# 5. CHẠY
# ==============================================================================
def main():
    print("=" * 70)
    print("BẮT ĐẦU NẠP GOLD DATA WAREHOUSE VÀO SQL SERVER")
    print("=" * 70)
    check_files()

    # Bước 1: tạo CSDL + toàn bộ bảng/khóa/index từ file SQL của bạn
    print(f"-> [1/3] Đang chạy file schema trên [{SERVER_NAME}]...")
    result = run_sqlcmd(["-i", SCHEMA_SQL_FILE])
    if result.returncode != 0:
        print("❌ LỖI KHI TẠO SCHEMA:")
        print(result.stdout or result.stderr)
        sys.exit(1)
    print("   Xong schema.")

    # Bước 2: nạp dữ liệu
    print("-> [2/3] Đang nạp dữ liệu (bảng Fact_Sales_Order_Items hơn 570 nghìn dòng, vui lòng đợi)...")
    temp_sql_file = "temp_load_gold_dw.sql"
    with open(temp_sql_file, "w", encoding="utf-8") as f:
        f.write(build_load_script())
    try:
        result = run_sqlcmd(["-i", temp_sql_file])
    finally:
        if os.path.exists(temp_sql_file):
            os.remove(temp_sql_file)
    print(result.stdout)
    if result.returncode != 0:
        print("❌ CÓ LỖI XẢY RA KHI NẠP:")
        print(result.stderr or result.stdout)
        sys.exit(1)

    # Bước 3: đối chiếu số dòng CSV với SQL Server
    print("-> [3/3] Đối chiếu số dòng:")
    print("-" * 70)
    ok = verify_counts()
    print("-" * 70)
    print("✓ NẠP DỮ LIỆU THÀNH CÔNG, SỐ DÒNG KHỚP!" if ok else "⚠ SỐ DÒNG CHƯA KHỚP, HÃY KIỂM TRA LẠI.")


if __name__ == "__main__":
    main()
