#include "Recorder.h"

#include "presentation/common/Icons.h"

#include <QApplication>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFontMetrics>
#include <QImage>
#include <QLinearGradient>
#include <QMutexLocker>
#include <QPainter>
#include <QPolygonF>
#include <QStandardPaths>
#include <QTextStream>
#include <QWidget>
#include <algorithm>

namespace {
constexpr int kRippleMs = 450;

bool isPopup(const QWidget* w) {
    const Qt::WindowType type = w->windowType();
    return type == Qt::Popup || type == Qt::ToolTip;
}

// How many windows own this one (a dialog of the main window = 1, a message box of that dialog = 2): the
// deeper window is drawn later, so it ends on top
int windowDepth(const QWidget* w) {
    int depth = 0;
    for (const QWidget* p = w->parentWidget(); p; p = p->parentWidget())
        if (p->isWindow())
            ++depth;
    return depth;
}

QString ffmpegProgram() {
    const QString configured = qEnvironmentVariable("QLTTTA_FFMPEG");
    return configured.isEmpty() ? QStandardPaths::findExecutable(QStringLiteral("ffmpeg")) : configured;
}

QString withSuffix(const QString& file, const QString& suffix) {
    const QFileInfo info(file);
    return info.dir().filePath(info.completeBaseName() + suffix + QStringLiteral(".mp4"));
}
} // namespace

Recorder::Recorder(QSize appSize, int captionBand, int fps, QString outputPath)
    : m_app(appSize), m_band(captionBand), m_canvas(appSize.width(), appSize.height() + captionBand),
      m_fps(fps), m_output(std::move(outputPath)), m_partFile(withSuffix(m_output, QStringLiteral(".part"))) {
}

bool Recorder::start(QString* error) {
    const QString program = ffmpegProgram();
    if (program.isEmpty()) {
        *error = QStringLiteral("ffmpeg was not found in PATH (macOS: brew install ffmpeg; Windows: winget "
                                "install Gyan.FFmpeg); QLTTTA_FFMPEG can name the program");
        return false;
    }
    QDir().mkpath(QFileInfo(m_output).absolutePath());
    const QStringList arguments = {
        QStringLiteral("-hide_banner"), QStringLiteral("-loglevel"), QStringLiteral("error"),
        QStringLiteral("-y"),
        // What Recorder::compose() writes: raw 32-bit pictures (Format_RGB32 = bytes B, G, R, unused)
        QStringLiteral("-f"), QStringLiteral("rawvideo"), QStringLiteral("-pix_fmt"), QStringLiteral("bgr0"),
        QStringLiteral("-video_size"), QStringLiteral("%1x%2").arg(m_canvas.width()).arg(m_canvas.height()),
        QStringLiteral("-framerate"), QString::number(m_fps), QStringLiteral("-i"), QStringLiteral("pipe:0"),
        // H.264 in a yuv420p .mp4 plays everywhere (QuickTime, browsers, GitHub); an interface changes little
        // from one picture to the next, so a high CRF keeps the file small without visible loss
        QStringLiteral("-an"), QStringLiteral("-c:v"), QStringLiteral("libx264"), QStringLiteral("-preset"),
        QStringLiteral("slow"), QStringLiteral("-crf"),
        qEnvironmentVariable("QLTTTA_DEMO_CRF", QStringLiteral("27")), QStringLiteral("-pix_fmt"),
        QStringLiteral("yuv420p"), QStringLiteral("-profile:v"), QStringLiteral("high"),
        QStringLiteral("-movflags"), QStringLiteral("+faststart"), m_partFile};
    m_ffmpeg.setProcessChannelMode(QProcess::ForwardedChannels);
    m_ffmpeg.start(program, arguments);
    if (!m_ffmpeg.waitForStarted(10000)) {
        *error = QStringLiteral("cannot start %1: %2").arg(program, m_ffmpeg.errorString());
        return false;
    }
    m_clock.start();
    m_timer.setTimerType(Qt::PreciseTimer);
    m_timer.setInterval(std::max(5, 500 / m_fps));
    QObject::connect(&m_timer, &QTimer::timeout, &m_timer, [this] { pump(); });
    m_timer.start();
    return true;
}

