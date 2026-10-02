#pragma once

#include <QList>
#include <QStringList>
#include <QVariant>

// Tabular data (column keys + rows) for read-only lookup screens and reports.
// `columns` holds column KEYS = the column names of the database view/procedure (e.g. "ClassId", "Balance"),
// not display text: the presentation layer looks the key up in its column catalog (Columns) to get a
// localized header and the formatting rules.
struct TableData {
    QStringList columns;
    QList<QVariantList> rows;
};
