#pragma once

#include "application/ports/IDanhMucRepository.h"
#include "application/ports/IHocVienRepository.h"

// Use case quản lý học viên: kiểm tra quy tắc nghiệp vụ trước khi gọi repository
class HocVienService {
public:
    HocVienService(IHocVienRepository& repository, IDanhMucRepository& danhMuc);

    Result<QList<HocVien>> timKiem(const BoLocHocVien& boLoc);
    Result<HocVien> layChiTiet(const QString& maHV);
    Result<QString> themMoi(const HocVien& hocVien, const QDate& homNay);
    VoidResult capNhat(const HocVien& hocVien, const QDate& homNay);
    VoidResult xoa(const QString& maHV);
    Result<QList<ChiNhanh>> danhSachChiNhanh();

private:
    IHocVienRepository& m_repository;
    IDanhMucRepository& m_danhMuc;
};
