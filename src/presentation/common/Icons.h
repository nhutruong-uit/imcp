#pragma once

#include <QIcon>
#include <QString>

// Biểu tượng SVG trong resources/icons, tô màu theo yêu cầu (dùng chung 1 bộ icon cho nền sáng/tối)
namespace Icons {
QIcon get(const QString& ten, const QString& mau = QStringLiteral("#334155"), int kichThuoc = 20);
QPixmap pixmap(const QString& ten, const QString& mau, int kichThuoc);
} // namespace Icons
