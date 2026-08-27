#pragma once

#include <QPlainTextEdit>
#include <QPointer>
#include <QString>
#include <QTimer>

#include <functional>
#include <utility>

inline void scheduleTrayReportRefresh(QObject *context,
                                      QPlainTextEdit *report,
                                      int delayMs,
                                      std::function<QString()> readReport,
                                      std::function<void()> refreshHealth)
{
    const QPointer<QPlainTextEdit> guardedReport(report);
    QTimer::singleShot(delayMs, context,
                       [guardedReport, readReport = std::move(readReport),
                        refreshHealth = std::move(refreshHealth)] {
        if (guardedReport)
            guardedReport->setPlainText(readReport());
        refreshHealth();
    });
}
