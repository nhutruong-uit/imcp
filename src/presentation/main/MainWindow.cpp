#include "presentation/main/MainWindow.h"

#include "presentation/common/Icons.h"
#include "presentation/common/UiHelpers.h"
#include "presentation/dashboard/DashboardPage.h"
#include "presentation/danhsach/DanhSachPage.h"
#include "presentation/hocvien/HocVienPage.h"
#include "presentation/main/ChangePasswordDialog.h"

#include <QApplication>
#include <QHBoxLayout>
#include <QLabel>
#include <QListWidget>
#include <QPushButton>
#include <QStackedWidget>
#include <QVBoxLayout>

MainWindow::MainWindow(AppServices services, QWidget* parent) : QMainWindow(parent), m_services(services) {
    setWindowTitle(QStringLiteral("Quản lý Trung tâm Tiếng Anh"));
    resize(1280, 780);
    setMinimumSize(1024, 640);

    m_chucNang = PhanQuyen::chucNangDuocPhep(m_services.auth.vaiTro());

    auto* trungTam = new QWidget(this);
    auto* h = new QHBoxLayout(trungTam);
    h->setContentsMargins(0, 0, 0, 0);
    h->setSpacing(0);
    h->addWidget(taoSidebar());

    auto* phai = new QWidget(trungTam);
    auto* v = new QVBoxLayout(phai);
    v->setContentsMargins(0, 0, 0, 0);
    v->setSpacing(0);
    v->addWidget(taoHeader());
    m_noiDung = new QStackedWidget(phai);
    m_noiDung->setObjectName(QStringLiteral("Content"));
    v->addWidget(m_noiDung, 1);
    h->addWidget(phai, 1);
    setCentralWidget(trungTam);

    connect(m_menu, &QListWidget::currentRowChanged, this, &MainWindow::chonChucNang);
    // Dòng 0 của menu là tiêu đề nhóm ("CHUNG"), nên mở chức năng đầu tiên thay vì chọn dòng 0
    if (!m_chucNang.isEmpty())
        moChucNang(m_chucNang.first());
}

QWidget* MainWindow::taoSidebar() {
    auto* sidebar = new QFrame(this);
    sidebar->setObjectName(QStringLiteral("Sidebar"));
    sidebar->setFixedWidth(240);
    auto* v = new QVBoxLayout(sidebar);
    v->setContentsMargins(0, 18, 0, 12);
    v->setSpacing(4);

    auto* brand = new QWidget(sidebar);
    auto* bh = new QHBoxLayout(brand);
    bh->setContentsMargins(20, 0, 20, 12);
    auto* logo = new QLabel(brand);
    logo->setPixmap(Icons::pixmap(QStringLiteral("logo"), QStringLiteral("#FFFFFF"), 30));
    auto* ten = new QLabel(QStringLiteral("English Center"), brand);
    ten->setObjectName(QStringLiteral("SidebarBrand"));
    bh->addWidget(logo);
    bh->addWidget(ten, 1);
    v->addWidget(brand);

    m_menu = new QListWidget(sidebar);
    m_menu->setObjectName(QStringLiteral("NavList"));
    m_menu->setIconSize(QSize(18, 18));
    m_menu->setFocusPolicy(Qt::NoFocus);
    QString nhomTruoc;
    for (ChucNang cn : m_chucNang) {
        const ThongTinChucNang tt = PhanQuyen::thongTin(cn);
        if (tt.nhom != nhomTruoc) {
            auto* tieuDeNhom = new QListWidgetItem(tt.nhom.toUpper(), m_menu);
            tieuDeNhom->setFlags(Qt::NoItemFlags);
            tieuDeNhom->setData(Qt::UserRole, -1);
            tieuDeNhom->setSizeHint(QSize(0, 30));
            QFont f = tieuDeNhom->font();
            f.setPointSizeF(f.pointSizeF() * 0.8);
            f.setBold(true);
            tieuDeNhom->setFont(f);
            nhomTruoc = tt.nhom;
        }
        auto* item = new QListWidgetItem(Icons::get(tt.icon, QStringLiteral("#E2E8F0"), 18), tt.ten, m_menu);
        item->setData(Qt::UserRole, static_cast<int>(cn));
        item->setSizeHint(QSize(0, 40));
    }
    v->addWidget(m_menu, 1);

    auto* nguoiDung = new QLabel(QStringLiteral("%1\n%2")
                                     .arg(m_services.auth.taiKhoan().hoTen,
                                          tenVaiTro(m_services.auth.vaiTro())),
                                 sidebar);
    nguoiDung->setObjectName(QStringLiteral("SidebarUser"));
    v->addWidget(nguoiDung);
    return sidebar;
}

