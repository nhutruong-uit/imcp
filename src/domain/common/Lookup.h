#pragma once

#include <QString>

// One choice of a combo box filled from the database (a course, a teacher, a room, a promotion...): the key
// the procedures need (id) and the text the user reads (name). The combo shows the name and keeps the id as
// item data.
struct LookupItem {
    QString id;
    QString name;
};
