#include "presentation/common/FormDialog.h"

#include <QDialogButtonBox>
#include <QFormLayout>
#include <QKeyEvent>
#include <QLabel>
#include <QLineEdit>
#include <QPushButton>
#include <QStyle>
#include <QVBoxLayout>

FormDialog::FormDialog(const QString& title, QWidget* parent) : QDialog(parent) {
    setWindowTitle(title);
    setMinimumWidth(460);
    auto* v = new QVBoxLayout(this);
    v->setSpacing(10);
    auto* titleLabel = new QLabel(title, this);
    titleLabel->setObjectName(QStringLiteral("PageTitle"));
    titleLabel->setWordWrap(true);
    v->addWidget(titleLabel);

    m_form = new QFormLayout;
    m_form->setLabelAlignment(Qt::AlignRight | Qt::AlignVCenter);
    m_form->setFieldGrowthPolicy(QFormLayout::AllNonFixedFieldsGrow);
    v->addLayout(m_form);
    m_body = new QVBoxLayout;
    v->addLayout(m_body, 1);

    m_error = new QLabel(this);
    m_error->setObjectName(QStringLiteral("ErrorText"));
    m_error->setWordWrap(true);
    m_error->hide();
    v->addWidget(m_error);

    m_buttons = new QDialogButtonBox(QDialogButtonBox::Save | QDialogButtonBox::Cancel, this);
    m_buttons->setObjectName(QStringLiteral("buttonBox"));
    QPushButton* saveButton = m_buttons->button(QDialogButtonBox::Save);
    saveButton->setText(tr("Save"));
    saveButton->setProperty("variant", QStringLiteral("primary"));
    saveButton->style()->unpolish(saveButton); // re-apply the style sheet after changing the property
    saveButton->style()->polish(saveButton);
    m_buttons->button(QDialogButtonBox::Cancel)->setText(tr("Cancel"));
    v->addWidget(m_buttons);

    connect(m_buttons, &QDialogButtonBox::accepted, this, &FormDialog::onSave);
    connect(m_buttons, &QDialogButtonBox::rejected, this, &QDialog::reject);
}

void FormDialog::setSaveAction(std::function<VoidResult()> action) {
    m_action = std::move(action);
}

void FormDialog::setSaveText(const QString& text) {
    m_buttons->button(QDialogButtonBox::Save)->setText(text);
}

void FormDialog::hideSaveButton() {
    m_buttons->button(QDialogButtonBox::Save)->hide();
    m_buttons->button(QDialogButtonBox::Cancel)->setText(tr("Close"));
}

void FormDialog::showError(const QString& message) {
    m_error->setText(message);
    m_error->setVisible(!message.isEmpty());
}

void FormDialog::setSearchField(QLineEdit* field, std::function<void()> search) {
    m_searchFields.insert(field, std::move(search));
    field->installEventFilter(this);
}

bool FormDialog::eventFilter(QObject* watched, QEvent* event) {
    if (event->type() == QEvent::KeyPress && m_searchFields.contains(watched)) {
        const int key = static_cast<QKeyEvent*>(event)->key();
        if (key == Qt::Key_Return || key == Qt::Key_Enter) {
            if (const std::function<void()> search = m_searchFields.value(watched))
                search();
            return true; // handled here: the dialog never sees the key, so Save is not clicked
        }
    }
    return QDialog::eventFilter(watched, event);
}

bool FormDialog::save() {
    if (!m_action)
        return true;
    const VoidResult result = m_action();
    if (!result.ok()) {
        showError(result.error());
        return false;
    }
    return true;
}

void FormDialog::onSave() {
    showError(QString());
    if (save())
        accept();
}
