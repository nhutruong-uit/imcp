# Tầng DOMAIN: thực thể nghiệp vụ và quy tắc thuần túy.
# Chỉ phụ thuộc Qt Core (QString, QDate), không biết gì về CSDL hay giao diện.
add_library(qlttta_domain STATIC
    common/Result.h
    common/TableData.h
    entities/VaiTro.h
    entities/VaiTro.cpp
    entities/TaiKhoan.h
    entities/CauHinhMayChu.h
    entities/ChiNhanh.h
    entities/HocVien.h
    entities/HocVien.cpp
    entities/ThongKe.h
)
target_include_directories(qlttta_domain PUBLIC ${PROJECT_SOURCE_DIR}/src)
target_link_libraries(qlttta_domain PUBLIC Qt6::Core)
