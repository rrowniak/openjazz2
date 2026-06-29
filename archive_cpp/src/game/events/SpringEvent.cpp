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
//     SpringEvent.cpp created 3/29/2013
//
//     Author: Rafal Rowniak
//
**********************************************************************************************/

#include "SpringEvent.h"

SpringEvent::SpringEvent(Animation a)
    : anim(std::move(a))
{
    anim.SetStrategy(AnimationStrategy::OnlyFirtsFrame);
}

SpringEvent::~SpringEvent()
{ }

void SpringEvent::SetPosition(const Point2D& p, const TileCoordinates& c)
{
    x = p.x;
    y = p.y;
    tc = c;
}

void SpringEvent::SetId(int id)
{
    eventHandleId = id;
}

TileCoordinates SpringEvent::GetTileCoord() const
{ return tc; }

int SpringEvent::getX() const
{
    return x;
}

int SpringEvent::getY() const
{
    return y;
}

void SpringEvent::Render(Surface& screen, const Rectangle2D& positionOnSurface)
{
    auto now = GameClock::now();

    anim.Update(now);

    if (anim.IsFinished())
    {
        anim.SetStrategy(AnimationStrategy::OnlyFirtsFrame);
        jump = false;
    }

    auto s = &anim.GetCurrentFrame();

    if (s != nullptr)
    {
        screen.Draw(*s, NormalizeToDisplay(*s, positionOnSurface));
    }
}

EventCommand SpringEvent::CollisionWihtHero(const Point2D& /*p*/)
{
    auto now = GameClock::now();
    if (!jump && (now - jumpStart) >= blockTime)
    {
        jumpStart = now;
        anim.SetStrategy(AnimationStrategy::AnimateTillLastFrame);
        jump = true;        
        EventCommand c;
        c.type = EventCommandType::Spring;        
        return c;
    }
    return { };
}
