#include "WorldTransformations.h"

void WorldTransformations::SetUniverseSize(unsigned int wWidth, unsigned int wHeight)
{
    universeWidth = wWidth;
    universeHeight = wHeight;
}

void WorldTransformations::SetScreenSize(unsigned int width, unsigned int height)
{
    screenWidth = width;
    screenHeight = height;
}

void WorldTransformations::SetCurrentPositionInUniverse(const Point2D& p, PositionAnchor a)
{
    positionInUniverse = p;
    anchor = a;
}

void WorldTransformations::MoveCurrentPositionInUniverse(const Vector2D& v)
{
    positionInUniverse.x += v.dx;
    positionInUniverse.y += v.dy;
}

Point2D WorldTransformations::FromUniverseToScreen(const Point2D& posInUniverse) const
{
    Point2D axis_origin = positionInUniverse;

    if (anchor == PositionAnchor::Centered)
    {
        axis_origin.x -= screenWidth / 2;
        axis_origin.y -= screenHeight / 2;
    }

    return {posInUniverse.x - axis_origin.x, posInUniverse.y - axis_origin.y};
}

const Point2D WorldTransformations::GetCurrentPositionInUniverse(PositionAnchor a) const
{
    auto comm_p = convertToLeftTop(positionInUniverse, anchor);
    return convertFromLeftTop(comm_p, a);
}

Point2D WorldTransformations::convertToLeftTop(const Point2D& p, PositionAnchor a) const
{
    if (a == PositionAnchor::Centered)
    {
        return {p.x - static_cast<int>(screenWidth) / 2, p.y - static_cast<int>(screenHeight) / 2};
    }
    return p;
}

Point2D WorldTransformations::convertFromLeftTop(const Point2D& p_lt, PositionAnchor a) const
{
    if (a == PositionAnchor::Centered)
    {
        return {p_lt.x + static_cast<int>(screenWidth) / 2, p_lt.y + static_cast<int>(screenHeight) / 2};
    }
    return p_lt;
}
