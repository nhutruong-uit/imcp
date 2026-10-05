#include "presentation/backup/BackupPage.h"

#include "application/services/BackupService.h"
#include "presentation/common/UiHelpers.h"

#include <QApplication>
#include <QComboBox>
#include <QDateTime>
#include <QFormLayout>
#include <QHash>
#include <QLabel>
#include <QLineEdit>
#include <QListWidget>
#include <QPushButton>
#include <QStyle>
#include <QVBoxLayout>

BackupPage::BackupPage(AppServices services, QWidget* parent) : QWidget(parent), m_services(services) {
    auto* v = new QVBoxLayout(this);
    v->setContentsMargins(24, 20, 24, 16);
    v->setSpacing(12);

    auto* card = UiHelpers::card(this);
    auto* cv = new QVBoxLayout(card);
    cv->setContentsMargins(20, 16, 20, 16);
    auto* title = new QLabel(tr("Back up the database"), card);
    title->setObjectName(QStringLiteral("CardTitle"));
    cv->addWidget(title);
    auto* explanation =
        new QLabel(tr("FULL: the whole database. DIFF: what changed since the last full backup. LOG: "
                      "the transaction log since the last log backup (needs a full backup first). "
                      "Restore = the last FULL, then the last DIFF, then the LOG files in order."),
                   card);
    explanation->setObjectName(QStringLiteral("Muted"));
    explanation->setWordWrap(true);
    cv->addWidget(explanation);

    auto* form = new QFormLayout;
    m_type = new QComboBox(card);
    m_type->setObjectName(QStringLiteral("backupTypeCombo"));
    // The types usp_Backup accepts come from the use case; the page only gives each one its label
    const QHash<QString, QString> labels = {{QStringLiteral("FULL"), tr("Full backup (FULL)")},
                                            {QStringLiteral("DIFF"), tr("Differential backup (DIFF)")},
                                            {QStringLiteral("LOG"), tr("Transaction log backup (LOG)")}};
    for (const QString& type : BackupService::types())
        m_type->addItem(labels.value(type, type), type);
    m_folder = new QLineEdit(card);
    m_folder->setPlaceholderText(tr("Default backup folder of the server"));
    form->addRow(tr("Type"), m_type);
    form->addRow(tr("Folder on the server"), m_folder);
    cv->addLayout(form);
    auto* runButton = UiHelpers::primaryButton(tr("Run backup"), QStringLiteral("database"), card);
    runButton->setObjectName(QStringLiteral("runBackupButton"));
    cv->addWidget(runButton, 0, Qt::AlignLeft);
    m_result = new QLabel(card);
    m_result->setWordWrap(true);
    m_result->setTextInteractionFlags(Qt::TextSelectableByMouse);
    cv->addWidget(m_result);
    v->addWidget(card);

    auto* historyTitle = new QLabel(tr("Backups made in this session"), this);
    historyTitle->setObjectName(QStringLiteral("CardTitle"));
    v->addWidget(historyTitle);
    m_history = new QListWidget(this);
    v->addWidget(m_history, 1);

    connect(runButton, &QPushButton::clicked, this, &BackupPage::runBackup);
}

void BackupPage::runBackup() {
    const QString type = m_type->currentData().toString();
    QApplication::setOverrideCursor(Qt::WaitCursor);
    const auto result = m_services.backup.backup(type, m_folder->text());
    QApplication::restoreOverrideCursor();
    if (!result.ok()) {
        m_result->setObjectName(QStringLiteral("ErrorText"));
        m_result->setText(result.error());
    } else {
        m_result->setObjectName(QStringLiteral("Muted"));
        m_result->setText(tr("Backup written by SQL Server to: %1").arg(result.value()));
        m_history->insertItem(
            0, QStringLiteral("%1   %2   %3")
                   .arg(QDateTime::currentDateTime().toString(QStringLiteral("dd/MM/yyyy HH:mm")), type,
                        result.value()));
    }
    m_result->style()->unpolish(m_result); // the object name decides the style (QSS)
    m_result->style()->polish(m_result);
}
