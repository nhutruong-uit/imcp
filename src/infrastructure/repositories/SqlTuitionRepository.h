#pragma once

#include "application/ports/ITuitionRepository.h"
#include "infrastructure/db/DatabaseManager.h"

#include <QCoreApplication>

// ITuitionRepository with SQL Server: usp_Receipt_Search / _Create / _Cancel / _Print and
// vw_OutstandingTuition.
class SqlTuitionRepository : public ITuitionRepository {
    Q_DECLARE_TR_FUNCTIONS(SqlTuitionRepository)
public:
    explicit SqlTuitionRepository(DatabaseManager& db);
    Result<TableData> receipts(const ReceiptFilter& filter) override;
    Result<TableData> outstanding() override;
    Result<QString> collect(const ReceiptRequest& request) override;
    VoidResult cancel(const QString& receiptId, const QString& reason) override;
    Result<ReceiptPrint> print(const QString& receiptId) override;

private:
    DatabaseManager& m_db;
};
