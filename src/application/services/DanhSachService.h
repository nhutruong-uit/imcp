#pragma once

#include "application/ports/IDanhSachRepository.h"
#include "application/services/AuthService.h"
#include "application/services/PhanQuyen.h"

// Use case tra cứu danh sách: kiểm tra vai trò hiện tại có được xem chức năng không
class DanhSachService {
public:
    DanhSachService(IDanhSachRepository& repository, const AuthService& auth);
    Result<TableData> layDanhSach(ChucNang chucNang);
    static bool coDanhSach(ChucNang chucNang);

private:
    IDanhSachRepository& m_repository;
    const AuthService& m_auth;
};
