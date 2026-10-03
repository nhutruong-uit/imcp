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
    const FeatureGroup general = FeatureGroup::General;
    const FeatureGroup training = FeatureGroup::Training;
    const FeatureGroup finance = FeatureGroup::Finance;
    const FeatureGroup teaching = FeatureGroup::Teaching;
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
        return {f, LabelsText::tr("Accounts"), QStringLiteral("shield"), FeatureGroup::System};
    case Feature::MyClasses:
        return {f, LabelsText::tr("My classes"), QStringLiteral("book"), teaching};
    case Feature::MyTeachingSchedule:
        return {f, LabelsText::tr("Teaching schedule"), QStringLiteral("calendar"), teaching};
    case Feature::MyPay:
        return {f, LabelsText::tr("My pay"), QStringLiteral("cash"), teaching};
    }
    return {f, QString(), QString(), FeatureGroup::General};
}

QString Labels::group(FeatureGroup group) {
    switch (group) {
    case FeatureGroup::General:
        return LabelsText::tr("General");
    case FeatureGroup::Training:
        return LabelsText::tr("Training");
    case FeatureGroup::Finance:
        return LabelsText::tr("Finance");
    case FeatureGroup::System:
        return LabelsText::tr("System");
    case FeatureGroup::Teaching:
        return LabelsText::tr("Teaching");
    }
    return QString();
}

QString Labels::accountName(const Account& account) {
    return account.databaseOwner ? LabelsText::tr("%1 (database administrator)").arg(account.username)
                                 : account.fullName;
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
