#include "application/services/CatalogService.h"

namespace {
// Codes are compared without regard to case by the database (collation CI); upper case keeps them uniform
QString normalizedCode(const QString& code) {
    return code.trimmed().toUpper();
}

VoidResult failed(const QStringList& errors) {
    return VoidResult::failure(errors.join(QLatin1Char('\n')));
}
} // namespace

CatalogService::CatalogService(ICatalogRepository& repository) : m_repository(repository) {}

Result<QList<Branch>> CatalogService::activeBranches() {
    return m_repository.branches();
}

Result<TableData> CatalogService::branchList() {
    return m_repository.branchList();
}

Result<Branch> CatalogService::branch(const QString& id) {
    if (id.isEmpty())
        return Result<Branch>::failure(tr("No branch is selected."));
    return m_repository.branch(id);
}

VoidResult CatalogService::saveBranch(const Branch& b, bool isNew) {
    Branch c = b;
    c.id = normalizedCode(c.id);
    c.name = c.name.simplified();
    c.address = c.address.trimmed();
    c.phone = c.phone.trimmed();
    c.email = c.email.trimmed().toLower();
    const QStringList errors = c.validate(isNew);
    if (!errors.isEmpty())
        return failed(errors);
    return isNew ? m_repository.addBranch(c) : m_repository.updateBranch(c);
}

Result<TableData> CatalogService::roomList(const QString& branchId) {
    return m_repository.roomList(branchId);
}

Result<Room> CatalogService::room(const QString& id) {
    if (id.isEmpty())
        return Result<Room>::failure(tr("No room is selected."));
    return m_repository.room(id);
}

VoidResult CatalogService::saveRoom(const Room& r, bool isNew) {
    Room c = r;
    c.id = normalizedCode(c.id);
    c.name = c.name.simplified();
    const QStringList errors = c.validate(isNew);
    if (!errors.isEmpty())
        return failed(errors);
    return isNew ? m_repository.addRoom(c) : m_repository.updateRoom(c);
}

Result<TableData> CatalogService::programList() {
    return m_repository.programList();
}

Result<QList<LookupItem>> CatalogService::programOptions() {
    return m_repository.programOptions();
}

Result<Program> CatalogService::program(const QString& id) {
    if (id.isEmpty())
        return Result<Program>::failure(tr("No program is selected."));
    return m_repository.program(id);
}

VoidResult CatalogService::saveProgram(const Program& p, bool isNew) {
    Program c = p;
    c.id = normalizedCode(c.id);
    c.name = c.name.simplified();
    c.targetLearners = c.targetLearners.trimmed();
    c.description = c.description.trimmed();
    const QStringList errors = c.validate(isNew);
    if (!errors.isEmpty())
        return failed(errors);
    return isNew ? m_repository.addProgram(c) : m_repository.updateProgram(c);
}

Result<TableData> CatalogService::promotionList() {
    return m_repository.promotionList();
}

Result<Promotion> CatalogService::promotion(const QString& id) {
    if (id.isEmpty())
        return Result<Promotion>::failure(tr("No promotion is selected."));
    return m_repository.promotion(id);
}

VoidResult CatalogService::savePromotion(const Promotion& p, bool isNew) {
    Promotion c = p;
    c.id = normalizedCode(c.id);
    c.name = c.name.simplified();
    const QStringList errors = c.validate(isNew);
    if (!errors.isEmpty())
        return failed(errors);
    return isNew ? m_repository.addPromotion(c) : m_repository.updatePromotion(c);
}
