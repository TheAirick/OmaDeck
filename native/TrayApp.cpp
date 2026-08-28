#include "TrayCallbacks.h"

#include <QAction>
#include <QApplication>
#include <QCheckBox>
#include <QClipboard>
#include <QCommandLineOption>
#include <QCommandLineParser>
#include <QComboBox>
#include <QDesktopServices>
#include <QDialog>
#include <QDialogButtonBox>
#include <QFileInfo>
#include <QFormLayout>
#include <QIcon>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLabel>
#include <QLockFile>
#include <QMenu>
#include <QMessageBox>
#include <QPlainTextEdit>
#include <QProcess>
#include <QPushButton>
#include <QSignalBlocker>
#include <QStandardPaths>
#include <QSystemTrayIcon>
#include <QTimer>
#include <QUrl>
#include <QVBoxLayout>
#include <QWheelEvent>

class SafeComboBox final : public QComboBox
{
protected:
    void wheelEvent(QWheelEvent *event) override
    {
        if (!hasFocus()) {
            event->ignore();
            return;
        }
        QComboBox::wheelEvent(event);
    }
};

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

        auto *appearance = m_menu.addAction(QStringLiteral("Clock & weather settings…"));
        connect(appearance, &QAction::triggered, this, [this] { showAppearanceSettings(); });

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

    QString runOmaDeckIpc(const QStringList &arguments, bool *ok = nullptr) const
    {
        QProcess process;
        QStringList commandArguments{QStringLiteral("pretty.omadeck")};
        commandArguments.append(arguments);
        process.start(QStringLiteral("omarchy-shell"), commandArguments);
        if (!process.waitForStarted(1000)) {
            if (ok)
                *ok = false;
            return QStringLiteral("OmaDeck IPC could not start: %1").arg(process.errorString());
        }
        if (!process.waitForFinished(2000)) {
            process.terminate();
            if (!process.waitForFinished(250)) {
                process.kill();
                process.waitForFinished(250);
            }
            if (ok)
                *ok = false;
            return QStringLiteral("OmaDeck IPC timed out");
        }

        const bool succeeded = process.exitStatus() == QProcess::NormalExit && process.exitCode() == 0;
        if (ok)
            *ok = succeeded;
        const QString output = QString::fromUtf8(process.readAllStandardOutput()).trimmed();
        const QString error = QString::fromUtf8(process.readAllStandardError()).trimmed();
        return succeeded ? output : (error.isEmpty() ? QStringLiteral("OmaDeck IPC failed") : error);
    }

    bool parseIpcResult(const QString &response, bool processOk,
                        QJsonObject *result, QString *error) const
    {
        if (!processOk) {
            if (error)
                *error = response;
            return false;
        }

        QJsonParseError parseError;
        const QJsonDocument document = QJsonDocument::fromJson(response.toUtf8(), &parseError);
        if (parseError.error != QJsonParseError::NoError || !document.isObject()) {
            if (error)
                *error = QStringLiteral("OmaDeck returned an invalid response");
            return false;
        }

        const QJsonObject object = document.object();
        const QJsonValue okValue = object.value(QStringLiteral("ok"));
        if (!okValue.isBool() || !okValue.toBool()) {
            if (error)
                *error = object.value(QStringLiteral("error")).toString(QStringLiteral("OmaDeck rejected the request"));
            return false;
        }
        if (result)
            *result = object;
        return true;
    }

    bool validateAppearanceState(const QJsonObject &state, QString *error) const
    {
        const bool valid = state.value(QStringLiteral("version")).isDouble()
            && state.value(QStringLiteral("version")).toInt() == 1
            && state.value(QStringLiteral("clockStyle")).isString()
            && state.value(QStringLiteral("use24Hour")).isBool()
            && state.value(QStringLiteral("showSeconds")).isBool()
            && state.value(QStringLiteral("showWeather")).isBool()
            && state.value(QStringLiteral("weatherStyle")).isString()
            && state.value(QStringLiteral("weatherDetail")).isString()
            && state.value(QStringLiteral("temperatureUnit")).isString();
        if (!valid && error)
            *error = QStringLiteral("OmaDeck returned incomplete appearance settings");
        return valid;
    }

    void reloadAppearanceSettings()
    {
        if (!m_settingsDialog) {
            showAppearanceSettings();
            return;
        }

        QDialog *dialog = m_settingsDialog.data();
        connect(dialog, &QObject::destroyed, this, [this] {
            QTimer::singleShot(0, this, [this] { showAppearanceSettings(); });
        }, Qt::SingleShotConnection);
        dialog->close();
    }

    bool setAppearanceOption(const QString &key, const QString &value)
    {
        bool processOk = false;
        const QString response = runOmaDeckIpc(
            {QStringLiteral("setAppearance"), key, value}, &processOk);
        QJsonObject result;
        QString error;
        if (!parseIpcResult(response, processOk, &result, &error)) {
            QMessageBox::warning(m_settingsDialog, QStringLiteral("OmaDeck settings"), error);
            reloadAppearanceSettings();
            return false;
        }

        const QJsonValue accepted = result.value(QStringLiteral("value"));
        const bool expectedBoolean = value == QStringLiteral("true") || value == QStringLiteral("false");
        const bool matches = expectedBoolean
            ? accepted.isBool() && accepted.toBool() == (value == QStringLiteral("true"))
            : accepted.isString() && accepted.toString() == value;
        if (!matches) {
            QMessageBox::warning(m_settingsDialog, QStringLiteral("OmaDeck settings"),
                                 QStringLiteral("OmaDeck did not accept the requested value"));
            reloadAppearanceSettings();
            return false;
        }
        return true;
    }

    void showAppearanceSettings()
    {
        if (m_settingsDialog) {
            reloadAppearanceSettings();
            return;
        }

        bool processOk = false;
        const QString stateText = runOmaDeckIpc({QStringLiteral("appearanceState")}, &processOk);
        QJsonObject state;
        QString error;
        if (!parseIpcResult(stateText, processOk, &state, &error)) {
            QMessageBox::warning(nullptr, QStringLiteral("OmaDeck settings"), error);
            return;
        }
        if (!validateAppearanceState(state, &error)) {
            QMessageBox::warning(nullptr, QStringLiteral("OmaDeck settings"), error);
            return;
        }

        m_settingsDialog = new QDialog;
        m_settingsDialog->setAttribute(Qt::WA_DeleteOnClose);
        m_settingsDialog->setWindowTitle(QStringLiteral("OmaDeck Clock & Weather"));
        m_settingsDialog->setFixedSize(460, 430);
        connect(m_settingsDialog, &QObject::destroyed, this, [this] { m_settingsDialog = nullptr; });

        auto *layout = new QVBoxLayout(m_settingsDialog);
        auto *title = new QLabel(QStringLiteral("<h2>Clock & Weather</h2>"));
        title->setTextFormat(Qt::RichText);
        layout->addWidget(title);
        auto *description = new QLabel(QStringLiteral(
            "These settings apply directly to the Clock and Weather tile on OmaDeck."));
        description->setWordWrap(true);
        layout->addWidget(description);

        auto *form = new QFormLayout;
        layout->addLayout(form);

        const auto addCombo = [this, form, &state](
                                  const QString &label, const QString &key,
                                  const QList<QPair<QString, QString>> &choices) -> SafeComboBox * {
            auto *combo = new SafeComboBox;
            const QSignalBlocker blocker(combo);
            for (const auto &[choiceLabel, value] : choices)
                combo->addItem(choiceLabel, value);
            const int selected = combo->findData(state.value(key).toString());
            if (selected >= 0)
                combo->setCurrentIndex(selected);
            form->addRow(label, combo);
            connect(combo, qOverload<int>(&QComboBox::currentIndexChanged), this,
                    [this, combo, key](int) {
                if (!setAppearanceOption(key, combo->currentData().toString()))
                    return;
            });
            return combo;
        };

        addCombo(QStringLiteral("Clock style"), QStringLiteral("clockStyle"),
                 {{QStringLiteral("Hero"), QStringLiteral("hero")},
                  {QStringLiteral("Split"), QStringLiteral("split")},
                  {QStringLiteral("Compact"), QStringLiteral("compact")}});

        auto *use24Hour = new QCheckBox;
        use24Hour->setChecked(state.value(QStringLiteral("use24Hour")).toBool());
        form->addRow(QStringLiteral("24-hour time"), use24Hour);
        connect(use24Hour, &QCheckBox::toggled, this, [this](bool checked) {
            if (!setAppearanceOption(QStringLiteral("use24Hour"),
                                     checked ? QStringLiteral("true") : QStringLiteral("false")))
                return;
        });

        auto *showSeconds = new QCheckBox;
        showSeconds->setChecked(state.value(QStringLiteral("showSeconds")).toBool());
        form->addRow(QStringLiteral("Show seconds"), showSeconds);
        connect(showSeconds, &QCheckBox::toggled, this, [this](bool checked) {
            if (!setAppearanceOption(QStringLiteral("showSeconds"),
                                     checked ? QStringLiteral("true") : QStringLiteral("false")))
                return;
        });

        auto *showWeather = new QCheckBox;
        showWeather->setChecked(state.value(QStringLiteral("showWeather")).toBool(true));
        form->addRow(QStringLiteral("Show weather"), showWeather);

        auto *weatherVisual = addCombo(
            QStringLiteral("Weather visual"), QStringLiteral("weatherStyle"),
            {{QStringLiteral("Rich"), QStringLiteral("scene")},
             {QStringLiteral("Glyph"), QStringLiteral("glyph")},
             {QStringLiteral("Minimal"), QStringLiteral("minimal")}});
        auto *weatherDetails = addCombo(
            QStringLiteral("Weather details"), QStringLiteral("weatherDetail"),
            {{QStringLiteral("Compact"), QStringLiteral("compact")},
             {QStringLiteral("Standard"), QStringLiteral("standard")},
             {QStringLiteral("Full"), QStringLiteral("full")}});
        auto *temperatureUnit = addCombo(
            QStringLiteral("Temperature"), QStringLiteral("temperatureUnit"),
            {{QStringLiteral("Fahrenheit"), QStringLiteral("fahrenheit")},
             {QStringLiteral("Celsius"), QStringLiteral("celsius")}});

        auto *buttons = new QDialogButtonBox(QDialogButtonBox::Close);
        auto *refreshWeather = buttons->addButton(QStringLiteral("Refresh weather"), QDialogButtonBox::ActionRole);
        auto *weatherLocation = buttons->addButton(QStringLiteral("Weather location…"), QDialogButtonBox::ActionRole);
        connect(refreshWeather, &QPushButton::clicked, this, [this] {
            bool processOk = false;
            const QString response = runOmaDeckIpc({QStringLiteral("refreshWeather")}, &processOk);
            QString error;
            if (!parseIpcResult(response, processOk, nullptr, &error))
                QMessageBox::warning(m_settingsDialog, QStringLiteral("OmaDeck settings"), error);
        });
        connect(weatherLocation, &QPushButton::clicked, this, [] {
            QProcess::startDetached(QStringLiteral("omarchy-shell"),
                                    {QStringLiteral("omarchy.weather"), QStringLiteral("edit")});
        });
        const auto updateWeatherControls = [weatherVisual, weatherDetails, temperatureUnit,
                                            refreshWeather, weatherLocation](bool enabled) {
            weatherVisual->setEnabled(enabled);
            weatherDetails->setEnabled(enabled);
            temperatureUnit->setEnabled(enabled);
            refreshWeather->setEnabled(enabled);
            weatherLocation->setEnabled(enabled);
        };
        connect(showWeather, &QCheckBox::toggled, this, [this, updateWeatherControls](bool checked) {
            if (!setAppearanceOption(QStringLiteral("showWeather"),
                                     checked ? QStringLiteral("true") : QStringLiteral("false")))
                return;
            updateWeatherControls(checked);
        });
        updateWeatherControls(showWeather->isChecked());
        connect(buttons, &QDialogButtonBox::rejected, m_settingsDialog, &QDialog::close);
        layout->addWidget(buttons);

        m_settingsDialog->show();
        m_settingsDialog->raise();
        m_settingsDialog->activateWindow();
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
        const QPointer<QPlainTextEdit> guardedReport(report);
        connect(reconnect, &QPushButton::clicked, this, [this, guardedReport] {
            reconnectTouchscreen();
            scheduleTrayReportRefresh(
                this, guardedReport.data(), 1400,
                [this] { return runDoctor(); },
                [this] { refreshHealth(); });
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
    QPointer<QDialog> m_settingsDialog;
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
