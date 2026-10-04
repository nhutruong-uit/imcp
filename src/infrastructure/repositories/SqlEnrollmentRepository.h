#pragma once

#include "application/ports/IEnrollmentRepository.h"
#include "infrastructure/db/DatabaseManager.h"

#include <QCoreApplication>

// IEnrollmentRepository with SQL Server: usp_Enrollment_Search / _Create / _TransferClass / _UpdateStatus,
// the open classes of vw_ClassDetails and the valid promotions (PROMOTION is granted to academic staff).
class SqlEnrollmentRepository : public IEnrollmentRepository {
    Q_DECLARE_TR_FUNCTIONS(SqlEnrollmentRepository)
public:
    explicit SqlEnrollmentRepository(DatabaseManager& db);
    Result<TableData> search(const EnrollmentFilter& filter) override;
    Result<QString> enroll(const EnrollmentRequest& request) override;
    VoidResult transfer(const QString& enrollmentId, const QString& newClassId) override;
    VoidResult changeStatus(const QString& enrollmentId, const QString& status) override;
    Result<QList<ClassOption>> openClasses() override;
    Result<QList<LookupItem>> promotionOptions(const QDate& date) override;

private:
    DatabaseManager& m_db;
};
