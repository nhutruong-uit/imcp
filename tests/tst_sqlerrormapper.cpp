#include "infrastructure/db/DatabaseManager.h"
#include "infrastructure/db/SqlErrorMapper.h"

#include <QtTest>

class TestSqlErrorMapper : public QObject {
    Q_OBJECT

private slots:
    void boTienToOdbc() {
        const QString goc = QStringLiteral(
            "[Microsoft][ODBC Driver 18 for SQL Server][SQL Server]Học viên đã ghi danh lớp này.");
        QCOMPARE(SqlErrorMapper::lamSachThongDiep(goc), QStringLiteral("Học viên đã ghi danh lớp này."));
    }

    void loiDangNhap() {
        const QSqlError e(QStringLiteral("QODBC: Unable to connect"),
                          QStringLiteral("[Microsoft][ODBC Driver 18 for SQL Server][SQL Server]Login failed for user 'x'."),
                          QSqlError::ConnectionError, QStringLiteral("18456"));
        QVERIFY(SqlErrorMapper::thongBao(e).startsWith(QStringLiteral("Sai tên đăng nhập")));
    }

    void loiRangBuocCheck() {
        const QSqlError e(QStringLiteral("QODBC: Unable to execute statement"),
                          QStringLiteral("[Microsoft][ODBC Driver 18 for SQL Server][SQL Server]The INSERT statement "
                                         "conflicted with the CHECK constraint \"CK_HOCVIEN_PhuHuynh\"."),
                          QSqlError::StatementError, QStringLiteral("547"));
        QCOMPARE(SqlErrorMapper::thongBao(e), QStringLiteral("Học viên dưới 18 tuổi phải có thông tin phụ huynh."));
    }

    void chuoiKetNoi_matKhauKyTuDacBiet() {
        CauHinhMayChu c;
        const QString s = DatabaseManager::chuoiKetNoi(QStringLiteral("ODBC Driver 18 for SQL Server"), c,
                                                       QStringLiteral("gvu_lan"), QStringLiteral("a;b}c"));
        QVERIFY(s.contains(QStringLiteral("PWD={a;b}}c};")));
        QVERIFY(s.contains(QStringLiteral("TrustServerCertificate=yes")));
    }
};

QTEST_APPLESS_MAIN(TestSqlErrorMapper)
#include "tst_sqlerrormapper.moc"
