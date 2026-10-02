---
paths:
  - "scripts/**"
  - ".github/**"
  - "docker-compose.yml"
  - "CMakePresets.json"
---
# Quy tắc script, CI, đóng gói

- Mỗi script có **hai bản cùng các bước**: `.sh` (macOS/Linux) và `.ps1` (Windows). Sửa một bản thì sửa bản kia.
- `.sh`: `#!/usr/bin/env bash` + `set -euo pipefail`; đường dẫn gốc lấy từ `$(dirname "$0")`; có khối chú thích
  "Cách dùng" ở đầu file.
- `.ps1`: lưu **UTF-8 có BOM + CRLF** (Windows PowerShell 5.1 mới đọc đúng tiếng Việt), chỉ dùng cú pháp chạy được
  trên PowerShell 5.1 (không `??`, không toán tử ba ngôi), `$ErrorActionPreference = "Stop"`, kiểm tra `$LASTEXITCODE`
  sau lệnh ngoài; kiểm tra cú pháp bằng `pwsh` Parser trước khi commit.
- Mật khẩu chỉ đi qua biến môi trường (`SQL_PASSWORD`, `SQLCMDPASSWORD`; `docker exec -e SQLCMDPASSWORD` không kèm giá trị)
  - không đặt trên dòng lệnh, không in ra log, trả lại biến môi trường sau khi chạy.
- CI (`.github/workflows/ci.yml`) chỉ chạy khi merge vào `develop`, khi có PR vào `main` (bắt buộc cho branch
  protection) và chạy tay. Giữ tên 2 job `macOS (Apple Silicon)` và `Windows (Qt + MinGW)`: đổi tên job phải sửa
  luôn required checks của `main`, nếu không mọi PR vào `main` bị kẹt.
- Không thêm `paths-ignore` vào trigger `pull_request` của `main` (check bắt buộc sẽ không bao giờ chạy).
- CI không có SQL Server và không chấp nhận EULA của Microsoft thay người dùng; kiểm thử CSDL/e2e chạy bằng `test_all` trên máy.
