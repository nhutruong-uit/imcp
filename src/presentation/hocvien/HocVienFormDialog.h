#pragma once

#include "domain/entities/ChiNhanh.h"
#include "domain/entities/HocVien.h"

#include <QDialog>

#include <memory>

class HocVienService;

namespace Ui {
class HocVienFormDialog;
}

// Form thêm/sửa học viên. Giao diện thiết kế bằng Qt Designer (HocVienFormDialog.ui)
class HocVienFormDialog : public QDialog {
    Q_OBJECT
public:
    // hocVien rỗng (maHV trống) => chế độ thêm mới
    HocVienFormDialog(HocVienService& service, const QList<ChiNhanh>& chiNhanh, const HocVien& hocVien,
                      QWidget* parent = nullptr);
    ~HocVienFormDialog() override;

    QString maHocVienDaLuu() const { return m_maDaLuu; }

private slots:
    void luu();
    void capNhatNhomPhuHuynh();

private:
    HocVien docForm() const;
    void ghiForm(const HocVien& hv);

    std::unique_ptr<Ui::HocVienFormDialog> ui;
    HocVienService& m_service;
    HocVien m_goc;
    QString m_maDaLuu;
};
