#pragma once

#include "application/ports/IStudentRepository.h"
#include "infrastructure/db/DatabaseManager.h"

#include <QCoreApplication>

// IStudentRepository implemented with the usp_Student_* procedures of SQL Server
class SqlStudentRepository : public IStudentRepository {
    Q_DECLARE_TR_FUNCTIONS(SqlStudentRepository)
public:
    explicit SqlStudentRepository(DatabaseManager& db);
    Result<QList<Student>> search(const StudentFilter& filter) override;
    Result<Student> findById(const QString& id) override;
    Result<QString> add(const Student& student) override;
    VoidResult update(const Student& student) override;
    VoidResult remove(const QString& id) override;

private:
    DatabaseManager& m_db;
};
