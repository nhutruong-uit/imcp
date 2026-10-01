#pragma once

#include "application/services/AuthService.h"
#include "application/services/DanhSachService.h"
#include "application/services/HocVienService.h"
#include "application/services/ThongKeService.h"

// Gói các use case mà giao diện được phép dùng (được tạo ở composition root - src/app)
struct AppServices {
    AuthService& auth;
    HocVienService& hocVien;
    ThongKeService& thongKe;
    DanhSachService& danhSach;
};
