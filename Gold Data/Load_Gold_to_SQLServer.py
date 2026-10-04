"""
=====================================================================================
ETL SCRIPT: NẠP DỮ LIỆU GOLD LAYER VÀO MICROSOFT SQL SERVER
Database: Gold_Customer_DW
Kiến trúc: Star Schema (6 Dimension tables + 2 Fact tables)
Hỗ trợ:
  - Phương thức 1 (Mặc định - Khuyên dùng): T-SQL BULK INSERT (Cực nhanh: ~2-5s)
  - Phương thức 2: Pandas + pyodbc / sqlalchemy fast_executemany (Linh hoạt)
  - Tự động phát hiện ODBC Driver phù hợp trên máy Windows
  - Tùy chọn tự động khởi tạo Schema từ file Create_Gold_Data_Warehouse_Schema.sql
  - Đối soát (Verification) số lượng bản ghi giữa CSV và SQL Server
=====================================================================================
"""

import os
import sys
import time
import argparse
# pyrefly: ignore [missing-import]
import pyodbc
import pandas as pd
from pathlib import Path

# Cấu hình đường dẫn thư mục gốc dự án
BASE_DIR = Path(__file__).resolve().parent
GOLD_DIR = BASE_DIR / "Gold Data"
DIM_DIR = GOLD_DIR / "Gold_Dimensions"
FACT_DIR = GOLD_DIR / "Gold_Facts"
SCHEMA_SQL_FILE = BASE_DIR / "Create_Gold_Data_Warehouse_Schema.sql"

# Danh sách bảng và file CSV tương ứng (theo đúng thứ tự nạp: Dims -> Facts)
TABLES_METADATA = [
    {
        "table_name": "dbo.Dim_Date",
        "csv_path": DIM_DIR / "Dim_Date.csv",
        "is_fact": False,
        "identity_col": None
    },
    {
        "table_name": "dbo.Dim_Geography",
        "csv_path": DIM_DIR / "Dim_Geography.csv",
        "is_fact": False,
        "identity_col": None
    },
    {
        "table_name": "dbo.Dim_Customer",
        "csv_path": DIM_DIR / "Dim_Customer.csv",
        "is_fact": False,
        "identity_col": None
    },
    {
        "table_name": "dbo.Dim_Product",
        "csv_path": DIM_DIR / "Dim_Product.csv",
        "is_fact": False,
        "identity_col": None
    },
    {
        "table_name": "dbo.Dim_Promotion",
        "csv_path": DIM_DIR / "Dim_Promotion.csv",
        "is_fact": False,
        "identity_col": None
    },
    {
        "table_name": "dbo.Dim_Sales_Employee",
        "csv_path": DIM_DIR / "Dim_Sales_Employee.csv",
        "is_fact": False,
        "identity_col": None
    },
    {
        "table_name": "dbo.Fact_Sales_Order_Items",
        "csv_path": FACT_DIR / "Fact_Sales_Order_Items.csv",
        "is_fact": True,
        "identity_col": "Sales_Item_Key"
    },
    {
        "table_name": "dbo.Fact_Customer_Metrics",
        "csv_path": FACT_DIR / "Fact_Customer_Metrics.csv",
        "is_fact": True,
        "identity_col": "Customer_Metric_Key"
    }
]

def get_best_odbc_driver():
    """Tự động tìm kiếm Driver ODBC SQL Server tốt nhất đã cài đặt trên máy"""
    drivers = pyodbc.drivers()
    preferred_drivers = [
        "ODBC Driver 18 for SQL Server",
        "ODBC Driver 17 for SQL Server",
        "ODBC Driver 13 for SQL Server",
        "SQL Server Native Client 11.0",
        "SQL Server"
    ]
    for d in preferred_drivers:
        if d in drivers:
            return d
    return "SQL Server"

def get_connection_string(server, database="master", username=None, password=None, trusted=True, driver=None):
    """Tạo chuỗi kết nối connection string tới SQL Server"""
    if not driver:
        driver = get_best_odbc_driver()
        
    conn_str = f"DRIVER={{{driver}}};SERVER={server};DATABASE={database};"
    if trusted or (not username and not password):
        conn_str += "Trusted_Connection=yes;"
    else:
        conn_str += f"UID={username};PWD={password};"
        
    # Bỏ qua xác thực SSL certificate cho ODBC Driver 18+ nếu chạy local/self-signed
    if "18" in driver:
        conn_str += "TrustServerCertificate=yes;"
        
    return conn_str

