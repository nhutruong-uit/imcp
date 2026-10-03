#pragma once

#include <QString>

// A branch of the center (table BRANCH). Read by SqlCatalogRepository::branches for the branch combo boxes of
// the student list (filter) and the student form.
struct Branch {
    QString id;
    QString name;
};
