#pragma once

#include "application/services/Permissions.h"
#include "domain/entities/Language.h"
#include "domain/entities/Role.h"

#include <QString>

// How a feature appears in the menu
struct FeatureInfo {
    Feature feature;
    QString name;  // in the UI language
    QString icon;  // file name in resources/icons (without .svg)
    QString group; // menu group
};

// Display text for the CODES of the inner layers. Domain/application only keep codes (Role, Feature);
// which words to show, in which language, is a UI decision. Every function returns text in the current UI
// language. Values stored in the database are handled by DbValues, column titles by Columns.
namespace Labels {
QString role(Role role);
FeatureInfo feature(Feature feature);

// Language name written in that language ("Tiếng Việt", "English"), never translated, so users always find it
QString language(Language language);
} // namespace Labels
