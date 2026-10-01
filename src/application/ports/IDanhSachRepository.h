#pragma once

#include "domain/common/Result.h"
#include "domain/common/TableData.h"

// Các danh sách tra cứu chỉ đọc (mỗi loại tương ứng một view/thủ tục trong CSDL)
enum class LoaiDanhSach {
    LopHoc,          // vw_LopHoc_ChiTiet
    LichHocTuanNay,  // vw_BuoiHoc_ChiTiet
    CongNo,          // vw_CongNo
    KetQuaHocTap,    // vw_KetQuaHocTap
    DoanhThuThang,   // vw_DoanhThuThang
    BangLuong,       // BANGLUONG
    TaiKhoan,        // usp_TaiKhoan_DanhSach
    LopCuaToi,       // vw_GV_LopCuaToi
    LichDayCuaToi,   // vw_GV_LichDayCuaToi
    LuongCuaToi      // vw_GV_LuongCuaToi
};

class IDanhSachRepository {
public:
    virtual ~IDanhSachRepository() = default;
    virtual Result<TableData> layDanhSach(LoaiDanhSach loai) = 0;
};
