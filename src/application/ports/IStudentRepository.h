#pragma once

#include "domain/common/Result.h"
#include "domain/entities/Student.h"

#include <QList>

// PORT (interface) of the reference module: the list of operations StudentService needs from storage, with no
// code. How to read it:
//   - "virtual ... = 0" = a function without a body here; a class that implements the port must provide it.
//   - Implemented by SqlStudentRepository (infrastructure, calls the usp_Student_* procedures) in the real
//     application, and by FakeStudentRepository (an in-memory list) in tests/tst_application.cpp, so the
//     business rules can be tested without SQL Server.
//   - The application layer depends only on this interface, never on the SQL class (dependency inversion).
class IStudentRepository {
public:
    virtual ~IStudentRepository() = default;
    // usp_Student_Search: keyword in ID/name/phone/guardian phone; empty filter fields = no filter
    virtual Result<QList<Student>> search(const StudentFilter& filter) = 0;
    // usp_Student_Details: the full profile of one student (for the edit form)
    virtual Result<Student> findById(const QString& id) = 0;
    virtual Result<QString> add(const Student& student) = 0; // returns the new student ID
    virtual VoidResult update(const Student& student) = 0;
    // usp_Student_Delete: refused by the database when the student has an enrollment history
    virtual VoidResult remove(const QString& id) = 0;
};
