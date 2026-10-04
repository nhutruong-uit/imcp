#pragma once

#include "presentation/common/DataPage.h"

// Accounts page (manager only): the sign-in accounts (usp_Account_List), create one for an employee or a
// teacher (usp_Account_Create: a contained database user + its role), lock / unlock it (DENY / GRANT CONNECT,
// usp_Account_Lock) and reset its password (usp_Account_ResetPassword). The database refuses to lock the
// account the manager is signed in with (50065).
class AccountPage : public DataPage {
    Q_OBJECT
public:
    explicit AccountPage(AppServices services, QWidget* parent = nullptr);

protected:
    Result<TableData> fetch() override;

private:
    void createAccount();
    void setLocked(bool locked);
    void resetPassword();
};
