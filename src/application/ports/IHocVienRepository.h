#pragma once

#include "domain/common/Result.h"
#include "domain/entities/HocVien.h"

#include <QList>

class IHocVienRepository {
public:
    virtual ~IHocVienRepository() = default;
    virtual Result<QList<HocVien>> timKiem(const BoLocHocVien& boLoc) = 0;
    virtual Result<HocVien> layTheoMa(const QString& maHV) = 0;
    virtual Result<QString> them(const HocVien& hocVien) = 0;   // trả về mã học viên mới
    virtual VoidResult capNhat(const HocVien& hocVien) = 0;
    virtual VoidResult xoa(const QString& maHV) = 0;
};
