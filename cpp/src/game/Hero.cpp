#include "Hero.h"

#include <algorithm>

struct ConvexHullPoint
{
    enum Values
    {
        LeftTop     = 0,
        RightTop    = 1,
        RightDown   = 2,
        LeftDown    = 3
    };
};

Hero::Hero(ContrAnim<HeroEvent>&& anims)
    : _convexHull{{0, 0}, {31, 0}, {31, 31}, {0, 31}}
    , _movementVector{0, 0}
    , _animations(std::move(anims))
    , _normalWalkSpeed(10)
{
    _actualPosition.assign(_convexHull.size(), {0, 0});
}

void Hero::SetPosition(const Point2D& p)
{
    assert(_convexHull.size() == _actualPosition.size());
    for (unsigned i = 0; i < _convexHull.size(); ++i)
    {
        _actualPosition[i] = p + _convexHull[i];
    }
}

void Hero::UpdateState(GameClock::time_point now)
{
    if (_collisionStats.touchCeiling)
    {
        //_physics.Fall(600);
    }
    //_physics.Update(now);
    /*if (_physics.GetDy() != 0)
    {
        _movementVector.dy += _physics.GetDy();
    }
    else if (!_collisionStats.onTheGround)
    {
        _physics.Fall(600);
    }*/
    _animations.OnEvent(_lastEvent);
    _lastEvent = HeroEvent::NoInput;
    _animations.Update();
}

void Hero::Render(Surface& screen, const Rectangle2D& positionOnSurface)
{
    int x = positionOnSurface.x;
    int y = positionOnSurface.y;
    if (x >= 0 && y >= 0 && x < screen.getWidth() && y < screen.getHeight())
    {
        const auto& a = _animations.GetCurrent();
        // calculate position of current frame
        int dx = _actualPosition[ConvexHullPoint::RightTop].x - _actualPosition[ConvexHullPoint::LeftTop].x;
        int dy = _actualPosition[ConvexHullPoint::LeftDown].y - _actualPosition[ConvexHullPoint::LeftTop].y;
        int ground_y = positionOnSurface.y + dy;
        int center_x = positionOnSurface.x + dx / 2;
        int anim_x = center_x - a.GetCurrentFrame().getWidth() / 2;
        int anim_y = ground_y - a.GetCurrentFrame().getHeight();

        if (_orientation == HeroOrientation::Left)
        {
            screen.Draw(a.GetCurrentFrameMirrored(), anim_x, anim_y);
        }
        else
        {
            screen.Draw(a.GetCurrentFrame(), anim_x, anim_y);
        }
        for (const auto& v : _convexHull)
        {
            int x = positionOnSurface.x + v.dx;
            int y = positionOnSurface.y + v.dy;
            if (x >= 0 && y >= 0 && x < screen.getWidth() && y < screen.getHeight())
                screen.PutPixel(x, y, {255, 255, 255});
        }
    }
}

Rectangle2D Hero::GetPosition() const
{
    return {_actualPosition[ConvexHullPoint::LeftTop].x,
            _actualPosition[ConvexHullPoint::LeftTop].y, 16, 32};
}

Vector2D Hero::GetMovementVector() const
{
    return _movementVector;
}

void Hero::SetMovementVector(const Vector2D& v, const CollisionEngine::NeighborhoodStats& stats)
{
    _movementVector = v;
    _collisionStats = stats;
}

void Hero::BigJump()
{
    _lastEvent = HeroEvent::InputUp;
    //_physics.Idle();
    //_physics.Jump(500);
}

void Hero::Jump()
{
    if (_collisionStats.onTheGround)
    {
        _lastEvent = HeroEvent::InputUp;
        //_physics.Jump(140);
    }
}

void Hero::MoveLeft()
{
    _movementVector.dx += -_normalWalkSpeed;
    _orientation = HeroOrientation::Left;
    _lastEvent = HeroEvent::InputRun;
}

void Hero::MoveRight()
{
    _movementVector.dx += _normalWalkSpeed;
    _orientation = HeroOrientation::Right;
    _lastEvent = HeroEvent::InputRun;
}

void Hero::Ground()
{
    _movementVector.dy += _normalWalkSpeed;
    _lastEvent = HeroEvent::InputDown;
    //_physics.Idle();
}
