#include "presentation/dashboard/RevenueChart.h"

#include "presentation/common/Format.h"

#include <QDate>
#include <QPainter>
#include <QPainterPath>

#include <algorithm>

RevenueChart::RevenueChart(QWidget* parent) : QWidget(parent) {
    setMinimumHeight(260);
}

void RevenueChart::setDuLieu(const QList<DoanhThuThang>& duLieu) {
    m_duLieu = duLieu;
    m_thongBao.clear();
    update();
}

void RevenueChart::setThongBao(const QString& thongBao) {
    m_duLieu.clear();
    m_thongBao = thongBao;
    update();
}

void RevenueChart::paintEvent(QPaintEvent*) {
    QPainter p(this);
    p.setRenderHint(QPainter::Antialiasing);
    const QRectF vung = rect().adjusted(56, 16, -16, -32);

    if (!m_thongBao.isEmpty() || m_duLieu.isEmpty()) {
        p.setPen(QColor(0x64, 0x74, 0x8B));
        p.drawText(rect(), Qt::AlignCenter, m_thongBao.isEmpty() ? QStringLiteral("Chưa có dữ liệu") : m_thongBao);
        return;
    }

    qint64 lonNhat = 1;
    for (const auto& d : m_duLieu)
        lonNhat = std::max(lonNhat, d.doanhThu);

    // Lưới ngang + nhãn trục tung
    p.setFont(QFont(font().family(), 8));
    for (int i = 0; i <= 4; ++i) {
        const qreal y = vung.bottom() - vung.height() * i / 4.0;
        p.setPen(QPen(QColor(0xE2, 0xE8, 0xF0), 1));
        p.drawLine(QPointF(vung.left(), y), QPointF(vung.right(), y));
        p.setPen(QColor(0x94, 0xA3, 0xB8));
        p.drawText(QRectF(0, y - 8, vung.left() - 8, 16), Qt::AlignRight | Qt::AlignVCenter,
                   Format::tienRutGon(lonNhat * i / 4));
    }

    const int thangHienTai = QDate::currentDate().month();
    const qreal oRong = vung.width() / 12.0;
    for (const auto& d : m_duLieu) {
        if (d.thang < 1 || d.thang > 12)
            continue;
        const qreal cao = vung.height() * static_cast<double>(d.doanhThu) / static_cast<double>(lonNhat);
        const QRectF cot(vung.left() + oRong * (d.thang - 1) + oRong * 0.2, vung.bottom() - cao, oRong * 0.6, cao);
        QPainterPath path;
        path.addRoundedRect(cot, 4, 4);
        p.fillPath(path, d.thang == thangHienTai ? QColor(0x1F, 0x38, 0x64) : QColor(0x2E, 0x75, 0xB6));
        p.setPen(QColor(0x64, 0x74, 0x8B));
        p.drawText(QRectF(cot.left() - 10, vung.bottom() + 6, cot.width() + 20, 18), Qt::AlignCenter,
                   QStringLiteral("T%1").arg(d.thang));
        if (d.doanhThu > 0) {
            p.setPen(QColor(0x33, 0x41, 0x55));
            p.drawText(QRectF(cot.left() - 14, cot.top() - 18, cot.width() + 28, 16), Qt::AlignCenter,
                       Format::tienRutGon(d.doanhThu));
        }
    }
}
