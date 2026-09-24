#include <LayerShellQt/Window>
#include <LayerShellQt/Shell>

#include <QCommandLineParser>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QLocalServer>
#include <QLocalSocket>
#include <QQmlContext>
#include <QQuickView>
#include <QRandomGenerator>
#include <QRegularExpression>
#include <QScreen>
#include <QTimer>
#include <QtWebEngineQuick>

#include <cstdio>

class WatchBridge final : public QObject {
    Q_OBJECT
public:
    explicit WatchBridge(QQuickView *view, QObject *parent = nullptr)
        : QObject(parent), m_view(view) {
        setObjectName(QStringLiteral("bridge"));
    }

    bool listen() {
        const QString runtime = qEnvironmentVariable("XDG_RUNTIME_DIR");
        if (runtime.isEmpty()) return false;
        m_path = runtime + QStringLiteral("/omadeck-watch-%1-%2.sock")
            .arg(QCoreApplication::applicationPid())
            .arg(QRandomGenerator::system()->generate64(), 0, 16);
        m_server.setSocketOptions(QLocalServer::UserAccessOption);
        if (!m_server.listen(m_path)) return false;
        connect(&m_server, &QLocalServer::newConnection, this, &WatchBridge::acceptClient);
        std::printf("SOCKET %s\n", qPrintable(m_path));
        std::fflush(stdout);
        return true;
    }

    ~WatchBridge() override {
        m_server.close();
        if (!m_path.isEmpty()) QLocalServer::removeServer(m_path);
    }

    Q_INVOKABLE void primed(double seconds) {
        if (!m_loaded) return;
        send({{QStringLiteral("event"), QStringLiteral("primed")},
              {QStringLiteral("seconds"), seconds}});
    }

    Q_INVOKABLE void playerState(int state) {
        if (!m_loaded) return;
        send({{QStringLiteral("event"), QStringLiteral("state")},
              {QStringLiteral("state"), state}});
    }

    Q_INVOKABLE void playerPosition(double seconds) {
        if (!m_loaded || !qIsFinite(seconds) || seconds < 0) return;
        send({{QStringLiteral("event"), QStringLiteral("position")},
              {QStringLiteral("seconds"), seconds}});
    }

    Q_INVOKABLE void playerDuration(double seconds) {
        if (!m_loaded || !qIsFinite(seconds) || seconds <= 0) return;
        send({{QStringLiteral("event"), QStringLiteral("duration")},
              {QStringLiteral("seconds"), seconds}});
    }

    Q_INVOKABLE void playerError(int code) {
        if (!m_loaded) return;
        send({{QStringLiteral("event"), QStringLiteral("error")},
              {QStringLiteral("code"), code}});
    }

    Q_INVOKABLE void returnSnapshot(double seconds) {
        if (!m_loaded || !qIsFinite(seconds) || seconds < 0 || seconds > 604800) return;
        send({{QStringLiteral("event"), QStringLiteral("returnSnapshot")},
              {QStringLiteral("seconds"), seconds}});
    }

    Q_INVOKABLE void captionState(bool available, bool enabled) {
        if (!m_loaded) return;
        send({{QStringLiteral("event"), QStringLiteral("captions")},
              {QStringLiteral("available"), available}, {QStringLiteral("enabled"), enabled}});
    }

    Q_INVOKABLE void probeLoaded(bool success) {
        std::printf("PROBE %s\n", success ? "loaded" : "failed");
        std::fflush(stdout);
        qApp->exit(success ? 0 : 6);
    }

signals:
    void loadRequested(const QString &videoId, int seconds);
    void controlRequested(const QString &action, int seconds);

private:
    void send(const QJsonObject &message) {
        if (!m_client || m_client->state() != QLocalSocket::ConnectedState) return;
        m_client->write(QJsonDocument(message).toJson(QJsonDocument::Compact) + '\n');
        m_client->flush();
    }

