#include "domain/entities/HocVien.h"
#include "domain/entities/VaiTro.h"

#include <QtTest>

class TestDomain : public QObject {
    Q_OBJECT

private:
    static HocVien hocVienHopLe() {
        HocVien hv;
        hv.hoTen = QStringLiteral("Nguyễn Văn An");
        hv.ngaySinh = QDate(2000, 5, 10);
        hv.gioiTinh = QStringLiteral("Nam");
        hv.soDienThoai = QStringLiteral("0901234567");
        hv.maCN = QStringLiteral("CN01");
        return hv;
    }

private slots:
    void hocVienHopLe_khongCoLoi() {
        QVERIFY(hocVienHopLe().kiemTra(QDate(2026, 10, 1)).isEmpty());
    }

    void tinhTuoi_chuaToiSinhNhat() {
        HocVien hv;
        hv.ngaySinh = QDate(2008, 12, 31);
        QCOMPARE(hv.tuoi(QDate(2026, 10, 1)), 17);
        QCOMPARE(hv.tuoi(QDate(2026, 12, 31)), 18);
    }

    void duoi18Tuoi_batBuocPhuHuynh() {
        HocVien hv = hocVienHopLe();
        hv.ngaySinh = QDate(2015, 1, 1);
        QVERIFY(!hv.kiemTra(QDate(2026, 10, 1)).isEmpty());
        hv.tenPhuHuynh = QStringLiteral("Nguyễn Văn Hòa");
        hv.sdtPhuHuynh = QStringLiteral("0912000001");
        QVERIFY(hv.kiemTra(QDate(2026, 10, 1)).isEmpty());
    }

    void soDienThoai_chiChuSo() {
        HocVien hv = hocVienHopLe();
        hv.soDienThoai = QStringLiteral("09-123");
        QVERIFY(!hv.kiemTra(QDate(2026, 10, 1)).isEmpty());
    }

    void email_dinhDang() {
        HocVien hv = hocVienHopLe();
        hv.email = QStringLiteral("khong-hop-le");
        QVERIFY(!hv.kiemTra(QDate(2026, 10, 1)).isEmpty());
        hv.email = QStringLiteral("an.nv@gmail.com");
        QVERIFY(hv.kiemTra(QDate(2026, 10, 1)).isEmpty());
    }

    void canItNhatMotSoLienLac() {
        HocVien hv = hocVienHopLe();
        hv.soDienThoai.clear();
        QVERIFY(!hv.kiemTra(QDate(2026, 10, 1)).isEmpty());
    }

    void vaiTro_anhXaMa() {
        QCOMPARE(vaiTroTuMa(QStringLiteral("QUANLY")), VaiTro::QuanLy);
        QCOMPARE(vaiTroTuMa(QStringLiteral("giaovien")), VaiTro::GiaoVien);
        QCOMPARE(vaiTroTuMa(QStringLiteral("abc")), VaiTro::KhongXacDinh);
        QCOMPARE(maVaiTro(VaiTro::KeToan), QStringLiteral("KETOAN"));
    }
};

QTEST_APPLESS_MAIN(TestDomain)
#include "tst_domain.moc"
