#include "app/AppContainer.h"
#include "presentation/common/Icons.h"
#include "presentation/common/Theme.h"
#include "presentation/login/LoginDialog.h"
#include "presentation/main/MainWindow.h"

#include <QApplication>

int main(int argc, char* argv[]) {
    QApplication app(argc, argv);
    QApplication::setOrganizationName(QStringLiteral("UIT-IE103"));
    QApplication::setApplicationName(QStringLiteral("QLTTTA"));
    QApplication::setApplicationDisplayName(QStringLiteral("Quản lý Trung tâm Tiếng Anh"));
    QApplication::setApplicationVersion(QStringLiteral(QLTTTA_VERSION));
    QApplication::setWindowIcon(Icons::get(QStringLiteral("logo"), QStringLiteral("#1F3864"), 64));
    Theme::apply(app);

    AppContainer container;

    // Vòng lặp: Đăng nhập -> Cửa sổ chính -> (Đăng xuất) -> Đăng nhập lại
    for (;;) {
        LoginDialog login(container.auth());
        if (login.exec() != QDialog::Accepted)
            return 0;

        bool dangXuat = false;
        {
            MainWindow window(container.services());
            QObject::connect(&window, &MainWindow::yeuCauDangXuat, &window, [&] {
                dangXuat = true;
                window.close();
            });
            window.show();
            app.exec();
        }
        container.auth().dangXuat();
        if (!dangXuat)
            return 0;
    }
}
