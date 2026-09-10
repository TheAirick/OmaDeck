#pragma once

#include <QObject>
#include <QQmlParserStatus>
#include <QSet>

class HostInputGuard;

// Process-local primitive state only. Never publish a QObject from the
// authentication service: that would expose its parent/context and credentials.
class HostInputState : public QObject
{
    Q_OBJECT
public:
    static HostInputState &instance();
    bool available() const { return m_publishers.size() == 1; }
    bool allowed() const;
    void add(HostInputGuard *publisher);
    void remove(HostInputGuard *publisher);
    void update();

signals:
    void changed();

private:
    QSet<HostInputGuard *> m_publishers;
};

// Created privately by the user-owned lock service's optional Loader. Default
// deny, including QML construction, unresolved orphan locks and provider loss.
class HostInputGuard : public QObject, public QQmlParserStatus
{
    Q_OBJECT
    Q_INTERFACES(QQmlParserStatus)
    Q_PROPERTY(bool blocked READ blocked WRITE setBlocked NOTIFY blockedChanged)
public:
    explicit HostInputGuard(QObject *parent = nullptr) : QObject(parent) {}
    ~HostInputGuard() override;
    bool blocked() const { return m_blocked; }
    void setBlocked(bool blocked);
    void classBegin() override {}
    void componentComplete() override;

signals:
    void blockedChanged();

private:
    bool m_blocked = true;
    bool m_complete = false;
};
