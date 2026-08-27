#include <QPlainTextEdit>
#include <QtTest>

#include "../TrayCallbacks.h"

class TrayCallbackTest : public QObject
{
    Q_OBJECT

private slots:
    void closedReportIsNotDereferenced();
    void liveReportReceivesFreshDiagnostics();
};

void TrayCallbackTest::closedReportIsNotDereferenced()
{
    int doctorCalls = 0;
    int healthRefreshes = 0;
    auto *report = new QPlainTextEdit;

    scheduleTrayReportRefresh(
        this, report, 0,
        [&doctorCalls] {
            ++doctorCalls;
            return QStringLiteral("fresh report");
        },
        [&healthRefreshes] { ++healthRefreshes; });

    delete report;

    QTRY_COMPARE_WITH_TIMEOUT(healthRefreshes, 1, 100);
    QCOMPARE(doctorCalls, 0);
}

void TrayCallbackTest::liveReportReceivesFreshDiagnostics()
{
    int healthRefreshes = 0;
    QPlainTextEdit report;

    scheduleTrayReportRefresh(
        this, &report, 0,
        [] { return QStringLiteral("fresh report"); },
        [&healthRefreshes] { ++healthRefreshes; });

    QTRY_COMPARE_WITH_TIMEOUT(healthRefreshes, 1, 100);
    QCOMPARE(report.toPlainText(), QStringLiteral("fresh report"));
}

QTEST_MAIN(TrayCallbackTest)
#include "TrayCallbackTest.moc"
