#include "presentation/common/Icons.h"

#include <QFile>
#include <QGuiApplication>
#include <QPainter>
#include <QPixmap>
#include <QSvgRenderer>

QPixmap Icons::pixmap(const QString& ten, const QString& mau, int kichThuoc) {
    QFile f(QStringLiteral(":/icons/%1.svg").arg(ten));
    if (!f.open(QIODevice::ReadOnly))
        return {};
    QByteArray svg = f.readAll();
    svg.replace("currentColor", mau.toUtf8());

    const qreal tiLe = qGuiApp ? qGuiApp->devicePixelRatio() : 1.0;
    QPixmap pm(QSize(kichThuoc, kichThuoc) * tiLe);
    pm.fill(Qt::transparent);
    QSvgRenderer renderer(svg);
    QPainter painter(&pm);
    renderer.render(&painter);
    painter.end();
    pm.setDevicePixelRatio(tiLe);
    return pm;
}

QIcon Icons::get(const QString& ten, const QString& mau, int kichThuoc) {
    return QIcon(pixmap(ten, mau, kichThuoc));
}
