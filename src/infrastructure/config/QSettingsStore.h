#pragma once

#include "application/ports/ISettingsStore.h"

// Settings stored with QSettings (Windows: Registry, macOS: plist file in ~/Library/Preferences)
class QSettingsStore : public ISettingsStore {
public:
    ServerConfig serverConfig() const override;
    void saveServerConfig(const ServerConfig& config) override;
    QString lastUsername() const override;
    void saveLastUsername(const QString& username) override;
    Language language() const override;
    void saveLanguage(Language language) override;
};
