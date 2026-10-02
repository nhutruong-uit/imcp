#pragma once

#include "application/ports/ICatalogRepository.h"
#include "application/ports/IStudentRepository.h"

#include <QCoreApplication>

// Student management use case: checks the business rules before calling the repository
class StudentService {
    Q_DECLARE_TR_FUNCTIONS(StudentService)
public:
    StudentService(IStudentRepository& repository, ICatalogRepository& catalog);

    Result<QList<Student>> search(const StudentFilter& filter);
    Result<Student> details(const QString& id);
    Result<QString> add(const Student& student, const QDate& today);
    VoidResult update(const Student& student, const QDate& today);
    VoidResult remove(const QString& id);
    Result<QList<Branch>> branches();

private:
    IStudentRepository& m_repository;
    ICatalogRepository& m_catalog;
};
