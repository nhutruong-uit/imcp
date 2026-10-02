#pragma once

#include <QString>

#include <optional>
#include <utility>

// Outcome of an operation: success (with a value) or failure (with a user-facing error message).
// Used instead of exceptions so that errors flow explicitly through the layers and are easy to show
// in the UI.
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

// Variant without a value (only success or failure matters)
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
