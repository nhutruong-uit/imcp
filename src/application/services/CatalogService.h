#pragma once

#include "application/ports/ICatalogRepository.h"

#include <QCoreApplication>

// Catalog use case (manager only): branches, rooms, programs and promotions. "save" adds a new row (isNew) or
// changes an existing one; the code of a new row is checked here and by the procedures (50091, 50092).
// Used by BranchPage, CoursePage (programs) and PromotionPage.
class CatalogService {
    Q_DECLARE_TR_FUNCTIONS(CatalogService)
public:
    explicit CatalogService(ICatalogRepository& repository);

    Result<QList<Branch>> activeBranches();
    Result<TableData> branchList();
    Result<Branch> branch(const QString& id);
    VoidResult saveBranch(const Branch& b, bool isNew);

    Result<TableData> roomList(const QString& branchId);
    Result<Room> room(const QString& id);
    VoidResult saveRoom(const Room& r, bool isNew);

    Result<TableData> programList();
    Result<QList<LookupItem>> programOptions();
    Result<Program> program(const QString& id);
    VoidResult saveProgram(const Program& p, bool isNew);

    Result<TableData> promotionList();
    Result<Promotion> promotion(const QString& id);
    VoidResult savePromotion(const Promotion& p, bool isNew);

private:
    ICatalogRepository& m_repository;
};
