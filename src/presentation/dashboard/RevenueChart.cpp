#include "presentation/dashboard/RevenueChart.h"

#include "presentation/common/Format.h"

#include <QDate>
#include <QPainter>
#include <QPainterPath>

#include <algorithm>

RevenueChart::RevenueChart(QWidget* parent) : QWidget(parent) {
    setMinimumHeight(260);
}

void RevenueChart::setData(const QList<MonthlyRevenue>& data) {
    m_data = data;
    m_message.clear();
    update();
}

void RevenueChart::setMessage(const QString& message) {
    m_data.clear();
    m_message = message;
    update();
}

void RevenueChart::paintEvent(QPaintEvent*) {
    QPainter p(this);
    p.setRenderHint(QPainter::Antialiasing);
    const QRectF area = rect().adjusted(56, 16, -16, -32);

    if (!m_message.isEmpty() || m_data.isEmpty()) {
        p.setPen(QColor(0x64, 0x74, 0x8B));
        p.drawText(rect(), Qt::AlignCenter, m_message.isEmpty() ? tr("No data yet") : m_message);
        return;
    }

    // Bars are scaled to the best month (at least 1 to avoid dividing by zero)
    qint64 maximum = 1;
    for (const auto& d : m_data)
        maximum = std::max(maximum, d.revenue);

    // Horizontal grid + y-axis labels
    p.setFont(QFont(font().family(), 8));
    for (int i = 0; i <= 4; ++i) {
        const qreal y = area.bottom() - area.height() * i / 4.0;
        p.setPen(QPen(QColor(0xE2, 0xE8, 0xF0), 1));
        p.drawLine(QPointF(area.left(), y), QPointF(area.right(), y));
        p.setPen(QColor(0x94, 0xA3, 0xB8));
        p.drawText(QRectF(0, y - 8, area.left() - 8, 16), Qt::AlignRight | Qt::AlignVCenter,
                   Format::moneyShort(maximum * i / 4));
    }

    const int currentMonth = QDate::currentDate().month();
    const qreal slotWidth = area.width() / 12.0;
    for (const auto& d : m_data) {
        if (d.month < 1 || d.month > 12)
            continue;
        const qreal height = area.height() * static_cast<double>(d.revenue) / static_cast<double>(maximum);
        const QRectF bar(area.left() + slotWidth * (d.month - 1) + slotWidth * 0.2, area.bottom() - height,
                         slotWidth * 0.6, height);
        QPainterPath path;
        path.addRoundedRect(bar, 4, 4);
        p.fillPath(path, d.month == currentMonth ? QColor(0x1F, 0x38, 0x64) : QColor(0x2E, 0x75, 0xB6));
        p.setPen(QColor(0x64, 0x74, 0x8B));
        p.drawText(QRectF(bar.left() - 10, area.bottom() + 6, bar.width() + 20, 18), Qt::AlignCenter,
                   Format::month(d.month));
        if (d.revenue > 0) {
            p.setPen(QColor(0x33, 0x41, 0x55));
            p.drawText(QRectF(bar.left() - 14, bar.top() - 18, bar.width() + 28, 16), Qt::AlignCenter,
                       Format::moneyShort(d.revenue));
        }
    }
}
