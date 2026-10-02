#pragma once

#include "domain/common/Result.h"
#include "domain/entities/Student.h"

#include <QList>

class IStudentRepository {
public:
    virtual ~IStudentRepository() = default;
    virtual Result<QList<Student>> search(const StudentFilter& filter) = 0;
    virtual Result<Student> findById(const QString& id) = 0;
    virtual Result<QString> add(const Student& student) = 0; // returns the new student ID
    virtual VoidResult update(const Student& student) = 0;
    virtual VoidResult remove(const QString& id) = 0;
};
