#ifndef PHYSICSCALCS_H
#define PHYSICSCALCS_H

#include "CalcInterfaces.h"
#include "Basics.h"

namespace physics {

class JumpFallCalc : public IVertCalc
{
public:
    JumpFallCalc(Velocity initial_v, Gravity g, Velocity max_v)
        : initialV(initial_v)
        , maxV(max_v)
        , gravity(g)
    { }
    // IVertCalc interface
    virtual void Start(GameClock::time_point now) override;
    virtual int GetDY(GameClock::time_point now) override;
private:
    Velocity initialV;
    Velocity maxV;
    Gravity  gravity;
    GameClock::time_point lastRequest;
};

class HorizMovementCalc : public IHorizCalc
{
public:
    HorizMovementCalc(Velocity max_v)
        : maxV(max_v)
    { }
    // IHorizCalc
    virtual void Start(GameClock::time_point now) override;
    virtual int GetDX(GameClock::time_point now) override;
    // end of IHorizCalc
private:
    const Velocity maxV;
    GameClock::time_point lastRequest;
};

}

#endif // PHYSICSCALCS_H