    void acceptClient() {
        while (auto *next = m_server.nextPendingConnection()) {
            if (m_client) {
                next->disconnectFromServer();
                next->deleteLater();
                continue;
            }
            m_client = next;
            connect(next, &QLocalSocket::readyRead, this, &WatchBridge::readClient);
            connect(next, &QLocalSocket::disconnected, qApp, &QCoreApplication::quit);
            send({{QStringLiteral("event"), QStringLiteral("connected")}});
        }
    }

    void readClient() {
        if (!m_client) return;
        m_buffer += m_client->readAll();
        if (m_buffer.size() > 4096) {
            qApp->quit();
            return;
        }
        while (true) {
            const int newline = m_buffer.indexOf('\n');
            if (newline < 0) break;
            const QByteArray line = m_buffer.left(newline);
            m_buffer.remove(0, newline + 1);
            if (line.size() > 1024) { qApp->quit(); return; }
            QJsonParseError error;
            const auto parsed = QJsonDocument::fromJson(line, &error);
            if (error.error != QJsonParseError::NoError || !parsed.isObject()) continue;
            command(parsed.object());
        }
    }

    void command(const QJsonObject &value) {
        const QString action = value.value(QStringLiteral("action")).toString();
        if (action == QStringLiteral("close")) { qApp->quit(); return; }
        if (action == QStringLiteral("load") && !m_loaded) {
            const QString id = value.value(QStringLiteral("videoId")).toString();
            static const QRegularExpression idPattern(QStringLiteral("^[A-Za-z0-9_-]{11}$"));
            const int seconds = value.value(QStringLiteral("seconds")).toInt(-1);
            const int width = value.value(QStringLiteral("width")).toInt(-1);
            const int height = value.value(QStringLiteral("height")).toInt(-1);
            const int left = value.value(QStringLiteral("left")).toInt(-1);
            const int top = value.value(QStringLiteral("top")).toInt(-1);
            if (!idPattern.match(id).hasMatch() || seconds < 0 || seconds > 604800
                || width < 480 || width > 3000 || height < 270 || height > 1200
                || left < 0 || left > 5000 || top < 0 || top > 3000) {
                send({{QStringLiteral("event"), QStringLiteral("error")},
                      {QStringLiteral("code"), QStringLiteral("invalid-load")}});
                return;
            }
            m_loaded = true;
            auto *layer = LayerShellQt::Window::get(m_view);
            if (layer) {
                layer->setMargins(QMargins(left, top, 0, 0));
                layer->setDesiredSize(QSize(width, height));
            }
            m_view->resize(width, height);
            m_view->show();
            QTimer::singleShot(0, this, [this, id, seconds] { emit loadRequested(id, seconds); });
            return;
        }
        if (!m_loaded) return;
        if (action == QStringLiteral("geometry")) {
            const int left = value.value(QStringLiteral("left")).toInt(-1);
            const int top = value.value(QStringLiteral("top")).toInt(-1);
            const int width = value.value(QStringLiteral("width")).toInt(-1);
            const int height = value.value(QStringLiteral("height")).toInt(-1);
            if (left < 0 || left > 5000 || top < 0 || top > 3000
                || width < 160 || width > 3000 || height < 90 || height > 1200) return;
            if (auto *layer = LayerShellQt::Window::get(m_view)) {
                layer->setMargins(QMargins(left, top, 0, 0));
                layer->setDesiredSize(QSize(width, height));
            }
            m_view->resize(width, height);
            m_view->requestUpdate();
            return;
        }
        if (action == QStringLiteral("position")) {
            const int left = value.value(QStringLiteral("left")).toInt(-1);
            const int top = value.value(QStringLiteral("top")).toInt(-1);
            if (left < 0 || left > 5000 || top < 0 || top > 3000) return;
            if (auto *layer = LayerShellQt::Window::get(m_view))
                layer->setMargins(QMargins(left, top, 0, 0));
            m_view->requestUpdate();
            return;
        }
        if (action == QStringLiteral("play") || action == QStringLiteral("pause")
            || action == QStringLiteral("returnSnapshot")
            || action == QStringLiteral("captionsOn") || action == QStringLiteral("captionsOff")) {
            emit controlRequested(action, 0);
        } else if (action == QStringLiteral("seek") || action == QStringLiteral("commit")) {
            const int seconds = value.value(QStringLiteral("seconds")).toInt(-1);
            if (seconds >= 0 && seconds <= 604800) emit controlRequested(action, seconds);
        }
    }

