#include "presentation/common/Icons.h"

#include <QFile>
#include <QGuiApplication>
#include <QPainter>
#include <QPixmap>
#include <QSvgRenderer>

QPixmap Icons::pixmap(const QString& name, const QString& color, int size) {
    QFile f(QStringLiteral(":/icons/%1.svg").arg(name));
    if (!f.open(QIODevice::ReadOnly))
        return {};
    QByteArray svg = f.readAll();
    svg.replace("currentColor", color.toUtf8());

    const qreal ratio = qGuiApp ? qGuiApp->devicePixelRatio() : 1.0;
    QPixmap pm(QSize(size, size) * ratio);
    pm.fill(Qt::transparent);
    QSvgRenderer renderer(svg);
    QPainter painter(&pm);
    renderer.render(&painter);
    painter.end();
    pm.setDevicePixelRatio(ratio);
    return pm;
}

QIcon Icons::get(const QString& name, const QString& color, int size) {
    return QIcon(pixmap(name, color, size));
}
