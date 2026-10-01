#include "presentation/hocvien/HocVienPage.h"

#include "presentation/common/Icons.h"
#include "presentation/common/UiHelpers.h"
#include "presentation/hocvien/HocVienFormDialog.h"
#include "presentation/hocvien/HocVienTableModel.h"

#include <QApplication>
#include <QComboBox>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QLabel>
#include <QLineEdit>
#include <QPushButton>
#include <QSortFilterProxyModel>
#include <QTableView>
#include <QTimer>
#include <QVBoxLayout>

HocVienPage::HocVienPage(AppServices services, QWidget* parent) : QWidget(parent), m_services(services) {
    m_duocSua = PhanQuyen::duocSuaHocVien(m_services.auth.vaiTro());

    auto* v = new QVBoxLayout(this);
    v->setContentsMargins(24, 20, 24, 16);
    v->setSpacing(12);

    // --- Thanh công cụ: lọc bên trái, thao tác bên phải
    auto* thanh = new QHBoxLayout;
    m_tuKhoa = new QLineEdit(this);
    m_tuKhoa->setPlaceholderText(QStringLiteral("Tìm theo mã, họ tên, số điện thoại..."));
    m_tuKhoa->addAction(Icons::get(QStringLiteral("search"), QStringLiteral("#94A3B8"), 16), QLineEdit::LeadingPosition);
    m_tuKhoa->setClearButtonEnabled(true);
    m_tuKhoa->setMinimumWidth(280);
    m_locChiNhanh = new QComboBox(this);
    m_locChiNhanh->addItem(QStringLiteral("Tất cả chi nhánh"), QString());
    m_locTrangThai = new QComboBox(this);
    m_locTrangThai->addItem(QStringLiteral("Tất cả trạng thái"), QString());
    for (const QString& tt : HocVienGiaTri::trangThai())
        m_locTrangThai->addItem(tt, tt);
    thanh->addWidget(m_tuKhoa, 1);
    thanh->addWidget(m_locChiNhanh);
    thanh->addWidget(m_locTrangThai);
    thanh->addSpacing(12);

    auto* nutThem = UiHelpers::nutChinh(QStringLiteral("Thêm"), QStringLiteral("plus"), this);
    m_nutSua = UiHelpers::nutPhu(QStringLiteral("Sửa"), QStringLiteral("edit"), this);
    m_nutXoa = UiHelpers::nutPhu(QStringLiteral("Xóa"), QStringLiteral("trash"), this);
    auto* nutCsv = UiHelpers::nutPhu(QStringLiteral("Excel"), QStringLiteral("download"), this);
    auto* nutPdf = UiHelpers::nutPhu(QStringLiteral("PDF"), QStringLiteral("file"), this);
    nutThem->setVisible(m_duocSua);
    m_nutSua->setVisible(m_duocSua);
    m_nutXoa->setVisible(m_duocSua);
    thanh->addWidget(nutThem);
    thanh->addWidget(m_nutSua);
    thanh->addWidget(m_nutXoa);
    thanh->addWidget(nutCsv);
    thanh->addWidget(nutPdf);
    v->addLayout(thanh);

    // --- Bảng dữ liệu
    m_model = new HocVienTableModel(this);
    m_proxy = new QSortFilterProxyModel(this);
    m_proxy->setSourceModel(m_model);
    m_proxy->setSortRole(Qt::UserRole);
    m_proxy->setSortLocaleAware(true);
    m_bang = new QTableView(this);
    m_bang->setModel(m_proxy);
    m_bang->setSortingEnabled(true);
    m_bang->horizontalHeader()->setSortIndicator(-1, Qt::AscendingOrder);   // giữ thứ tự ORDER BY của CSDL
    m_bang->setSelectionBehavior(QAbstractItemView::SelectRows);
    m_bang->setSelectionMode(QAbstractItemView::SingleSelection);
    m_bang->setEditTriggers(QAbstractItemView::NoEditTriggers);
    m_bang->setAlternatingRowColors(true);
    m_bang->verticalHeader()->hide();
    m_bang->horizontalHeader()->setStretchLastSection(true);
    m_bang->horizontalHeader()->setSectionResizeMode(QHeaderView::ResizeToContents);
    v->addWidget(m_bang, 1);

    m_dem = new QLabel(this);
    m_dem->setObjectName(QStringLiteral("Muted"));
    v->addWidget(m_dem);

    // Tìm kiếm tự động sau khi ngừng gõ 300ms
    m_hoan = new QTimer(this);
    m_hoan->setSingleShot(true);
    m_hoan->setInterval(300);
    connect(m_hoan, &QTimer::timeout, this, &HocVienPage::timKiem);
    connect(m_tuKhoa, &QLineEdit::textChanged, m_hoan, qOverload<>(&QTimer::start));
    connect(m_locChiNhanh, &QComboBox::currentIndexChanged, this, &HocVienPage::timKiem);
    connect(m_locTrangThai, &QComboBox::currentIndexChanged, this, &HocVienPage::timKiem);
    connect(nutThem, &QPushButton::clicked, this, &HocVienPage::them);
    connect(m_nutSua, &QPushButton::clicked, this, &HocVienPage::sua);
    connect(m_nutXoa, &QPushButton::clicked, this, &HocVienPage::xoa);
    connect(m_bang, &QTableView::doubleClicked, this, [this] {
        if (m_duocSua)
            sua();
    });
    connect(nutCsv, &QPushButton::clicked, this,
            [this] { UiHelpers::xuatCsv(this, *m_proxy, QStringLiteral("DanhSachHocVien")); });
    connect(nutPdf, &QPushButton::clicked, this, [this] {
        UiHelpers::xuatPdf(this, *m_proxy, QStringLiteral("Danh sách học viên"), m_services.auth.taiKhoan().hoTen);
    });

    const auto cn = m_services.hocVien.danhSachChiNhanh();
    if (cn.ok()) {
        m_chiNhanh = cn.value();
        for (const ChiNhanh& c : m_chiNhanh)
            m_locChiNhanh->addItem(c.tenCN, c.maCN);
    }
    timKiem();
}

