#include "infrastructure/repositories/SqlCatalogRepository.h"

#include "infrastructure/db/SqlHelpers.h"

using namespace SqlHelpers;

SqlCatalogRepository::SqlCatalogRepository(DatabaseManager& db) : m_db(db) {}

// A plain SELECT is enough: every role is granted SELECT on BRANCH (06_security.sql) and nothing is written
Result<QList<Branch>> SqlCatalogRepository::branches() {
    QSqlQuery q = makeQuery(m_db.db());
    if (!q.exec(QStringLiteral(
            "SELECT BranchId, BranchName FROM dbo.BRANCH WHERE Status = N'Active' ORDER BY BranchId")))
        return Result<QList<Branch>>::failure(errorOf(q));
    QList<Branch> branches;
    while (q.next()) {
        Branch b;
        b.id = q.value(0).toString();
        b.name = q.value(1).toString();
        branches.append(b);
    }
    return Result<QList<Branch>>::success(branches);
}

Result<TableData> SqlCatalogRepository::branchList() {
    return queryTable(
        m_db,
        QStringLiteral("SELECT br.BranchId, br.BranchName, br.Address, br.Phone, br.Email, br.FoundedOn, "
                       "br.Status, (SELECT COUNT(*) FROM dbo.ROOM rm WHERE rm.BranchId = br.BranchId) "
                       "AS RoomCount, (SELECT COUNT(*) FROM dbo.CLASS cl WHERE cl.BranchId = br.BranchId "
                       "AND cl.Status IN (N'Enrolling', N'In progress')) AS ActiveClassCount "
                       "FROM dbo.BRANCH br ORDER BY br.BranchId"),
        {});
}

Result<Branch> SqlCatalogRepository::branch(const QString& id) {
    QSqlQuery q = makeQuery(m_db.db());
    if (!execPrepared(q, m_db,
                      QStringLiteral("SELECT BranchId, BranchName, Address, Phone, Email, FoundedOn, Status "
                                     "FROM dbo.BRANCH WHERE BranchId = ?"),
                      {id}))
        return Result<Branch>::failure(errorOf(q));
    if (!q.next())
        return Result<Branch>::failure(tr("Branch %1 was not found.").arg(id));
    Branch b;
    b.id = q.value(0).toString();
    b.name = q.value(1).toString();
    b.address = q.value(2).toString();
    b.phone = q.value(3).toString();
    b.email = q.value(4).toString();
    b.foundedOn = q.value(5).toDate();
    b.status = q.value(6).toString();
    return Result<Branch>::success(b);
}

VoidResult SqlCatalogRepository::addBranch(const Branch& b) {
    return execCall(
        m_db,
        QStringLiteral("EXEC dbo.usp_Branch_Add @BranchId = ?, @BranchName = ?, @Address = ?, @Phone = ?, "
                       "@Email = ?, @FoundedOn = ?"),
        {b.id, b.name, b.address, stringOrNull(b.phone), stringOrNull(b.email), dateOrNull(b.foundedOn)});
}

VoidResult SqlCatalogRepository::updateBranch(const Branch& b) {
    return execCall(m_db,
                    QStringLiteral("EXEC dbo.usp_Branch_Update @BranchId = ?, @BranchName = ?, @Address = ?, "
                                   "@Phone = ?, @Email = ?, @FoundedOn = ?, @Status = ?"),
                    {b.id, b.name, b.address, stringOrNull(b.phone), stringOrNull(b.email),
                     dateOrNull(b.foundedOn), b.status});
}

Result<TableData> SqlCatalogRepository::roomList(const QString& branchId) {
    return queryTable(m_db,
                      QStringLiteral("SELECT RoomId, RoomName, Capacity, RoomType, Status FROM dbo.ROOM "
                                     "WHERE BranchId = ? ORDER BY RoomId"),
                      {branchId});
}

Result<Room> SqlCatalogRepository::room(const QString& id) {
    QSqlQuery q = makeQuery(m_db.db());
    if (!execPrepared(
            q, m_db,
            QStringLiteral("SELECT RoomId, BranchId, RoomName, Capacity, RoomType, Status FROM dbo.ROOM "
                           "WHERE RoomId = ?"),
            {id}))
        return Result<Room>::failure(errorOf(q));
    if (!q.next())
        return Result<Room>::failure(tr("Room %1 was not found.").arg(id));
    Room r;
    r.id = q.value(0).toString();
    r.branchId = q.value(1).toString();
    r.name = q.value(2).toString();
    r.capacity = q.value(3).toInt();
    r.type = q.value(4).toString();
    r.status = q.value(5).toString();
    return Result<Room>::success(r);
}

VoidResult SqlCatalogRepository::addRoom(const Room& r) {
    return execCall(
        m_db,
        QStringLiteral("EXEC dbo.usp_Room_Add @RoomId = ?, @BranchId = ?, @RoomName = ?, @Capacity = ?, "
                       "@RoomType = ?"),
        {r.id, r.branchId, r.name, r.capacity, r.type});
}

