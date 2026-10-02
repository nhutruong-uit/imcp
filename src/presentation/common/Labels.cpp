#include "presentation/common/Labels.h"

#include <QCoreApplication>

namespace {
// Provides tr() with translation context "Labels" for the free functions of namespace Labels
struct LabelsText {
    Q_DECLARE_TR_FUNCTIONS(Labels)
};
} // namespace

QString Labels::role(Role role) {
    switch (role) {
    case Role::Manager:
        return LabelsText::tr("Manager");
    case Role::AcademicStaff:
        return LabelsText::tr("Academic staff");
    case Role::Accountant:
        return LabelsText::tr("Accountant");
    case Role::Teacher:
        return LabelsText::tr("Teacher");
    case Role::Unknown:
        break;
    }
    return LabelsText::tr("Unknown");
}

FeatureInfo Labels::feature(Feature f) {
    const QString general = LabelsText::tr("General");
    const QString training = LabelsText::tr("Training");
    const QString finance = LabelsText::tr("Finance");
    const QString teaching = LabelsText::tr("Teaching");
    switch (f) {
    case Feature::Dashboard:
        return {f, LabelsText::tr("Overview"), QStringLiteral("home"), general};
    case Feature::Students:
        return {f, LabelsText::tr("Students"), QStringLiteral("users"), training};
    case Feature::Classes:
        return {f, LabelsText::tr("Classes"), QStringLiteral("book"), training};
    case Feature::WeeklySchedule:
        return {f, LabelsText::tr("This week's schedule"), QStringLiteral("calendar"), training};
    case Feature::LearningResults:
        return {f, LabelsText::tr("Learning results"), QStringLiteral("award"), training};
    case Feature::OutstandingTuition:
        return {f, LabelsText::tr("Outstanding tuition"), QStringLiteral("wallet"), finance};
    case Feature::Revenue:
        return {f, LabelsText::tr("Revenue"), QStringLiteral("chart"), finance};
    case Feature::Payroll:
        return {f, LabelsText::tr("Teacher payroll"), QStringLiteral("cash"), finance};
    case Feature::Accounts:
        return {f, LabelsText::tr("Accounts"), QStringLiteral("shield"), LabelsText::tr("System")};
    case Feature::MyClasses:
        return {f, LabelsText::tr("My classes"), QStringLiteral("book"), teaching};
    case Feature::MyTeachingSchedule:
        return {f, LabelsText::tr("Teaching schedule"), QStringLiteral("calendar"), teaching};
    case Feature::MyPay:
        return {f, LabelsText::tr("My pay"), QStringLiteral("cash"), teaching};
    }
    return {f, QString(), QString(), QString()};
}

QString Labels::language(Language language) {
    switch (language) {
    case Language::Vietnamese:
        return QStringLiteral("Tiếng Việt");
    case Language::English:
        return QStringLiteral("English");
    }
    return QString();
}
