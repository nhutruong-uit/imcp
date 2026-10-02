#include "infrastructure/db/SqlHelpers.h"

#include <algorithm>

namespace {
// Positions of the '?' parameter markers, skipping 'literals', "quoted" / [bracketed] identifiers
// (a doubled closing character is an escaped one) and -- / /* */ comments (T-SQL block comments nest)
QList<qsizetype> markerPositions(const QString& sql) {
    QList<qsizetype> positions;
    const qsizetype n = sql.size();
    for (qsizetype i = 0; i < n; ++i) {
        const QChar c = sql.at(i);
        if (c == u'\'' || c == u'"' || c == u'[') {
            const QChar close = c == u'[' ? QChar(u']') : c;
            for (++i; i < n; ++i) {
                if (sql.at(i) != close)
                    continue;
                if (i + 1 < n && sql.at(i + 1) == close)
                    ++i;
                else
                    break;
            }
        } else if (c == u'-' && i + 1 < n && sql.at(i + 1) == u'-') {
            while (i < n && sql.at(i) != u'\n')
                ++i;
        } else if (c == u'/' && i + 1 < n && sql.at(i + 1) == u'*') {
            int depth = 0;
            for (; i < n; ++i) {
                if (sql.at(i) == u'/' && i + 1 < n && sql.at(i + 1) == u'*') {
                    ++depth;
                    ++i;
                } else if (sql.at(i) == u'*' && i + 1 < n && sql.at(i + 1) == u'/') {
                    ++i;
                    if (--depth == 0)
                        break;
                }
            }
        } else if (c == u'?') {
            positions.append(i);
        }
    }
    return positions;
}

// Only non-ASCII text is damaged by the VARCHAR conversion; ASCII text, NULLs and other types are not
bool needsUnicodeTransport(const QVariant& v) {
    if (v.typeId() != QMetaType::QString || v.isNull())
        return false;
    const QString s = v.toString();
    return std::any_of(s.cbegin(), s.cend(), [](QChar c) { return c.unicode() > 0x7F; });
}

QByteArray utf16LittleEndian(const QString& s) {
    QByteArray bytes;
    bytes.reserve(s.size() * 2);
    for (const QChar c : s) {
        bytes.append(char(c.unicode() & 0xFF));
        bytes.append(char(c.unicode() >> 8));
    }
    return bytes;
}
} // namespace

namespace SqlHelpers {

BoundStatement withUnicodeText(const QString& sql, const QVariantList& values) {
    const QList<qsizetype> markers = markerPositions(sql);
    if (markers.size() != values.size())
        return {sql, values}; // let the driver report the mismatch
    QString declarations;
    QString body;
    QVariantList textValues;
    QVariantList otherValues;
    qsizetype copied = 0;
    for (qsizetype i = 0; i < markers.size(); ++i) {
        body += sql.mid(copied, markers.at(i) - copied);
        copied = markers.at(i) + 1;
        if (!needsUnicodeTransport(values.at(i))) {
            body += u'?';
            otherValues.append(values.at(i));
            continue;
        }
        const QString variable = QStringLiteral("@UnicodeText%1").arg(textValues.size() + 1);
        declarations +=
            QStringLiteral("DECLARE %1 NVARCHAR(MAX) = CAST(CAST(? AS VARBINARY(MAX)) AS NVARCHAR(MAX)); ")
                .arg(variable);
        textValues.append(utf16LittleEndian(values.at(i).toString()));
        body += variable;
    }
    if (textValues.isEmpty())
        return {sql, values};
    body += sql.mid(copied);
    return {declarations + body, textValues + otherValues};
}

bool execPrepared(QSqlQuery& q, const DatabaseManager& db, const QString& sql, const QVariantList& values) {
    const BoundStatement statement =
        db.usesFreeTds() ? withUnicodeText(sql, values) : BoundStatement{sql, values};
    if (!q.prepare(statement.sql))
        return false;
    for (const QVariant& v : statement.values)
        q.addBindValue(v);
    return q.exec();
}

} // namespace SqlHelpers