VoidResult SqlCatalogRepository::updateRoom(const Room& r) {
    return execCall(
        m_db,
        QStringLiteral("EXEC dbo.usp_Room_Update @RoomId = ?, @BranchId = ?, @RoomName = ?, @Capacity = ?, "
                       "@RoomType = ?, @Status = ?"),
        {r.id, r.branchId, r.name, r.capacity, r.type, r.status});
}

Result<TableData> SqlCatalogRepository::programList() {
    return queryTable(
        m_db,
        QStringLiteral("SELECT pg.ProgramId, pg.ProgramName, pg.TargetLearners, pg.Description, "
                       "(SELECT COUNT(*) FROM dbo.COURSE co WHERE co.ProgramId = pg.ProgramId) "
                       "AS CourseCount FROM dbo.PROGRAM pg ORDER BY pg.ProgramId"),
        {});
}

Result<QList<LookupItem>> SqlCatalogRepository::programOptions() {
    return queryLookup(m_db,
                       QStringLiteral("SELECT ProgramId, ProgramId + N' - ' + ProgramName FROM dbo.PROGRAM "
                                      "ORDER BY ProgramId"),
                       {});
}

Result<Program> SqlCatalogRepository::program(const QString& id) {
    QSqlQuery q = makeQuery(m_db.db());
    if (!execPrepared(
            q, m_db,
            QStringLiteral("SELECT ProgramId, ProgramName, TargetLearners, Description FROM dbo.PROGRAM "
                           "WHERE ProgramId = ?"),
            {id}))
        return Result<Program>::failure(errorOf(q));
    if (!q.next())
        return Result<Program>::failure(tr("Program %1 was not found.").arg(id));
    return Result<Program>::success(
        {q.value(0).toString(), q.value(1).toString(), q.value(2).toString(), q.value(3).toString()});
}

VoidResult SqlCatalogRepository::addProgram(const Program& p) {
    return execCall(
        m_db,
        QStringLiteral("EXEC dbo.usp_Program_Add @ProgramId = ?, @ProgramName = ?, @TargetLearners = ?, "
                       "@Description = ?"),
        {p.id, p.name, stringOrNull(p.targetLearners), stringOrNull(p.description)});
}

VoidResult SqlCatalogRepository::updateProgram(const Program& p) {
    return execCall(
        m_db,
        QStringLiteral("EXEC dbo.usp_Program_Update @ProgramId = ?, @ProgramName = ?, @TargetLearners = ?, "
                       "@Description = ?"),
        {p.id, p.name, stringOrNull(p.targetLearners), stringOrNull(p.description)});
}

Result<TableData> SqlCatalogRepository::promotionList() {
    // fn_Today: "valid today" is a day of the center, whatever the time zone of the computer; a promotion
    // that starts later is Upcoming, not Expired
    return queryTable(
        m_db,
        QStringLiteral("SELECT pr.PromotionId, pr.PromotionName, pr.DiscountType, pr.DiscountValue, "
                       "pr.StartDate, pr.EndDate, CASE WHEN dbo.fn_Today() < pr.StartDate THEN N'Upcoming' "
                       "WHEN dbo.fn_Today() <= pr.EndDate THEN N'Active' ELSE N'Expired' END AS Validity, "
                       "(SELECT COUNT(*) FROM dbo.ENROLLMENT en WHERE en.PromotionId = pr.PromotionId) "
                       "AS EnrollmentCount FROM dbo.PROMOTION pr ORDER BY pr.EndDate DESC"),
        {});
}

Result<Promotion> SqlCatalogRepository::promotion(const QString& id) {
    QSqlQuery q = makeQuery(m_db.db());
    if (!execPrepared(
            q, m_db,
            QStringLiteral("SELECT PromotionId, PromotionName, DiscountType, DiscountValue, StartDate, "
                           "EndDate FROM dbo.PROMOTION WHERE PromotionId = ?"),
            {id}))
        return Result<Promotion>::failure(errorOf(q));
    if (!q.next())
        return Result<Promotion>::failure(tr("Promotion %1 was not found.").arg(id));
    Promotion p;
    p.id = q.value(0).toString();
    p.name = q.value(1).toString();
    p.discountType = q.value(2).toString();
    p.discountValue = q.value(3).toDouble();
    p.startDate = q.value(4).toDate();
    p.endDate = q.value(5).toDate();
    return Result<Promotion>::success(p);
}

VoidResult SqlCatalogRepository::addPromotion(const Promotion& p) {
    return execCall(
        m_db,
        QStringLiteral("EXEC dbo.usp_Promotion_Add @PromotionId = ?, @PromotionName = ?, @DiscountType = ?, "
                       "@DiscountValue = ?, @StartDate = ?, @EndDate = ?"),
        {p.id, p.name, p.discountType, p.discountValue, p.startDate, p.endDate});
}

VoidResult SqlCatalogRepository::updatePromotion(const Promotion& p) {
    return execCall(m_db,
                    QStringLiteral("EXEC dbo.usp_Promotion_Update @PromotionId = ?, @PromotionName = ?, "
                                   "@DiscountType = ?, @DiscountValue = ?, @StartDate = ?, @EndDate = ?"),
                    {p.id, p.name, p.discountType, p.discountValue, p.startDate, p.endDate});
}
