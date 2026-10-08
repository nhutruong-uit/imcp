#pragma once

#include <QString>
#include <QStringList>

class Director;

struct DemoSettings {
    QString password;     // shared password of the demo accounts
    QStringList chapters; // names of the chapters to record, empty = all of them
};

// False (with the reason) when a name is not a chapter of the story
bool validChapters(const QStringList& chapters, QString* error);

// The story of the video, chapter by chapter. Throws DemoError when the application does not do what the
// story expects.
void runScenario(Director& director, const DemoSettings& settings);
