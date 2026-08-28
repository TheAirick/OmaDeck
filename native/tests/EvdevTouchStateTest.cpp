#include "../EvdevTouchState.h"

#include <QtTest>

static input_event inputEvent(unsigned short type, unsigned short code, int value)
{
    input_event event{};
    event.type = type;
    event.code = code;
    event.value = value;
    return event;
}

class EvdevTouchStateTest : public QObject
{
    Q_OBJECT

private slots:
    void frameTransitionsSurviveInputChunkBoundaries();
    void droppedStreamReleasesAndWaitsForFreshFrame();
    void activeContactHandoffKeepsPointerPressed();
};

void EvdevTouchStateTest::frameTransitionsSurviveInputChunkBoundaries()
{
    EvdevTouchState state;
    state.reset();

    QVERIFY(!state.process(inputEvent(EV_ABS, ABS_MT_TRACKING_ID, 7), true));
    QVERIFY(!state.process(inputEvent(EV_ABS, ABS_MT_POSITION_X, 25), true));
    QVERIFY(!state.process(inputEvent(EV_ABS, ABS_MT_POSITION_Y, 40), true));

    const std::optional<EvdevTouchState::Frame> press =
        state.process(inputEvent(EV_SYN, SYN_REPORT, 0), true);
    QVERIFY(press);
    QVERIFY(press->pressed);
    QVERIFY(!press->released);
    QCOMPARE(state.activeSlot(), 0);
    QCOMPARE(state.x(0), 25);
    QCOMPARE(state.y(0), 40);

    QVERIFY(!state.process(inputEvent(EV_ABS, ABS_MT_TRACKING_ID, -1), true));

    const std::optional<EvdevTouchState::Frame> release =
        state.process(inputEvent(EV_SYN, SYN_REPORT, 0), true);
    QVERIFY(release);
    QVERIFY(!release->pressed);
    QVERIFY(release->released);
    QCOMPARE(state.activeSlot(), -1);
}

void EvdevTouchStateTest::droppedStreamReleasesAndWaitsForFreshFrame()
{
    EvdevTouchState state;
    state.reset();

    QVERIFY(!state.process(inputEvent(EV_ABS, ABS_MT_TRACKING_ID, 7), true));
    const std::optional<EvdevTouchState::Frame> press =
        state.process(inputEvent(EV_SYN, SYN_REPORT, 0), true);
    QVERIFY(press && press->pressed);

    const std::optional<EvdevTouchState::Frame> dropped =
        state.process(inputEvent(EV_SYN, SYN_DROPPED, 0), true);
    QVERIFY(dropped);
    QVERIFY(!dropped->pressed);
    QVERIFY(dropped->released);
    QCOMPARE(state.activeSlot(), -1);

    QVERIFY(!state.process(inputEvent(EV_ABS, ABS_MT_TRACKING_ID, 8), true));
    QVERIFY(!state.process(inputEvent(EV_ABS, ABS_MT_POSITION_X, 80), true));
    QVERIFY(!state.process(inputEvent(EV_SYN, SYN_REPORT, 0), true));
    QCOMPARE(state.activeSlot(), -1);

    QVERIFY(!state.process(inputEvent(EV_ABS, ABS_MT_TRACKING_ID, 9), true));
    QVERIFY(!state.process(inputEvent(EV_ABS, ABS_MT_POSITION_X, 30), true));
    const std::optional<EvdevTouchState::Frame> recovered =
        state.process(inputEvent(EV_SYN, SYN_REPORT, 0), true);
    QVERIFY(recovered);
    QVERIFY(recovered->pressed);
    QVERIFY(!recovered->released);
    QCOMPARE(state.activeSlot(), 0);
    QCOMPARE(state.x(0), 30);
}

void EvdevTouchStateTest::activeContactHandoffKeepsPointerPressed()
{
    EvdevTouchState state;
    state.reset();

    QVERIFY(!state.process(inputEvent(EV_ABS, ABS_MT_TRACKING_ID, 7), true));
    const std::optional<EvdevTouchState::Frame> press =
        state.process(inputEvent(EV_SYN, SYN_REPORT, 0), true);
    QVERIFY(press && press->pressed && !press->released);

    QVERIFY(!state.process(inputEvent(EV_ABS, ABS_MT_SLOT, 1), true));
    QVERIFY(!state.process(inputEvent(EV_ABS, ABS_MT_TRACKING_ID, 8), true));
    const std::optional<EvdevTouchState::Frame> secondContact =
        state.process(inputEvent(EV_SYN, SYN_REPORT, 0), true);
    QVERIFY(secondContact && !secondContact->pressed && !secondContact->released);

    QVERIFY(!state.process(inputEvent(EV_ABS, ABS_MT_SLOT, 0), true));
    QVERIFY(!state.process(inputEvent(EV_ABS, ABS_MT_TRACKING_ID, -1), true));
    const std::optional<EvdevTouchState::Frame> handoff =
        state.process(inputEvent(EV_SYN, SYN_REPORT, 0), true);
    QVERIFY(handoff);
    QVERIFY(!handoff->pressed);
    QVERIFY(!handoff->released);
    QCOMPARE(state.activeSlot(), 1);

    QVERIFY(!state.process(inputEvent(EV_ABS, ABS_MT_SLOT, 1), true));
    QVERIFY(!state.process(inputEvent(EV_ABS, ABS_MT_TRACKING_ID, -1), true));
    const std::optional<EvdevTouchState::Frame> release =
        state.process(inputEvent(EV_SYN, SYN_REPORT, 0), true);
    QVERIFY(release && !release->pressed && release->released);
}

QTEST_APPLESS_MAIN(EvdevTouchStateTest)
#include "EvdevTouchStateTest.moc"
