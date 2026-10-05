#pragma once

#include "application/services/Permissions.h"
#include "domain/entities/Account.h"
#include "domain/entities/Language.h"
#include "domain/entities/Role.h"

#include <QString>

// Groups of the menu; the sidebar compares these codes, never the translated group names
enum class FeatureGroup { General, Training, Finance, Catalog, System, Teaching };

// How a feature appears in the menu (built by Labels::feature, read by MainWindow::buildSidebar)
struct FeatureInfo {
    Feature feature;
    QString name;       // in the UI language
    QString icon;       // file name in resources/icons (without .svg)
    FeatureGroup group; // menu group (its title: Labels::group)
};

// Display text for the CODES of the inner layers. Domain/application only keep codes (Role, Feature);
// which words to show, in which language, is a UI decision. Every function returns text in the current UI
// language. Values stored in the database are handled by DbValues, column titles by Columns.
namespace Labels {
QString role(Role role);
FeatureInfo feature(Feature feature);
QString group(FeatureGroup group);

// Name of the signed-in user for the header and the reports; a database owner gets "(database administrator)"
QString accountName(const Account& account);

// Language name written in that language ("Tiếng Việt", "English"), never translated, so users always find it
QString language(Language language);
} // namespace Labels
