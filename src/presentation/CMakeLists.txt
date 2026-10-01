# Tầng PRESENTATION: giao diện Qt Widgets (Menu - Form - Report).
# Chỉ gọi các service của tầng application, không truy cập CSDL trực tiếp.
add_library(qlttta_presentation STATIC
    common/Theme.h
    common/Theme.cpp
    common/Icons.h
    common/Icons.cpp
    common/Format.h
    common/Format.cpp
    common/TableDataModel.h
    common/TableDataModel.cpp
    common/TableExporter.h
    common/TableExporter.cpp
    common/UiHelpers.h
    common/UiHelpers.cpp
    login/LoginDialog.h
    login/LoginDialog.cpp
    main/AppServices.h
    main/MainWindow.h
    main/MainWindow.cpp
    main/ChangePasswordDialog.h
    main/ChangePasswordDialog.cpp
    dashboard/DashboardPage.h
    dashboard/DashboardPage.cpp
    dashboard/RevenueChart.h
    dashboard/RevenueChart.cpp
    hocvien/HocVienPage.h
    hocvien/HocVienPage.cpp
    hocvien/HocVienTableModel.h
    hocvien/HocVienTableModel.cpp
    hocvien/HocVienFormDialog.h
    hocvien/HocVienFormDialog.cpp
    hocvien/HocVienFormDialog.ui
    danhsach/DanhSachPage.h
    danhsach/DanhSachPage.cpp
)
target_link_libraries(qlttta_presentation PUBLIC qlttta_application Qt6::Widgets Qt6::Svg)
