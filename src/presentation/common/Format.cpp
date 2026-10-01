#include "presentation/common/Format.h"

#include <QDateTime>
#include <QLocale>
#include <QStringList>

#include <cmath>

namespace {
const QLocale& viVN() {
    static const QLocale l(QLocale::Vietnamese, QLocale::Vietnam);
    return l;
}
} // namespace

QString Format::tien(qint64 soTien) {
    return viVN().toString(soTien) + QStringLiteral(" ₫");
}

QString Format::tienRutGon(qint64 soTien) {
    if (std::llabs(soTien) >= 1000000000LL)
        return viVN().toString(soTien / 1e9, 'f', 1) + QStringLiteral(" tỷ");
    if (std::llabs(soTien) >= 1000000LL)
        return viVN().toString(soTien / 1e6, 'f', 1) + QStringLiteral(" tr");
    return viVN().toString(soTien);
}

QString Format::ngay(const QDate& d) {
    return d.isValid() ? d.toString(QStringLiteral("dd/MM/yyyy")) : QString();
}

bool Format::laCotTien(const QString& tieuDe) {
    static const QStringList cot = {QStringLiteral("Học phí"),     QStringLiteral("Đã đóng"),
                                    QStringLiteral("Còn nợ"),      QStringLiteral("Doanh thu"),
                                    QStringLiteral("Đơn giá/giờ"), QStringLiteral("Thưởng"),
                                    QStringLiteral("Khấu trừ"),    QStringLiteral("Tổng lương"),
                                    QStringLiteral("Công nợ"),     QStringLiteral("Số tiền")};
    return cot.contains(tieuDe);
}

bool Format::laCotCongDon(const QString& tieuDe) {
    static const QStringList cot = {QStringLiteral("Đã đóng"), QStringLiteral("Còn nợ"), QStringLiteral("Doanh thu"),
                                    QStringLiteral("Thưởng"), QStringLiteral("Khấu trừ"), QStringLiteral("Tổng lương"),
                                    QStringLiteral("Công nợ"), QStringLiteral("Số tiền")};
    return cot.contains(tieuDe);
}

QString Format::oBang(const QVariant& v, const QString& tieuDeCot) {
    if (v.isNull() || !v.isValid())
        return QString();
    switch (v.metaType().id()) {
    case QMetaType::QDate:
        return ngay(v.toDate());
    case QMetaType::QDateTime:
        return v.toDateTime().toString(QStringLiteral("dd/MM/yyyy HH:mm"));
    case QMetaType::Double:
    case QMetaType::Float: {
        const double d = v.toDouble();
        if (laCotTien(tieuDeCot))
            return tien(static_cast<qint64>(std::llround(d)));
        if (std::floor(d) == d)
            return viVN().toString(static_cast<qint64>(d));
        return viVN().toString(d, 'f', 2);
    }
    case QMetaType::Int:
    case QMetaType::LongLong:
    case QMetaType::UInt:
    case QMetaType::ULongLong:
        return laCotTien(tieuDeCot) ? tien(v.toLongLong()) : v.toString();
    default:
        return v.toString();
    }
}
