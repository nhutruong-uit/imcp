#pragma once

#include "domain/common/Result.h"

#include <QDialog>
#include <QHash>
#include <functional>

class QDialogButtonBox;
class QFormLayout;
class QLabel;
class QLineEdit;
class QPushButton;
class QVBoxLayout;

// Base of the data-entry forms: a title, a form (label + field rows), room for more widgets, an error line
// and Save / Cancel. Save runs save(); on failure the error is shown in the form and the dialog stays open,
// so nothing typed is lost (the same behavior as StudentFormDialog). Two ways to use it: a subclass overrides
// save() (larger forms), or a page builds a small form in place and gives the action with setSaveAction
// (one-field prompts such as "reason for cancelling").
class FormDialog : public QDialog {
    Q_OBJECT
public:
    explicit FormDialog(const QString& title, QWidget* parent = nullptr);

    QFormLayout* form() const { return m_form; }
    QVBoxLayout* body() const { return m_body; } // widgets placed under the form
    void setSaveAction(std::function<VoidResult()> action);
    void setSaveText(const QString& text);
    void showError(const QString& message);
    // A search or filter field of the form: Return runs search (when given) and stays in the dialog.
    // QLineEdit passes Return on to the dialog after returnPressed, and the dialog would click Save.
    void setSearchField(QLineEdit* field, std::function<void()> search = {});

protected:
    virtual bool save(); // true = close the dialog (Accepted)
    bool eventFilter(QObject* watched, QEvent* event) override;

private:
    void onSave();

    QFormLayout* m_form = nullptr;
    QVBoxLayout* m_body = nullptr;
    QLabel* m_error = nullptr;
    QDialogButtonBox* m_buttons = nullptr;
    std::function<VoidResult()> m_action;
    QHash<QObject*, std::function<void()>> m_searchFields;
};
