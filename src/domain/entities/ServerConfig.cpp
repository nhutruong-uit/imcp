#include "domain/entities/ServerConfig.h"

bool ServerConfig::isLocalHost(const QString& host) {
    QString name = host.trimmed().toLower();
    if (name.startsWith(QLatin1String("tcp:")))
        name = name.mid(4).trimmed();
    if (name.startsWith(QLatin1Char('['))) {
        // "[::1],1433": the address is what stands between the brackets
        const qsizetype end = name.indexOf(QLatin1Char(']'));
        name = end > 0 ? name.mid(1, end - 1) : name.mid(1);
    } else if (name.startsWith(QLatin1String("::1"))) {
        name = QStringLiteral("::1"); // "::1,1433" is the loopback address with a port
    } else {
        // "name,port" or "name\instance" (an IPv6 address has colons, but never a comma or a backslash)
        for (const QChar separator : {QLatin1Char(','), QLatin1Char('\\')}) {
            const qsizetype cut = name.indexOf(separator);
            if (cut >= 0)
                name.truncate(cut);
        }
        name = name.trimmed();
    }
    return name == QLatin1String("localhost") || name == QLatin1String("127.0.0.1") ||
           name == QLatin1String("::1") || name == QLatin1String(".") || name == QLatin1String("(local)");
}
