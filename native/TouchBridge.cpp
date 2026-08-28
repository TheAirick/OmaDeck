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
    return m_target.data();
}

void TouchBridge::setWindow(QObject *window)
{
    if (window == m_target.data())
        return;
    if (m_target)
        disconnect(m_target.data(), nullptr, this, nullptr);
    m_target = window;
    m_window.clear();
    if (m_target) {
        connect(m_target.data(), &QObject::destroyed, this, [this] {
            m_target.clear();
            m_window.clear();
            emit windowChanged();
        });
    }
    auto *quickWindow = qobject_cast<QQuickWindow *>(window);
    if (!quickWindow) {
        if (auto *item = qobject_cast<QQuickItem *>(window)) {
            quickWindow = item->window();
            connect(item, &QQuickItem::windowChanged, this, [this](QQuickWindow *attachedWindow) {
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

QString TouchBridge::findTouchscreen(QStringList *detectedNames) const
{
    QDir input(QStringLiteral("/dev/input"));
    auto entries = input.entryInfoList({QStringLiteral("event*")}, QDir::System | QDir::Files, QDir::Name);
    QStringList paths;
    QStringList names;

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
        paths.append(entry.absoluteFilePath());
        names.append(name);
    }
    if (detectedNames)
        *detectedNames = names;
    const int selected = selectDeviceIndex(names, m_deviceNames);
    return selected >= 0 ? paths.at(selected) : QString();
}

int TouchBridge::selectDeviceIndex(const QStringList &detectedNames,
                                   const QStringList &configuredNames)
{
    if (configuredNames.isEmpty())
        return -1;
    for (int index = 0; index < detectedNames.size(); ++index) {
        for (const QString &configuredName : configuredNames) {
            if (!configuredName.isEmpty()
                && detectedNames.at(index).contains(configuredName, Qt::CaseInsensitive))
                return index;
        }
    }
    return -1;
}

void TouchBridge::setDeviceNames(const QStringList &deviceNames)
{
    QStringList normalized;
    for (const QString &deviceName : deviceNames) {
        const QString trimmed = deviceName.trimmed();
        if (!trimmed.isEmpty() && !normalized.contains(trimmed, Qt::CaseInsensitive))
            normalized.append(trimmed);
    }
    if (normalized == m_deviceNames)
        return;

    const bool reconnect = m_wantsActive;
    if (active())
        closeDevice(QStringLiteral("Touchscreen identity changed; reconnecting…"));
    m_deviceNames = normalized;
    emit deviceNamesChanged();
    if (reconnect)
        start();
}

bool TouchBridge::start()
{
    m_wantsActive = true;
    if (active())
        return true;

    // A recovered QML engine replaces the previous bridge in-process. Release
    // that bridge before any early return so an invalid or absent replacement
    // configuration cannot leave the old identity's EVIOCGRAB behind.
    if (activeBridge && activeBridge != this) {
        qInfo() << "[OmaDeckTouch] releasing stale bridge before reconnect";
        activeBridge->stop();
    }

    if (m_deviceNames.isEmpty()) {
        setStatus(QStringLiteral("No touchscreen identity configured; refusing exclusive grab"));
        scheduleReconnect();
        return false;
    }

    QStringList detectedNames;
    const QString path = findTouchscreen(&detectedNames);
    if (path.isEmpty()) {
        const QString expected = m_deviceNames.join(QStringLiteral(", "));
        if (detectedNames.isEmpty()) {
            setStatus(QStringLiteral("Configured touchscreen not found (expected name containing: %1)")
                          .arg(expected));
        } else {
            setStatus(QStringLiteral("Configured touchscreen absent or mismatched (expected: %1); refusing to grab %2 other direct touchscreen(s): %3")
                          .arg(expected)
                          .arg(detectedNames.size())
                          .arg(detectedNames.join(QStringLiteral(", "))));
        }
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

    // Discovery and open are separate syscalls. A USB re-enumeration can reuse
    // the event path between them, so authorize the name from the descriptor
    // that will actually be grabbed rather than trusting the earlier scan.
    if (selectDeviceIndex({name}, m_deviceNames) < 0) {
        setStatus(QStringLiteral("Refusing to isolate %1: device identity changed to %2")
                      .arg(path, name));
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
        setTouchInProgress(false);
        setStatus(status);
        return;
    }

    const int descriptor = m_fd;
    m_fd = -1;
    const QPointer<QQuickWindow> window = m_window;
    const bool sendRelease = m_pointerDown && window;
    const QPointF releasePosition = m_lastPosition;
    m_pointerDown = false;
    delete m_notifier;
    m_notifier = nullptr;
    ::ioctl(descriptor, EVIOCGRAB, 0);
    ::close(descriptor);
    if (activeBridge == this)
        activeBridge.clear();
    m_devicePath.clear();
    resetInputState();
    setStatus(status);
    emit devicePathChanged();
    emit activeChanged();

    // Deliver the final release only after teardown is complete. Qt event
    // handlers run synchronously and may call stop() again; by this point that
    // nested call observes an already-inactive bridge and cannot double-close.
    if (sendRelease && window) {
        QMouseEvent release(QEvent::MouseButtonRelease, releasePosition,
                            window->mapToGlobal(releasePosition), Qt::LeftButton,
                            Qt::NoButton, Qt::NoModifier);
        QCoreApplication::sendEvent(window.data(), &release);
        QEvent leaveEvent(QEvent::Leave);
        QCoreApplication::sendEvent(window.data(), &leaveEvent);
    }
    setTouchInProgress(false);
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
    const QPointer<QQuickWindow> window = m_window;
    if (!window) {
        if (released) {
            m_pointerDown = false;
            setTouchInProgress(false);
        }
        return;
    }
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
        m_lastPosition = QPointF(nx * window->width(), ny * window->height());
    }

    if (pressed || released)
        qInfo() << "[OmaDeckTouch]" << (pressed ? "press" : "release")
                << "raw" << (released && m_hasMultitouch ? QStringLiteral("last") : QString::number(rawX))
                << (released && m_hasMultitouch ? QStringLiteral("last") : QString::number(rawY))
                << "local" << m_lastPosition
                << "window" << window->size();

    QEvent::Type type = QEvent::MouseMove;
    Qt::MouseButton button = Qt::NoButton;
    Qt::MouseButtons buttons = m_pointerDown ? Qt::LeftButton : Qt::NoButton;
    if (pressed) {
        type = QEvent::MouseButtonPress;
        button = Qt::LeftButton;
        buttons = Qt::LeftButton;
        m_pointerDown = true;
        setTouchInProgress(true);
    } else if (released) {
        type = QEvent::MouseButtonRelease;
        button = Qt::LeftButton;
        buttons = Qt::NoButton;
        m_pointerDown = false;
    } else if (!m_pointerDown) {
        return;
    }

    QMouseEvent mouseEvent(type, m_lastPosition, window->mapToGlobal(m_lastPosition),
                           button, buttons, Qt::NoModifier);
    mouseEvent.setTimestamp(0);
    const bool delivered = QCoreApplication::sendEvent(window.data(), &mouseEvent);
    if (pressed || released)
        qInfo() << "[OmaDeckTouch] Qt delivery" << delivered
                << "accepted" << mouseEvent.isAccepted();

    // A direct touch has no persistent pointer position.  Without a leave
    // event, Qt keeps HoverHandlers under the synthetic mouse release active
    // until a real mouse moves or another touch occurs.
    if (released && window) {
        QEvent leaveEvent(QEvent::Leave);
        QCoreApplication::sendEvent(window.data(), &leaveEvent);
        setTouchInProgress(false);
    }
}

void TouchBridge::setTouchInProgress(bool inProgress)
{
    if (m_touchInProgress == inProgress)
        return;
    m_touchInProgress = inProgress;
    emit touchInProgressChanged();
}

void TouchBridge::setStatus(const QString &status)
{
    if (m_status == status)
        return;
    m_status = status;
    qInfo() << "[OmaDeckTouch] status" << m_status;
    emit statusChanged();
}