void Recorder::setAnchor(QWidget* window) {
    m_anchor = window;
}

// ---- frame loop ------------------------------------------------------------------------------------------

// The video must last as long as the script did, so the number of pictures follows the clock: when a picture
// takes longer than one frame (a database call blocks the GUI thread) the same picture fills the gap
void Recorder::pump() {
    const qint64 due = m_clock.elapsed() * m_fps / 1000;
    if (m_written >= due)
        return;
    const QImage frame = compose();
    const qint64 bytes = frame.sizeInBytes();
    while (m_written < due) {
        m_ffmpeg.write(reinterpret_cast<const char*>(frame.constBits()), bytes);
        ++m_written;
        if (m_ffmpeg.bytesToWrite() > 6 * bytes) // ffmpeg is behind: wait instead of filling the memory
            m_ffmpeg.waitForBytesWritten(5000);
    }
}

bool Recorder::finish(bool succeeded, QString* error) {
    m_timer.stop();
    pump();
    const qint64 lengthMs = m_clock.elapsed();
    m_ffmpeg.waitForBytesWritten(60000);
    m_ffmpeg.closeWriteChannel();
    if (!m_ffmpeg.waitForFinished(600000) || m_ffmpeg.exitStatus() != QProcess::NormalExit ||
        m_ffmpeg.exitCode() != 0) {
        *error = QStringLiteral("ffmpeg failed (exit code %1)").arg(m_ffmpeg.exitCode());
        return false;
    }
    // A broken run keeps its pictures under another name, so a good video is never overwritten by half a one
    const QString target = succeeded ? m_output : withSuffix(m_output, QStringLiteral(".failed"));
    QFile::remove(target);
    if (succeeded && !m_chapters.isEmpty()) {
        const QString metadata = withSuffix(m_output, QStringLiteral(".chapters")) + QStringLiteral(".txt");
        QFile file(metadata);
        if (file.open(QIODevice::WriteOnly | QIODevice::Text)) {
            QTextStream out(&file);
            out << ";FFMETADATA1\n";
            for (int i = 0; i < m_chapters.size(); ++i) {
                const qint64 end = i + 1 < m_chapters.size() ? m_chapters[i + 1].startMs : lengthMs;
                out << "[CHAPTER]\nTIMEBASE=1/1000\nSTART=" << m_chapters[i].startMs << "\nEND=" << end
                    << "\ntitle=" << m_chapters[i].title << "\n";
            }
            file.close();
            // Second, quick pass: copies the streams and adds the chapter list (shown by QuickTime, VLC...)
            QProcess remux;
            remux.setProcessChannelMode(QProcess::ForwardedChannels);
            remux.start(ffmpegProgram(), {QStringLiteral("-hide_banner"), QStringLiteral("-loglevel"),
                                          QStringLiteral("error"), QStringLiteral("-y"), QStringLiteral("-i"),
                                          m_partFile, QStringLiteral("-i"), metadata, QStringLiteral("-map"),
                                          QStringLiteral("0"), QStringLiteral("-map_metadata"),
                                          QStringLiteral("1"), QStringLiteral("-map_chapters"),
                                          QStringLiteral("1"), QStringLiteral("-c"), QStringLiteral("copy"),
                                          QStringLiteral("-movflags"), QStringLiteral("+faststart"), target});
            const bool remuxed = remux.waitForFinished(120000) && remux.exitCode() == 0;
            QFile::remove(metadata);
            if (remuxed) {
                QFile::remove(m_partFile);
                return true;
            }
            QFile::remove(target); // fall through: keep the video without chapters
        }
    }
    if (!QFile::rename(m_partFile, target)) {
        *error = QStringLiteral("cannot write %1").arg(target);
        return false;
    }
    return true;
}

// ---- overlay (script thread) -----------------------------------------------------------------------------

void Recorder::setCursor(const QPointF& position, bool visible) {
    QMutexLocker lock(&m_mutex);
    m_overlay.cursor = position;
    m_overlay.cursorVisible = visible;
}

QPointF Recorder::cursor() const {
    QMutexLocker lock(&m_mutex);
    return m_overlay.cursor;
}