void HocVienPage::timKiem() {
    BoLocHocVien boLoc;
    boLoc.tuKhoa = m_tuKhoa->text();
    boLoc.maCN = m_locChiNhanh->currentData().toString();
    boLoc.trangThai = m_locTrangThai->currentData().toString();

    QApplication::setOverrideCursor(Qt::WaitCursor);
    const auto kq = m_services.hocVien.timKiem(boLoc);
    QApplication::restoreOverrideCursor();
    if (!kq.ok()) {
        UiHelpers::baoLoi(this, kq.error());
        return;
    }
    m_model->setDanhSach(kq.value());
    m_dem->setText(QStringLiteral("%1 học viên").arg(kq.value().size()));
}

const HocVien* HocVienPage::hocVienDangChon() const {
    const QModelIndex idx = m_bang->currentIndex();
    if (!idx.isValid())
        return nullptr;
    return m_model->hocVienTai(m_proxy->mapToSource(idx).row());
}

void HocVienPage::chonLaiTheoMa(const QString& maHV) {
    for (int r = 0; r < m_proxy->rowCount(); ++r) {
        const QModelIndex idx = m_proxy->index(r, HocVienTableModel::MaHV);
        if (idx.data().toString() == maHV) {
            m_bang->selectRow(r);
            m_bang->scrollTo(idx);
            return;
        }
    }
}

void HocVienPage::them() {
    HocVienFormDialog dlg(m_services.hocVien, m_chiNhanh, HocVien{}, this);
    if (dlg.exec() == QDialog::Accepted) {
        timKiem();
        chonLaiTheoMa(dlg.maHocVienDaLuu());
    }
}

void HocVienPage::sua() {
    const HocVien* chon = hocVienDangChon();
    if (!chon) {
        UiHelpers::baoLoi(this, QStringLiteral("Hãy chọn một học viên trong danh sách."));
        return;
    }
    const auto chiTiet = m_services.hocVien.layChiTiet(chon->maHV);
    if (!chiTiet.ok()) {
        UiHelpers::baoLoi(this, chiTiet.error());
        return;
    }
    HocVienFormDialog dlg(m_services.hocVien, m_chiNhanh, chiTiet.value(), this);
    if (dlg.exec() == QDialog::Accepted) {
        timKiem();
        chonLaiTheoMa(dlg.maHocVienDaLuu());
    }
}

void HocVienPage::xoa() {
    const HocVien* chon = hocVienDangChon();
    if (!chon) {
        UiHelpers::baoLoi(this, QStringLiteral("Hãy chọn một học viên trong danh sách."));
        return;
    }
    if (!UiHelpers::xacNhan(this, QStringLiteral("Xóa học viên %1 - %2?").arg(chon->maHV, chon->hoTen)))
        return;
    const auto kq = m_services.hocVien.xoa(chon->maHV);
    if (!kq.ok()) {
        UiHelpers::baoLoi(this, kq.error());
        return;
    }
    timKiem();
}
