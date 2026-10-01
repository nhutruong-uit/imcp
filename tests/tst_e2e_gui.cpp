// Kiểm thử end-to-end qua GIAO DIỆN với CSDL thật: gõ phím/bấm nút trên chính các màn hình của ứng dụng.
// Cần CSDL QLTTTA đã nạp dữ liệu mẫu. Bỏ qua (SKIP) nếu không đặt biến môi trường:
//   QLTTTA_E2E_PASSWORD  mật khẩu chung của tài khoản demo (docs/SETUP.md)
//   QLTTTA_SERVER        máy chủ SQL Server (mặc định localhost,1433)
// Chạy: QLTTTA_E2E_PASSWORD='...' ctest --preset macos-debug -R e2e --output-on-failure
#include "app/AppContainer.h"
#include "application/services/PhanQuyen.h"
#include "presentation/common/TableExporter.h"
#include "presentation/login/LoginDialog.h"
#include "presentation/main/ChangePasswordDialog.h"
#include "presentation/main/MainWindow.h"

#include <QApplication>
#include <QDateEdit>
#include <QDialogButtonBox>
#include <QFileInfo>
#include <QLabel>
#include <QLineEdit>
#include <QListWidget>
#include <QMessageBox>
#include <QPushButton>
#include <QTableView>
#include <QTemporaryDir>
#include <QTimer>
#include <QtTest>

#include <memory>

namespace {
// Gõ từng ký tự (kể cả tiếng Việt có dấu) như bộ gõ gửi sự kiện bàn phím có text
void goChu(QWidget* o, const QString& chu) {
    for (const QChar c : chu)
        QTest::sendKeyEvent(QTest::Click, o, Qt::Key_unknown, QString(c), Qt::NoModifier);
}

template <typename T>
T* timTheoVaiTro(QWidget* goc, const QString& vaiTro) {
    for (T* w : goc->findChildren<T*>())
        if (w->property("vaiTro").toString() == vaiTro)
            return w;
    return nullptr;
}

QStringList menuHienThi(MainWindow& w) {
    QStringList ten;
    auto* nav = w.findChild<QListWidget*>(QStringLiteral("NavList"));
    for (int i = 0; nav && i < nav->count(); ++i)
        if (nav->item(i)->data(Qt::UserRole).toInt() >= 0)
            ten << nav->item(i)->text();
    return ten;
}

QStringList menuMongDoi(VaiTro vt) {
    QStringList ten;
    for (ChucNang cn : PhanQuyen::chucNangDuocPhep(vt))
        ten << PhanQuyen::thongTin(cn).ten;
    return ten;
}

// Bảng (QTableView) đang hiển thị trên trang hiện tại của cửa sổ chính
QTableView* bangDangHien(MainWindow& w, const QString& ten) {
    for (QTableView* t : w.findChildren<QTableView*>(ten))
        if (t->isVisible())
            return t;
    return nullptr;
}
} // namespace

class TestE2EGui : public QObject {
    Q_OBJECT

private:
    std::unique_ptr<AppContainer> m_app;
    QString m_matKhau;

    // Đăng nhập bằng cách gõ vào LoginDialog và bấm nút "Đăng nhập"
    bool dangNhap(const QString& ten, const QString& matKhau, QString* loi = nullptr) {
        LoginDialog dlg(m_app->auth());
        dlg.show();
        auto* oTen = dlg.findChild<QLineEdit*>(QStringLiteral("tenDangNhap"));
        auto* oMatKhau = dlg.findChild<QLineEdit*>(QStringLiteral("matKhau"));
        auto* nut = dlg.findChild<QPushButton*>(QStringLiteral("nutDangNhap"));
        if (!oTen || !oMatKhau || !nut)
            return false;
        oTen->clear();
        oMatKhau->clear();
        QTest::keyClicks(oTen, ten);
        QTest::keyClicks(oMatKhau, matKhau);
        QTest::mouseClick(nut, Qt::LeftButton);
        if (loi) {
            auto* nhan = timTheoVaiTro<QLabel>(&dlg, QStringLiteral("loiDangNhap"));
            *loi = (nhan && !nhan->isHidden()) ? nhan->text() : QString();
        }
        return dlg.result() == QDialog::Accepted;
    }

private slots:
    void initTestCase() {
        m_matKhau = qEnvironmentVariable("QLTTTA_E2E_PASSWORD");
        if (m_matKhau.isEmpty())
            QSKIP("Chưa đặt QLTTTA_E2E_PASSWORD - bỏ qua kiểm thử giao diện với CSDL thật.");
        QApplication::setOrganizationName(QStringLiteral("UIT-IE103-E2E"));   // không đụng cấu hình thật
        m_app = std::make_unique<AppContainer>();
        CauHinhMayChu cauHinh;
        cauHinh.mayChu = qEnvironmentVariable("QLTTTA_SERVER", QStringLiteral("localhost,1433"));
        m_app->auth().luuCauHinh(cauHinh);
    }

