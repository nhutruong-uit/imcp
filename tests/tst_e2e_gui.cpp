// Kiểm thử end-to-end qua GIAO DIỆN với CSDL thật: gõ phím/bấm nút trên chính các màn hình của ứng dụng.
// Cần CSDL QLTTTA đã nạp dữ liệu mẫu. Bỏ qua (SKIP) nếu không đặt biến môi trường:
//   QLTTTA_E2E_PASSWORD  mật khẩu chung của tài khoản demo (docs/SETUP.md)
//   QLTTTA_SERVER        máy chủ SQL Server (mặc định localhost,1433)
// Chạy: QLTTTA_E2E_PASSWORD='...' ctest --preset macos-debug -R e2e --output-on-failure
#include "app/AppContainer.h"
#include "application/services/PhanQuyen.h"
#include "presentation/common/Format.h"
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
#include <QStackedWidget>
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

// Vừa mở cửa sổ chính: phải chọn sẵn chức năng đầu tiên (không phải dòng tiêu đề nhóm) và có tiêu đề trang
bool moSanTrangDau(MainWindow& w, VaiTro vt) {
    auto* nav = w.findChild<QListWidget*>(QStringLiteral("NavList"));
    auto* tieuDe = w.findChild<QLabel*>(QStringLiteral("HeaderTitle"));
    const ChucNang dau = PhanQuyen::chucNangDuocPhep(vt).first();
    return nav && nav->currentItem() && nav->currentItem()->data(Qt::UserRole).toInt() == static_cast<int>(dau)
           && tieuDe && tieuDe->text() == PhanQuyen::thongTin(dau).ten;
}

// Bắt mọi hộp thoại thông báo (QMessageBox) bật lên trong lúc kiểm thử: ghi lại nội dung rồi đóng,
// để bài test không bị treo và biết màn hình nào đã báo lỗi
class BatHopThoai {
public:
    BatHopThoai() {
        m_dongHo.setInterval(100);
        QObject::connect(&m_dongHo, &QTimer::timeout, [this] {
            if (auto* hop = qobject_cast<QMessageBox*>(QApplication::activeModalWidget())) {
                m_noiDung << hop->text();
                hop->done(0);
            }
        });
        m_dongHo.start();
    }
    const QStringList& noiDung() const { return m_noiDung; }

private:
    QTimer m_dongHo;
    QStringList m_noiDung;
};

