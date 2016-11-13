#ifndef EVENT_H
#define EVENT_H

#include "gfx/Surface.h"
#include "game/WorldTransformations.h"
#include "utils/Utils.h"

enum class EventCommandType
{
    DoNothing,
    Bonus,
    Spring
};

struct BonusInfo
{
    int NewLifes = 0;
    int Score = 0;
};

struct EventCommand
{
    EventCommand() { }
    EventCommandType type = EventCommandType::DoNothing;
    union
    {
        BonusInfo bonus;
    };
};

class IEvent
{
public:
    virtual ~IEvent();
    virtual void SetPosition(const Point2D& p, const TileCoordinates& c) = 0;
    virtual void SetId(int id) = 0;
    virtual TileCoordinates GetTileCoord() const = 0;
    virtual int getX() const = 0;
    virtual int getY() const = 0;
    virtual void Render(Surface& screen, const Rectangle2D& positionOnSurface) = 0;
    virtual EventCommand CollisionWihtHero(const Point2D&) = 0;
};

typedef std::unique_ptr<IEvent> EventPtr;

Point2D NormalizeToDisplay(const Surface& eventSurface, const Rectangle2D& positionOnSurface);

#endif // EVENT_H
