#include "domain/entities/HocVien.h"

#include <QRegularExpression>

namespace HocVienGiaTri {
QStringList gioiTinh() {
    return {QStringLiteral("Nam"), QStringLiteral("Nữ"), QStringLiteral("Khác")};
}
QStringList trangThai() {
    return {QStringLiteral("Tiềm năng"), QStringLiteral("Đang học"), QStringLiteral("Bảo lưu"),
            QStringLiteral("Ngừng học")};
}
} // namespace HocVienGiaTri

namespace {
bool laSoDienThoaiHopLe(const QString& sdt) {
    static const QRegularExpression mau(QStringLiteral("^[0-9]{9,11}$"));
    return mau.match(sdt).hasMatch();
}

bool laEmailHopLe(const QString& email) {
    static const QRegularExpression mau(QStringLiteral("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$"));
    return mau.match(email).hasMatch();
}
} // namespace

int HocVien::tuoi(const QDate& tinhDen) const {
    if (!ngaySinh.isValid() || !tinhDen.isValid())
        return 0;
    int t = tinhDen.year() - ngaySinh.year();
    if (tinhDen.month() < ngaySinh.month() ||
        (tinhDen.month() == ngaySinh.month() && tinhDen.day() < ngaySinh.day()))
        --t;
    return t;
}

bool HocVien::canThongTinPhuHuynh(const QDate& tinhDen) const {
    return tuoi(tinhDen) < 18;
}

QStringList HocVien::kiemTra(const QDate& homNay) const {
    QStringList loi;
    const QDate mocTinhTuoi = ngayDangKy.isValid() ? ngayDangKy : homNay;

    if (hoTen.trimmed().isEmpty())
        loi << QStringLiteral("Họ tên không được để trống.");
    else if (hoTen.trimmed().size() > 100)
        loi << QStringLiteral("Họ tên tối đa 100 ký tự.");

    if (!ngaySinh.isValid())
        loi << QStringLiteral("Ngày sinh không hợp lệ.");
    else if (ngaySinh <= QDate(1930, 1, 1) || tuoi(mocTinhTuoi) < 4)
        loi << QStringLiteral("Học viên phải từ 4 tuổi trở lên.");

    if (!HocVienGiaTri::gioiTinh().contains(gioiTinh))
        loi << QStringLiteral("Giới tính không hợp lệ.");

    if (!soDienThoai.isEmpty() && !laSoDienThoaiHopLe(soDienThoai))
        loi << QStringLiteral("Số điện thoại chỉ gồm 9-11 chữ số.");
    if (!sdtPhuHuynh.isEmpty() && !laSoDienThoaiHopLe(sdtPhuHuynh))
        loi << QStringLiteral("Số điện thoại phụ huynh chỉ gồm 9-11 chữ số.");
    if (!email.isEmpty() && !laEmailHopLe(email))
        loi << QStringLiteral("Email không đúng định dạng.");

    if (ngaySinh.isValid() && canThongTinPhuHuynh(mocTinhTuoi) &&
        (tenPhuHuynh.trimmed().isEmpty() || sdtPhuHuynh.isEmpty()))
        loi << QStringLiteral("Học viên dưới 18 tuổi phải có họ tên và số điện thoại phụ huynh.");

    if (soDienThoai.isEmpty() && sdtPhuHuynh.isEmpty())
        loi << QStringLiteral("Cần ít nhất một số điện thoại liên lạc (học viên hoặc phụ huynh).");

    if (maCN.isEmpty())
        loi << QStringLiteral("Chưa chọn chi nhánh.");

    if (!HocVienGiaTri::trangThai().contains(trangThai))
        loi << QStringLiteral("Trạng thái không hợp lệ.");

    return loi;
}
