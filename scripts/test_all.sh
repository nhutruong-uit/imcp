#!/usr/bin/env bash
# Chạy TOÀN BỘ kiểm thử, dừng ngay khi có bước hỏng (dùng trước khi tạo PR):
#   1. Khởi tạo lại CSDL QLTTTA từ đầu (scripts/db_init.sh) => dữ liệu mẫu luôn giống nhau
#   2. Kiểm thử CSDL: database/12_kiem_thu.sql (ràng buộc, nghiệp vụ, hàm/trigger/cursor, XML, phân quyền)
#   3. Build ứng dụng + unit test + kiểm thử end-to-end qua giao diện với CSDL thật (ctest)
#
# Cách dùng:
#   SQL_PASSWORD='<mật khẩu sa>' ./scripts/test_all.sh --docker sql2022   # sqlcmd trong container
#   SQL_PASSWORD='<mật khẩu sa>' ./scripts/test_all.sh                    # sqlcmd trên máy (SQL_SERVER)
#   ... ./scripts/test_all.sh --docker sql2022 --no-init                   # bỏ qua bước 1
#
# Biến môi trường: SQL_SERVER (mặc định localhost,1433), SQL_USER (mặc định sa), SQL_PASSWORD (bắt buộc),
#   QLTTTA_E2E_PASSWORD (mật khẩu tài khoản demo, mặc định như docs/SETUP.md), PRESET (mặc định macos-debug),
#   EXTRA_CMAKE_ARGS (vd -DCMAKE_OSX_SYSROOT=... khi CMake báo trình biên dịch "broken")
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SQL_SERVER="${SQL_SERVER:-localhost,1433}"
SQL_USER="${SQL_USER:-sa}"
PRESET="${PRESET:-macos-debug}"
CONTAINER=""
KHOI_TAO=1

while [[ $# -gt 0 ]]; do
  case "$1" in
    --docker)  CONTAINER="${2:?Thiếu tên container, ví dụ: --docker sql2022}"; shift 2 ;;
    --no-init) KHOI_TAO=0; shift ;;
    *) echo "Tham số không hợp lệ: $1" >&2; exit 2 ;;
  esac
done
: "${SQL_PASSWORD:?Hãy đặt biến SQL_PASSWORD (mật khẩu tài khoản sa)}"
export QLTTTA_E2E_PASSWORD="${QLTTTA_E2E_PASSWORD:-Demo@2026}"   # tài khoản demo, không phải mật khẩu thật

KET_QUA="$ROOT/build/test-results"
mkdir -p "$KET_QUA"
buoc() { printf '\n==== %s ====\n' "$1"; }

# 1. Khởi tạo lại CSDL
if [[ $KHOI_TAO -eq 1 ]]; then
  buoc "1/3 Khởi tạo lại CSDL"
  if [[ -n "$CONTAINER" ]]; then "$ROOT/scripts/db_init.sh" --docker "$CONTAINER"; else "$ROOT/scripts/db_init.sh"; fi
fi

# 2. Kiểm thử CSDL (file tự THROW khi có ca KHÔNG ĐẠT => sqlcmd -b trả mã lỗi)
buoc "2/3 Kiểm thử CSDL (database/12_kiem_thu.sql)"
FILE_KT="$KET_QUA/kiem_thu_csdl.txt"
set +e
if [[ -n "$CONTAINER" ]]; then
  docker cp "$ROOT/database/12_kiem_thu.sql" "$CONTAINER:/tmp/12_kiem_thu.sql" >/dev/null
  docker exec -e SQLCMDPASSWORD="$SQL_PASSWORD" "$CONTAINER" /opt/mssql-tools18/bin/sqlcmd \
    -S localhost -U "$SQL_USER" -C -I -b -f 65001 -d QLTTTA -W -s '|' -i /tmp/12_kiem_thu.sql > "$FILE_KT" 2>&1
else
  SQLCMDPASSWORD="$SQL_PASSWORD" sqlcmd -S "$SQL_SERVER" -U "$SQL_USER" -C -I -b -f 65001 -d QLTTTA -W -s '|' \
    -i "$ROOT/database/12_kiem_thu.sql" > "$FILE_KT" 2>&1
fi
MA_CSDL=$?
set -e
TONG=$(grep -cE '^[TP][0-9]{2}\|' "$FILE_KT" || true)
DAT=$(grep -E '^[TP][0-9]{2}\|' "$FILE_KT" | grep -c '|ĐẠT|' || true)
echo "Kết quả: $DAT/$TONG ca ĐẠT (chi tiết: ${FILE_KT#"$ROOT"/})"
if [[ $MA_CSDL -ne 0 ]]; then
  grep -E '^[TP][0-9]{2}\|.*\|KHÔNG ĐẠT\|' "$FILE_KT" || tail -20 "$FILE_KT"
  echo "THẤT BẠI: kiểm thử CSDL có ca không đạt." >&2
  exit 1
fi

# 3. Build + unit test + e2e
buoc "3/3 Build, unit test và kiểm thử giao diện (ctest)"
# shellcheck disable=SC2086
cmake --preset "$PRESET" ${EXTRA_CMAKE_ARGS:-} > "$KET_QUA/cmake_configure.log" 2>&1 \
  || { cat "$KET_QUA/cmake_configure.log"; exit 1; }
cmake --build --preset "$PRESET"
QLTTTA_SERVER="${QLTTTA_SERVER:-$SQL_SERVER}" ctest --preset "$PRESET" --output-on-failure \
  --output-junit "$KET_QUA/ctest.xml"

# Không chấp nhận e2e bị SKIP âm thầm (vd quên mật khẩu, không kết nối được CSDL)
if grep -q 'status="skipped"\|<skipped' "$KET_QUA/ctest.xml"; then
  echo "THẤT BẠI: có bài kiểm thử bị bỏ qua (SKIP) - kiểm tra kết nối CSDL / QLTTTA_E2E_PASSWORD." >&2
  exit 1
fi

printf '\nTẤT CẢ KIỂM THỬ ĐẠT: CSDL %s/%s ca, unit test + end-to-end qua giao diện đều đạt.\n' "$DAT" "$TONG"
