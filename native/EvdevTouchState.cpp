#include "EvdevTouchState.h"

#include <algorithm>
#include <iterator>

void EvdevTouchState::reset()
{
    std::fill(std::begin(m_trackingIds), std::end(m_trackingIds), -1);
    std::fill(std::begin(m_x), std::end(m_x), 0);
    std::fill(std::begin(m_y), std::end(m_y), 0);
    m_currentSlot = 0;
    m_activeSlot = -1;
    m_singleX = 0;
    m_singleY = 0;
    m_singlePressed = false;
    m_reportedActive = false;
    m_dropPending = false;
}

std::optional<EvdevTouchState::Frame> EvdevTouchState::process(const input_event &event,
                                                               bool multitouch)
{
    if (event.type == EV_SYN && event.code == SYN_DROPPED) {
        // The kernel's state after an overrun is unknowable without ioctl
        // resynchronization. Release any reported contact immediately, discard
        // the corrupt tail, and accept fresh transitions after its SYN_REPORT.
        const bool released = m_reportedActive;
        reset();
        m_dropPending = true;
        return Frame{false, released};
    }

    if (m_dropPending) {
        if (event.type == EV_SYN && event.code == SYN_REPORT)
            m_dropPending = false;
        return std::nullopt;
    }

    if (event.type == EV_ABS && multitouch) {
        if (event.code == ABS_MT_SLOT)
            m_currentSlot = std::clamp(event.value, 0, 15);
        else if (event.code == ABS_MT_TRACKING_ID) {
            m_trackingIds[m_currentSlot] = event.value;
            if (event.value >= 0 && m_activeSlot < 0) {
                m_activeSlot = m_currentSlot;
            } else if (event.value < 0 && m_activeSlot == m_currentSlot) {
                m_activeSlot = -1;
                for (int slot = 0; slot < 16; ++slot) {
                    if (m_trackingIds[slot] >= 0) {
                        m_activeSlot = slot;
                        break;
                    }
                }
            }
        } else if (event.code == ABS_MT_POSITION_X) {
            m_x[m_currentSlot] = event.value;
        } else if (event.code == ABS_MT_POSITION_Y) {
            m_y[m_currentSlot] = event.value;
        }
    } else if (event.type == EV_ABS) {
        if (event.code == ABS_X)
            m_singleX = event.value;
        else if (event.code == ABS_Y)
            m_singleY = event.value;
    } else if (event.type == EV_KEY && event.code == BTN_TOUCH) {
        m_singlePressed = event.value;
    } else if (event.type == EV_SYN && event.code == SYN_REPORT) {
        const bool active = multitouch ? m_activeSlot >= 0 : m_singlePressed;
        const Frame frame{active && !m_reportedActive, !active && m_reportedActive};
        m_reportedActive = active;
        return frame;
    }

    return std::nullopt;
}
