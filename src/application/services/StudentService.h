#pragma once

#include "application/ports/ICatalogRepository.h"
#include "application/ports/IStudentRepository.h"

#include <QCoreApplication>

// Student management use case: checks the business rules before calling the repository.
// Reference module (copy this structure for a new module): StudentPage / StudentFormDialog (UI) -> this
// service -> IStudentRepository (port) -> SqlStudentRepository -> usp_Student_* procedures.
// Tested without a database in tests/tst_application.cpp (fake repository).
class StudentService {
    Q_DECLARE_TR_FUNCTIONS(StudentService)
public:
    StudentService(IStudentRepository& repository, ICatalogRepository& catalog);

    Result<QList<Student>> search(const StudentFilter& filter);
    Result<Student> details(const QString& id);
    // today is a parameter (not read inside) so the tests can choose the date the age rules use
    Result<QString> add(const Student& student, const QDate& today); // the new student ID
    VoidResult update(const Student& student, const QDate& today);
    VoidResult remove(const QString& id);
    Result<QList<Branch>> branches();

private:
    IStudentRepository& m_repository;
    ICatalogRepository& m_catalog;
};