// Cột có tiêu đề cho trước trong bảng (-1 nếu không có)
int cotTheoTieuDe(const QAbstractItemModel* model, const QString& tieuDe) {
    for (int c = 0; c < model->columnCount(); ++c)
        if (model->headerData(c, Qt::Horizontal).toString() == tieuDe)
            return c;
    return -1;
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
        QVERIFY(moSanTrangDau(w, VaiTro::GiaoVu));
        // Giáo vụ không được xem doanh thu: CSDL trả NULL, thẻ KPI ghi "Không có quyền"
        auto* kpiDoanhThu = timTheoVaiTro<QLabel>(&w, QStringLiteral("kpiDoanhThu"));
        QVERIFY(kpiDoanhThu);
        QCOMPARE(kpiDoanhThu->text(), QStringLiteral("Không có quyền"));

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
        QVERIFY(moSanTrangDau(w, VaiTro::GiaoVien));

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
        QVERIFY(moSanTrangDau(w, VaiTro::KeToan));
        auto* kpiDoanhThu = timTheoVaiTro<QLabel>(&w, QStringLiteral("kpiDoanhThu"));
        QVERIFY(kpiDoanhThu);
        QVERIFY2(kpiDoanhThu->text().at(0).isDigit(), qPrintable(kpiDoanhThu->text()));   // vd "5.000.000 ₫"

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

    // Sai mật khẩu hiện tại: SQL Server từ chối ALTER USER ... OLD_PASSWORD, thủ tục báo lỗi tiếng Việt
    void doiMatKhau_saiMatKhauHienTai_baoLoi() {
        QVERIFY(dangNhap(QStringLiteral("gvu_ha"), m_matKhau));
        ChangePasswordDialog dlg(m_app->auth());
        dlg.show();
        const auto o = dlg.findChildren<QLineEdit*>();
        QCOMPARE(o.size(), 3);
        QTest::keyClicks(o[0], QStringLiteral("SaiMatKhau@1"));
        QTest::keyClicks(o[1], QStringLiteral("MatKhauMoi@1"));
        QTest::keyClicks(o[2], QStringLiteral("MatKhauMoi@1"));
        dlg.findChild<QDialogButtonBox*>()->button(QDialogButtonBox::Save)->click();
        QVERIFY(dlg.isVisible());
        QString loi;
        for (QLabel* l : dlg.findChildren<QLabel*>(QStringLiteral("ErrorText")))
            if (!l->isHidden())
                loi = l->text();
        QCOMPARE(loi, QStringLiteral("Mật khẩu hiện tại không đúng."));
    }

    // Mỗi vai trò mở lần lượt MỌI chức năng được phép: đúng tiêu đề, có dữ liệu, không báo lỗi.
    // Bắt được cả lỗi phân quyền ở CSDL (thiếu GRANT trong 06_security.sql thì trang sẽ rỗng/báo lỗi).
    void moiVaiTro_moMoiChucNang_coDuLieu_data() {
        QTest::addColumn<QString>("taiKhoan");
        QTest::addColumn<int>("vaiTro");
        QTest::newRow("quan_ly") << QStringLiteral("ql_quan") << static_cast<int>(VaiTro::QuanLy);
        QTest::newRow("giao_vu") << QStringLiteral("gvu_lan") << static_cast<int>(VaiTro::GiaoVu);
        QTest::newRow("ke_toan") << QStringLiteral("kt_minh") << static_cast<int>(VaiTro::KeToan);
        QTest::newRow("giao_vien") << QStringLiteral("gv_john") << static_cast<int>(VaiTro::GiaoVien);
    }

    void moiVaiTro_moMoiChucNang_coDuLieu() {
        QFETCH(QString, taiKhoan);
        QFETCH(int, vaiTro);
        const auto vt = static_cast<VaiTro>(vaiTro);
        QVERIFY(dangNhap(taiKhoan, m_matKhau));
        QCOMPARE(m_app->auth().vaiTro(), vt);

        BatHopThoai hopThoai;
        MainWindow w(m_app->services());
        w.show();
        QCOMPARE(menuHienThi(w), menuMongDoi(vt));
        auto* tieuDe = w.findChild<QLabel*>(QStringLiteral("HeaderTitle"));
        auto* noiDung = w.findChild<QStackedWidget*>(QStringLiteral("Content"));
        QVERIFY(tieuDe && noiDung);

        for (ChucNang cn : PhanQuyen::chucNangDuocPhep(vt)) {
            const QString ten = PhanQuyen::thongTin(cn).ten;
            w.moChucNang(cn);
            QCOMPARE(tieuDe->text(), ten);
            QWidget* trang = noiDung->currentWidget();
            QVERIFY(trang);
            if (cn == ChucNang::TongQuan) {
                for (QLabel* l : trang->findChildren<QLabel*>(QStringLiteral("ErrorText")))
                    QVERIFY2(l->isHidden(), qPrintable(ten + QStringLiteral(": ") + l->text()));
                continue;
            }
            QTableView* bang = nullptr;
            for (QTableView* t : trang->findChildren<QTableView*>())
                if (t->isVisible())
                    bang = t;
            QVERIFY2(bang, qPrintable(ten));
            QTRY_VERIFY2(bang->model()->rowCount() > 0,
                         qPrintable(QStringLiteral("%1 / %2: không có dữ liệu").arg(taiKhoan, ten)));
        }
        QVERIFY2(hopThoai.noiDung().isEmpty(), qPrintable(hopThoai.noiDung().join(QStringLiteral(" | "))));
    }

    // Giáo vụ sửa địa chỉ học viên qua form, kiểm tra đã lưu xuống CSDL rồi trả lại như cũ
    void giaoVu_suaHocVien_luuXuongCsdl() {
        QVERIFY(dangNhap(QStringLiteral("gvu_lan"), m_matKhau));
        MainWindow w(m_app->services());
        w.show();
        w.moChucNang(ChucNang::HocVien);
        QTableView* bang = nullptr;
        QTRY_VERIFY((bang = bangDangHien(w, QStringLiteral("bangHocVien"))) != nullptr);
        auto* tuKhoa = w.findChild<QLineEdit*>(QStringLiteral("tuKhoa"));
        goChu(tuKhoa, QStringLiteral("HV00010"));
        QTRY_COMPARE_WITH_TIMEOUT(bang->model()->rowCount(), 1, 3000);

        // Mở form Sửa, đổi ô Địa chỉ rồi bấm Lưu; trả về false nếu form không mở hoặc không đóng được
        auto suaDiaChi = [&](const QString& diaChiMoi, QString* diaChiCu) {
            bool daLuu = false;
            QTimer::singleShot(300, this, [&] {
                auto* dlg = qobject_cast<QDialog*>(QApplication::activeModalWidget());
                if (!dlg)
                    return;
                auto* o = dlg->findChild<QLineEdit*>(QStringLiteral("diaChiEdit"));
                if (diaChiCu)
                    *diaChiCu = o->text();
                o->setText(diaChiMoi);
                dlg->findChild<QDialogButtonBox*>(QStringLiteral("buttonBox"))->button(QDialogButtonBox::Save)->click();
                daLuu = !dlg->isVisible();
                if (dlg->isVisible())
                    dlg->reject();   // tránh treo nếu lưu thất bại
            });
            bang->selectRow(0);
            QTest::mouseClick(w.findChild<QPushButton*>(QStringLiteral("nutSua")), Qt::LeftButton);
            return daLuu;
        };

        const QString diaChiMoi = QStringLiteral("Số 1 đường Kiểm Thử E2E, TP. Thủ Đức");
        QString diaChiCu;
        QVERIFY(suaDiaChi(diaChiMoi, &diaChiCu));
        auto ct = m_app->services().hocVien.layChiTiet(QStringLiteral("HV00010"));
        QVERIFY2(ct.ok(), qPrintable(ct.error()));
        QCOMPARE(ct.value().diaChi, diaChiMoi);

        QVERIFY(suaDiaChi(diaChiCu, nullptr));   // trả dữ liệu mẫu về như cũ
        ct = m_app->services().hocVien.layChiTiet(QStringLiteral("HV00010"));
        QVERIFY(ct.ok());
        QCOMPARE(ct.value().diaChi, diaChiCu);
    }

    // Lọc nhanh danh sách công nợ: chỉ còn dòng khớp, dòng tổng tính lại theo các dòng đang hiển thị
    void keToan_locNhanh_dongTongTinhLai() {
        QVERIFY(dangNhap(QStringLiteral("kt_minh"), m_matKhau));
        MainWindow w(m_app->services());
        w.show();
        w.moChucNang(ChucNang::CongNo);
        QTableView* bang = nullptr;
        QTRY_VERIFY((bang = bangDangHien(w, QStringLiteral("bangDanhSach"))) != nullptr);
        const int tatCa = bang->model()->rowCount();
        QVERIFY(tatCa > 2);

        QLineEdit* loc = nullptr;
        for (QLineEdit* o : w.findChildren<QLineEdit*>(QStringLiteral("locNhanh")))
            if (o->isVisible())
                loc = o;
        QVERIFY(loc);
        goChu(loc, QStringLiteral("LH0008"));
        QTRY_VERIFY(bang->model()->rowCount() > 0 && bang->model()->rowCount() < tatCa);

        const auto* m = bang->model();
        const int cotLop = cotTheoTieuDe(m, QStringLiteral("Mã lớp"));
        const int cotNo = cotTheoTieuDe(m, QStringLiteral("Còn nợ"));
        QVERIFY(cotLop >= 0 && cotNo >= 0);
        qint64 tongNo = 0;
        for (int r = 0; r < m->rowCount(); ++r) {
            QCOMPARE(m->index(r, cotLop).data().toString(), QStringLiteral("LH0008"));
            tongNo += m->index(r, cotNo).data(Qt::UserRole).toLongLong();
        }
        QLabel* dongTong = nullptr;
        for (QLabel* l : w.findChildren<QLabel*>())
            if (l->isVisible() && l->property("vaiTro").toString() == QStringLiteral("dongTong"))
                dongTong = l;
        QVERIFY(dongTong);
        QVERIFY2(dongTong->text().startsWith(QStringLiteral("%1 dòng").arg(m->rowCount())), qPrintable(dongTong->text()));
        QVERIFY2(dongTong->text().contains(QStringLiteral("Tổng còn nợ: ") + Format::tien(tongNo)),
                 qPrintable(dongTong->text()));
    }
};

QTEST_MAIN(TestE2EGui)
#include "tst_e2e_gui.moc"
