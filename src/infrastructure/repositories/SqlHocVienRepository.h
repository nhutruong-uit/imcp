#pragma once

#include "application/ports/IHocVienRepository.h"
#include "infrastructure/db/DatabaseManager.h"

// Hiện thực IHocVienRepository bằng các thủ tục usp_HocVien_* của SQL Server
class SqlHocVienRepository : public IHocVienRepository {
public:
    explicit SqlHocVienRepository(DatabaseManager& db);
    Result<QList<HocVien>> timKiem(const BoLocHocVien& boLoc) override;
    Result<HocVien> layTheoMa(const QString& maHV) override;
    Result<QString> them(const HocVien& hocVien) override;
    VoidResult capNhat(const HocVien& hocVien) override;
    VoidResult xoa(const QString& maHV) override;

private:
    DatabaseManager& m_db;
};
