#include "TouchBridge.h"

#include <QCoreApplication>
#include <QDir>
#include <QFileInfoList>
#include <QMouseEvent>
#include <QPointer>
#include <QQuickItem>
#include <QQuickWindow>
#include <QSocketNotifier>
#include <QTimer>
#include <QDebug>

#include <algorithm>
#include <cerrno>
#include <cstring>

#include <fcntl.h>
#include <linux/input.h>
#include <sys/ioctl.h>
#include <unistd.h>

namespace {
QPointer<TouchBridge> activeBridge;

template <size_t N>
bool bitSet(const unsigned long (&bits)[N], unsigned int bit)
{
    constexpr unsigned int wordBits = sizeof(unsigned long) * 8;
    return bit / wordBits < N && (bits[bit / wordBits] & (1UL << (bit % wordBits)));
}

bool isDirectTouchscreen(int fd, QString *name, bool *multitouch)
{
    char rawName[256]{};
    if (::ioctl(fd, EVIOCGNAME(sizeof(rawName)), rawName) >= 0)
        *name = QString::fromUtf8(rawName);

    unsigned long properties[(INPUT_PROP_MAX / (sizeof(unsigned long) * 8)) + 1]{};
    unsigned long absBits[(ABS_MAX / (sizeof(unsigned long) * 8)) + 1]{};
    unsigned long keyBits[(KEY_MAX / (sizeof(unsigned long) * 8)) + 1]{};
    ::ioctl(fd, EVIOCGPROP(sizeof(properties)), properties);
    ::ioctl(fd, EVIOCGBIT(EV_ABS, sizeof(absBits)), absBits);
    ::ioctl(fd, EVIOCGBIT(EV_KEY, sizeof(keyBits)), keyBits);

    const bool mt = bitSet(absBits, ABS_MT_POSITION_X)
        && bitSet(absBits, ABS_MT_POSITION_Y)
        && bitSet(absBits, ABS_MT_TRACKING_ID);
    const bool single = bitSet(absBits, ABS_X)
        && bitSet(absBits, ABS_Y)
        && bitSet(keyBits, BTN_TOUCH);
    *multitouch = mt;
    return bitSet(properties, INPUT_PROP_DIRECT) && (mt || single);
}
}

TouchBridge::TouchBridge(QObject *parent)
    : QObject(parent)
{
    resetInputState();
    m_retryTimer = new QTimer(this);
    m_retryTimer->setInterval(1000);
    connect(m_retryTimer, &QTimer::timeout, this, [this] {
        if (m_wantsActive && !active())
            start();
    });
}

TouchBridge::~TouchBridge()
{
    stop();
}

QObject *TouchBridge::window() const
{
    return m_target;
}

void TouchBridge::setWindow(QObject *window)
{
    if (window == m_target)
        return;
    if (m_target)
        disconnect(m_target, nullptr, this, nullptr);
    m_target = window;
    auto *quickWindow = qobject_cast<QQuickWindow *>(window);
    if (!quickWindow) {
        if (auto *item = qobject_cast<QQuickItem *>(window)) {
            quickWindow = item->window();
            connect(item, &QQuickItem::windowChanged, this, [this, item](QQuickWindow *attachedWindow) {
                m_window = attachedWindow;
                qInfo() << "[OmaDeckTouch] target window attached" << m_window
                        << (m_window ? m_window->size() : QSize());
            });
        }
    }
    m_window = quickWindow;
    qInfo() << "[OmaDeckTouch] target window" << m_window
            << (m_window ? m_window->size() : QSize());
    emit windowChanged();
}

