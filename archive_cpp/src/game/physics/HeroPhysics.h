#ifndef HEROPHYSICS_H
#define HEROPHYSICS_H

#include "CalcInterfaces.h"
#include "utils/Time.h"

#include <queue>
#include <vector>
#include <memory>

namespace physics {

enum class PhysicsEvent
{
    no_collisions,
    collision_with_ground,
    collision_with_wall,
    collision_with_roof,

    jump,
    jump_doubled,
    walk,
    run
};

class HeroPhysics
{
public:
    HeroPhysics();
    void Update(GameClock::time_point now);
    void PushEvent(PhysicsEvent ev);
    int GetDX() const { return dx; }
    int GetDY() const { return dy; }
private:
    std::queue<PhysicsEvent> eventsToConsume;
    int dx = 0;
    int dy = 0;
    IHorizCalc*     horizCalc = nullptr;
    IVertCalc*      vertCalc = nullptr;
    std::vector<std::unique_ptr<IHorizCalc>> horizCalcs;
    std::vector<std::unique_ptr<IVertCalc>> vertCalcs;
};

}

#endif // HEROPHYSICS_H
