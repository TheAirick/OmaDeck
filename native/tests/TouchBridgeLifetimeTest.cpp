#include <QQuickItem>
#include <QQuickWindow>
#include <QtTest>

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

class TouchBridgeLifetimeTest : public QObject
{
    Q_OBJECT

private slots:
    void destroyingTargetClearsTargetAndWindow();
    void destroyingWindowClearsAttachedWindow();
    void stopIsSafeAfterActiveTargetDestruction();
    void syntheticReleaseCannotReenterActiveCleanup();
};

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

QTEST_MAIN(TouchBridgeLifetimeTest)
#include "TouchBridgeLifetimeTest.moc"