QString TouchBridge::findTouchscreen() const
{
    QDir input(QStringLiteral("/dev/input"));
    auto entries = input.entryInfoList({QStringLiteral("event*")}, QDir::System | QDir::Files, QDir::Name);
    QString fallback;

    for (const QFileInfo &entry : entries) {
        const int fd = ::open(entry.absoluteFilePath().toUtf8().constData(),
                              O_RDONLY | O_NONBLOCK | O_CLOEXEC);
        if (fd < 0)
            continue;
        QString name;
        bool multitouch = false;
        const bool touch = isDirectTouchscreen(fd, &name, &multitouch);
        ::close(fd);
        if (!touch)
            continue;
        if (fallback.isEmpty())
            fallback = entry.absoluteFilePath();
        if (name.contains(QStringLiteral("WCH.CN"), Qt::CaseInsensitive)
            || name.contains(QStringLiteral("XENEON"), Qt::CaseInsensitive))
            return entry.absoluteFilePath();
    }
    return fallback;
}

bool TouchBridge::start()
{
    m_wantsActive = true;
    if (active())
        return true;

    // Quickshell can recover from a QML crash inside the same process. The old
    // plugin object may survive that engine reset long enough to retain its
    // EVIOCGRAB, so explicitly hand ownership to the replacement instance.
    if (activeBridge && activeBridge != this) {
        qInfo() << "[OmaDeckTouch] releasing stale bridge before reconnect";
        activeBridge->stop();
    }

    const QString path = findTouchscreen();
    if (path.isEmpty()) {
        setStatus(QStringLiteral("No accessible direct touchscreen found"));
        scheduleReconnect();
        return false;
    }
    const bool opened = openDevice(path);
    if (opened)
        m_retryTimer->stop();
    else
        scheduleReconnect();
    return opened;
}

bool TouchBridge::openDevice(const QString &path)
{
    // Never leak the exclusive evdev file description into helpers launched
    // by Quickshell. A leaked duplicate keeps EVIOCGRAB alive after the bridge
    // or shell restarts, making the replacement bridge look connected while
    // all touch remains permanently blocked.
    m_fd = ::open(path.toUtf8().constData(), O_RDONLY | O_NONBLOCK | O_CLOEXEC);
    if (m_fd < 0) {
        setStatus(QStringLiteral("Cannot open %1: %2").arg(path, QString::fromLocal8Bit(std::strerror(errno))));
        return false;
    }

    // Belt-and-suspenders: Quickshell launches many long-lived helpers from
    // this process. Confirm the descriptor flag directly instead of relying
    // only on the atomic open flag.
    const int descriptorFlags = ::fcntl(m_fd, F_GETFD);
    if (descriptorFlags < 0 || ::fcntl(m_fd, F_SETFD, descriptorFlags | FD_CLOEXEC) < 0) {
        setStatus(QStringLiteral("Cannot protect %1 from descriptor inheritance: %2")
                      .arg(path, QString::fromLocal8Bit(std::strerror(errno))));
        ::close(m_fd);
        m_fd = -1;
        return false;
    }

    QString name;
    if (!isDirectTouchscreen(m_fd, &name, &m_hasMultitouch)) {
        setStatus(QStringLiteral("%1 is not a direct touchscreen").arg(path));
        ::close(m_fd);
        m_fd = -1;
        return false;
    }

    input_absinfo xInfo{}, yInfo{};
    const int xAxis = m_hasMultitouch ? ABS_MT_POSITION_X : ABS_X;
    const int yAxis = m_hasMultitouch ? ABS_MT_POSITION_Y : ABS_Y;
    if (::ioctl(m_fd, EVIOCGABS(xAxis), &xInfo) < 0
        || ::ioctl(m_fd, EVIOCGABS(yAxis), &yInfo) < 0
        || xInfo.maximum <= xInfo.minimum || yInfo.maximum <= yInfo.minimum) {
        setStatus(QStringLiteral("Invalid touchscreen axis range"));
        ::close(m_fd);
        m_fd = -1;
        return false;
    }
    m_xMin = xInfo.minimum;
    m_xMax = xInfo.maximum;
    m_yMin = yInfo.minimum;
    m_yMax = yInfo.maximum;

    if (::ioctl(m_fd, EVIOCGRAB, 1) < 0) {
        setStatus(QStringLiteral("Cannot isolate %1: %2").arg(path, QString::fromLocal8Bit(std::strerror(errno))));
        ::close(m_fd);
        m_fd = -1;
        return false;
    }

    resetInputState();
    m_devicePath = path;
    m_notifier = new QSocketNotifier(m_fd, QSocketNotifier::Read, this);
    connect(m_notifier, &QSocketNotifier::activated, this, &TouchBridge::readEvents);
    activeBridge = this;
    setStatus(QStringLiteral("Isolated direct touch: %1").arg(name));
    qInfo() << "[OmaDeckTouch] grabbed" << path << name
            << "multitouch" << m_hasMultitouch
            << "axes" << m_xMin << m_xMax << m_yMin << m_yMax
            << "closeOnExec" << bool(::fcntl(m_fd, F_GETFD) & FD_CLOEXEC);
    emit devicePathChanged();
    emit activeChanged();
    return true;
}

