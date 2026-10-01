#include "presentation/common/TableExporter.h"

#include "presentation/common/Format.h"

#include <QAbstractItemModel>
#include <QDateTime>
#include <QFile>
#include <QPageLayout>
#include <QPageSize>
#include <QPdfWriter>
#include <QTextDocument>

namespace {
QString csvField(QString s) {
    if (s.contains(QLatin1Char(',')) || s.contains(QLatin1Char('"')) || s.contains(QLatin1Char('\n'))) {
        s.replace(QLatin1String("\""), QLatin1String("\"\""));
        return QLatin1Char('"') + s + QLatin1Char('"');
    }
    return s;
}
} // namespace

bool TableExporter::xuatCsv(const QAbstractItemModel& model, const QString& duongDan, QString* loi) {
    QFile f(duongDan);
    if (!f.open(QIODevice::WriteOnly | QIODevice::Truncate)) {
        if (loi)
            *loi = f.errorString();
        return false;
    }
    QByteArray out("\xEF\xBB\xBF");   // BOM UTF-8 cho Excel
    QStringList dong;
    for (int c = 0; c < model.columnCount(); ++c)
        dong << csvField(model.headerData(c, Qt::Horizontal).toString());
    out += dong.join(QLatin1Char(',')).toUtf8() + "\r\n";
    for (int r = 0; r < model.rowCount(); ++r) {
        dong.clear();
        for (int c = 0; c < model.columnCount(); ++c)
            dong << csvField(model.index(r, c).data(Qt::DisplayRole).toString());
        out += dong.join(QLatin1Char(',')).toUtf8() + "\r\n";
    }
    f.write(out);
    return true;
}

bool TableExporter::xuatPdf(const QAbstractItemModel& model, const QString& tieuDe, const QString& nguoiLap,
                            const QString& duongDan, QString* loi) {
    // Bố cục giống Crystal Report: Report Header -> Page Header (tiêu đề cột lặp lại mỗi trang)
    // -> Details -> Report Footer (tổng); số trang do QTextDocument tự in ở chân trang.
    QString html = QStringLiteral(
        "<html><head><style>"
        "body{font-family:'Segoe UI','Helvetica Neue',Arial;font-size:9pt;color:#1E293B;}"
        "h1{color:#1F3864;font-size:16pt;margin:0;} .sub{color:#64748B;margin-bottom:8px;}"
        "table{border-collapse:collapse;width:100%;} th{background:#1F3864;color:white;padding:4px;}"
        "td{border-bottom:1px solid #E2E8F0;padding:3px;} .r{text-align:right;} .tong{font-weight:bold;}"
        "</style></head><body>");
    html += QStringLiteral("<div class='sub'>TRUNG TÂM ANH NGỮ — HỆ THỐNG QUẢN LÝ QLTTTA</div>");
    html += QStringLiteral("<h1>%1</h1>").arg(tieuDe.toHtmlEscaped());
    html += QStringLiteral("<div class='sub'>Ngày lập: %1 &nbsp;|&nbsp; Người lập: %2</div>")
                .arg(QDateTime::currentDateTime().toString(QStringLiteral("dd/MM/yyyy HH:mm")),
                     nguoiLap.toHtmlEscaped());

    const int soCot = model.columnCount();
    QVector<double> tong(soCot, 0.0);
    QVector<bool> laTien(soCot, false);
    html += QStringLiteral("<table><thead><tr><th>STT</th>");
    for (int c = 0; c < soCot; ++c) {
        const QString t = model.headerData(c, Qt::Horizontal).toString();
        laTien[c] = Format::laCotCongDon(t);
        html += QStringLiteral("<th>%1</th>").arg(t.toHtmlEscaped());
    }
    html += QStringLiteral("</tr></thead><tbody>");
    for (int r = 0; r < model.rowCount(); ++r) {
        html += QStringLiteral("<tr><td class='r'>%1</td>").arg(r + 1);
        for (int c = 0; c < soCot; ++c) {
            const QModelIndex idx = model.index(r, c);
            const bool canPhai = (idx.data(Qt::TextAlignmentRole).toInt() & Qt::AlignRight) != 0;
            html += QStringLiteral("<td%1>%2</td>")
                        .arg(canPhai ? QStringLiteral(" class='r'") : QString(),
                             idx.data(Qt::DisplayRole).toString().toHtmlEscaped());
            if (laTien[c])
                tong[c] += idx.data(Qt::UserRole).toDouble();
        }
        html += QStringLiteral("</tr>");
    }
    // Report Footer: dòng tổng cho các cột tiền
    if (std::find(laTien.begin(), laTien.end(), true) != laTien.end()) {
        html += QStringLiteral("<tr class='tong'><td></td>");
        for (int c = 0; c < soCot; ++c)
            html += laTien[c] ? QStringLiteral("<td class='r tong'>%1</td>").arg(Format::tien(qint64(tong[c])))
                              : (c == 0 ? QStringLiteral("<td class='tong'>TỔNG CỘNG</td>") : QStringLiteral("<td></td>"));
        html += QStringLiteral("</tr>");
    }
    html += QStringLiteral("</tbody></table><p class='sub'>Tổng số dòng: %1</p></body></html>").arg(model.rowCount());

    QPdfWriter writer(duongDan);
    if (!writer.setPageLayout(QPageLayout(QPageSize(QPageSize::A4),
                                          soCot > 7 ? QPageLayout::Landscape : QPageLayout::Portrait,
                                          QMarginsF(12, 12, 12, 12), QPageLayout::Millimeter))) {
        if (loi)
            *loi = QStringLiteral("Không thiết lập được khổ giấy.");
        return false;
    }
    writer.setTitle(tieuDe);
    writer.setCreator(QStringLiteral("QLTTTA"));

    QTextDocument doc;
    doc.setHtml(html);
    doc.print(&writer);
    return true;
}
