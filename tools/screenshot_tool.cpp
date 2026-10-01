// Chụp ảnh màn hình tự động cho báo cáo.
// Biến môi trường:
//   QLTTTA_SERVER        (mặc định localhost,1433)
//   QLTTTA_SHOT_USERS    danh sách tài khoản, cách nhau dấu phẩy (mặc định ql_quan,gvu_lan,kt_minh,gv_john)
//   QLTTTA_SHOT_PASSWORD mật khẩu chung của các tài khoản demo (bắt buộc)
//   QLTTTA_SHOT_DIR      thư mục lưu ảnh (mặc định docs/report/images/screens)
// Chạy không cần màn hình: QT_QPA_PLATFORM=offscreen ./qlttta_screenshots
#include "app/AppContainer.h"
#include "application/services/PhanQuyen.h"
#include "presentation/common/Theme.h"
#include "presentation/hocvien/HocVienFormDialog.h"
#include "presentation/login/LoginDialog.h"
#include "presentation/main/MainWindow.h"

#include <QApplication>
#include <QDir>
#include <QElapsedTimer>
#include <QTextStream>
#include <QThread>

namespace {
void cho(int ms) {
    QElapsedTimer t;
    t.start();
    while (t.elapsed() < ms) {
        QApplication::processEvents(QEventLoop::AllEvents, 20);
        QThread::msleep(10);
    }
}

QString tenFile(const QString& s) {
    static const QHash<QChar, QChar> boDau = [] {
        QHash<QChar, QChar> h;
        const QString co = QStringLiteral("àáạảãâầấậẩẫăằắặẳẵèéẹẻẽêềếệểễìíịỉĩòóọỏõôồốộổỗơờớợởỡùúụủũưừứựửữỳýỵỷỹđ");
        const QString khong = QStringLiteral("aaaaaaaaaaaaaaaaaeeeeeeeeeeeiiiiiooooooooooooooooouuuuuuuuuuuyyyyyd");
        for (int i = 0; i < co.size(); ++i)
            h.insert(co.at(i), khong.at(i));
        return h;
    }();
    QString out;
    for (QChar c : s.toLower())
        out += c.isLetterOrNumber() ? boDau.value(c, c) : QLatin1Char('_');
    return out;
}
} // namespace

int main(int argc, char* argv[]) {
    QApplication app(argc, argv);
    QApplication::setOrganizationName(QStringLiteral("UIT-IE103-Screenshots"));
    QApplication::setApplicationName(QStringLiteral("QLTTTA"));
    QApplication::setApplicationVersion(QStringLiteral(QLTTTA_VERSION));
    Theme::apply(app);
    QTextStream out(stdout);

    const QString matKhau = qEnvironmentVariable("QLTTTA_SHOT_PASSWORD");
    if (matKhau.isEmpty()) {
        out << "Thiếu biến QLTTTA_SHOT_PASSWORD\n";
        return 2;
    }
    const QString thuMuc = qEnvironmentVariable("QLTTTA_SHOT_DIR", QStringLiteral("docs/report/images/screens"));
    QDir().mkpath(thuMuc);
    const QStringList taiKhoan = qEnvironmentVariable("QLTTTA_SHOT_USERS",
                                                      QStringLiteral("ql_quan,gvu_lan,kt_minh,gv_john"))
                                     .split(QLatin1Char(','), Qt::SkipEmptyParts);

    AppContainer container;
    CauHinhMayChu cauHinh;
    cauHinh.mayChu = qEnvironmentVariable("QLTTTA_SERVER", QStringLiteral("localhost,1433"));
    container.auth().luuCauHinh(cauHinh);

    {   // Màn hình đăng nhập
        LoginDialog login(container.auth());
        login.resize(860, 520);
        login.show();
        cho(300);
        login.grab().save(QDir(thuMuc).filePath(QStringLiteral("00_dang_nhap.png")));
    }

    int loi = 0;
    for (const QString& tk : taiKhoan) {
        const auto kq = container.auth().dangNhap(tk, matKhau);
        if (!kq.ok()) {
            out << "[" << tk << "] dang nhap that bai: " << kq.error() << "\n";
            ++loi;
            continue;
        }
        out << "[" << tk << "] " << kq.value().hoTen << " - " << tenVaiTro(kq.value().vaiTro) << "\n";
        {
            MainWindow w(container.services());
            w.resize(1440, 860);
            w.show();
            int stt = 1;
            for (ChucNang cn : w.danhSachChucNang()) {
                w.moChucNang(cn);
                cho(400);
                const QString ten = QStringLiteral("%1_%2_%3.png")
                                        .arg(tk)
                                        .arg(stt++, 2, 10, QLatin1Char('0'))
                                        .arg(tenFile(PhanQuyen::thongTin(cn).ten));
                w.grab().save(QDir(thuMuc).filePath(ten));
                out << "   -> " << ten << "\n";
            }
            // Form sửa học viên (Qt Designer)
            if (PhanQuyen::duocSuaHocVien(kq.value().vaiTro)) {
                const auto hv = container.services().hocVien.layChiTiet(QStringLiteral("HV00010"));
                const auto cn = container.services().hocVien.danhSachChiNhanh();
                if (hv.ok() && cn.ok()) {
                    HocVienFormDialog dlg(container.services().hocVien, cn.value(), hv.value());
                    dlg.show();
                    cho(300);
                    dlg.grab().save(QDir(thuMuc).filePath(tk + QStringLiteral("_form_hoc_vien.png")));
                }
            }
        }
        container.auth().dangXuat();
    }
    return loi == 0 ? 0 : 1;
}
