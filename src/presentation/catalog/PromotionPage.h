#pragma once

#include "presentation/common/DataPage.h"

// Promotions page (manager only): the tuition promotions, whether they are valid today and how many
// enrollments used them; add or change one (usp_Promotion_Add / _Update; PERCENT at most 50, the end not
// before the start). An enrollment keeps the discount amount it was given, so changing a promotion never
// changes old tuition.
class PromotionPage : public DataPage {
    Q_OBJECT
public:
    explicit PromotionPage(AppServices services, QWidget* parent = nullptr);

protected:
    Result<TableData> fetch() override;

private:
    void editPromotion(bool isNew);
};