QWidget* MainWindow::taoHeader() {
    auto* header = new QFrame(this);
    header->setObjectName(QStringLiteral("Header"));
    header->setFixedHeight(60);
    auto* h = new QHBoxLayout(header);
    h->setContentsMargins(24, 0, 16, 0);

    m_tieuDe = new QLabel(header);
    m_tieuDe->setObjectName(QStringLiteral("HeaderTitle"));
    h->addWidget(m_tieuDe, 1);

    auto* vaiTro = new QLabel(tenVaiTro(m_services.auth.vaiTro()), header);
    vaiTro->setObjectName(QStringLiteral("RoleBadge"));
    vaiTro->setFixedHeight(26);
    h->addWidget(vaiTro, 0, Qt::AlignVCenter);

    auto* nutMatKhau = UiHelpers::nutPhu(QStringLiteral("Đổi mật khẩu"), QStringLiteral("key"), header);
    auto* nutThoat = UiHelpers::nutPhu(QStringLiteral("Đăng xuất"), QStringLiteral("logout"), header);
    h->addWidget(nutMatKhau);
    h->addWidget(nutThoat);

    connect(nutMatKhau, &QPushButton::clicked, this, &MainWindow::doiMatKhau);
    connect(nutThoat, &QPushButton::clicked, this, [this] {
        if (UiHelpers::xacNhan(this, QStringLiteral("Bạn muốn đăng xuất?")))
            emit yeuCauDangXuat();
    });
    return header;
}

QWidget* MainWindow::trangCho(ChucNang chucNang) {
    const int khoa = static_cast<int>(chucNang);
    if (QWidget* daCo = m_trang.value(khoa, nullptr))
        return daCo;

    QWidget* trang = nullptr;
    switch (chucNang) {
    case ChucNang::TongQuan:
        trang = new DashboardPage(m_services, m_noiDung);
        break;
    case ChucNang::HocVien:
        trang = new HocVienPage(m_services, m_noiDung);
        break;
    default:
        trang = new DanhSachPage(m_services, chucNang, m_noiDung);
        break;
    }
    m_noiDung->addWidget(trang);
    m_trang.insert(khoa, trang);
    return trang;
}

void MainWindow::chonChucNang(int dong) {
    QListWidgetItem* item = m_menu->item(dong);
    if (!item || item->data(Qt::UserRole).toInt() < 0)
        return;
    const auto cn = static_cast<ChucNang>(item->data(Qt::UserRole).toInt());
    m_tieuDe->setText(PhanQuyen::thongTin(cn).ten);
    m_noiDung->setCurrentWidget(trangCho(cn));
}

void MainWindow::moChucNang(ChucNang chucNang) {
    for (int i = 0; i < m_menu->count(); ++i) {
        if (m_menu->item(i)->data(Qt::UserRole).toInt() == static_cast<int>(chucNang)) {
            m_menu->setCurrentRow(i);
            return;
        }
    }
}

void MainWindow::doiMatKhau() {
    ChangePasswordDialog dlg(m_services.auth, this);
    dlg.exec();
}
