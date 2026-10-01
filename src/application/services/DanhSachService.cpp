#include "application/services/DanhSachService.h"

#include <optional>

namespace {
std::optional<LoaiDanhSach> loaiTheoChucNang(ChucNang chucNang) {
    switch (chucNang) {
    case ChucNang::LopHoc:
        return LoaiDanhSach::LopHoc;
    case ChucNang::LichHoc:
        return LoaiDanhSach::LichHocTuanNay;
    case ChucNang::KetQuaHocTap:
        return LoaiDanhSach::KetQuaHocTap;
    case ChucNang::CongNo:
        return LoaiDanhSach::CongNo;
    case ChucNang::DoanhThu:
        return LoaiDanhSach::DoanhThuThang;
    case ChucNang::BangLuong:
        return LoaiDanhSach::BangLuong;
    case ChucNang::TaiKhoan:
        return LoaiDanhSach::TaiKhoan;
    case ChucNang::LopCuaToi:
        return LoaiDanhSach::LopCuaToi;
    case ChucNang::LichDayCuaToi:
        return LoaiDanhSach::LichDayCuaToi;
    case ChucNang::LuongCuaToi:
        return LoaiDanhSach::LuongCuaToi;
    case ChucNang::TongQuan:
    case ChucNang::HocVien:
        break;
    }
    return std::nullopt;
}
} // namespace

DanhSachService::DanhSachService(IDanhSachRepository& repository, const AuthService& auth)
    : m_repository(repository), m_auth(auth) {}

bool DanhSachService::coDanhSach(ChucNang chucNang) {
    return loaiTheoChucNang(chucNang).has_value();
}

Result<TableData> DanhSachService::layDanhSach(ChucNang chucNang) {
    if (!PhanQuyen::duocPhep(m_auth.vaiTro(), chucNang))
        return Result<TableData>::failure(QStringLiteral("Bạn không có quyền xem chức năng này."));
    const auto loai = loaiTheoChucNang(chucNang);
    if (!loai)
        return Result<TableData>::failure(QStringLiteral("Chức năng không có danh sách tra cứu."));
    return m_repository.layDanhSach(*loai);
}
