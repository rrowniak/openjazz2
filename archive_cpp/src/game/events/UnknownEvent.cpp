#include "UnknownEvent.h"

UnknownEvent::~UnknownEvent()
{ }

void UnknownEvent::SetPosition(const Point2D& p, const TileCoordinates& c)
{
    x = p.x;
    y = p.y;
    tc = c;
}

void UnknownEvent::SetId(int id)
{
    eventHandleId = id;
}

TileCoordinates UnknownEvent::GetTileCoord() const
{ return tc; }

int UnknownEvent::getX() const
{
    return x;
}

int UnknownEvent::getY() const
{
    return y;
}

void UnknownEvent::Render(Surface& screen, const Rectangle2D& positionOnSurface)
{
    if (!_displayMessage.empty())
    {
        screen.WriteText(_displayMessage, positionOnSurface.x, positionOnSurface.y, {255, 255, 255, 160});
    }
}

EventCommand UnknownEvent::CollisionWihtHero(const Point2D&)
{
    return {};
}

void UnknownEvent::SetDisplayMessage(const std::string& msg)
{
    _displayMessage = msg;
}
