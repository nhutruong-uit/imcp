#include "infrastructure/config/QSettingsStore.h"

#include <QSettings>

// A missing key returns the default of ServerConfig (localhost,1433 / QLTTTA / trust the certificate)
ServerConfig QSettingsStore::serverConfig() const {
    QSettings s;
    const ServerConfig defaults;
    ServerConfig c;
    c.host = s.value(QStringLiteral("server/host"), defaults.host).toString();
    c.database = s.value(QStringLiteral("server/database"), defaults.database).toString();
    c.trustServerCertificate =
        s.value(QStringLiteral("server/trustCertificate"), defaults.trustServerCertificate).toBool();
    return c;
}

void QSettingsStore::saveServerConfig(const ServerConfig& config) {
    QSettings s;
    s.setValue(QStringLiteral("server/host"), config.host.trimmed());
    s.setValue(QStringLiteral("server/database"), config.database.trimmed());
    s.setValue(QStringLiteral("server/trustCertificate"), config.trustServerCertificate);
}

QString QSettingsStore::lastUsername() const {
    return QSettings().value(QStringLiteral("login/lastUser")).toString();
}

void QSettingsStore::saveLastUsername(const QString& username) {
    QSettings().setValue(QStringLiteral("login/lastUser"), username);
}

Language QSettingsStore::language() const {
    // Never chosen => Vietnamese (the default language of the application)
    return languageFromCode(
        QSettings().value(QStringLiteral("ui/language"), languageCode(Language::Vietnamese)).toString());
}

void QSettingsStore::saveLanguage(Language language) {
    QSettings().setValue(QStringLiteral("ui/language"), languageCode(language));
}
