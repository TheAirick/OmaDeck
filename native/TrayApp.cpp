#include <QAction>
#include <QApplication>
#include <QClipboard>
#include <QCommandLineOption>
#include <QCommandLineParser>
#include <QDesktopServices>
#include <QDialog>
#include <QDialogButtonBox>
#include <QFileInfo>
#include <QIcon>
#include <QLabel>
#include <QLockFile>
#include <QMenu>
#include <QMessageBox>
#include <QPlainTextEdit>
#include <QProcess>
#include <QPushButton>
#include <QStandardPaths>
#include <QSystemTrayIcon>
#include <QTimer>
#include <QUrl>
#include <QVBoxLayout>

class TrayController final : public QObject
{
public:
    TrayController(QString doctorPath, QString guidePath, QString iconPath,
                   QString pluginDir, QString targetScreen, QString primaryMonitor,
                   QObject *parent = nullptr)
        : QObject(parent)
        , m_doctorPath(std::move(doctorPath))
        , m_guidePath(std::move(guidePath))
        , m_pluginDir(std::move(pluginDir))
        , m_targetScreen(std::move(targetScreen))
        , m_primaryMonitor(std::move(primaryMonitor))
        , m_baseIcon(iconPath)
    {
        if (m_baseIcon.isNull())
            m_baseIcon = QIcon::fromTheme(QStringLiteral("input-touchpad"));
        if (m_baseIcon.isNull())
            m_baseIcon = QIcon::fromTheme(QStringLiteral("preferences-system"));

        m_healthAction.setEnabled(false);
        m_menu.addAction(&m_healthAction);
        m_menu.addSeparator();

        auto *diagnostics = m_menu.addAction(QStringLiteral("Diagnostics…"));
        connect(diagnostics, &QAction::triggered, this, [this] { showDiagnostics(); });

        auto *reconnect = m_menu.addAction(QStringLiteral("Reconnect touchscreen"));
        connect(reconnect, &QAction::triggered, this, [this] { reconnectTouchscreen(); });

        auto *configuration = m_menu.addAction(QStringLiteral("Configuration guide"));
        configuration->setEnabled(QFileInfo::exists(m_guidePath));
        connect(configuration, &QAction::triggered, this, [this] {
            QDesktopServices::openUrl(QUrl::fromLocalFile(m_guidePath));
        });

        m_menu.addSeparator();
        auto *restart = m_menu.addAction(QStringLiteral("Restart Omarchy shell…"));
        connect(restart, &QAction::triggered, this, [this] { restartShell(); });

        m_tray.setContextMenu(&m_menu);
        m_tray.setIcon(m_baseIcon);
        m_tray.setToolTip(QStringLiteral("OmaDeck — checking health…"));
        connect(&m_tray, &QSystemTrayIcon::activated, this,
                [this](QSystemTrayIcon::ActivationReason reason) {
            if (reason == QSystemTrayIcon::Trigger || reason == QSystemTrayIcon::DoubleClick)
                showDiagnostics();
        });
        m_tray.show();

        connect(&m_refreshTimer, &QTimer::timeout, this, [this] { refreshHealth(); });
        m_refreshTimer.setInterval(5000);
        m_refreshTimer.start();
        refreshHealth();
    }

private:
    QStringList doctorArguments(bool summary = false) const
    {
        QStringList arguments;
        if (summary)
            arguments << QStringLiteral("--summary");
        arguments << QStringLiteral("--plugin-dir") << m_pluginDir
                  << QStringLiteral("--target-screen") << m_targetScreen
                  << QStringLiteral("--primary-monitor") << m_primaryMonitor;
        return arguments;
    }

    QString runDoctor(bool summary = false) const
    {
        QProcess process;
        process.start(m_doctorPath, doctorArguments(summary));
        if (!process.waitForStarted(2000))
            return QStringLiteral("OmaDeck doctor could not start: %1").arg(process.errorString());
        if (!process.waitForFinished(5000)) {
            process.kill();
            return QStringLiteral("OmaDeck doctor timed out");
        }
        QString output = QString::fromUtf8(process.readAllStandardOutput()).trimmed();
        const QString error = QString::fromUtf8(process.readAllStandardError()).trimmed();
        if (output.isEmpty())
            output = error.isEmpty() ? QStringLiteral("OmaDeck doctor returned no output") : error;
        return output;
    }

    void refreshHealth()
    {
        const QString summary = runDoctor(true);
        const bool healthy = summary.startsWith(QStringLiteral("Healthy"));
        m_healthAction.setText(summary);
        m_tray.setToolTip(QStringLiteral("OmaDeck — %1").arg(summary));
        if (healthy) {
            m_tray.setIcon(m_baseIcon);
        } else {
            const QIcon warning = QIcon::fromTheme(QStringLiteral("dialog-warning"));
            m_tray.setIcon(warning.isNull() ? m_baseIcon : warning);
        }
    }

