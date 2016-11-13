#ifndef COLLISIONENGINE_H
#define COLLISIONENGINE_H

#include <cmath>
#include <limits>
#include <vector>
#include <assert.h>
#include "utils/Utils.h"
#include "utils/MicroLogger.h"

namespace CollisionEngine
{

struct NeighborhoodStats
{
    bool onTheGround = false;
    bool inFrontOfLeftWall = false;
    bool inFrontOfRightWall = false;
    bool touchCeiling = false;
    //bool inFrontOfLeftEdge = false;
    //bool inFrontOfRightEdge = false;
};

template <class TerrainGetterFn>
bool OnTheGround(const TerrainGetterFn& terrain, const Point2D& p)
{
    //        p
    //        x
    return terrain(p.x, p.y + 1);
}

template <class TerrainGetterFn>
bool InFrontOfLeftWall(const TerrainGetterFn& terrain, const Point2D& p)
{
    //        x
    //        x
    //        xp
    return terrain(p.x - 1, p.y) && terrain(p.x - 1, p.y - 1) && terrain(p.x - 1, p.y - 2);
}

template <class TerrainGetterFn>
bool InFrontOfRightWall(const TerrainGetterFn& terrain, const Point2D& p)
{
    //         x
    //         x
    //        px
    return terrain(p.x + 1, p.y) && terrain(p.x + 1, p.y - 1) && terrain(p.x + 1, p.y - 2);
}

template <class TerrainGetterFn>
bool TouchCeiling(const TerrainGetterFn& terrain, const Point2D& p)
{
    //         x
    //         p
    return terrain(p.x, p.y - 1);
}

template <class TerrainGetterFn>
void GetStatistics(const TerrainGetterFn& terrain, const Point2D& p, NeighborhoodStats& stats)
{
    stats.onTheGround = OnTheGround(terrain, p);
    stats.inFrontOfLeftWall = InFrontOfLeftWall(terrain, p);
    stats.inFrontOfRightWall = InFrontOfRightWall(terrain, p);
    stats.touchCeiling = TouchCeiling(terrain, p);
}

// returns true if collision with terrain happens
template <class TerrainGetterFn>
bool AdjustMovementVector(const TerrainGetterFn& terrain, const Point2D& p, Vector2D& v)
{
    bool isCollision = false;
    int non_collidind_x = p.x;
    // go through X
    int abs_dx = abs_i(v.dx);
    int sign_dx = sign_i(v.dx);
    for (int dx = 0; dx <= abs_dx; ++dx)
    {
        int dxx = dx * sign_dx;
        if (!terrain(p.x + dxx, p.y))
        {
            non_collidind_x = p.x + dxx;
        }
        else
        {
            isCollision = true;
            break;
        }
    }
    // go through Y
    int non_colliding_y = p.y;
    int abs_dy = abs_i(v.dy);
    int sign_dy = sign_i(v.dy);
    for (int dy = 0; dy <= abs_dy; ++dy)
    {
        int dyy = dy * sign_dy;
        if (!terrain(non_collidind_x, p.y + dyy))
        {
            non_colliding_y = p.y + dyy;
        }
        else
        {
            isCollision = true;
            break;
        }
    }
    // truncate the v vector
    v = {non_collidind_x - p.x, non_colliding_y - p.y};
    return isCollision;
}

}

#endif // COLLISIONENGINE_H
