#include "presentation/common/UiHelpers.h"

#include "presentation/common/Icons.h"
#include "presentation/common/TableExporter.h"

#include <QDesktopServices>
#include <QDir>
#include <QFileDialog>
#include <QFrame>
#include <QLabel>
#include <QMessageBox>
#include <QPushButton>
#include <QStandardPaths>
#include <QUrl>

QPushButton* UiHelpers::nutChinh(const QString& text, const QString& icon, QWidget* parent) {
    auto* b = new QPushButton(text, parent);
    b->setProperty("variant", QStringLiteral("primary"));
    if (!icon.isEmpty())
        b->setIcon(Icons::get(icon, QStringLiteral("#FFFFFF"), 16));
    b->setCursor(Qt::PointingHandCursor);
    return b;
}

QPushButton* UiHelpers::nutPhu(const QString& text, const QString& icon, QWidget* parent) {
    auto* b = new QPushButton(text, parent);
    if (!icon.isEmpty())
        b->setIcon(Icons::get(icon, QStringLiteral("#334155"), 16));
    b->setCursor(Qt::PointingHandCursor);
    return b;
}

QLabel* UiHelpers::tieuDeTrang(const QString& text, QWidget* parent) {
    auto* l = new QLabel(text, parent);
    l->setObjectName(QStringLiteral("PageTitle"));
    return l;
}

QFrame* UiHelpers::theCard(QWidget* parent) {
    auto* f = new QFrame(parent);
    f->setProperty("card", true);
    return f;
}

void UiHelpers::baoLoi(QWidget* parent, const QString& thongBao) {
    QMessageBox::warning(parent, QStringLiteral("Không thực hiện được"), thongBao);
}

bool UiHelpers::xacNhan(QWidget* parent, const QString& cauHoi) {
    // Qt không kèm bản dịch tiếng Việt cho nút chuẩn (Yes/No) nên tự đặt chữ trên nút
    QMessageBox hop(QMessageBox::Question, QStringLiteral("Xác nhận"), cauHoi,
                    QMessageBox::Yes | QMessageBox::No, parent);
    hop.setDefaultButton(QMessageBox::No);
    hop.button(QMessageBox::Yes)->setText(QStringLiteral("Đồng ý"));
    hop.button(QMessageBox::No)->setText(QStringLiteral("Không"));
    return hop.exec() == QMessageBox::Yes;
}

void UiHelpers::xuatCsv(QWidget* parent, const QAbstractItemModel& model, const QString& tenGoiY) {
    const QString thuMuc = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    const QString duongDan = QFileDialog::getSaveFileName(parent, QStringLiteral("Xuất Excel (CSV)"),
                                                          QDir(thuMuc).filePath(tenGoiY + QStringLiteral(".csv")),
                                                          QStringLiteral("CSV (*.csv)"));
    if (duongDan.isEmpty())
        return;
    QString loi;
    if (!TableExporter::xuatCsv(model, duongDan, &loi))
        baoLoi(parent, loi);
    else
        QDesktopServices::openUrl(QUrl::fromLocalFile(duongDan));
}

void UiHelpers::xuatPdf(QWidget* parent, const QAbstractItemModel& model, const QString& tieuDe,
                        const QString& nguoiLap) {
    const QString thuMuc = QStandardPaths::writableLocation(QStandardPaths::DocumentsLocation);
    const QString duongDan = QFileDialog::getSaveFileName(parent, QStringLiteral("Xuất báo cáo PDF"),
                                                          QDir(thuMuc).filePath(tieuDe + QStringLiteral(".pdf")),
                                                          QStringLiteral("PDF (*.pdf)"));
    if (duongDan.isEmpty())
        return;
    QString loi;
    if (!TableExporter::xuatPdf(model, tieuDe, nguoiLap, duongDan, &loi))
        baoLoi(parent, loi);
    else
        QDesktopServices::openUrl(QUrl::fromLocalFile(duongDan));
}