    void cleanup() {
        if (m_app)
            m_app->auth().dangXuat();
    }

    void dangNhap_saiMatKhau_hienLoi() {
        QString loi;
        QVERIFY(!dangNhap(QStringLiteral("gvu_lan"), QStringLiteral("sai-mat-khau-123"), &loi));
        QVERIFY2(loi.contains(QStringLiteral("Sai tên đăng nhập")), qPrintable(loi));
        QVERIFY(!m_app->auth().daDangNhap());
    }

    void giaoVu_timKiem_them_xoaHocVien() {
        QVERIFY(dangNhap(QStringLiteral("gvu_lan"), m_matKhau));
        QCOMPARE(m_app->auth().vaiTro(), VaiTro::GiaoVu);

        MainWindow w(m_app->services());
        w.show();
        QCOMPARE(menuHienThi(w), menuMongDoi(VaiTro::GiaoVu));

        w.moChucNang(ChucNang::HocVien);
        QTableView* bang = nullptr;
        QTRY_VERIFY((bang = bangDangHien(w, QStringLiteral("bangHocVien"))) != nullptr);
        QTRY_VERIFY(bang->model()->rowCount() >= 72);

        // Tìm kiếm (tự chạy sau 300 ms ngừng gõ)
        auto* tuKhoa = w.findChild<QLineEdit*>(QStringLiteral("tuKhoa"));
        QVERIFY(tuKhoa);
        goChu(tuKhoa, QStringLiteral("Ngô Khánh"));
        QTRY_COMPARE_WITH_TIMEOUT(bang->model()->rowCount(), 1, 3000);
        QCOMPARE(bang->model()->index(0, 1).data().toString(), QStringLiteral("Ngô Khánh Linh"));

        // Thêm học viên 10 tuổi: lần 1 thiếu phụ huynh => form báo lỗi, lần 2 bổ sung => lưu được
        QString loiLan1;
        bool daMoForm = false;
        QTimer::singleShot(300, this, [&] {
            auto* dlg = qobject_cast<QDialog*>(QApplication::activeModalWidget());
            if (!dlg)
                return;
            daMoForm = true;
            dlg->findChild<QLineEdit*>(QStringLiteral("hoTenEdit"))->setText(QStringLiteral("Bé Kiểm Thử E2E"));
            dlg->findChild<QDateEdit*>(QStringLiteral("ngaySinhEdit"))->setDate(QDate::currentDate().addYears(-10));
            auto* luu = dlg->findChild<QDialogButtonBox*>(QStringLiteral("buttonBox"))->button(QDialogButtonBox::Save);
            luu->click();
            for (QLabel* l : dlg->findChildren<QLabel*>(QStringLiteral("ErrorText")))
                if (!l->isHidden())
                    loiLan1 = l->text();
            dlg->findChild<QLineEdit*>(QStringLiteral("tenPhuHuynhEdit"))->setText(QStringLiteral("Phụ Huynh E2E"));
            dlg->findChild<QLineEdit*>(QStringLiteral("sdtPhuHuynhEdit"))->setText(QStringLiteral("0987000111"));
            luu->click();
            if (dlg->isVisible())
                dlg->reject();   // tránh treo nếu lưu thất bại
        });
        tuKhoa->clear();
        QTest::mouseClick(w.findChild<QPushButton*>(QStringLiteral("nutThem")), Qt::LeftButton);
        QVERIFY(daMoForm);
        QVERIFY2(loiLan1.contains(QStringLiteral("phụ huynh")), qPrintable(loiLan1));

        goChu(tuKhoa, QStringLiteral("Kiểm Thử E2E"));
        QTRY_COMPARE_WITH_TIMEOUT(bang->model()->rowCount(), 1, 3000);
        const QString maMoi = bang->model()->index(0, 0).data().toString();
        QVERIFY2(maMoi.startsWith(QStringLiteral("HV")), qPrintable(maMoi));

        // Xóa học viên vừa thêm (xác nhận Yes trong hộp thoại)
        bang->selectRow(0);
        QTimer::singleShot(300, this, [] {
            if (auto* mb = qobject_cast<QMessageBox*>(QApplication::activeModalWidget()))
                mb->button(QMessageBox::Yes)->click();
        });
        QTest::mouseClick(w.findChild<QPushButton*>(QStringLiteral("nutXoa")), Qt::LeftButton);
        QTRY_COMPARE_WITH_TIMEOUT(bang->model()->rowCount(), 0, 3000);
    }

