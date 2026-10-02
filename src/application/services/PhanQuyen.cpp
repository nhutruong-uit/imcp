#include "application/services/PhanQuyen.h"

QList<ChucNang> PhanQuyen::chucNangDuocPhep(VaiTro vaiTro) {
    switch (vaiTro) {
    case VaiTro::QuanLy:
        return {ChucNang::TongQuan, ChucNang::HocVien,  ChucNang::LopHoc,    ChucNang::LichHoc,
                ChucNang::KetQuaHocTap, ChucNang::CongNo, ChucNang::DoanhThu, ChucNang::BangLuong,
                ChucNang::TaiKhoan};
    case VaiTro::GiaoVu:
        return {ChucNang::TongQuan, ChucNang::HocVien, ChucNang::LopHoc, ChucNang::LichHoc,
                ChucNang::KetQuaHocTap, ChucNang::CongNo};
    case VaiTro::KeToan:
        return {ChucNang::TongQuan, ChucNang::HocVien, ChucNang::CongNo, ChucNang::DoanhThu,
                ChucNang::BangLuong};
    case VaiTro::GiaoVien:
        return {ChucNang::LopCuaToi, ChucNang::LichDayCuaToi, ChucNang::LuongCuaToi};
    case VaiTro::KhongXacDinh:
        break;
    }
    return {};
}

bool PhanQuyen::duocPhep(VaiTro vaiTro, ChucNang chucNang) {
    return chucNangDuocPhep(vaiTro).contains(chucNang);
}

bool PhanQuyen::duocSuaHocVien(VaiTro vaiTro) {
    return vaiTro == VaiTro::QuanLy || vaiTro == VaiTro::GiaoVu;
}

ThongTinChucNang PhanQuyen::thongTin(ChucNang chucNang) {
    switch (chucNang) {
    case ChucNang::TongQuan:
        return {chucNang, QStringLiteral("Tổng quan"), QStringLiteral("home"), QStringLiteral("Chung")};
    case ChucNang::HocVien:
        return {chucNang, QStringLiteral("Học viên"), QStringLiteral("users"), QStringLiteral("Đào tạo")};
    case ChucNang::LopHoc:
        return {chucNang, QStringLiteral("Lớp học"), QStringLiteral("book"), QStringLiteral("Đào tạo")};
    case ChucNang::LichHoc:
        return {chucNang, QStringLiteral("Lịch học tuần này"), QStringLiteral("calendar"),
                QStringLiteral("Đào tạo")};
    case ChucNang::KetQuaHocTap:
        return {chucNang, QStringLiteral("Kết quả học tập"), QStringLiteral("award"),
                QStringLiteral("Đào tạo")};
    case ChucNang::CongNo:
        return {chucNang, QStringLiteral("Công nợ học phí"), QStringLiteral("wallet"),
                QStringLiteral("Tài chính")};
    case ChucNang::DoanhThu:
        return {chucNang, QStringLiteral("Doanh thu"), QStringLiteral("chart"), QStringLiteral("Tài chính")};
    case ChucNang::BangLuong:
        return {chucNang, QStringLiteral("Lương giáo viên"), QStringLiteral("cash"),
                QStringLiteral("Tài chính")};
    case ChucNang::TaiKhoan:
        return {chucNang, QStringLiteral("Tài khoản"), QStringLiteral("shield"), QStringLiteral("Hệ thống")};
    case ChucNang::LopCuaToi:
        return {chucNang, QStringLiteral("Lớp của tôi"), QStringLiteral("book"), QStringLiteral("Giảng dạy")};
    case ChucNang::LichDayCuaToi:
        return {chucNang, QStringLiteral("Lịch dạy"), QStringLiteral("calendar"), QStringLiteral("Giảng dạy")};
    case ChucNang::LuongCuaToi:
        return {chucNang, QStringLiteral("Lương của tôi"), QStringLiteral("cash"), QStringLiteral("Giảng dạy")};
    }
    return {chucNang, QString(), QString(), QString()};
}
