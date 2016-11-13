#ifndef WORLDTRANSFORMATIONS_H
#define WORLDTRANSFORMATIONS_H

#include "utils/Utils.h"

struct TileCoordinates
{
    static constexpr int tileWidth = 32;
    static constexpr int tileHeight = 32;
    int x;
    int y;

    Point2D ToPoint() const { return {x, y}; }
    Point2D ToUnivCoord() const { return { x * tileWidth, y * tileHeight}; }
};

inline TileCoordinates FromUnivCoord(int x, int y)
{
    return {x / TileCoordinates::tileWidth, y / TileCoordinates::tileHeight};
}

enum class PositionAnchor
{
    LeftTop,
    Centered
};

class WorldTransformations
{
public:
    void SetUniverseSize(unsigned int wWidth, unsigned int wHeight);
    void SetScreenSize(unsigned int width, unsigned int height);
    void SetCurrentPositionInUniverse(const Point2D& p, PositionAnchor a);
    void MoveCurrentPositionInUniverse(const Vector2D& v);
    Point2D FromUniverseToScreen(const Point2D& posInUniverse) const;
    const Point2D& GetCurrentPositionInUniverse() const { return positionInUniverse; }
    const Point2D GetCurrentPositionInUniverse(PositionAnchor a) const;
private:
    unsigned int    universeWidth;
    unsigned int    universeHeight;

    unsigned int    screenWidth = 0;
    unsigned int    screenHeight = 0;

    Point2D       positionInUniverse;
    PositionAnchor  anchor = PositionAnchor::LeftTop;

    Point2D convertToLeftTop(const Point2D& p, PositionAnchor a) const;
    Point2D convertFromLeftTop(const Point2D& p_lt, PositionAnchor a) const;
};

#endif // WORLDTRANSFORMATIONS_H