def execute_sql_file(conn, file_path):
    """Thực thi file script T-SQL chứa nhiều batch GO"""
    print(f"\n⚙️  Đang thực thi file SQL: {file_path.name}...")
    if not file_path.exists():
        print(f"❌ Không tìm thấy file: {file_path}")
        return False
        
    with open(file_path, "r", encoding="utf-8-sig", errors="ignore") as f:
        sql_content = f.read()

    # Tách các batch theo từ khóa GO
    batches = [b.strip() for b in sql_content.split("GO\n") if b.strip()]
    if not batches:
        batches = [b.strip() for b in sql_content.split("go\n") if b.strip()]
    if not batches:
        batches = [sql_content]

    cursor = conn.cursor()
    for i, batch in enumerate(batches, 1):
        # Bỏ qua lệnh USE master / USE Gold_Customer_DW riêng lẻ nếu gặp lỗi ngữ cảnh
        clean_batch = batch.strip()
        if not clean_batch or clean_batch.lower() == 'go':
            continue
        try:
            cursor.execute(clean_batch)
            conn.commit()
        except Exception as e:
            # Ghi nhận cảnh báo nhưng tiếp tục nếu batch chỉ là thông báo/drop bảng
            print(f"   ⚠️ Batch {i} cảnh báo/thông báo: {e}")
            conn.rollback()

    print(f"✅ Đã khởi tạo cấu trúc Data Warehouse hoàn tất!")
    return True

def load_via_bulk_insert(conn, database_name):
    """Phương thức nạp nhanh nhất sử dụng BULK INSERT T-SQL"""
    cursor = conn.cursor()
    
    print("\n" + "=" * 80)
    print("🚀 BẮT ĐẦU NẠP DỮ LIỆU BẰNG PHƯƠNG PHÁP: T-SQL BULK INSERT (SIÊU TỐC)")
    print("=" * 80)
    
    # 1. Tắt ràng buộc khóa ngoại
    print("1. Tắt tạm thời các Foreign Key Constraints...")
    cursor.execute("EXEC sp_MSforeachtable 'ALTER TABLE ? NOCHECK CONSTRAINT all';")
    conn.commit()
    
    # 2. Xóa dữ liệu cũ theo thứ tự Fact trước, Dim sau
    print("2. Dọn dẹp dữ liệu cũ (Xóa Fact -> Dim)...")
    reversed_tables = list(reversed(TABLES_METADATA))
    for item in reversed_tables:
        cursor.execute(f"DELETE FROM {item['table_name']};")
    conn.commit()
    print("   ✓ Đã dọn dẹp xong dữ liệu cũ.")
    
    # 3. Nạp dữ liệu từng bảng
    print("3. Nạp dữ liệu các bảng...")
    start_total = time.time()
    
    for item in TABLES_METADATA:
        t_name = item["table_name"]
        csv_file = item["csv_path"].resolve()
        is_fact = item["is_fact"]
        
        if not csv_file.exists():
            print(f"❌ Lỗi: Không tìm thấy file {csv_file}")
            continue
            
        t_start = time.time()
        
        # Câu lệnh BULK INSERT
        # Thêm KEEPIDENTITY nếu là bảng Fact có cột IDENTITY
        keep_id = ", KEEPIDENTITY" if is_fact else ""
        sql = f"""
        BULK INSERT {t_name}
        FROM '{str(csv_file)}'
        WITH (
            FORMAT = 'CSV',
            FIRSTROW = 2,
            FIELDTERMINATOR = ',',
            ROWTERMINATOR = '0x0a',
            CODEPAGE = '65001',
            TABLOCK{keep_id}
        );
        """
        try:
            cursor.execute(sql)
            conn.commit()
            duration = time.time() - t_start
            cursor.execute(f"SELECT COUNT(*) FROM {t_name}")
            row_count = cursor.fetchone()[0]
            print(f"   ✓ [{duration:5.2f}s] {t_name:30}: Nạp thành công {row_count:,} dòng")
        except Exception as e:
            conn.rollback()
            print(f"   ❌ Lỗi khi nạp {t_name}: {e}")
            
    # 4. Bật lại toàn bộ ràng buộc khóa ngoại và kiểm tra
    print("4. Bật lại và xác thực Foreign Key Constraints...")
    cursor.execute("EXEC sp_MSforeachtable 'ALTER TABLE ? WITH CHECK CHECK CONSTRAINT all';")
    conn.commit()
    
    total_time = time.time() - start_total
    print(f"\n🎉 Nạp toàn bộ dữ liệu hoàn tất trong {total_time:.2f} giây!")

