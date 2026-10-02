#pragma once

#include <QList>

#include <optional>

// Số liệu màn hình Tổng quan (thủ tục dbo.usp_ThongKe_TongQuan)
struct ThongKeTongQuan {
    int hocVienDangHoc = 0;
    int lopDangHoc = 0;
    int lopTuyenSinh = 0;
    std::optional<qint64> doanhThuThangNay;   // không có giá trị = người dùng không được xem doanh thu
    qint64 tongCongNo = 0;
    int buoiHocHomNay = 0;
};

// Doanh thu một tháng (hàm dbo.fn_DoanhThuTheoThang)
struct DoanhThuThang {
    int thang = 0;
    qint64 doanhThu = 0;
};
