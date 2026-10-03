#pragma once

#include "domain/common/Result.h"
#include "domain/common/TableData.h"
#include "domain/entities/Receipt.h"

// Port of the Tuition module: implemented by SqlTuitionRepository (usp_Receipt_*, vw_OutstandingTuition),
// faked in tst_application.cpp, used by TuitionService.
class ITuitionRepository {
public:
    virtual ~ITuitionRepository() = default;
    virtual Result<TableData> receipts(const ReceiptFilter& filter) = 0; // usp_Receipt_Search
    virtual Result<TableData> outstanding() = 0;                         // vw_OutstandingTuition
    virtual Result<QString> collect(const ReceiptRequest& request) = 0;  // usp_Receipt_Create, new ReceiptId
    virtual VoidResult cancel(const QString& receiptId, const QString& reason) = 0;
    virtual Result<ReceiptPrint> print(const QString& receiptId) = 0; // usp_Receipt_Print
};
