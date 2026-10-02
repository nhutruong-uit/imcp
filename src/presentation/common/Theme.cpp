#include "presentation/common/Theme.h"

#include <QApplication>
#include <QFile>
#include <QPalette>
#include <QStyleFactory>

void Theme::apply(QApplication& app) {
    app.setStyle(QStyleFactory::create(QStringLiteral("Fusion")));

    // Always use the light palette so the UI looks the same even when the OS is in Dark Mode
    QPalette p;
    p.setColor(QPalette::Window, QColor(0xF4, 0xF6, 0xFA));
    p.setColor(QPalette::WindowText, QColor(0x1E, 0x29, 0x3B));
    p.setColor(QPalette::Base, Qt::white);
    p.setColor(QPalette::AlternateBase, QColor(0xF8, 0xFA, 0xFC));
    p.setColor(QPalette::Text, QColor(0x1E, 0x29, 0x3B));
    p.setColor(QPalette::Button, Qt::white);
    p.setColor(QPalette::ButtonText, QColor(0x1E, 0x29, 0x3B));
    p.setColor(QPalette::Highlight, QColor(0xDB, 0xEA, 0xFE));
    p.setColor(QPalette::HighlightedText, QColor(0x0F, 0x17, 0x2A));
    p.setColor(QPalette::ToolTipBase, QColor(0x1F, 0x38, 0x64));
    p.setColor(QPalette::ToolTipText, Qt::white);
    p.setColor(QPalette::PlaceholderText, QColor(0x94, 0xA3, 0xB8));
    p.setColor(QPalette::Disabled, QPalette::Text, QColor(0x94, 0xA3, 0xB8));
    p.setColor(QPalette::Disabled, QPalette::ButtonText, QColor(0x94, 0xA3, 0xB8));
    app.setPalette(p);

    QFile qss(QStringLiteral(":/styles/app.qss"));
    if (qss.open(QIODevice::ReadOnly | QIODevice::Text))
        app.setStyleSheet(QString::fromUtf8(qss.readAll()));
}
