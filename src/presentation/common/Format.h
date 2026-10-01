#pragma once

#include <QDate>
#include <QString>
#include <QVariant>

// Định dạng hiển thị theo thói quen Việt Nam: 6.500.000 ₫, 25/10/2026
namespace Format {
QString tien(qint64 soTien);
QString tienRutGon(qint64 soTien);   // 12,5 tr
QString ngay(const QDate& d);
bool laCotTien(const QString& tieuDe);
bool laCotCongDon(const QString& tieuDe);   // cột tiền có ý nghĩa khi cộng tổng (còn nợ, doanh thu, lương...)
QString oBang(const QVariant& giaTri, const QString& tieuDeCot);
} // namespace Format
