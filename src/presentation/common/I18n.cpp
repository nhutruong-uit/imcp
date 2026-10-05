#include "presentation/common/I18n.h"

#include "application/services/LanguageService.h"

#include <QCoreApplication>
#include <QGuiApplication>
#include <QPointer>
#include <QTranslator>

namespace {
// The language currently applied (g_ = a global of this file). English until apply() succeeds, because the
// source strings are English.
Language g_current = Language::English;

// One shared QTranslator, owned by the application object (destroyed together with QCoreApplication)
QTranslator* translator() {
    static QPointer<QTranslator> t;
    if (!t)
        t = new QTranslator(QCoreApplication::instance());
    return t;
}
} // namespace

QLocale I18n::locale(Language language) {
    switch (language) {
    case Language::Vietnamese:
        return QLocale(QLocale::Vietnamese, QLocale::Vietnam);
    case Language::English:
        break;
    }
    // British English: weeks start on Monday and dates read dd/MM, as in Vietnam
    return QLocale(QLocale::English, QLocale::UnitedKingdom);
}

bool I18n::apply(Language language) {
    QTranslator* t = translator();
    QCoreApplication::removeTranslator(t);
    bool ok = true;
    if (language != Language::English) {
        ok = t->load(QStringLiteral(":/i18n/qlttta_%1.qm").arg(languageCode(language)));
        if (ok)
            QCoreApplication::installTranslator(t);
    }
    g_current = ok ? language : Language::English;
    QLocale::setDefault(locale(g_current));
    QGuiApplication::setApplicationDisplayName(
        QCoreApplication::translate("I18n", "English Center Management"));
    return ok;
}

Language I18n::current() {
    return g_current;
}

void I18n::switchTo(LanguageService& service, Language language) {
    service.select(language);
    apply(language);
}
