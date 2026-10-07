#pragma once

#include "presentation/common/DataPage.h"

// Generic page for every read-only lookup list (outstanding tuition, learning results, my pay...): quick
// filter, sorting, totals line for money columns, Excel/PDF export, print preview - all from DataPage. Data:
// ListService::fetch(feature) -> TableData -> DataTable. The page knows nothing about the columns of a list:
// titles and formats come from the column catalog (Columns), so a new list needs no new page
// (docs/ARCHITECTURE.md, section 4).
class ListPage : public DataPage {
    Q_OBJECT
public:
    ListPage(AppServices services, Feature feature, QWidget* parent = nullptr);

protected:
    Result<TableData> fetch() override;
};
