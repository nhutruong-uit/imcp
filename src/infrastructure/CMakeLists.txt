# Tầng INFRASTRUCTURE: hiện thực các port của tầng application bằng Qt SQL (ODBC -> SQL Server)
# và QSettings. Mọi câu SQL của ứng dụng nằm ở đây.
add_library(qlttta_infrastructure STATIC
    db/DatabaseManager.h
    db/DatabaseManager.cpp
    db/SqlErrorMapper.h
    db/SqlErrorMapper.cpp
    db/SqlHelpers.h
    config/QSettingsCauHinhStore.h
    config/QSettingsCauHinhStore.cpp
    repositories/SqlAuthGateway.h
    repositories/SqlAuthGateway.cpp
    repositories/SqlHocVienRepository.h
    repositories/SqlHocVienRepository.cpp
    repositories/SqlDanhMucRepository.h
    repositories/SqlDanhMucRepository.cpp
    repositories/SqlThongKeRepository.h
    repositories/SqlThongKeRepository.cpp
    repositories/SqlDanhSachRepository.h
    repositories/SqlDanhSachRepository.cpp
)
target_link_libraries(qlttta_infrastructure PUBLIC qlttta_application Qt6::Sql)
