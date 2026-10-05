#include "domain/common/Validation.h"

#include <QRegularExpression>

bool Validation::isPhone(const QString& phone) {
    static const QRegularExpression pattern(QStringLiteral("^[0-9]{9,11}$"));
    return pattern.match(phone).hasMatch();
}

bool Validation::isEmail(const QString& email) {
    static const QRegularExpression pattern(
        QStringLiteral("^[\\x21-\\x7E]+@[\\x21-\\x7E]+\\.[\\x21-\\x7E]+$"));
    return pattern.match(email).hasMatch() && email.count(QLatin1Char('@')) == 1;
}

bool Validation::isCode(const QString& code, int maxLength) {
    static const QRegularExpression pattern(QStringLiteral("^[A-Za-z0-9_-]+$"));
    return code.size() <= maxLength && pattern.match(code).hasMatch();
}

QString Validation::withoutXmlDeclaration(const QString& xml) {
    const QString text = xml.trimmed();
    if (!text.startsWith(QLatin1String("<?xml")))
        return text;
    const qsizetype end = text.indexOf(QLatin1String("?>"));
    return end < 0 ? text : text.mid(end + 2).trimmed();
}

int Validation::age(const QDate& dateOfBirth, const QDate& asOf) {
    if (!dateOfBirth.isValid() || !asOf.isValid())
        return 0;
    int years = asOf.year() - dateOfBirth.year();
    if (asOf.month() < dateOfBirth.month() ||
        (asOf.month() == dateOfBirth.month() && asOf.day() < dateOfBirth.day()))
        --years;
    return years;
}
