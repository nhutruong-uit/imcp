#pragma once

#include "application/ports/ICatalogRepository.h"
#include "infrastructure/db/DatabaseManager.h"

#include <QCoreApplication>

// Implements the port ICatalogRepository: branches, rooms, programs and promotions. Reads the tables directly
// (BRANCH, PROGRAM and ROOM are granted to the roles that use the combo boxes; the manager reads every table)
// and writes through the procedures of group J (usp_Branch_Add ... usp_Promotion_Update).
class SqlCatalogRepository : public ICatalogRepository {
    Q_DECLARE_TR_FUNCTIONS(SqlCatalogRepository)
public:
    explicit SqlCatalogRepository(DatabaseManager& db);
    Result<QList<Branch>> branches() override;
    Result<TableData> branchList() override;
    Result<Branch> branch(const QString& id) override;
    VoidResult addBranch(const Branch& b) override;
    VoidResult updateBranch(const Branch& b) override;
    Result<TableData> roomList(const QString& branchId) override;
    Result<Room> room(const QString& id) override;
    VoidResult addRoom(const Room& r) override;
    VoidResult updateRoom(const Room& r) override;
    Result<TableData> programList() override;
    Result<QList<LookupItem>> programOptions() override;
    Result<Program> program(const QString& id) override;
    VoidResult addProgram(const Program& p) override;
    VoidResult updateProgram(const Program& p) override;
    Result<TableData> promotionList() override;
    Result<Promotion> promotion(const QString& id) override;
    VoidResult addPromotion(const Promotion& p) override;
    VoidResult updatePromotion(const Promotion& p) override;

private:
    DatabaseManager& m_db;
};