    QQuickView *m_view = nullptr;
    QLocalServer m_server;
    QLocalSocket *m_client = nullptr;
    QByteArray m_buffer;
    QString m_path;
    bool m_loaded = false;
};

int main(int argc, char **argv) {
    QtWebEngineQuick::initialize();
    if (!qEnvironmentVariableIsEmpty("WAYLAND_DISPLAY")
        && qEnvironmentVariable("QT_QPA_PLATFORM") != QStringLiteral("offscreen")) {
        LayerShellQt::Shell::useLayerShell();
    }
    QGuiApplication app(argc, argv);
    QCoreApplication::setApplicationName(QStringLiteral("omadeck-watch-host"));

    QCommandLineParser parser;
    parser.addHelpOption();
    QCommandLineOption screenOption(QStringList{QStringLiteral("screen")},
                                    QStringLiteral("Target screen name"), QStringLiteral("name"));
    QCommandLineOption probeOption(QStringList{QStringLiteral("probe")},
                                   QStringLiteral("Run isolated local-page load probe"));
    QCommandLineOption offscreenHostOption(QStringList{QStringLiteral("offscreen-host")},
                                          QStringLiteral("Run isolated socket protocol probe"));
    parser.addOption(screenOption);
    parser.addOption(probeOption);
    parser.addOption(offscreenHostOption);
    parser.process(app);
    const bool probe = parser.isSet(probeOption);
    const bool offscreenHost = parser.isSet(offscreenHostOption);

    QQuickView view;
    view.setColor(Qt::transparent);
    view.setFlags(Qt::FramelessWindowHint | Qt::WindowTransparentForInput);
    const QString screenName = parser.value(screenOption);
    bool foundScreen = false;
    for (QScreen *screen : app.screens()) {
        if (screen->name() != screenName) continue;
        view.setScreen(screen);
        foundScreen = true;
        break;
    }
    if (!foundScreen && !probe && !offscreenHost) return 2;

    if (!probe && !offscreenHost) {
        auto *layer = LayerShellQt::Window::get(&view);
        if (!layer) return 3;
        layer->setScreen(view.screen());
        layer->setLayer(LayerShellQt::Window::LayerTop);
        layer->setAnchors(LayerShellQt::Window::Anchors(LayerShellQt::Window::AnchorTop)
                          | LayerShellQt::Window::AnchorLeft);
        layer->setExclusiveZone(0);
        layer->setKeyboardInteractivity(LayerShellQt::Window::KeyboardInteractivityNone);
        layer->setActivateOnShow(false);
        layer->setScope(QStringLiteral("omadeck-watch-video"));
        layer->setCloseOnDismissed(true);
    }
    QObject::connect(&view, &QQuickWindow::visibleChanged, &app, [&view, &app] {
        if (!view.isVisible()) app.quit();
    });

    WatchBridge bridge(&view);
    view.rootContext()->setContextProperty(QStringLiteral("watchBridge"), &bridge);
    view.rootContext()->setContextProperty(QStringLiteral("watchProbe"), probe);
    view.setSource(QUrl(QStringLiteral("qrc:/WatchView.qml")));
    if (view.status() != QQuickView::Ready) return 4;
    if (probe) {
        view.resize(800, 450);
        view.show();
        QTimer::singleShot(5000, &app, &QCoreApplication::quit);
        return app.exec();
    }
    if (!bridge.listen()) return 5;
    return app.exec();
}

#include "main.moc"
