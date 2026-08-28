#pragma once

#include <QObject>
#include <QPointF>
#include <QPointer>
#include <QString>
#include <QStringList>

class QQuickWindow;
class QSocketNotifier;
class QTimer;

class TouchBridge : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QObject *window READ window WRITE setWindow NOTIFY windowChanged)
    Q_PROPERTY(bool active READ active NOTIFY activeChanged)
    Q_PROPERTY(bool touchInProgress READ touchInProgress NOTIFY touchInProgressChanged)
    Q_PROPERTY(QString devicePath READ devicePath NOTIFY devicePathChanged)
    Q_PROPERTY(QStringList deviceNames READ deviceNames WRITE setDeviceNames NOTIFY deviceNamesChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)

public:
    explicit TouchBridge(QObject *parent = nullptr);
    ~TouchBridge() override;

    QObject *window() const;
    void setWindow(QObject *window);
    bool active() const { return m_fd >= 0; }
    bool touchInProgress() const { return m_touchInProgress; }
    QString devicePath() const { return m_devicePath; }
    QStringList deviceNames() const { return m_deviceNames; }
    void setDeviceNames(const QStringList &deviceNames);
    QString status() const { return m_status; }

    Q_INVOKABLE bool start();
    Q_INVOKABLE void stop();

signals:
    void windowChanged();
    void activeChanged();
    void touchInProgressChanged();
    void devicePathChanged();
    void deviceNamesChanged();
    void statusChanged();

private:
    struct Contact {
        int trackingId = -1;
        int x = 0;
        int y = 0;
    };

    static int selectDeviceIndex(const QStringList &detectedNames, const QStringList &configuredNames);
    QString findTouchscreen(QStringList *detectedNames) const;
    bool openDevice(const QString &path);
    void closeDevice(const QString &status);
    void scheduleReconnect();
    void resetInputState();
    void readEvents();
    void dispatch(bool pressed, bool released);
    void setTouchInProgress(bool inProgress);
    void setStatus(const QString &status);

    QPointer<QObject> m_target;
    QPointer<QQuickWindow> m_window;
    QSocketNotifier *m_notifier = nullptr;
    QTimer *m_retryTimer = nullptr;
    int m_fd = -1;
    QString m_devicePath;
    QStringList m_deviceNames;
    QString m_status = QStringLiteral("Direct touch not started");
    int m_xMin = 0;
    int m_xMax = 1;
    int m_yMin = 0;
    int m_yMax = 1;
    int m_currentSlot = 0;
    int m_activeSlot = -1;
    int m_trackingIds[16]{};
    int m_x[16]{};
    int m_y[16]{};
    int m_singleX = 0;
    int m_singleY = 0;
    bool m_hasMultitouch = false;
    bool m_singlePressed = false;
    bool m_pointerDown = false;
    bool m_touchInProgress = false;
    bool m_wantsActive = false;
    QPointF m_lastPosition;
};
