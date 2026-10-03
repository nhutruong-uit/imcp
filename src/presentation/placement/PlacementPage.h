#pragma once

#include "presentation/common/DataPage.h"

// Placement tests page: every test with its four skills, the overall score and the course recommended by the
// database (usp_PlacementTest_Search); academic staff record a new test (usp_PlacementTest_Add). The latest
// test of a student decides whether they meet the minimum score of a course when they enroll
// (usp_Enrollment_Create).
class PlacementPage : public DataPage {
    Q_OBJECT
public:
    explicit PlacementPage(AppServices services, QWidget* parent = nullptr);

protected:
    Result<TableData> fetch() override;

private:
    void addTest();
};
