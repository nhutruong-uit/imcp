#pragma once

#include <QSqlError>
#include <QString>

// Chuyển lỗi ODBC/SQL Server thành thông báo tiếng Việt dễ hiểu cho người dùng.
// - Lỗi nghiệp vụ do THROW/RAISERROR trong thủ tục/trigger: giữ nguyên nội dung tiếng Việt
// - Lỗi hệ thống (sai mật khẩu, mất kết nối, thiếu quyền, vi phạm ràng buộc): dịch sang câu dễ hiểu
class SqlErrorMapper {
public:
    static QString thongBao(const QSqlError& loi);
    static QString lamSachThongDiep(const QString& thongDiepGoc);   // bỏ tiền tố [Microsoft][ODBC ...]
    static QString thongBaoRangBuoc(const QString& tenRangBuoc);
};
