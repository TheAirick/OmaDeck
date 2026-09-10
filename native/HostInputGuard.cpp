#include "HostInputGuard.h"

HostInputState &HostInputState::instance()
{
    static HostInputState state;
    return state;
}

bool HostInputState::allowed() const
{
    // Ambiguous ownership during replacement fails closed, too.
    return available() && !(*m_publishers.constBegin())->blocked();
}

void HostInputState::add(HostInputGuard *publisher)
{
    m_publishers.insert(publisher);
    emit changed();
}

void HostInputState::remove(HostInputGuard *publisher)
{
    m_publishers.remove(publisher);
    emit changed();
}

void HostInputState::update()
{
    emit changed();
}

HostInputGuard::~HostInputGuard()
{
    if (m_complete)
        HostInputState::instance().remove(this);
}

void HostInputGuard::setBlocked(bool blocked)
{
    if (m_blocked == blocked)
        return;
    m_blocked = blocked;
    if (m_complete)
        HostInputState::instance().update();
    emit blockedChanged();
}

void HostInputGuard::componentComplete()
{
    if (m_complete)
        return;
    m_complete = true;
    HostInputState::instance().add(this);
}
