#include <QEvent>
#include <QQuickItem>
#include <QQuickWindow>
#include <QtTest>

#include <initializer_list>
#include <linux/input.h>
#include <unistd.h>

#define private public
#include "../TouchBridge.h"
#undef private

class ReentrantStopWindow : public QQuickWindow
{
public:
    TouchBridge *bridge = nullptr;
    int releaseCount = 0;

protected:
    bool event(QEvent *event) override
    {
        if (event->type() == QEvent::MouseButtonRelease && bridge) {
            ++releaseCount;
            TouchBridge *target = bridge;
            bridge = nullptr;
            target->stop();
        }
        return QQuickWindow::event(event);
    }
};

class RecordingWindow : public QQuickWindow
{
public:
    int pressCount = 0;
    int releaseCount = 0;

protected:
    bool event(QEvent *event) override
    {
        if (event->type() == QEvent::MouseButtonPress)
            ++pressCount;
        else if (event->type() == QEvent::MouseButtonRelease)
            ++releaseCount;
        return QQuickWindow::event(event);
    }
};

static input_event inputEvent(unsigned short type, unsigned short code, int value)
{
    input_event event{};
    event.type = type;
    event.code = code;
    event.value = value;
    return event;
}

static void writeEvents(int descriptor, std::initializer_list<input_event> events)
{
    const ssize_t bytes = ::write(descriptor, events.begin(),
                                  static_cast<size_t>(events.size()) * sizeof(input_event));
    QCOMPARE(bytes, static_cast<ssize_t>(events.size() * sizeof(input_event)));
}

class TouchBridgeLifetimeTest : public QObject
{
    Q_OBJECT

private slots:
    void deviceSelectionRequiresConfiguredIdentity();
    void deviceSelectionSupportsConfiguredHardware();
    void destroyingTargetClearsTargetAndWindow();
    void destroyingWindowClearsAttachedWindow();
    void stopIsSafeAfterActiveTargetDestruction();
    void syntheticReleaseCannotReenterActiveCleanup();
    void directTouchContactIsExposedUntilSyntheticHoverLeaves();
    void touchTransitionsSurviveReadBoundaries();
    void droppedStreamClearsSyntheticPointer();
};

void TouchBridgeLifetimeTest::deviceSelectionRequiresConfiguredIdentity()
{
    const QStringList detectedNames{
        QStringLiteral("ELAN Laptop Touchscreen"),
        QStringLiteral("WCH.CN Touchscreen"),
    };

    QCOMPARE(TouchBridge::selectDeviceIndex(detectedNames, {}), -1);
    QCOMPARE(TouchBridge::selectDeviceIndex(detectedNames, {QStringLiteral("XENEON")}), -1);
    QCOMPARE(TouchBridge::selectDeviceIndex(detectedNames, {QStringLiteral("WCH.CN")}), 1);
}

void TouchBridgeLifetimeTest::deviceSelectionSupportsConfiguredHardware()
{
    const QStringList detectedNames{
        QStringLiteral("ELAN Laptop Touchscreen"),
        QStringLiteral("ACME Deck 9000"),
    };

    QCOMPARE(TouchBridge::selectDeviceIndex(detectedNames, {QStringLiteral("ACME Deck")}), 1);
}

void TouchBridgeLifetimeTest::destroyingTargetClearsTargetAndWindow()
{
    TouchBridge bridge;
    QQuickWindow window;
    auto *item = new QQuickItem(window.contentItem());

    bridge.setWindow(item);
    QCOMPARE(bridge.m_target.data(), item);
    QCOMPARE(bridge.m_window.data(), &window);

    delete item;

    QVERIFY(bridge.m_target.isNull());
    QVERIFY(bridge.m_window.isNull());
    QCOMPARE(bridge.window(), nullptr);
}

void TouchBridgeLifetimeTest::destroyingWindowClearsAttachedWindow()
{
    TouchBridge bridge;
    auto *window = new QQuickWindow;
    auto *item = new QQuickItem(window->contentItem());

    bridge.setWindow(item);
    item->setParentItem(nullptr);
    item->setParent(nullptr);
    delete window;

    QCOMPARE(bridge.window(), item);
    QVERIFY(bridge.m_window.isNull());

    delete item;
    QVERIFY(bridge.m_target.isNull());
}

void TouchBridgeLifetimeTest::stopIsSafeAfterActiveTargetDestruction()
{
    int descriptors[2];
    QVERIFY(::pipe(descriptors) == 0);

    TouchBridge bridge;
    QQuickWindow window;
    auto *item = new QQuickItem(window.contentItem());
    bridge.setWindow(item);
    bridge.m_fd = descriptors[0];
    bridge.m_pointerDown = true;

    delete item;
    bridge.stop();

    QVERIFY(!bridge.active());
    QVERIFY(bridge.m_target.isNull());
    QVERIFY(bridge.m_window.isNull());
    QVERIFY(!bridge.m_pointerDown);

    ::close(descriptors[1]);
}

