#include "presentation/danhsach/DanhSachPage.h"

#include "presentation/common/Format.h"
#include "presentation/common/Icons.h"
#include "presentation/common/TableDataModel.h"
#include "presentation/common/UiHelpers.h"

#include <QApplication>
#include <QHBoxLayout>
#include <QHeaderView>
#include <QLabel>
#include <QLineEdit>
#include <QPushButton>
#include <QSortFilterProxyModel>
#include <QTableView>
#include <QVBoxLayout>

DanhSachPage::DanhSachPage(AppServices services, ChucNang chucNang, QWidget* parent)
    : QWidget(parent), m_services(services), m_chucNang(chucNang) {
    auto* v = new QVBoxLayout(this);
    v->setContentsMargins(24, 20, 24, 16);
    v->setSpacing(12);

    auto* thanh = new QHBoxLayout;
    m_loc = new QLineEdit(this);
    m_loc->setObjectName(QStringLiteral("locNhanh"));
    m_loc->setPlaceholderText(QStringLiteral("Lọc nhanh trong danh sách..."));
    m_loc->addAction(Icons::get(QStringLiteral("search"), QStringLiteral("#94A3B8"), 16), QLineEdit::LeadingPosition);
    m_loc->setClearButtonEnabled(true);
    auto* nutTai = UiHelpers::nutPhu(QStringLiteral("Làm mới"), QStringLiteral("refresh"), this);
    auto* nutCsv = UiHelpers::nutPhu(QStringLiteral("Excel"), QStringLiteral("download"), this);
    auto* nutPdf = UiHelpers::nutChinh(QStringLiteral("Xuất báo cáo PDF"), QStringLiteral("file"), this);
    thanh->addWidget(m_loc, 1);
    thanh->addWidget(nutTai);
    thanh->addWidget(nutCsv);
    thanh->addWidget(nutPdf);
    v->addLayout(thanh);

    m_model = new TableDataModel(this);
    m_proxy = new QSortFilterProxyModel(this);
    m_proxy->setSourceModel(m_model);
    m_proxy->setFilterCaseSensitivity(Qt::CaseInsensitive);
    m_proxy->setFilterKeyColumn(-1);
    m_proxy->setSortRole(Qt::UserRole);
    m_proxy->setSortLocaleAware(true);

    m_bang = new QTableView(this);
    m_bang->setObjectName(QStringLiteral("bangDanhSach"));
    m_bang->setModel(m_proxy);
    m_bang->setSortingEnabled(true);
    m_bang->horizontalHeader()->setSortIndicator(-1, Qt::AscendingOrder);   // giữ thứ tự ORDER BY của CSDL
    m_bang->setSelectionBehavior(QAbstractItemView::SelectRows);
    m_bang->setEditTriggers(QAbstractItemView::NoEditTriggers);
    m_bang->setAlternatingRowColors(true);
    m_bang->verticalHeader()->hide();
    m_bang->horizontalHeader()->setStretchLastSection(true);
    m_bang->horizontalHeader()->setSectionResizeMode(QHeaderView::ResizeToContents);
    v->addWidget(m_bang, 1);

    m_tong = new QLabel(this);
    m_tong->setProperty("vaiTro", QStringLiteral("dongTong"));
    m_tong->setObjectName(QStringLiteral("Muted"));
    v->addWidget(m_tong);

    connect(m_loc, &QLineEdit::textChanged, this, [this](const QString& s) {
        m_proxy->setFilterFixedString(s);
        capNhatTong();
    });
    connect(nutTai, &QPushButton::clicked, this, &DanhSachPage::taiLai);
    connect(nutCsv, &QPushButton::clicked, this, [this] {
        UiHelpers::xuatCsv(this, *m_proxy, PhanQuyen::thongTin(m_chucNang).ten);
    });
    connect(nutPdf, &QPushButton::clicked, this, [this] {
        UiHelpers::xuatPdf(this, *m_proxy, PhanQuyen::thongTin(m_chucNang).ten, m_services.auth.taiKhoan().hoTen);
    });
    taiLai();
}

void DanhSachPage::taiLai() {
    QApplication::setOverrideCursor(Qt::WaitCursor);
    const auto kq = m_services.danhSach.layDanhSach(m_chucNang);
    QApplication::restoreOverrideCursor();
    if (!kq.ok()) {
        m_model->setTableData({});
        m_tong->setText(kq.error());
        return;
    }
    m_model->setTableData(kq.value());
    capNhatTong();
}

void DanhSachPage::capNhatTong() {
    QStringList phan{QStringLiteral("%1 dòng").arg(m_proxy->rowCount())};
    const QStringList& cot = m_model->tableData().columns;
    for (int c = 0; c < cot.size(); ++c) {
        if (!Format::laCotCongDon(cot.at(c)))
            continue;
        double tong = 0;
        for (int r = 0; r < m_proxy->rowCount(); ++r)
            tong += m_proxy->index(r, c).data(Qt::UserRole).toDouble();
        phan << QStringLiteral("Tổng %1: %2").arg(cot.at(c).toLower(), Format::tien(static_cast<qint64>(tong)));
    }
    m_tong->setText(phan.join(QStringLiteral("   •   ")));
}
