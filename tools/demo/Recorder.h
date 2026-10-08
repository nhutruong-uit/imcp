#pragma once

#include <QElapsedTimer>
#include <QList>
#include <QMutex>
#include <QPoint>
#include <QPointF>
#include <QProcess>
#include <QSize>
#include <QString>
#include <QTimer>

class QImage;
class QPainter;
class QWidget;

// Records the demo video: several times a second it takes a picture of the application's own windows (the
// main window, the dialog on top of it, an open combo box list), paints what a screen recorder would show
// (a mouse pointer with a click ripple, a caption bar, title cards) and pipes the picture to ffmpeg, which
// writes the .mp4. The pictures come from Qt itself (QWidget::grab), so nothing depends on the real screen:
// no Screen Recording permission, no other window can get in the way, and a rerun gives the same video.
// Used by `Director` (the script's helper) and `demo_video_tool.cpp`. Course concept: none (developer tool).
//
// Threads: the recorder lives in the GUI thread (QWidget may only be touched there). The script runs in its
// own thread and changes the overlay (pointer, caption, card) through the setters, which lock a mutex.
class Recorder {
public:
    // appSize: the area the application (its windows and dialogs) fills; captionBand: height of the strip
    // below it where the captions are written, so a caption never hides a button. The video is
    // appSize + captionBand high.
    Recorder(QSize appSize, int captionBand, int fps, QString outputPath);

    // Starts ffmpeg and the frame timer; false (with the reason) when ffmpeg cannot be started
    bool start(QString* error);
    // Writes the last frames and closes ffmpeg. succeeded: the video becomes the output file (with the
    // chapters); otherwise the pictures so far are kept as <output>.failed.mp4 and the output file is left
    // alone. False (with the reason) when ffmpeg or the file fails.
    bool finish(bool succeeded, QString* error);

    // The window that fills the picture (the main window, or the login dialog centered on a backdrop).
    // Other windows (dialogs, popups) are drawn relative to it.
    void setAnchor(QWidget* window);
    // Where a point of a widget appears in the picture (the pointer glides there)
    QPointF canvasPoint(const QWidget* widget, const QPoint& local) const;

    // --- overlay, callable from the script thread ---
    qint64 nowMs() const { return m_clock.elapsed(); }
    void setCursor(const QPointF& position, bool visible);
    QPointF cursor() const;
    void ripple(const QPointF& position); // a click at that place
    void setCaption(const QString& text);
    void setCard(const QString& title, const QString& subtitle, double opacity);
    void addChapter(const QString& title);

private:
    struct Overlay {
        QPointF cursor{-100, -100};
        bool cursorVisible = false;
        QPointF rippleAt;
        qint64 rippleSince = -100000;
        QString caption;
        qint64 captionSince = 0;
        QString cardTitle;
        QString cardSubtitle;
        double cardOpacity = 0;
    };
    struct Chapter {
        qint64 startMs;
        QString title;
    };

    void pump();
    QImage compose();
    QPoint drawnPosition(const QWidget* window) const;
    QList<QWidget*> visibleWindows() const;
    void drawWindows(QPainter& p) const;
    void drawCursor(QPainter& p, const Overlay& o, qint64 now) const;
    void drawCaption(QPainter& p, const Overlay& o, qint64 now) const;
    void drawCard(QPainter& p, const Overlay& o) const;

    QSize m_app;    // where the application is drawn
    int m_band;     // caption strip below it
    QSize m_canvas; // the whole picture
    int m_fps;
    QString m_output;
    QString m_partFile;
    QProcess m_ffmpeg;
    QTimer m_timer;
    QElapsedTimer m_clock;
    qint64 m_written = 0;
    QWidget* m_anchor = nullptr;
    mutable QMutex m_mutex;
    Overlay m_overlay;
    QList<Chapter> m_chapters;
};
