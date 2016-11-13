#ifndef STANDARDEVENT_H
#define STANDARDEVENT_H

#include "game/Event.h"
#include "gfx/Animation.h"
#include "gfx/GraphicsEngine.h"


class StandardEvent : public IEvent
{
public:
    virtual ~StandardEvent();
    // IEvent interface
    virtual void SetPosition(const Point2D& p, const TileCoordinates& c) override;
    virtual void SetId(int id) override;
    virtual TileCoordinates GetTileCoord() const override;
    virtual int getX() const override;
    virtual int getY() const override;
    virtual void Render(Surface& screen, const Rectangle2D& positionOnSurface) override;
    virtual EventCommand CollisionWihtHero(const Point2D&) override;
    // end of IEvent interface
    void AddSurface(const SurfaceSharedPtr& s);
    void AddAnimation(const Animation& a);

    Rectangle2D GetPosition() const;
    bool isFlipped() const;
    void SetDisplayMessage(const std::string& msg);
protected:
    bool isRenderable = false;
    int x = 0;
    int y = 0;
    TileCoordinates tc;
    bool _isFlipped = false;
    bool isAnimated = false;
    std::string _displayMessage;
    SurfaceSharedPtr surface;
    Animation animation = Animation(10);
    int eventHandleId;
};

#endif // STANDARDEVENT_H
