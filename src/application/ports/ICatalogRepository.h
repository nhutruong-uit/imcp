#pragma once

#include "domain/common/Lookup.h"
#include "domain/common/Result.h"
#include "domain/common/TableData.h"
#include "domain/entities/Catalog.h"

#include <QList>

// Reference data of the center: branches, rooms, programs, promotions.
// Port (interface, see IStudentRepository.h): implemented by SqlCatalogRepository (reads the tables, writes
// through the procedures of group J), faked in tst_application.cpp, used by StudentService::branches and
// CatalogService.
class ICatalogRepository {
public:
    virtual ~ICatalogRepository() = default;
    virtual Result<QList<Branch>> branches() = 0; // active branches, ordered by ID (combo boxes)

    virtual Result<TableData> branchList() = 0; // every branch, with its number of rooms and active classes
    virtual Result<Branch> branch(const QString& id) = 0;
    virtual VoidResult addBranch(const Branch& b) = 0;    // usp_Branch_Add
    virtual VoidResult updateBranch(const Branch& b) = 0; // usp_Branch_Update

    virtual Result<TableData> roomList(const QString& branchId) = 0;
    virtual Result<Room> room(const QString& id) = 0;
    virtual VoidResult addRoom(const Room& r) = 0;
    virtual VoidResult updateRoom(const Room& r) = 0;

    virtual Result<TableData> programList() = 0;
    virtual Result<QList<LookupItem>> programOptions() = 0;
    virtual Result<Program> program(const QString& id) = 0;
    virtual VoidResult addProgram(const Program& p) = 0;
    virtual VoidResult updateProgram(const Program& p) = 0;

    virtual Result<TableData> promotionList() = 0;
    virtual Result<Promotion> promotion(const QString& id) = 0;
    virtual VoidResult addPromotion(const Promotion& p) = 0;
    virtual VoidResult updatePromotion(const Promotion& p) = 0;
};