def load_via_pandas(conn, chunk_size=50000):
    """Phương thức nạp linh hoạt sử dụng Pandas và pyodbc fast_executemany"""
    cursor = conn.cursor()
    cursor.fast_executemany = True
    
    print("\n" + "=" * 80)
    print("🚀 BẮT ĐẦU NẠP DỮ LIỆU BẰNG PHƯƠNG PHÁP: PANDAS + FAST_EXECUTEMANY")
    print("=" * 80)
    
    # 1. Tắt ràng buộc khóa ngoại
    print("1. Tắt tạm thời các Foreign Key Constraints...")
    cursor.execute("EXEC sp_MSforeachtable 'ALTER TABLE ? NOCHECK CONSTRAINT all';")
    conn.commit()
    
    # 2. Xóa dữ liệu cũ
    print("2. Dọn dẹp dữ liệu cũ (Xóa Fact -> Dim)...")
    for item in reversed(TABLES_METADATA):
        cursor.execute(f"DELETE FROM {item['table_name']};")
    conn.commit()
    print("   ✓ Đã dọn dẹp xong dữ liệu cũ.")
    
    # 3. Nạp dữ liệu từng bảng
    start_total = time.time()
    for item in TABLES_METADATA:
        t_name = item["table_name"]
        csv_file = item["csv_path"]
        is_fact = item["is_fact"]
        
        if not csv_file.exists():
            print(f"❌ Lỗi: Không tìm thấy file {csv_file}")
            continue
            
        print(f"\n📥 Đang đọc và nạp {t_name}...")
        t_start = time.time()
        
        # Bật IDENTITY_INSERT nếu là bảng Fact
        if is_fact:
            cursor.execute(f"SET IDENTITY_INSERT {t_name} ON;")
            conn.commit()
            
        total_rows_inserted = 0
        for chunk in pd.read_csv(csv_file, chunksize=chunk_size, low_memory=False):
            # Xử lý NaN thành None cho SQL
            chunk = chunk.where(pd.notnull(chunk), None)
            
            cols = list(chunk.columns)
            placeholders = ",".join(["?"] * len(cols))
            cols_str = ",".join([f"[{c}]" for c in cols])
            insert_sql = f"INSERT INTO {t_name} ({cols_str}) VALUES ({placeholders})"
            
            data = [tuple(row) for row in chunk.itertuples(index=False, name=None)]
            cursor.executemany(insert_sql, data)
            conn.commit()
            total_rows_inserted += len(data)
            print(f"   -> Đã nạp {total_rows_inserted:,} dòng...", end="\r")
            
        if is_fact:
            cursor.execute(f"SET IDENTITY_INSERT {t_name} OFF;")
            conn.commit()
            
        duration = time.time() - t_start
        print(f"   ✓ [{duration:5.2f}s] {t_name:30}: Nạp thành công {total_rows_inserted:,} dòng")
        
    # 4. Bật lại toàn bộ ràng buộc khóa ngoại
    print("\n4. Bật lại và xác thực Foreign Key Constraints...")
    cursor.execute("EXEC sp_MSforeachtable 'ALTER TABLE ? WITH CHECK CHECK CONSTRAINT all';")
    conn.commit()
    
    total_time = time.time() - start_total
    print(f"\n🎉 Nạp toàn bộ dữ liệu hoàn tất trong {total_time:.2f} giây!")

def verify_data(conn):
    """Kiểm tra và so sánh đối soát số lượng bản ghi giữa CSV và SQL Server"""
    print("\n" + "=" * 80)
    print("📊 BẢNG ĐỐI SOÁT DỮ LIỆU GIỮA CSV VÀ SQL SERVER")
    print("=" * 80)
    print(f"{'STT':<4} | {'Tên Bảng':<26} | {'Số Dòng CSV':<13} | {'Số Dòng SQL':<13} | {'Trạng Thái'}")
    print("-" * 80)
    
    cursor = conn.cursor()
    all_matched = True
    
    for idx, item in enumerate(TABLES_METADATA, 1):
        t_name = item["table_name"]
        csv_file = item["csv_path"]
        
        # Đếm dòng CSV
        csv_count = 0
        if csv_file.exists():
            with open(csv_file, "r", encoding="utf-8-sig", errors="ignore") as f:
                csv_count = sum(1 for _ in f) - 1 # Trừ dòng header
                
        # Đếm dòng SQL
        sql_count = 0
        try:
            cursor.execute(f"SELECT COUNT(*) FROM {t_name};")
            sql_count = cursor.fetchone()[0]
        except Exception as e:
            sql_count = -1
            
        status = "✅ KHỚP 100%" if csv_count == sql_count else "❌ LỆCH DỮ LIỆU"
        if csv_count != sql_count:
            all_matched = False
            
        clean_table_name = t_name.replace("dbo.", "")
        print(f"{idx:<4} | {clean_table_name:<26} | {csv_count:<13,f} | {sql_count:<13,f} | {status}")
        
    print("-" * 80)
    if all_matched:
        print("🎉 TẤT CẢ 8 BẢNG GOLD DATA WAREHOUSE ĐÃ ĐỒNG BỘ TOÀN VẸN VÀ CHÍNH XÁC!")
    else:
        print("⚠️ CÓ BẢNG BỊ LỆCH DỮ LIỆU, VUI LÒNG KIỂM TRA LẠI LOG CHI TIẾT TRÊN.")
    print("=" * 80)

