#pragma once

#include <QString>

// One choice of a combo box filled from the database (a course, a teacher, a room, a promotion...): the key
// the procedures need (id) and the text the user reads (name). The combo shows the name and keeps the id as
// item data. detail is an optional stored database value (e.g. the position of an employee): the presentation
// shows it with its label (DbValues), never the English value itself.
struct LookupItem {
    QString id;
    QString name;
    // A default, so {id, name} stays a complete initializer (-Wmissing-field-initializers)
    QString detail = {};
};
