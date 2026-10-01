#pragma once

#include <QList>
#include <QStringList>
#include <QVariant>

// Dữ liệu dạng bảng (tên cột + các dòng) dùng cho màn hình tra cứu/báo cáo chỉ đọc.
struct TableData {
    QStringList columns;
    QList<QVariantList> rows;
};
