#pragma once

#include "presentation/common/Theme.h"

#include <QIcon>
#include <QString>

// SVG icons from resources/icons, tinted on request (one icon set for light and dark backgrounds)
// The files are embedded in the program by resources/resources.qrc and read through ":/icons/<name>.svg";
// the word currentColor inside the SVG is replaced by the requested color.
namespace Icons {
QIcon get(const QString& name, const QString& color = QLatin1String(Theme::kIcon), int size = 20);
QPixmap pixmap(const QString& name, const QString& color, int size);
} // namespace Icons
