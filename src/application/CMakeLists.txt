# Tầng APPLICATION: các use case (service) điều phối nghiệp vụ.
# Khai báo "ports" (interface) mà tầng ngoài phải hiện thực: repository, gateway đăng nhập, lưu cấu hình.
add_library(qlttta_application STATIC
    ports/IAuthGateway.h
    ports/ICauHinhStore.h
    ports/IHocVienRepository.h
    ports/IDanhMucRepository.h
    ports/IThongKeRepository.h
    ports/IDanhSachRepository.h
    services/PhanQuyen.h
    services/PhanQuyen.cpp
    services/AuthService.h
    services/AuthService.cpp
    services/HocVienService.h
    services/HocVienService.cpp
    services/ThongKeService.h
    services/ThongKeService.cpp
    services/DanhSachService.h
    services/DanhSachService.cpp
)
target_link_libraries(qlttta_application PUBLIC qlttta_domain)
