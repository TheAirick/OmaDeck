#pragma once

#include "EvdevTouchState.h"

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
    Q_PROPERTY(QString activeDeviceName READ activeDeviceName NOTIFY activeDeviceNameChanged)
    Q_PROPERTY(QStringList deviceNames READ deviceNames WRITE setDeviceNames NOTIFY deviceNamesChanged)
    Q_PROPERTY(QStringList availableDeviceNames READ availableDeviceNames NOTIFY availableDeviceNamesChanged)
    Q_PROPERTY(QString status READ status NOTIFY statusChanged)

public:
    explicit TouchBridge(QObject *parent = nullptr);
    ~TouchBridge() override;

    QObject *window() const;
    void setWindow(QObject *window);
    bool active() const { return m_fd >= 0; }
    bool touchInProgress() const { return m_touchInProgress; }
    QString devicePath() const { return m_devicePath; }
    QString activeDeviceName() const { return m_activeDeviceName; }
    QStringList deviceNames() const { return m_deviceNames; }
    void setDeviceNames(const QStringList &deviceNames);
    QStringList availableDeviceNames() const { return m_availableDeviceNames; }
    QString status() const { return m_status; }

    Q_INVOKABLE bool start();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void refreshDevices();

signals:
    void windowChanged();
    void activeChanged();
    void touchInProgressChanged();
    void devicePathChanged();
    void activeDeviceNameChanged();
    void deviceNamesChanged();
    void availableDeviceNamesChanged();
    void statusChanged();

private:
    static int selectDeviceIndex(const QStringList &detectedNames, const QStringList &configuredNames);
    QString findTouchscreen(QStringList *detectedNames);
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
    QString m_activeDeviceName;
    QStringList m_deviceNames;
    QStringList m_availableDeviceNames;
    QString m_status = QStringLiteral("Direct touch not started");
    int m_xMin = 0;
    int m_xMax = 1;
    int m_yMin = 0;
    int m_yMax = 1;
    EvdevTouchState m_inputState;
    bool m_hasMultitouch = false;
    bool m_pointerDown = false;
    bool m_touchInProgress = false;
    bool m_wantsActive = false;
    QPointF m_lastPosition;
};
