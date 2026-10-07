#include "presentation/tuition/ReceiptPrinter.h"

#include "presentation/common/DbValues.h"
#include "presentation/common/Format.h"
#include "presentation/common/Theme.h"

#include <QCoreApplication>
#include <QPageLayout>
#include <QPageSize>

namespace {
// Provides tr() with translation context "ReceiptPrinter" for the free functions of namespace ReceiptPrinter
struct ReceiptText {
    Q_DECLARE_TR_FUNCTIONS(ReceiptPrinter)
};

QString row(const QString& label, const QString& value) {
    return QStringLiteral(
               "<tr><td style='color:%1; padding:3px 12px 3px 0;'>%2</td><td style='padding:3px 0;'>"
               "<b>%3</b></td></tr>")
        .arg(QLatin1String(Theme::kMuted), label.toHtmlEscaped(), value.toHtmlEscaped());
}
} // namespace

QString ReceiptPrinter::html(const ReceiptPrint& r) {
    QString h;
    h += QStringLiteral("<div style='font-family:Arial; font-size:10pt; color:%1;'>")
             .arg(QLatin1String(Theme::kText));
    h += QStringLiteral("<div style='font-size:13pt; font-weight:bold; color:%1;'>%2</div>")
             .arg(QLatin1String(Theme::kPrimary), r.branchName.toHtmlEscaped());
    h += QStringLiteral("<div>%1</div>").arg(r.branchAddress.toHtmlEscaped());
    if (!r.branchPhone.isEmpty())
        h += QStringLiteral("<div>%1</div>")
                 .arg(ReceiptText::tr("Phone: %1").arg(r.branchPhone).toHtmlEscaped());
    h += QStringLiteral("<h2 style='text-align:center; color:%1; margin-top:18px;'>%2</h2>")
             .arg(QLatin1String(Theme::kPrimary), ReceiptText::tr("TUITION RECEIPT").toHtmlEscaped());
    h += QStringLiteral("<p style='text-align:center;'>%1</p>")
             .arg(ReceiptText::tr("No. %1 - %2")
                      .arg(r.receiptId, Format::dateTime(r.paidAtUtc))
                      .toHtmlEscaped());
    if (r.status != ReceiptValues::valid())
        h += QStringLiteral("<p style='text-align:center; color:%1; font-weight:bold;'>%2</p>")
                 .arg(QLatin1String(Theme::kNegativeText), ReceiptText::tr("CANCELLED").toHtmlEscaped());
    h += QStringLiteral("<table style='margin-top:10px;'>");
    h += row(ReceiptText::tr("Student"), QStringLiteral("%1 - %2").arg(r.studentId, r.studentName));
    h += row(ReceiptText::tr("Class"), QStringLiteral("%1 - %2").arg(r.classId, r.className));
    h += row(ReceiptText::tr("Course"), r.courseName);
    // The default description is a stored English value: shown in the UI language like the other values
    h += row(ReceiptText::tr("Description"), DbValues::label(r.description));
    h += row(ReceiptText::tr("Payment method"), DbValues::label(r.paymentMethod));
    h += row(ReceiptText::tr("Amount"), Format::money(r.amount));
    h += row(ReceiptText::tr("Tuition due"), Format::money(r.tuitionDue));
    h += row(ReceiptText::tr("Paid so far"), Format::money(r.amountPaid));
    h += row(ReceiptText::tr("Balance"), Format::money(r.balance));
    h += QStringLiteral("</table>");
    h += QStringLiteral("<table width='100%' style='margin-top:36px;'><tr>"
                        "<td align='center' width='50%'>%1<br/><br/><br/><br/></td>"
                        "<td align='center' width='50%'>%2<br/><br/><br/><br/>%3</td></tr></table>")
             .arg(ReceiptText::tr("Payer").toHtmlEscaped(), ReceiptText::tr("Collected by").toHtmlEscaped(),
                  r.collectedBy.toHtmlEscaped());
    h += QStringLiteral("</div>");
    return h;
}

ReportDocument ReceiptPrinter::document(const ReceiptPrint& receipt) {
    ReportDocument document;
    document.title = ReceiptText::tr("Receipt %1").arg(receipt.receiptId);
    document.html = html(receipt);
    document.pageLayout = QPageLayout(QPageSize(QPageSize::A5), QPageLayout::Portrait,
                                      QMarginsF(14, 14, 14, 14), QPageLayout::Millimeter);
    return document;
}
