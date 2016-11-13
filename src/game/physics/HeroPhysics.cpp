#include "HeroPhysics.h"
#include "PhysicsCalcs.h"

namespace physics {

IHorizCalc::~IHorizCalc() { }
IVertCalc::~IVertCalc() { }

HeroPhysics::HeroPhysics()
{
    Velocity horiz_v_max{50};
    horizCalcs.emplace_back(new HorizMovementCalc{horiz_v_max});
    horizCalc = horizCalcs[0].get();

//    Velocity
}

void HeroPhysics::Update(GameClock::time_point now)
{

}

void HeroPhysics::PushEvent(PhysicsEvent ev)
{
    eventsToConsume.push(ev);
}

}
