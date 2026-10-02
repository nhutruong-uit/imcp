#!/usr/bin/env bash
# Khởi tạo CSDL QLTTTA (macOS / Linux): chạy lần lượt database/00..07.
#
# Cách dùng:
#   SQL_PASSWORD='<mật khẩu sa>' ./scripts/db_init.sh                  # dùng sqlcmd trên máy
#   SQL_PASSWORD='<mật khẩu sa>' ./scripts/db_init.sh --docker sql2022  # dùng sqlcmd trong container
#
# Biến môi trường: SQL_SERVER (mặc định localhost,1433), SQL_USER (mặc định sa), SQL_PASSWORD (bắt buộc)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DB_DIR="$ROOT/database"
SQL_SERVER="${SQL_SERVER:-localhost,1433}"
SQL_USER="${SQL_USER:-sa}"
CONTAINER=""

if [[ "${1:-}" == "--docker" ]]; then
  CONTAINER="${2:?Thiếu tên container, ví dụ: --docker sql2022}"
fi
: "${SQL_PASSWORD:?Hãy đặt biến SQL_PASSWORD (mật khẩu tài khoản sa)}"

FILES=(00_create_database.sql 01_tables.sql 02_functions.sql 03_views.sql
       04_procedures.sql 05_triggers.sql 06_security.sql 07_seed_data.sql)

run_sql() {
  local file="$1" db="$2"
  if [[ -n "$CONTAINER" ]]; then
    docker cp "$DB_DIR/$file" "$CONTAINER:/tmp/$file" >/dev/null
    SQLCMDPASSWORD="$SQL_PASSWORD" docker exec -e SQLCMDPASSWORD "$CONTAINER" \
      /opt/mssql-tools18/bin/sqlcmd -S localhost -U "$SQL_USER" -C -I -b -f 65001 -d "$db" -i "/tmp/$file"
  else
    SQLCMDPASSWORD="$SQL_PASSWORD" sqlcmd -S "$SQL_SERVER" -U "$SQL_USER" -C -I -b -f 65001 -d "$db" -i "$DB_DIR/$file"
  fi
}

for f in "${FILES[@]}"; do
  db=QLTTTA
  [[ "$f" == 00_* ]] && db=master
  echo ">> $f"
  run_sql "$f" "$db"
done
echo "Hoàn tất. CSDL QLTTTA đã sẵn sàng (tài khoản demo: xem docs/SETUP.md)."
