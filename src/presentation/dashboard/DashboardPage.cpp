#include "presentation/dashboard/DashboardPage.h"

#include "presentation/common/Format.h"
#include "presentation/common/Icons.h"
#include "presentation/common/UiHelpers.h"
#include "presentation/dashboard/RevenueChart.h"

#include <QDate>
#include <QGridLayout>
#include <QHBoxLayout>
#include <QLabel>
#include <QLocale>
#include <QPushButton>
#include <QVBoxLayout>

DashboardPage::DashboardPage(AppServices services, QWidget* parent) : QWidget(parent), m_services(services) {
    auto* v = new QVBoxLayout(this);
    v->setContentsMargins(24, 20, 24, 20);
    v->setSpacing(16);

    auto* dau = new QHBoxLayout;
    const QLocale vi(QLocale::Vietnamese, QLocale::Vietnam);
    auto* chao = new QLabel(QStringLiteral("Xin chào, %1").arg(m_services.auth.taiKhoan().hoTen), this);
    chao->setObjectName(QStringLiteral("PageTitle"));
    auto* ngay = new QLabel(vi.toString(QDate::currentDate(), QStringLiteral("dddd, dd/MM/yyyy")), this);
    ngay->setObjectName(QStringLiteral("Muted"));
    auto* nutTai = UiHelpers::nutPhu(QStringLiteral("Làm mới"), QStringLiteral("refresh"), this);
    auto* cotChao = new QVBoxLayout;
    cotChao->addWidget(chao);
    cotChao->addWidget(ngay);
    dau->addLayout(cotChao, 1);
    dau->addWidget(nutTai, 0, Qt::AlignTop);
    v->addLayout(dau);

    auto* luoi = new QGridLayout;
    luoi->setSpacing(16);
    luoi->addWidget(taoThe(QStringLiteral("Học viên đang học"), QStringLiteral("users"), &m_hocVien), 0, 0);
    luoi->addWidget(taoThe(QStringLiteral("Lớp đang học"), QStringLiteral("book"), &m_lopDangHoc), 0, 1);
    luoi->addWidget(taoThe(QStringLiteral("Lớp đang tuyển sinh"), QStringLiteral("award"), &m_lopTuyenSinh), 0, 2);
    luoi->addWidget(taoThe(QStringLiteral("Doanh thu tháng này"), QStringLiteral("chart"), &m_doanhThu), 1, 0);
    luoi->addWidget(taoThe(QStringLiteral("Tổng công nợ học phí"), QStringLiteral("wallet"), &m_congNo), 1, 1);
    luoi->addWidget(taoThe(QStringLiteral("Buổi học hôm nay"), QStringLiteral("calendar"), &m_buoiHoc), 1, 2);
    m_doanhThu->setProperty("vaiTro", QStringLiteral("kpiDoanhThu"));
    v->addLayout(luoi);

    auto* theBieuDo = UiHelpers::theCard(this);
    auto* vb = new QVBoxLayout(theBieuDo);
    vb->setContentsMargins(20, 16, 20, 16);
    auto* tieuDeBD = new QLabel(QStringLiteral("Doanh thu theo tháng - năm %1").arg(QDate::currentDate().year()),
                                theBieuDo);
    tieuDeBD->setObjectName(QStringLiteral("CardTitle"));
    m_bieuDo = new RevenueChart(theBieuDo);
    vb->addWidget(tieuDeBD);
    vb->addWidget(m_bieuDo, 1);
    v->addWidget(theBieuDo, 1);

    m_loi = new QLabel(this);
    m_loi->setObjectName(QStringLiteral("ErrorText"));
    m_loi->hide();
    v->addWidget(m_loi);

    connect(nutTai, &QPushButton::clicked, this, &DashboardPage::taiLai);
    taiLai();
}

QWidget* DashboardPage::taoThe(const QString& tieuDe, const QString& icon, QLabel** giaTri) {
    auto* the = UiHelpers::theCard(this);
    auto* h = new QHBoxLayout(the);
    h->setContentsMargins(18, 16, 18, 16);
    auto* bieuTuong = new QLabel(the);
    bieuTuong->setObjectName(QStringLiteral("KpiIcon"));
    bieuTuong->setPixmap(Icons::pixmap(icon, QStringLiteral("#2E75B6"), 24));
    bieuTuong->setFixedSize(44, 44);
    bieuTuong->setAlignment(Qt::AlignCenter);
    auto* cot = new QVBoxLayout;
    auto* nhan = new QLabel(tieuDe, the);
    nhan->setObjectName(QStringLiteral("Muted"));
    *giaTri = new QLabel(QStringLiteral("—"), the);
    (*giaTri)->setObjectName(QStringLiteral("KpiValue"));
    cot->addWidget(nhan);
    cot->addWidget(*giaTri);
    h->addWidget(bieuTuong);
    h->addSpacing(8);
    h->addLayout(cot, 1);
    return the;
}

void DashboardPage::taiLai() {
    const auto tk = m_services.thongKe.tongQuan();
    if (tk.ok()) {
        const auto& s = tk.value();
        m_hocVien->setText(QString::number(s.hocVienDangHoc));
        m_lopDangHoc->setText(QString::number(s.lopDangHoc));
        m_lopTuyenSinh->setText(QString::number(s.lopTuyenSinh));
        m_doanhThu->setText(s.doanhThuThangNay ? Format::tien(*s.doanhThuThangNay)
                                               : QStringLiteral("Không có quyền"));
        m_congNo->setText(Format::tien(s.tongCongNo));
        m_buoiHoc->setText(QString::number(s.buoiHocHomNay));
        m_loi->hide();
    } else {
        m_loi->setText(tk.error());
        m_loi->show();
    }

    const auto dt = m_services.thongKe.doanhThuTheoThang(QDate::currentDate().year());
    if (dt.ok())
        m_bieuDo->setDuLieu(dt.value());
    else
        m_bieuDo->setThongBao(QStringLiteral("Không có quyền xem doanh thu hoặc chưa có dữ liệu."));
}
