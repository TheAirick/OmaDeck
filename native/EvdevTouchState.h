#pragma once

#include <linux/input.h>

#include <optional>

class EvdevTouchState
{
public:
    struct Frame {
        bool pressed = false;
        bool released = false;
    };

    void reset();
    std::optional<Frame> process(const input_event &event, bool multitouch);

    int activeSlot() const { return m_activeSlot; }
    int x(int slot) const { return m_x[slot]; }
    int y(int slot) const { return m_y[slot]; }
    int singleX() const { return m_singleX; }
    int singleY() const { return m_singleY; }

private:
    int m_currentSlot = 0;
    int m_activeSlot = -1;
    int m_trackingIds[16]{};
    int m_x[16]{};
    int m_y[16]{};
    int m_singleX = 0;
    int m_singleY = 0;
    bool m_singlePressed = false;
    bool m_reportedActive = false;
    bool m_dropPending = false;
};
