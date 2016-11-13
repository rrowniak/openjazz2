#ifndef TILE_H
#define TILE_H

#include "gfx/Animation.h"
#include "utils/Utils.h"
#include "game/WorldTransformations.h"
#include "utils/BinaryReader.h"
#include "utils/Time.h"

class Tile
{
public:
    int x = 0;
    int y = 0;
    TileCoordinates tc;

    void AddSurface(const SurfaceSharedPtr& s)
    {
        Img = s;
        isAnimated = false;
    }
    void AddAnimation(const Animation& a)
    {
        Anim = a;
        isAnimated = true;
    }

    //
    void Render(Surface& screen, const Rectangle2D& positionOnSurface)
    {
        const Surface* s = nullptr;
        if (!isAnimated)
        {
            s = &*Img;
        }
        else
        {
            Anim.Update(GameClock::now());
            s = &Anim.GetCurrentFrame();
        }
        if (s != nullptr)
        screen.Draw(*s, positionOnSurface.x, positionOnSurface.y);
        /*
        for (int dx = 0; dx < 32; ++dx)
            for (int dy = 0; dy < 32; ++dy)
                if (IsCollidableAt(dx, dy))
                {
                    int x = positionOnSurface.x + dx;
                    int y = positionOnSurface.y + dy;
                    if (!(x >= screen.getWidth() || y >= screen.getHeight()))
                        screen.PutPixel(x, y, {0,0,255});
                }
        */
    }
    Rectangle2D GetPosition() const
    {
        return {x, y, TileCoordinates::tileWidth, TileCoordinates::tileHeight};
    }
    void SetCollisionMap(std::shared_ptr<std::vector<char>> cm)
    {
        collisionMap =  cm;
    }
    bool IsCollidableAt(int dx, int dy)
    {
        using BinaryReader::IsBitSetAt;
        if (!collisionMap)
        {
            return false;
        }
        unsigned int index = dy*TileCoordinates::tileHeight + dx;
        if (index >= 32 * 32)
        {
            return false;
        }
        return IsBitSetAt(&(*collisionMap)[0], index);
    }
private:
    bool isAnimated = false;
    std::shared_ptr<std::vector<char>> collisionMap;
    SurfaceSharedPtr Img;
    Animation Anim = Animation(10);
};

#endif // TILE_H
