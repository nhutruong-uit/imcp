#pragma once

#include <QString>

#include <optional>
#include <utility>

// Kết quả của một thao tác: thành công (kèm giá trị) hoặc thất bại (kèm thông báo lỗi).
// Dùng thay cho exception để luồng lỗi đi rõ ràng qua các tầng và dễ hiển thị lên giao diện.
template <typename T>
class Result {
public:
    static Result success(T value) {
        Result r;
        r.m_value = std::move(value);
        return r;
    }
    static Result failure(QString error) {
        Result r;
        r.m_error = std::move(error);
        return r;
    }

    bool ok() const { return m_value.has_value(); }
    const T& value() const { return *m_value; }
    T& value() { return *m_value; }
    const QString& error() const { return m_error; }

private:
    Result() = default;
    std::optional<T> m_value;
    QString m_error;
};

// Phiên bản không trả giá trị (chỉ cần biết thành công hay thất bại)
template <>
class Result<void> {
public:
    static Result success() {
        Result r;
        r.m_ok = true;
        return r;
    }
    static Result failure(QString error) {
        Result r;
        r.m_error = std::move(error);
        return r;
    }

    bool ok() const { return m_ok; }
    const QString& error() const { return m_error; }

private:
    Result() = default;
    bool m_ok = false;
    QString m_error;
};

using VoidResult = Result<void>;
