#include "BonusItem.h"

#include "StandardEvent.h"

BonusItem::~BonusItem() { }

void BonusItem::SetPosition(const Point2D& p, const TileCoordinates& c)
{
    x = p.x;
    y = p.y;
    tc = c;
}

void BonusItem::SetId(int id)
{
    eventHandleId = id;
}

TileCoordinates BonusItem::GetTileCoord() const
{ return tc; }

void BonusItem::Render(Surface& screen, const Rectangle2D& positionOnSurface)
{
    if (isActive)
    {
        animation.Update(GameClock::now());
        const Surface* s = &animation.GetCurrentFrame();

        screen.Draw(*s, NormalizeToDisplay(*s, positionOnSurface));
    }
}

EventCommand BonusItem::CollisionWihtHero(const Point2D&)
{
    isActive = false;
    return {};
}

void BonusItem::AddAnimation(const Animation& a)
{
    animation = a;
}

int BonusItem::getX() const
{ return x; }

int BonusItem::getY() const
{ return y; }
