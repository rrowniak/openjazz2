#ifndef UTILS_H
#define UTILS_H

#include "MicroLogger.h"
#include "utils/Time.h"
#include "utils/Math.h"
#include <cstdint>
#include <assert.h>

namespace {
template <typename T>
inline void __WriteToLogger__(MicroLogger& l, const Point2D_t<T>& p)
{
    l.Put("(");
    l.Put(p.x);
    l.Put(", ");
    l.Put(p.y);
    l.Put(")");
}

template <typename T>
inline void __WriteToLogger__(MicroLogger& l, const Vector2D_t<T>& p)
{
    l.Put("(");
    l.Put(p.dx);
    l.Put(", ");
    l.Put(p.dy);
    l.Put(")");
}

}

inline MicroLogger& operator<<(MicroLogger& l, const Point2D& p)
{
    __WriteToLogger__(l, p);
    return l;
}

inline MicroLogger& operator<<(MicroLogger& l, const Point2D_d& p)
{
    __WriteToLogger__(l, p);
    return l;
}

inline MicroLogger& operator<<(MicroLogger& l, const Vector2D_t<int>& v)
{
    __WriteToLogger__(l, v);
    return l;
}

inline MicroLogger& operator<<(MicroLogger& l, const Vector2D_t<double>& v)
{
    __WriteToLogger__(l, v);
    return l;
}

class FPSCounter
{
public:
    void UpdateStateEvery(uint32_t msec)
    {
        recalculate_msec = msec;
    }

    void Tick(uint32_t currentTime)
    {
        ++frame_count;
        if (start_msec == 0)
        {
            start_msec = currentTime;
            return;
        }

        uint32_t dt = currentTime - start_msec;

        if (dt >= recalculate_msec)
        {
            fps = (double)frame_count / ((double)dt / 1000.0);
            start_msec = currentTime;
            frame_count = 0;
        }
    }

    double GetFPS() const
    {
        return fps;
    }
private:
    uint32_t recalculate_msec = 1000; // 1 sec
    uint32_t start_msec = 0;
    uint32_t frame_count = 0;
    double fps = 0.0;
};

#endif // UTILS_H