    void giaoVien_chiThayLopCuaMinh() {
        QVERIFY(dangNhap(QStringLiteral("gv_john"), m_matKhau));
        MainWindow w(m_app->services());
        w.show();
        QCOMPARE(menuHienThi(w), menuMongDoi(VaiTro::GiaoVien));

        w.moChucNang(ChucNang::LopCuaToi);
        QTableView* bang = nullptr;
        QTRY_VERIFY((bang = bangDangHien(w, QStringLiteral("bangDanhSach"))) != nullptr);
        QCOMPARE(bang->model()->rowCount(), 2);   // GV0001 dạy LH0003 và LH0008

        w.moChucNang(ChucNang::LichDayCuaToi);
        QTRY_VERIFY((bang = bangDangHien(w, QStringLiteral("bangDanhSach"))) != nullptr);
        QVERIFY(bang->model()->rowCount() > 0);
        for (int r = 0; r < bang->model()->rowCount(); ++r) {
            const QString lop = bang->model()->index(r, 3).data().toString();
            QVERIFY2(lop == QStringLiteral("LH0003") || lop == QStringLiteral("LH0008"), qPrintable(lop));
        }
    }

    void keToan_congNo_xuatPdf() {
        QVERIFY(dangNhap(QStringLiteral("kt_minh"), m_matKhau));
        MainWindow w(m_app->services());
        w.show();
        QCOMPARE(menuHienThi(w), menuMongDoi(VaiTro::KeToan));

        // Kế toán chỉ xem học viên: nút Thêm/Sửa/Xóa bị ẩn
        w.moChucNang(ChucNang::HocVien);
        QTRY_VERIFY(bangDangHien(w, QStringLiteral("bangHocVien")) != nullptr);
        QVERIFY(w.findChild<QPushButton*>(QStringLiteral("nutThem"))->isHidden());

        w.moChucNang(ChucNang::CongNo);
        QTableView* bang = nullptr;
        QTRY_VERIFY((bang = bangDangHien(w, QStringLiteral("bangDanhSach"))) != nullptr);
        QVERIFY(bang->model()->rowCount() > 0);
        QLabel* tong = nullptr;
        for (QLabel* l : w.findChildren<QLabel*>())
            if (l->property("vaiTro") == QStringLiteral("dongTong") && l->isVisible())
                tong = l;
        QVERIFY(tong);
        QVERIFY2(tong->text().contains(QStringLiteral("Tổng còn nợ")), qPrintable(tong->text()));

        QTemporaryDir thuMuc;
        const QString pdf = thuMuc.filePath(QStringLiteral("cong_no.pdf"));
        QString loi;
        QVERIFY2(TableExporter::xuatPdf(*bang->model(), QStringLiteral("Công nợ học phí"), QStringLiteral("Kế toán"),
                                        pdf, &loi), qPrintable(loi));
        QVERIFY(QFileInfo(pdf).size() > 2000);
        QVERIFY(TableExporter::xuatCsv(*bang->model(), thuMuc.filePath(QStringLiteral("cong_no.csv")), &loi));
    }

    void doiMatKhau_nhapLaiSai_baoLoi() {
        QVERIFY(dangNhap(QStringLiteral("gvu_ha"), m_matKhau));
        ChangePasswordDialog dlg(m_app->auth());
        dlg.show();
        const auto o = dlg.findChildren<QLineEdit*>();
        QCOMPARE(o.size(), 3);
        QTest::keyClicks(o[0], m_matKhau);
        QTest::keyClicks(o[1], QStringLiteral("MatKhauMoi@1"));
        QTest::keyClicks(o[2], QStringLiteral("KhongKhop@2"));
        dlg.findChild<QDialogButtonBox*>()->button(QDialogButtonBox::Save)->click();
        QVERIFY(dlg.isVisible());   // không đóng vì lỗi
        bool coLoi = false;
        for (QLabel* l : dlg.findChildren<QLabel*>(QStringLiteral("ErrorText")))
            coLoi = coLoi || (!l->isHidden() && l->text().contains(QStringLiteral("không khớp")));
        QVERIFY(coLoi);
    }
};

QTEST_MAIN(TestE2EGui)
#include "tst_e2e_gui.moc"