void TouchBridge::stop()
{
    m_wantsActive = false;
    m_retryTimer->stop();
    closeDevice(QStringLiteral("Direct touch stopped"));
}

void TouchBridge::closeDevice(const QString &status)
{
    if (m_fd < 0) {
        if (activeBridge == this)
            activeBridge.clear();
        setStatus(status);
        return;
    }
    if (m_pointerDown && m_window) {
        QMouseEvent release(QEvent::MouseButtonRelease, m_lastPosition,
                            m_window->mapToGlobal(m_lastPosition), Qt::LeftButton,
                            Qt::NoButton, Qt::NoModifier);
        QCoreApplication::sendEvent(m_window, &release);
    }
    m_pointerDown = false;
    delete m_notifier;
    m_notifier = nullptr;
    ::ioctl(m_fd, EVIOCGRAB, 0);
    ::close(m_fd);
    m_fd = -1;
    if (activeBridge == this)
        activeBridge.clear();
    m_devicePath.clear();
    resetInputState();
    setStatus(status);
    emit devicePathChanged();
    emit activeChanged();
}

void TouchBridge::scheduleReconnect()
{
    if (m_wantsActive && !m_retryTimer->isActive())
        m_retryTimer->start();
}

void TouchBridge::resetInputState()
{
    std::fill(std::begin(m_trackingIds), std::end(m_trackingIds), -1);
    std::fill(std::begin(m_x), std::end(m_x), 0);
    std::fill(std::begin(m_y), std::end(m_y), 0);
    m_currentSlot = 0;
    m_activeSlot = -1;
    m_singleX = 0;
    m_singleY = 0;
    m_singlePressed = false;
    m_pointerDown = false;
    m_lastPosition = {};
}

void TouchBridge::readEvents()
{
    input_event events[32];
    const ssize_t bytes = ::read(m_fd, events, sizeof(events));
    if (bytes <= 0) {
        if (bytes == 0 || (errno != EAGAIN && errno != EINTR)) {
            qInfo() << "[OmaDeckTouch] device disconnected" << m_devicePath;
            closeDevice(QStringLiteral("Touch device disconnected; reconnecting…"));
            scheduleReconnect();
        }
        return;
    }

    bool pressed = false;
    bool released = false;
    const int count = static_cast<int>(bytes / sizeof(input_event));
    for (int i = 0; i < count; ++i) {
        const input_event &event = events[i];
        if (event.type == EV_ABS && m_hasMultitouch) {
            if (event.code == ABS_MT_SLOT)
                m_currentSlot = std::clamp(event.value, 0, 15);
            else if (event.code == ABS_MT_TRACKING_ID) {
                const int previous = m_trackingIds[m_currentSlot];
                m_trackingIds[m_currentSlot] = event.value;
                if (event.value >= 0 && m_activeSlot < 0) {
                    m_activeSlot = m_currentSlot;
                    pressed = true;
                } else if (event.value < 0 && m_activeSlot == m_currentSlot) {
                    released = previous >= 0;
                    m_activeSlot = -1;
                    for (int slot = 0; slot < 16; ++slot) {
                        if (m_trackingIds[slot] >= 0) {
                            m_activeSlot = slot;
                            break;
                        }
                    }
                }
            } else if (event.code == ABS_MT_POSITION_X)
                m_x[m_currentSlot] = event.value;
            else if (event.code == ABS_MT_POSITION_Y)
                m_y[m_currentSlot] = event.value;
        } else if (event.type == EV_ABS) {
            if (event.code == ABS_X) m_singleX = event.value;
            else if (event.code == ABS_Y) m_singleY = event.value;
        } else if (event.type == EV_KEY && event.code == BTN_TOUCH) {
            pressed = event.value && !m_singlePressed;
            released = !event.value && m_singlePressed;
            m_singlePressed = event.value;
        } else if (event.type == EV_SYN && event.code == SYN_REPORT) {
            dispatch(pressed, released);
            pressed = false;
            released = false;
        }
    }
}

