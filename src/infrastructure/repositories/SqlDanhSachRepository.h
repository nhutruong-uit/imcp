#pragma once

#include "application/ports/IDanhSachRepository.h"
#include "infrastructure/db/DatabaseManager.h"

// Các danh sách chỉ đọc: mỗi loại là một câu SELECT trên view (đã được GRANT cho role tương ứng)
class SqlDanhSachRepository : public IDanhSachRepository {
public:
    explicit SqlDanhSachRepository(DatabaseManager& db);
    Result<TableData> layDanhSach(LoaiDanhSach loai) override;

private:
    DatabaseManager& m_db;
};
