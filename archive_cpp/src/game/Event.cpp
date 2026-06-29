#include "Event.h"

IEvent::~IEvent() { }

Point2D NormalizeToDisplay(const Surface& eventSurface, const Rectangle2D& positionOnSurface)
{
    int x = positionOnSurface.x;
    int y = positionOnSurface.y;

    // adjust surface
    auto w = eventSurface.getWidth();
    auto h = eventSurface.getHeight();
    int dx = (TileCoordinates::tileWidth - w) / 2;
    int dy = TileCoordinates::tileHeight - h;
    return {x + dx, y + dy};
}