void TouchBridge::dispatch(bool pressed, bool released)
{
    if (!m_window)
        return;
    // A multitouch tracking ID is cleared before the release SYN_REPORT.  At
    // that point there is no active slot to read, so keep the position from
    // the preceding report instead of falling back to the zeroed single-touch
    // axes.  Moving the release to (0, 0) prevents Qt tap handlers from
    // recognizing clicks, although drag-driven controls can still appear to
    // work.
    int rawX = m_singleX;
    int rawY = m_singleY;
    if (!(released && m_hasMultitouch)) {
        if (m_hasMultitouch && m_activeSlot >= 0) {
            rawX = m_x[m_activeSlot];
            rawY = m_y[m_activeSlot];
        }
        const qreal nx = std::clamp(qreal(rawX - m_xMin) / qreal(m_xMax - m_xMin), 0.0, 1.0);
        const qreal ny = std::clamp(qreal(rawY - m_yMin) / qreal(m_yMax - m_yMin), 0.0, 1.0);
        m_lastPosition = QPointF(nx * m_window->width(), ny * m_window->height());
    }

    if (pressed || released)
        qInfo() << "[OmaDeckTouch]" << (pressed ? "press" : "release")
                << "raw" << (released && m_hasMultitouch ? QStringLiteral("last") : QString::number(rawX))
                << (released && m_hasMultitouch ? QStringLiteral("last") : QString::number(rawY))
                << "local" << m_lastPosition
                << "window" << m_window->size();

    QEvent::Type type = QEvent::MouseMove;
    Qt::MouseButton button = Qt::NoButton;
    Qt::MouseButtons buttons = m_pointerDown ? Qt::LeftButton : Qt::NoButton;
    if (pressed) {
        type = QEvent::MouseButtonPress;
        button = Qt::LeftButton;
        buttons = Qt::LeftButton;
        m_pointerDown = true;
    } else if (released) {
        type = QEvent::MouseButtonRelease;
        button = Qt::LeftButton;
        buttons = Qt::NoButton;
        m_pointerDown = false;
    } else if (!m_pointerDown) {
        return;
    }

    QMouseEvent mouseEvent(type, m_lastPosition, m_window->mapToGlobal(m_lastPosition),
                           button, buttons, Qt::NoModifier);
    mouseEvent.setTimestamp(0);
    const bool delivered = QCoreApplication::sendEvent(m_window, &mouseEvent);
    if (pressed || released)
        qInfo() << "[OmaDeckTouch] Qt delivery" << delivered
                << "accepted" << mouseEvent.isAccepted();

    // A direct touch has no persistent pointer position.  Without a leave
    // event, Qt keeps HoverHandlers under the synthetic mouse release active
    // until a real mouse moves or another touch occurs.
    if (released) {
        QEvent leaveEvent(QEvent::Leave);
        QCoreApplication::sendEvent(m_window, &leaveEvent);
    }
}

void TouchBridge::setStatus(const QString &status)
{
    if (m_status == status)
        return;
    m_status = status;
    qInfo() << "[OmaDeckTouch] status" << m_status;
    emit statusChanged();
}
