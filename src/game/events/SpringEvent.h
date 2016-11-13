/**********************************************************************************************
//     Copyright 2013 Rafal Rowniak
//
//     This software is distributed in the hope that it will be useful,
//     but WITHOUT ANY WARRANTY; without even the implied warranty of
//     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
//
//     Additional license information:
//     This software can be used and/or modified only for NON-COMMERCIAL purposes.
//
//     Additional information:
//     SpringEvent.h created 3/29/2013
//
//     Author: Rafal Rowniak
//
**********************************************************************************************/

#ifndef SPRINGEVENT_H
#define SPRINGEVENT_H

#include "game/Event.h"
#include "gfx/Animation.h"
#include "utils/Time.h"

class SpringEvent : public IEvent
{
public:
    SpringEvent(Animation a);
    virtual ~SpringEvent();
    virtual void SetPosition(const Point2D& p, const TileCoordinates& c) override;
    virtual void SetId(int id) override;
    virtual TileCoordinates GetTileCoord() const override;
    virtual int getX() const override;
    virtual int getY() const override;
    virtual void Render(Surface& screen, const Rectangle2D& positionOnSurface) override;
    virtual EventCommand CollisionWihtHero(const Point2D&) override;
private:
    int x = 0;
    int y = 0;
    TileCoordinates tc;
    Animation anim;
    int eventHandleId = 0;
    bool jump = false;

    time_point          jumpStart = GameClock::now();
    const miliseconds   blockTime{900};
};

#endif // SPRINGEVENT_H
