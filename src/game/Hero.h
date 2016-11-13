#ifndef HERO_H
#define HERO_H

#include "utils/Utils.h"
#include "gfx/Animation.h"
#include "utils/ContrAnim.h"
#include "CollisionEngine.h"
#include "physics/HeroPhysics.h"

enum class HeroOrientation
{
    Unspecified,
    Left,
    Right
};


enum class HeroEvent
{
    InputRun,
    InputUp,
    InputDown,
    NoInput,
    CollisionEnemy,
    CollisionHurt,
    CollisionBonus,
    CollisionWall,
    CollisionFloor,
    OnTheEdge,
};


namespace std {
    template<> struct hash<HeroEvent> {
        size_t operator()(const HeroEvent& e) const {
            hash<size_t> h;
            return h(static_cast<size_t>(e));
        }
    };
}

class Hero
{
public:
    Hero(ContrAnim<HeroEvent>&& anims);
    // implement Entity interface
    void SetPosition(const Point2D& p);
    void UpdateState(GameClock::time_point now);
    void Render(Surface& screen, const Rectangle2D& positionOnSurface);
    Rectangle2D GetPosition() const;
    const std::vector<Point2D>& GetConvexHull() const { return _actualPosition; }
    //
    Vector2D GetMovementVector() const;
    void SetMovementVector(const Vector2D& v, const CollisionEngine::NeighborhoodStats& stats);
    //
    void BigJump();
    void Jump();
    void MoveLeft();
    void MoveRight();
    void Ground();
private:
    std::vector<Point2D>        _actualPosition;
    const std::vector<Vector2D>  _convexHull;
    Vector2D                    _movementVector;
    ContrAnim<HeroEvent>        _animations;
    //
    HeroOrientation             _orientation = HeroOrientation::Unspecified;
    HeroEvent                   _lastEvent = HeroEvent::NoInput;
    const int                   _normalWalkSpeed;
    //PhysicalBodyMechanics       _physics;
    CollisionEngine::NeighborhoodStats  _collisionStats;
    physics::HeroPhysics        _physics;
};

#endif // HERO_H
