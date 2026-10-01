#pragma once

#include <QString>

class QAbstractItemModel;

// Xuất dữ liệu đang hiển thị trên bảng ra file:
// - CSV (UTF-8 có BOM, mở trực tiếp bằng Excel không lỗi font tiếng Việt)
// - PDF dạng báo cáo: tiêu đề báo cáo, thông tin người lập, bảng chi tiết, dòng tổng, số trang
namespace TableExporter {
bool xuatCsv(const QAbstractItemModel& model, const QString& duongDan, QString* loi = nullptr);
bool xuatPdf(const QAbstractItemModel& model, const QString& tieuDe, const QString& nguoiLap,
             const QString& duongDan, QString* loi = nullptr);
} // namespace TableExporter
