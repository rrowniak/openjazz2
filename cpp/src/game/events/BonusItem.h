#ifndef BONUSITEM_H
#define BONUSITEM_H

#include "game/Event.h"
#include "gfx/Animation.h"

class BonusItem : public IEvent
{
public:
    virtual ~BonusItem();
    // IEvent interface
    virtual void SetPosition(const Point2D& p, const TileCoordinates& c) override;
    virtual void SetId(int id) override;
    virtual TileCoordinates GetTileCoord() const override;
    virtual int getX() const override;
    virtual int getY() const override;
    virtual void Render(Surface& screen, const Rectangle2D& positionOnSurface) override;
    virtual EventCommand CollisionWihtHero(const Point2D&) override;
    // end of IEvent interface
    void AddAnimation(const Animation& a);
protected:
    bool isActive = true;
    int x = 0;
    int y = 0;
    TileCoordinates tc;
    Animation animation = Animation(10);
    int eventHandleId;
};

#endif // BONUSITEM_H
