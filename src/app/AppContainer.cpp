#include "app/AppContainer.h"

AppContainer::AppContainer()
    : m_authGateway(m_db),
      m_hocVienRepo(m_db),
      m_danhMucRepo(m_db),
      m_thongKeRepo(m_db),
      m_danhSachRepo(m_db),
      m_auth(m_authGateway, m_cauHinh),
      m_hocVien(m_hocVienRepo, m_danhMucRepo),
      m_thongKe(m_thongKeRepo),
      m_danhSach(m_danhSachRepo, m_auth) {}