void TouchBridgeLifetimeTest::syntheticReleaseCannotReenterActiveCleanup()
{
    int descriptors[2];
    QVERIFY(::pipe(descriptors) == 0);

    TouchBridge bridge;
    ReentrantStopWindow window;
    window.bridge = &bridge;
    bridge.setWindow(&window);
    bridge.m_fd = descriptors[0];
    bridge.m_pointerDown = true;
    bridge.m_lastPosition = QPointF(4, 5);
    QSignalSpy activeChanges(&bridge, &TouchBridge::activeChanged);
    QSignalSpy deviceChanges(&bridge, &TouchBridge::devicePathChanged);

    bridge.stop();

    QVERIFY(!bridge.active());
    QVERIFY(!bridge.m_pointerDown);
    QCOMPARE(window.releaseCount, 1);
    QCOMPARE(activeChanges.count(), 1);
    QCOMPARE(deviceChanges.count(), 1);

    ::close(descriptors[1]);
}

void TouchBridgeLifetimeTest::directTouchContactIsExposedUntilSyntheticHoverLeaves()
{
    TouchBridge bridge;
    QQuickWindow window;
    window.resize(100, 100);
    bridge.setWindow(&window);
    bridge.m_lastPosition = QPointF(20, 30);
    QSignalSpy contactChanges(&bridge, &TouchBridge::touchInProgressChanged);

    bridge.dispatch(true, false);
    QVERIFY(bridge.touchInProgress());

    bridge.dispatch(false, true);
    QVERIFY(!bridge.touchInProgress());
    QCOMPARE(contactChanges.count(), 2);
}

void TouchBridgeLifetimeTest::touchTransitionsSurviveReadBoundaries()
{
    int descriptors[2];
    QVERIFY(::pipe(descriptors) == 0);

    TouchBridge bridge;
    RecordingWindow window;
    window.resize(100, 100);
    bridge.setWindow(&window);
    bridge.m_fd = descriptors[0];
    bridge.m_hasMultitouch = true;
    bridge.m_xMin = 0;
    bridge.m_xMax = 100;
    bridge.m_yMin = 0;
    bridge.m_yMax = 100;

    writeEvents(descriptors[1], {
        inputEvent(EV_ABS, ABS_MT_TRACKING_ID, 7),
        inputEvent(EV_ABS, ABS_MT_POSITION_X, 25),
        inputEvent(EV_ABS, ABS_MT_POSITION_Y, 40),
    });
    bridge.readEvents();
    QCOMPARE(window.pressCount, 0);

    writeEvents(descriptors[1], {inputEvent(EV_SYN, SYN_REPORT, 0)});
    bridge.readEvents();
    QCOMPARE(window.pressCount, 1);
    QVERIFY(bridge.m_pointerDown);

    writeEvents(descriptors[1], {inputEvent(EV_ABS, ABS_MT_TRACKING_ID, -1)});
    bridge.readEvents();
    QCOMPARE(window.releaseCount, 0);

    writeEvents(descriptors[1], {inputEvent(EV_SYN, SYN_REPORT, 0)});
    bridge.readEvents();
    QCOMPARE(window.releaseCount, 1);
    QVERIFY(!bridge.m_pointerDown);

    bridge.m_fd = -1;
    ::close(descriptors[0]);
    ::close(descriptors[1]);
}

void TouchBridgeLifetimeTest::droppedStreamClearsSyntheticPointer()
{
    int descriptors[2];
    QVERIFY(::pipe(descriptors) == 0);

    TouchBridge bridge;
    RecordingWindow window;
    window.resize(100, 100);
    bridge.setWindow(&window);
    bridge.m_fd = descriptors[0];
    bridge.m_hasMultitouch = true;
    bridge.m_xMin = 0;
    bridge.m_xMax = 100;
    bridge.m_yMin = 0;
    bridge.m_yMax = 100;

    writeEvents(descriptors[1], {
        inputEvent(EV_ABS, ABS_MT_TRACKING_ID, 7),
        inputEvent(EV_ABS, ABS_MT_POSITION_X, 25),
        inputEvent(EV_ABS, ABS_MT_POSITION_Y, 40),
        inputEvent(EV_SYN, SYN_REPORT, 0),
    });
    bridge.readEvents();
    QCOMPARE(window.pressCount, 1);
    QVERIFY(bridge.m_pointerDown);
    QVERIFY(bridge.touchInProgress());

    writeEvents(descriptors[1], {inputEvent(EV_SYN, SYN_DROPPED, 0)});
    bridge.readEvents();
    QCOMPARE(window.releaseCount, 1);
    QVERIFY(!bridge.m_pointerDown);
    QVERIFY(!bridge.touchInProgress());

    writeEvents(descriptors[1], {
        inputEvent(EV_ABS, ABS_MT_TRACKING_ID, 8),
        inputEvent(EV_SYN, SYN_REPORT, 0),
    });
    bridge.readEvents();
    QCOMPARE(window.pressCount, 1);
    QCOMPARE(window.releaseCount, 1);
    QVERIFY(!bridge.m_pointerDown);

    bridge.m_fd = -1;
    ::close(descriptors[0]);
    ::close(descriptors[1]);
}

QTEST_MAIN(TouchBridgeLifetimeTest)
#include "TouchBridgeLifetimeTest.moc"
