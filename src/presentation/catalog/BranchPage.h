#pragma once

#include "presentation/common/DataPage.h"

class QLabel;
class QPushButton;

// Branches & rooms page (manager only): the branches with their number of rooms and active classes, and below
// them the rooms of the selected branch. New / edit a branch (usp_Branch_Add / _Update; a branch with active
// classes cannot be suspended, 50093) and a room (usp_Room_Add / _Update; trg_ROOM_CheckClasses keeps a room
// used by an active class in its branch and large enough).
class BranchPage : public DataPage {
    Q_OBJECT
public:
    explicit BranchPage(AppServices services, QWidget* parent = nullptr);

protected:
    Result<TableData> fetch() override;
    void dataLoaded() override;

private:
    void loadRooms();
    void editBranch(bool isNew);
    void editRoom(bool isNew);

    QLabel* m_roomsTitle = nullptr;
    DataTable* m_rooms = nullptr;
    QPushButton* m_addRoom = nullptr;
    QPushButton* m_editRoom = nullptr;
};