void Recorder::ripple(const QPointF& position) {
    QMutexLocker lock(&m_mutex);
    m_overlay.rippleAt = position;
    m_overlay.rippleSince = nowMs();
}

void Recorder::setCaption(const QString& text) {
    QMutexLocker lock(&m_mutex);
    m_overlay.caption = text;
    m_overlay.captionSince = nowMs();
}

void Recorder::setCard(const QString& title, const QString& subtitle, double opacity) {
    QMutexLocker lock(&m_mutex);
    m_overlay.cardTitle = title;
    m_overlay.cardSubtitle = subtitle;
    m_overlay.cardOpacity = opacity;
}

void Recorder::addChapter(const QString& title) {
    QMutexLocker lock(&m_mutex);
    m_chapters.append({nowMs(), title});
}

// ---- windows ---------------------------------------------------------------------------------------------

// Where a window appears in the picture. The anchor fills it (or sits in the middle when smaller, like the
// login dialog); a dialog is centered on the anchor, whatever the offscreen screen made of its position; a
// popup (combo box list, menu) keeps its place relative to the window it belongs to.
QPoint Recorder::drawnPosition(const QWidget* window) const {
    if (!m_anchor)
        return {};
    const QPoint anchorAt((m_app.width() - m_anchor->width()) / 2, (m_app.height() - m_anchor->height()) / 2);
    if (window == m_anchor)
        return anchorAt;
    if (isPopup(window)) {
        const QWidget* owner = window->parentWidget() ? window->parentWidget()->window() : m_anchor;
        if (owner == window)
            owner = m_anchor;
        return drawnPosition(owner) + (window->geometry().topLeft() - owner->geometry().topLeft());
    }
    return {(m_app.width() - window->width()) / 2, (m_app.height() - window->height()) / 2};
}

QPointF Recorder::canvasPoint(const QWidget* widget, const QPoint& local) const {
    const QWidget* top = widget->window();
    return QPointF(drawnPosition(top) + widget->mapTo(top, local));
}

QList<QWidget*> Recorder::visibleWindows() const {
    QList<QWidget*> windows;
    for (QWidget* w : QApplication::topLevelWidgets())
        if (w->isVisible() && !w->size().isEmpty())
            windows.append(w);
    const auto rank = [this](const QWidget* w) {
        if (w == m_anchor)
            return 0;
        return isPopup(w) ? 1000 : 10 + 10 * windowDepth(w);
    };
    std::sort(windows.begin(), windows.end(), [&](const QWidget* a, const QWidget* b) {
        return rank(a) != rank(b) ? rank(a) < rank(b) : a < b;
    });
    return windows;
}

void Recorder::drawWindows(QPainter& p) const {
    bool dimmed = false;
    for (QWidget* w : visibleWindows()) {
        const QPoint at = drawnPosition(w);
        if (w != m_anchor) {
            if (w->isModal() && !dimmed) { // what is behind a dialog fades, like the focus does
                p.fillRect(QRect(QPoint(), m_app), QColor(15, 23, 42, 96));
                dimmed = true;
            }
            for (int spread = 14; spread >= 2; spread -= 4) { // soft shadow
                p.setPen(Qt::NoPen);
                p.setBrush(QColor(0, 0, 0, 14));
                p.drawRoundedRect(QRect(at, w->size()).adjusted(-spread, -spread + 8, spread, spread + 8),
                                  8 + spread / 2, 8 + spread / 2);
            }
        }
        p.drawPixmap(at, w->grab());
    }
}

// ---- overlay painting ------------------------------------------------------------------------------------

void Recorder::drawCursor(QPainter& p, const Overlay& o, qint64 now) const {
    const qint64 age = now - o.rippleSince;
    if (age >= 0 && age < kRippleMs) {
        const double t = double(age) / kRippleMs;
        QColor ring(44, 118, 181, int(190 * (1 - t)));
        p.setBrush(Qt::NoBrush);
        p.setPen(QPen(ring, 3));
        p.drawEllipse(o.rippleAt, 8 + 26 * t, 8 + 26 * t);
    }
    if (!o.cursorVisible)
        return;
    // The arrow, with its tip at the pointer position
    static const QPolygonF arrow(
        {{0, 0}, {0, 17}, {4.2, 13.4}, {7.2, 20.4}, {9.8, 19.3}, {6.9, 12.4}, {12.3, 12.4}});
    p.save();
    p.translate(o.cursor);
    p.scale(1.35, 1.35);
    p.setPen(Qt::NoPen);
    p.setBrush(QColor(0, 0, 0, 70));
    p.drawPolygon(arrow.translated(1.2, 1.6));
    p.setPen(QPen(QColor(20, 24, 33), 1.2, Qt::SolidLine, Qt::RoundCap, Qt::RoundJoin));
    p.setBrush(Qt::white);
    p.drawPolygon(arrow);
    p.restore();
}

