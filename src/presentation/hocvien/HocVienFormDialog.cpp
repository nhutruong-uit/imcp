#include "presentation/hocvien/HocVienFormDialog.h"

#include "application/services/HocVienService.h"
#include "ui_HocVienFormDialog.h"

#include <QPushButton>
#include <QStyle>
#include <QRegularExpressionValidator>

HocVienFormDialog::HocVienFormDialog(HocVienService& service, const QList<ChiNhanh>& chiNhanh,
                                     const HocVien& hocVien, QWidget* parent)
    : QDialog(parent), ui(std::make_unique<Ui::HocVienFormDialog>()), m_service(service), m_goc(hocVien) {
    ui->setupUi(this);
    ui->tieuDeLabel->setObjectName(QStringLiteral("PageTitle"));
    ui->loiLabel->setObjectName(QStringLiteral("ErrorText"));
    ui->loiLabel->hide();
    ui->buttonBox->button(QDialogButtonBox::Save)->setText(QStringLiteral("Lưu"));
    QPushButton* nutLuu = ui->buttonBox->button(QDialogButtonBox::Save);
    nutLuu->setProperty("variant", QStringLiteral("primary"));
    nutLuu->style()->unpolish(nutLuu);   // áp lại QSS sau khi đổi thuộc tính
    nutLuu->style()->polish(nutLuu);
    ui->buttonBox->button(QDialogButtonBox::Cancel)->setText(QStringLiteral("Hủy"));

    // Chỉ cho nhập chữ số ở ô điện thoại (khớp ràng buộc CK_HOCVIEN_SoDienThoai)
    auto* chiSo = new QRegularExpressionValidator(QRegularExpression(QStringLiteral("[0-9]{0,11}")), this);
    ui->sdtEdit->setValidator(chiSo);
    ui->sdtPhuHuynhEdit->setValidator(chiSo);
    ui->ngaySinhEdit->setMaximumDate(QDate::currentDate());

    ui->gioiTinhCombo->addItems(HocVienGiaTri::gioiTinh());
    ui->trangThaiCombo->addItems(HocVienGiaTri::trangThai());
    for (const ChiNhanh& cn : chiNhanh)
        ui->chiNhanhCombo->addItem(cn.tenCN, cn.maCN);

    const bool themMoi = hocVien.maHV.isEmpty();
    ui->tieuDeLabel->setText(themMoi ? QStringLiteral("Thêm học viên") : QStringLiteral("Sửa thông tin học viên"));
    setWindowTitle(ui->tieuDeLabel->text());
    ui->trangThaiCombo->setEnabled(!themMoi);   // học viên mới luôn ở trạng thái "Tiềm năng"
    ghiForm(hocVien);
    capNhatNhomPhuHuynh();

    connect(ui->ngaySinhEdit, &QDateEdit::dateChanged, this, &HocVienFormDialog::capNhatNhomPhuHuynh);
    connect(ui->buttonBox, &QDialogButtonBox::accepted, this, &HocVienFormDialog::luu);
    connect(ui->buttonBox, &QDialogButtonBox::rejected, this, &QDialog::reject);
}

HocVienFormDialog::~HocVienFormDialog() = default;

void HocVienFormDialog::ghiForm(const HocVien& hv) {
    ui->maEdit->setText(hv.maHV);
    ui->hoTenEdit->setText(hv.hoTen);
    ui->ngaySinhEdit->setDate(hv.ngaySinh.isValid() ? hv.ngaySinh : QDate::currentDate().addYears(-18));
    ui->gioiTinhCombo->setCurrentText(hv.gioiTinh);
    ui->sdtEdit->setText(hv.soDienThoai);
    ui->emailEdit->setText(hv.email);
    ui->diaChiEdit->setText(hv.diaChi);
    ui->ngheNghiepEdit->setText(hv.ngheNghiep);
    const int idx = ui->chiNhanhCombo->findData(hv.maCN);
    ui->chiNhanhCombo->setCurrentIndex(idx >= 0 ? idx : 0);
    ui->trangThaiCombo->setCurrentText(hv.trangThai);
    ui->tenPhuHuynhEdit->setText(hv.tenPhuHuynh);
    ui->sdtPhuHuynhEdit->setText(hv.sdtPhuHuynh);
    ui->ghiChuEdit->setPlainText(hv.ghiChu);
}

HocVien HocVienFormDialog::docForm() const {
    HocVien hv = m_goc;
    hv.hoTen = ui->hoTenEdit->text();
    hv.ngaySinh = ui->ngaySinhEdit->date();
    hv.gioiTinh = ui->gioiTinhCombo->currentText();
    hv.soDienThoai = ui->sdtEdit->text();
    hv.email = ui->emailEdit->text();
    hv.diaChi = ui->diaChiEdit->text();
    hv.ngheNghiep = ui->ngheNghiepEdit->text();
    hv.maCN = ui->chiNhanhCombo->currentData().toString();
    hv.trangThai = ui->trangThaiCombo->currentText();
    hv.tenPhuHuynh = ui->tenPhuHuynhEdit->text();
    hv.sdtPhuHuynh = ui->sdtPhuHuynhEdit->text();
    hv.ghiChu = ui->ghiChuEdit->toPlainText();
    return hv;
}

void HocVienFormDialog::capNhatNhomPhuHuynh() {
    HocVien tam;
    tam.ngaySinh = ui->ngaySinhEdit->date();
    const bool batBuoc = tam.canThongTinPhuHuynh(m_goc.ngayDangKy.isValid() ? m_goc.ngayDangKy : QDate::currentDate());
    ui->phuHuynhGroup->setTitle(batBuoc ? QStringLiteral("Thông tin phụ huynh * (học viên dưới 18 tuổi)")
                                        : QStringLiteral("Thông tin phụ huynh (không bắt buộc)"));
}

void HocVienFormDialog::luu() {
    const HocVien hv = docForm();
    const QDate homNay = QDate::currentDate();
    if (hv.maHV.isEmpty()) {
        const auto kq = m_service.themMoi(hv, homNay);
        if (!kq.ok()) {
            ui->loiLabel->setText(kq.error());
            ui->loiLabel->show();
            return;
        }
        m_maDaLuu = kq.value();
    } else {
        const auto kq = m_service.capNhat(hv, homNay);
        if (!kq.ok()) {
            ui->loiLabel->setText(kq.error());
            ui->loiLabel->show();
            return;
        }
        m_maDaLuu = hv.maHV;
    }
    accept();
}
