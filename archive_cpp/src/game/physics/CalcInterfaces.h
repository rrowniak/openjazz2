#ifndef CALCINTERFACES_H
#define CALCINTERFACES_H

#include "utils/Time.h"

namespace physics {

struct IHorizCalc
{
    virtual ~IHorizCalc();
    virtual void Start(GameClock::time_point now) = 0;
    virtual int GetDX(GameClock::time_point now) = 0;
};

struct IVertCalc
{
    virtual ~IVertCalc();
    virtual void Start(GameClock::time_point now) = 0;
    virtual int GetDY(GameClock::time_point now) = 0;
};

}

#endif // CALCINTERFACES_H
