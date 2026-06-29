#ifndef UNKNOWNEVENT_H
#define UNKNOWNEVENT_H

#include "game/Event.h"

#include <string>

class UnknownEvent : public IEvent
{
public:
    virtual ~UnknownEvent();
    virtual void SetPosition(const Point2D& p, const TileCoordinates& c) override;
    virtual void SetId(int id) override;
    virtual TileCoordinates GetTileCoord() const override;
    virtual int getX() const override;
    virtual int getY() const override;
    virtual void Render(Surface& screen, const Rectangle2D& positionOnSurface) override;
    virtual EventCommand CollisionWihtHero(const Point2D&) override;

    void SetDisplayMessage(const std::string& msg);
private:
    std::string _displayMessage;
    int x = 0;
    int y = 0;
    TileCoordinates tc;
    int eventHandleId;
};

#endif // UNKNOWNEVENT_H
