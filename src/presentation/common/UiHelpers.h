#pragma once

#include <QString>

class QAbstractItemModel;
class QFrame;
class QLabel;
class QPushButton;
class QWidget;

namespace UiHelpers {
QPushButton* nutChinh(const QString& text, const QString& icon, QWidget* parent);   // nút màu nhấn
QPushButton* nutPhu(const QString& text, const QString& icon, QWidget* parent);     // nút viền
QLabel* tieuDeTrang(const QString& text, QWidget* parent);
QFrame* theCard(QWidget* parent);
void baoLoi(QWidget* parent, const QString& thongBao);
bool xacNhan(QWidget* parent, const QString& cauHoi);
// Hộp thoại chọn file rồi xuất model ra CSV/PDF
void xuatCsv(QWidget* parent, const QAbstractItemModel& model, const QString& tenGoiY);
void xuatPdf(QWidget* parent, const QAbstractItemModel& model, const QString& tieuDe, const QString& nguoiLap);
} // namespace UiHelpers
