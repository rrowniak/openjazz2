#include "StandardEvent.h"

StandardEvent::~StandardEvent() { }

void StandardEvent::SetPosition(const Point2D& p, const TileCoordinates& c)
{
    x = p.x;
    y = p.y;
    tc = c;
}

void StandardEvent::SetId(int id)
{
    eventHandleId = id;
}

TileCoordinates StandardEvent::GetTileCoord() const
{ return tc; }

void StandardEvent::Render(Surface& screen, const Rectangle2D& positionOnSurface)
{
    if (isRenderable)
    {
        const Surface* s = nullptr;
        if (!isAnimated)
        {
            s = &*surface;
        }
        else
        {
            animation.Update(GameClock::now());
            s = &animation.GetCurrentFrame();
        }
        if (s != nullptr)
        {
            screen.Draw(*s, NormalizeToDisplay(*s, positionOnSurface));
        }
    }

    if (!_displayMessage.empty())
    {
        screen.WriteText(_displayMessage, positionOnSurface.x, positionOnSurface.y, {255, 255, 255, 160});
    }
}

EventCommand StandardEvent::CollisionWihtHero(const Point2D&)
{
    return { };
}

void StandardEvent::AddSurface(const SurfaceSharedPtr& s)
{
    isRenderable = true;
    isAnimated = false;
    surface = s;
}

void StandardEvent::AddAnimation(const Animation& a)
{
    isRenderable = true;
    isAnimated = true;
    animation = a;
}


Rectangle2D StandardEvent::GetPosition() const
{
    return {x, y, TileCoordinates::tileWidth, TileCoordinates::tileHeight};
}

bool StandardEvent::isFlipped() const
{ return _isFlipped; }

void StandardEvent::SetDisplayMessage(const std::string& msg)
{
    _displayMessage = msg;
}

int StandardEvent::getX() const
{ return x; }

int StandardEvent::getY() const
{ return y; }
