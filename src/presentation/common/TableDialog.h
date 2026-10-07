#pragma once

#include "domain/common/TableData.h"

#include <QDialog>

class DataTable;
class QLabel;

// Shows a list in a window of its own, with the totals line, Excel / PDF export and the print preview: the
// students or results of a class, the syllabus of a course, the result of a search... Read-only; the caller
// fills it with setData.
class TableDialog : public QDialog {
    Q_OBJECT
public:
    // preparedBy: the user name printed on the PDF report
    TableDialog(const QString& title, const QString& preparedBy, QWidget* parent = nullptr);

    void setSubtitle(const QString& text);
    void setData(TableData data);
    DataTable* table() const { return m_table; }

private:
    QString m_title;
    QString m_preparedBy;
    QLabel* m_subtitle = nullptr;
    DataTable* m_table = nullptr;
    QLabel* m_totals = nullptr;
};
