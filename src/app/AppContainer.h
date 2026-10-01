#pragma once

#include "application/services/AuthService.h"
#include "application/services/DanhSachService.h"
#include "application/services/HocVienService.h"
#include "application/services/ThongKeService.h"
#include "infrastructure/config/QSettingsCauHinhStore.h"
#include "infrastructure/db/DatabaseManager.h"
#include "infrastructure/repositories/SqlAuthGateway.h"
#include "infrastructure/repositories/SqlDanhMucRepository.h"
#include "infrastructure/repositories/SqlDanhSachRepository.h"
#include "infrastructure/repositories/SqlHocVienRepository.h"
#include "infrastructure/repositories/SqlThongKeRepository.h"
#include "presentation/main/AppServices.h"

// Khởi tạo toàn bộ đối tượng theo đúng thứ tự phụ thuộc (Dependency Injection thủ công).
// Muốn đổi CSDL (vd. PostgreSQL) hoặc chạy kiểm thử với dữ liệu giả: chỉ cần thay các
// lớp Sql...Repository ở đây, tầng application và presentation giữ nguyên.
class AppContainer {
public:
    AppContainer();
    AuthService& auth() { return m_auth; }
    AppServices services() { return AppServices{m_auth, m_hocVien, m_thongKe, m_danhSach}; }

private:
    // Infrastructure
    DatabaseManager m_db;
    QSettingsCauHinhStore m_cauHinh;
    SqlAuthGateway m_authGateway;
    SqlHocVienRepository m_hocVienRepo;
    SqlDanhMucRepository m_danhMucRepo;
    SqlThongKeRepository m_thongKeRepo;
    SqlDanhSachRepository m_danhSachRepo;
    // Application
    AuthService m_auth;
    HocVienService m_hocVien;
    ThongKeService m_thongKe;
    DanhSachService m_danhSach;
};