void Recorder::drawCaption(QPainter& p, const Overlay& o, qint64 now) const {
    const QRect band(0, m_app.height(), m_canvas.width(), m_band);
    p.fillRect(band, QColor(15, 23, 42));
    if (o.caption.isEmpty())
        return;
    QFont font = QApplication::font();
    font.setPixelSize(std::max(18, m_band * 31 / 100));
    font.setWeight(QFont::DemiBold);
    p.save();
    p.setOpacity(std::min(1.0, double(now - o.captionSince) / 180)); // fades in
    p.setPen(Qt::white);
    p.setFont(font);
    p.drawText(band.adjusted(60, 6, -60, -6), Qt::AlignCenter | Qt::TextWordWrap, o.caption);
    p.restore();
}

void Recorder::drawCard(QPainter& p, const Overlay& o) const {
    if (o.cardOpacity <= 0)
        return;
    p.save();
    p.setOpacity(std::min(1.0, o.cardOpacity));
    QLinearGradient gradient(0, 0, m_canvas.width(), m_canvas.height());
    gradient.setColorAt(0, QColor(0x1e, 0x3a, 0x5f));
    gradient.setColorAt(1, QColor(0x2c, 0x76, 0xb5));
    p.fillRect(QRect(QPoint(), m_canvas), gradient);

    const QPixmap logo = Icons::pixmap(QStringLiteral("logo"), QLatin1String("#ffffff"), 96);
    p.drawPixmap((m_canvas.width() - logo.width()) / 2, m_canvas.height() * 28 / 100, logo);

    QFont title = QApplication::font();
    title.setPixelSize(std::max(30, m_canvas.height() / 15));
    title.setWeight(QFont::Bold);
    p.setFont(title);
    p.setPen(Qt::white);
    const QRect titleBox(m_canvas.width() / 10, m_canvas.height() * 46 / 100, m_canvas.width() * 8 / 10,
                         m_canvas.height() / 6);
    p.drawText(titleBox, Qt::AlignHCenter | Qt::AlignTop | Qt::TextWordWrap, o.cardTitle);

    QFont subtitle = QApplication::font();
    subtitle.setPixelSize(std::max(18, m_canvas.height() / 31));
    p.setFont(subtitle);
    p.setPen(QColor(255, 255, 255, 215));
    const QRect subtitleBox(m_canvas.width() / 10, m_canvas.height() * 64 / 100, m_canvas.width() * 8 / 10,
                            m_canvas.height() / 5);
    p.drawText(subtitleBox, Qt::AlignHCenter | Qt::AlignTop | Qt::TextWordWrap, o.cardSubtitle);
    p.restore();
}

QImage Recorder::compose() {
    Overlay overlay;
    {
        QMutexLocker lock(&m_mutex);
        overlay = m_overlay;
    }
    const qint64 now = nowMs();
    QImage frame(m_canvas, QImage::Format_RGB32);
    QPainter p(&frame);
    p.setRenderHints(QPainter::Antialiasing | QPainter::TextAntialiasing | QPainter::SmoothPixmapTransform);
    QLinearGradient backdrop(0, 0, 0, m_app.height());
    backdrop.setColorAt(0, QColor(0xe6, 0xed, 0xf6));
    backdrop.setColorAt(1, QColor(0xc6, 0xd4, 0xe6));
    p.fillRect(QRect(QPoint(), m_app), backdrop);
    drawWindows(p);
    drawCursor(p, overlay, now);
    drawCaption(p, overlay, now);
    drawCard(p, overlay);
    return frame;
}