    void showDiagnostics()
    {
        if (m_dialog) {
            m_dialog->show();
            m_dialog->raise();
            m_dialog->activateWindow();
            return;
        }

        m_dialog = new QDialog;
        m_dialog->setAttribute(Qt::WA_DeleteOnClose);
        m_dialog->setWindowTitle(QStringLiteral("OmaDeck Control Center"));
        m_dialog->resize(720, 520);
        connect(m_dialog, &QObject::destroyed, this, [this] { m_dialog = nullptr; });

        auto *layout = new QVBoxLayout(m_dialog);
        auto *title = new QLabel(QStringLiteral("<h2>OmaDeck Health</h2>"));
        title->setTextFormat(Qt::RichText);
        layout->addWidget(title);

        auto *description = new QLabel(QStringLiteral(
            "These checks run independently of the deck touchscreen. "
            "Use this window from the main monitor when touch is unavailable."));
        description->setWordWrap(true);
        layout->addWidget(description);

        auto *report = new QPlainTextEdit;
        report->setReadOnly(true);
        report->setLineWrapMode(QPlainTextEdit::NoWrap);
        report->setPlainText(runDoctor());
        layout->addWidget(report, 1);

        auto *buttons = new QDialogButtonBox(QDialogButtonBox::Close);
        auto *refresh = buttons->addButton(QStringLiteral("Refresh"), QDialogButtonBox::ActionRole);
        auto *copy = buttons->addButton(QStringLiteral("Copy report"), QDialogButtonBox::ActionRole);
        auto *reconnect = buttons->addButton(QStringLiteral("Reconnect touch"), QDialogButtonBox::ActionRole);
        auto *guide = buttons->addButton(QStringLiteral("Configuration"), QDialogButtonBox::ActionRole);
        guide->setEnabled(QFileInfo::exists(m_guidePath));
        connect(refresh, &QPushButton::clicked, this, [this, report] {
            report->setPlainText(runDoctor());
            refreshHealth();
        });
        connect(copy, &QPushButton::clicked, this, [report] {
            QApplication::clipboard()->setText(report->toPlainText());
        });
        connect(reconnect, &QPushButton::clicked, this, [this, report] {
            reconnectTouchscreen();
            QTimer::singleShot(1400, this, [this, report] {
                if (report)
                    report->setPlainText(runDoctor());
                refreshHealth();
            });
        });
        connect(guide, &QPushButton::clicked, this, [this] {
            QDesktopServices::openUrl(QUrl::fromLocalFile(m_guidePath));
        });
        connect(buttons, &QDialogButtonBox::rejected, m_dialog, &QDialog::close);
        layout->addWidget(buttons);

        m_dialog->show();
        m_dialog->raise();
        m_dialog->activateWindow();
    }

    void reconnectTouchscreen()
    {
        QProcess::startDetached(QStringLiteral("omarchy-shell"),
                                {QStringLiteral("pretty.omadeck"), QStringLiteral("reconnectTouch")});
        m_healthAction.setText(QStringLiteral("Touchscreen reconnect requested…"));
        QTimer::singleShot(1500, this, [this] { refreshHealth(); });
    }

    void restartShell()
    {
        const auto answer = QMessageBox::question(
            nullptr, QStringLiteral("Restart Omarchy shell"),
            QStringLiteral("Restart the Omarchy shell now? The bar and OmaDeck will briefly disappear."));
        if (answer != QMessageBox::Yes)
            return;
        QProcess::startDetached(QStringLiteral("omarchy"),
                                {QStringLiteral("restart"), QStringLiteral("shell")});
        QApplication::quit();
    }

    QString m_doctorPath;
    QString m_guidePath;
    QString m_pluginDir;
    QString m_targetScreen;
    QString m_primaryMonitor;
    QIcon m_baseIcon;
    QSystemTrayIcon m_tray;
    QMenu m_menu;
    QAction m_healthAction;
    QTimer m_refreshTimer;
    QDialog *m_dialog = nullptr;
};

int main(int argc, char **argv)
{
    QApplication application(argc, argv);
    QApplication::setApplicationName(QStringLiteral("OmaDeck"));
    QApplication::setApplicationDisplayName(QStringLiteral("OmaDeck"));
    QApplication::setQuitOnLastWindowClosed(false);

    QCommandLineParser parser;
    parser.setApplicationDescription(QStringLiteral("OmaDeck system tray and recovery controller"));
    parser.addHelpOption();
    parser.addVersionOption();
    QCommandLineOption doctorOption(QStringLiteral("doctor"), QStringLiteral("Path to omadeck-doctor"), QStringLiteral("path"));
    QCommandLineOption guideOption(QStringLiteral("guide"), QStringLiteral("Path to configuration guide"), QStringLiteral("path"));
    QCommandLineOption iconOption(QStringLiteral("icon"), QStringLiteral("Path to tray icon"), QStringLiteral("path"));
    QCommandLineOption pluginOption(QStringLiteral("plugin-dir"), QStringLiteral("OmaDeck plugin directory"), QStringLiteral("path"));
    QCommandLineOption targetOption(QStringLiteral("target-screen"), QStringLiteral("Deck monitor name"), QStringLiteral("name"), QStringLiteral("DP-3"));
    QCommandLineOption primaryOption(QStringLiteral("primary-monitor"), QStringLiteral("Primary monitor name"), QStringLiteral("name"), QStringLiteral("DP-1"));
    parser.addOptions({doctorOption, guideOption, iconOption, pluginOption, targetOption, primaryOption});
    parser.process(application);

    const QString runtimeDirectory = QStandardPaths::writableLocation(QStandardPaths::RuntimeLocation);
    QLockFile lock(runtimeDirectory + QStringLiteral("/omadeck-tray.lock"));
    lock.setStaleLockTime(0);
    if (!lock.tryLock(100))
        return 0;

    const QString doctorPath = parser.value(doctorOption);
    const QString pluginDir = parser.value(pluginOption);
    if (!QFileInfo(doctorPath).isExecutable() || pluginDir.isEmpty())
        return 2;

    TrayController controller(doctorPath, parser.value(guideOption), parser.value(iconOption),
                              pluginDir, parser.value(targetOption), parser.value(primaryOption));
    return application.exec();
}
