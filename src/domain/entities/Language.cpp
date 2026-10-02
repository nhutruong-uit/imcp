#include "domain/entities/Language.h"

QList<Language> supportedLanguages() {
    return {Language::Vietnamese, Language::English};
}

QString languageCode(Language language) {
    switch (language) {
    case Language::Vietnamese:
        return QStringLiteral("vi");
    case Language::English:
        return QStringLiteral("en");
    }
    return QStringLiteral("vi");
}

Language languageFromCode(const QString& code) {
    const QString c = code.trimmed().toLower();
    if (c == QLatin1String("en") || c.startsWith(QLatin1String("en_")))
        return Language::English;
    return Language::Vietnamese;
}
