#include "PhysicsCalcs.h"

namespace physics {

void JumpFallCalc::Start(GameClock::time_point now)
{
    lastRequest = now;
}

int JumpFallCalc::GetDY(GameClock::time_point now)
{
}


void HorizMovementCalc::Start(GameClock::time_point now)
{
    lastRequest = now;
}

int HorizMovementCalc::GetDX(GameClock::time_point now)
{
    std::chrono::milliseconds diff = now - lastRequest;
    auto v = maxV.GetPixelsPerSecond();
    return v * static_cast<double>(diff.count()) / 1000.0;
}

}
