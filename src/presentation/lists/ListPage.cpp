#include "presentation/lists/ListPage.h"

ListPage::ListPage(AppServices services, Feature feature, QWidget* parent)
    : DataPage(services, feature, parent) {
    reload();
}

Result<TableData> ListPage::fetch() {
    return m_services.lists.fetch(m_feature);
}
