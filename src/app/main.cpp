#include "app/AppContainer.h"
#include "presentation/common/Icons.h"
#include "presentation/common/Theme.h"
#include "presentation/login/LoginDialog.h"
#include "presentation/main/MainWindow.h"

#include <QApplication>
#include <QTextStream>

int main(int argc, char* argv[]) {
    QApplication app(argc, argv);
    QApplication::setOrganizationName(QStringLiteral("UIT-IE103"));
    QApplication::setApplicationName(QStringLiteral("QLTTTA"));
    QApplication::setApplicationDisplayName(QStringLiteral("Quản lý Trung tâm Tiếng Anh"));
    QApplication::setApplicationVersion(QStringLiteral(QLTTTA_VERSION));
    QApplication::setWindowIcon(Icons::get(QStringLiteral("logo"), QStringLiteral("#1F3864"), 64));
    Theme::apply(app);

    AppContainer container;

    // Chế độ chẩn đoán (không mở giao diện): QLTTTA_USER, QLTTTA_PASSWORD, tùy chọn QLTTTA_SERVER
    //   ./QLTTTA --check-connection
    if (QApplication::arguments().contains(QStringLiteral("--check-connection"))) {
        if (qEnvironmentVariableIsSet("QLTTTA_SERVER")) {
            CauHinhMayChu cauHinh = container.auth().cauHinh();
            cauHinh.mayChu = qEnvironmentVariable("QLTTTA_SERVER");
            container.auth().luuCauHinh(cauHinh);
        }
        const auto kq = container.auth().dangNhap(qEnvironmentVariable("QLTTTA_USER"),
                                                  qEnvironmentVariable("QLTTTA_PASSWORD"));
        QTextStream out(stdout);
        if (kq.ok())
            out << "OK: " << kq.value().hoTen << " (" << tenVaiTro(kq.value().vaiTro) << ")" << Qt::endl;
        else
            out << "LOI: " << kq.error() << Qt::endl;
        return kq.ok() ? 0 : 1;
    }

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
