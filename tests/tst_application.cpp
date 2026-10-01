#include "application/services/AuthService.h"
#include "application/services/HocVienService.h"
#include "application/services/PhanQuyen.h"

#include <QtTest>

// ===== Đối tượng giả (fake) thay cho SQL Server =====
class FakeHocVienRepository : public IHocVienRepository {
public:
    QList<HocVien> duLieu;
    int soLanThem = 0;

    Result<QList<HocVien>> timKiem(const BoLocHocVien&) override { return Result<QList<HocVien>>::success(duLieu); }
    Result<HocVien> layTheoMa(const QString& ma) override {
        for (const auto& hv : duLieu)
            if (hv.maHV == ma)
                return Result<HocVien>::success(hv);
        return Result<HocVien>::failure(QStringLiteral("Không tìm thấy"));
    }
    Result<QString> them(const HocVien& hv) override {
        ++soLanThem;
        HocVien moi = hv;
        moi.maHV = QStringLiteral("HV%1").arg(duLieu.size() + 1, 5, 10, QLatin1Char('0'));
        duLieu.append(moi);
        return Result<QString>::success(moi.maHV);
    }
    VoidResult capNhat(const HocVien&) override { return VoidResult::success(); }
    VoidResult xoa(const QString&) override { return VoidResult::success(); }
};

class FakeDanhMuc : public IDanhMucRepository {
public:
    Result<QList<ChiNhanh>> danhSachChiNhanh() override {
        return Result<QList<ChiNhanh>>::success({{QStringLiteral("CN01"), QStringLiteral("Quận 1")}});
    }
};

class FakeAuthGateway : public IAuthGateway {
public:
    Result<TaiKhoan> dangNhap(const CauHinhMayChu&, const QString& ten, const QString& mk) override {
        if (ten == QStringLiteral("gvu_lan") && mk == QStringLiteral("dung-mat-khau")) {
            TaiKhoan tk;
            tk.tenDangNhap = ten;
            tk.vaiTro = VaiTro::GiaoVu;
            tk.hoTen = QStringLiteral("Lê Thị Lan");
            return Result<TaiKhoan>::success(tk);
        }
        return Result<TaiKhoan>::failure(QStringLiteral("Sai tên đăng nhập hoặc mật khẩu"));
    }
    void dangXuat() override {}
    VoidResult doiMatKhau(const QString&, const QString&) override { return VoidResult::success(); }
};

class FakeStore : public ICauHinhStore {
public:
    CauHinhMayChu cauHinh;
    QString ten;
    CauHinhMayChu docCauHinh() const override { return cauHinh; }
    void luuCauHinh(const CauHinhMayChu& c) override { cauHinh = c; }
    QString tenDangNhapGanNhat() const override { return ten; }
    void luuTenDangNhap(const QString& t) override { ten = t; }
};

class TestApplication : public QObject {
    Q_OBJECT

private slots:
    void themHocVien_hopLe_goiRepository() {
        FakeHocVienRepository repo;
        FakeDanhMuc dm;
        HocVienService service(repo, dm);
        HocVien hv;
        hv.hoTen = QStringLiteral("  Trần   Thị  Bích  ");
        hv.ngaySinh = QDate(2001, 3, 4);
        hv.gioiTinh = QStringLiteral("Nữ");
        hv.soDienThoai = QStringLiteral("0909000111");
        hv.maCN = QStringLiteral("CN01");
        const auto kq = service.themMoi(hv, QDate(2026, 10, 1));
        QVERIFY2(kq.ok(), qPrintable(kq.error()));
        QCOMPARE(repo.soLanThem, 1);
        QCOMPARE(repo.duLieu.first().hoTen, QStringLiteral("Trần Thị Bích"));   // đã chuẩn hóa khoảng trắng
    }

    void themHocVien_khongHopLe_khongGoiRepository() {
        FakeHocVienRepository repo;
        FakeDanhMuc dm;
        HocVienService service(repo, dm);
        const auto kq = service.themMoi(HocVien{}, QDate(2026, 10, 1));
        QVERIFY(!kq.ok());
        QCOMPARE(repo.soLanThem, 0);
    }

    void dangNhap_thanhCong_luuPhien() {
        FakeAuthGateway gw;
        FakeStore store;
        AuthService auth(gw, store);
        QVERIFY(auth.dangNhap(QStringLiteral("gvu_lan"), QStringLiteral("dung-mat-khau")).ok());
        QVERIFY(auth.daDangNhap());
        QCOMPARE(auth.vaiTro(), VaiTro::GiaoVu);
        QCOMPARE(store.ten, QStringLiteral("gvu_lan"));
        auth.dangXuat();
        QVERIFY(!auth.daDangNhap());
    }

    void dangNhap_thieuThongTin_baoLoi() {
        FakeAuthGateway gw;
        FakeStore store;
        AuthService auth(gw, store);
        QVERIFY(!auth.dangNhap(QString(), QString()).ok());
        QVERIFY(!auth.dangNhap(QStringLiteral("gvu_lan"), QStringLiteral("sai")).ok());
    }

    void doiMatKhau_kiemTraDauVao() {
        FakeAuthGateway gw;
        FakeStore store;
        AuthService auth(gw, store);
        QVERIFY(auth.dangNhap(QStringLiteral("gvu_lan"), QStringLiteral("dung-mat-khau")).ok());
        QVERIFY(!auth.doiMatKhau(QStringLiteral("a"), QStringLiteral("ngan"), QStringLiteral("ngan")).ok());
        QVERIFY(!auth.doiMatKhau(QStringLiteral("a"), QStringLiteral("MatKhau@1"), QStringLiteral("KhacNhau@1")).ok());
        QVERIFY(auth.doiMatKhau(QStringLiteral("a"), QStringLiteral("MatKhau@1"), QStringLiteral("MatKhau@1")).ok());
    }

    void phanQuyen_giaoVienKhongThayHocVien() {
        QVERIFY(!PhanQuyen::duocPhep(VaiTro::GiaoVien, ChucNang::HocVien));
        QVERIFY(PhanQuyen::duocPhep(VaiTro::GiaoVien, ChucNang::LichDayCuaToi));
        QVERIFY(!PhanQuyen::duocPhep(VaiTro::GiaoVu, ChucNang::BangLuong));
        QVERIFY(PhanQuyen::duocPhep(VaiTro::KeToan, ChucNang::CongNo));
        QVERIFY(!PhanQuyen::duocSuaHocVien(VaiTro::KeToan));
        QVERIFY(PhanQuyen::chucNangDuocPhep(VaiTro::KhongXacDinh).isEmpty());
    }
};

QTEST_APPLESS_MAIN(TestApplication)
#include "tst_application.moc"