def main():
    parser = argparse.ArgumentParser(description="ETL Load Gold Layer Data into SQL Server Data Warehouse")
    parser.add_argument("--server", type=str, default=r"localhost", help="Tên máy chủ SQL Server (Mặc định: localhost hoặc .)")
    parser.add_argument("--database", type=str, default="Gold_Customer_DW", help="Tên cơ sở dữ liệu (Mặc định: Gold_Customer_DW)")
    parser.add_argument("--user", type=str, default=None, help="Tài khoản SQL Server (nếu dùng SQL Auth)")
    parser.add_argument("--password", type=str, default=None, help="Mật khẩu SQL Server (nếu dùng SQL Auth)")
    parser.add_argument("--method", choices=["bulk", "pandas"], default="bulk", help="Phương pháp nạp dữ liệu: 'bulk' (T-SQL siêu tốc) hoặc 'pandas' (chunking)")
    parser.add_argument("--init-schema", action="store_true", help="Tự động chạy file Create_Gold_Data_Warehouse_Schema.sql trước khi nạp")
    parser.add_argument("--driver", type=str, default=None, help="Tên ODBC Driver (Mặc định tự động nhận diện)")
    
    args = parser.parse_args()
    
    print("=" * 80)
    print("   HỆ THỐNG NẠP DỮ LIỆU GOLD DATA WAREHOUSE - E-COMMERCE CUSTOMER ANALYTICS")
    print("=" * 80)
    
    detected_driver = args.driver or get_best_odbc_driver()
    print(f"📌 SQL Server : {args.server}")
    print(f"📌 Database   : {args.database}")
    print(f"📌 ODBC Driver: {detected_driver}")
    print(f"📌 Phương thức: {args.method.upper()}")
    
    # 1. Kết nối thử nghiệm / Khởi tạo Database nếu cần
    try:
        if args.init_schema:
            print("\n🔄 Đang kết nối tới master để khởi tạo Database & Tables...")
            master_conn_str = get_connection_string(
                server=args.server,
                database="master",
                username=args.user,
                password=args.password,
                trusted=True if not args.user else False,
                driver=detected_driver
            )
            with pyodbc.connect(master_conn_str, autocommit=True) as master_conn:
                execute_sql_file(master_conn, SCHEMA_SQL_FILE)

        # 2. Kết nối tới Database đích
        print(f"\n🔌 Đang kết nối tới database [{args.database}]...")
        target_conn_str = get_connection_string(
            server=args.server,
            database=args.database,
            username=args.user,
            password=args.password,
            trusted=True if not args.user else False,
            driver=detected_driver
        )
        conn = pyodbc.connect(target_conn_str, autocommit=False)
        print("✅ Kết nối cơ sở dữ liệu thành công!")
        
    except Exception as e:
        print(f"\n❌ Lỗi kết nối SQL Server: {e}")
        print("\n💡 Gợi ý khắc phục:")
        print("   1. Kiểm tra xem dịch vụ SQL Server có đang chạy không.")
        print("   2. Nếu dùng SQLEXPRESS, hãy truyền tham số: --server localhost\\SQLEXPRESS hoặc --server .\\SQLEXPRESS")
        print("   3. Đảm bảo Database đã được tạo hoặc chạy kèm tham số: --init-schema")
        sys.exit(1)

    # 3. Thực hiện nạp dữ liệu
    try:
        if args.method == "bulk":
            load_via_bulk_insert(conn, args.database)
        else:
            load_via_pandas(conn)
            
        # 4. Đối soát kiểm tra dữ liệu sau khi nạp
        verify_data(conn)
        
    except Exception as e:
        print(f"\n❌ Có lỗi xảy ra trong quá trình nạp dữ liệu: {e}")
    finally:
        conn.close()
        print("\n🔒 Đã đóng kết nối SQL Server an toàn.")

if __name__ == "__main__":
    main()
