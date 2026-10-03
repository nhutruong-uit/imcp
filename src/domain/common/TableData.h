#pragma once

#include <QList>
#include <QStringList>
#include <QVariant>

// Tabular data (column keys + rows) for read-only lookup screens and reports.
// `columns` holds column KEYS = the column names of the database view/procedure (e.g. "ClassId", "Balance"),
// not display text: the presentation layer looks the key up in its column catalog (Columns) to get a
// localized header and the formatting rules.
// Flow: SqlListRepository::fetch fills it from the query result -> ListService returns it -> ListPage shows
// it through TableDataModel. rows[r][c] is the raw value (number, date, text) of row r, column c.
struct TableData {
    QStringList columns;
    QList<QVariantList> rows;
};
