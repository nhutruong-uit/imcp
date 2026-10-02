#pragma once

#include "domain/common/Result.h"
#include "domain/entities/ChiNhanh.h"

#include <QList>

// Danh mục dùng chung cho combobox
class IDanhMucRepository {
public:
    virtual ~IDanhMucRepository() = default;
    virtual Result<QList<ChiNhanh>> danhSachChiNhanh() = 0;
};
