#ifndef PHYSICS_BASICS_H
#define PHYSICS_BASICS_H

namespace physics {

class Gravity
{
public:
    Gravity() = default;
    explicit Gravity(int pixels_per_sec_2)
        : value(pixels_per_sec_2)
    { }
    Gravity(const Gravity&) = default;
    Gravity& operator=(const Gravity&) = default;
    int GetPixelsPerSecond2() const
    { return value; }
private:
    int value = 0; // pixels per secs square
};

class Velocity
{
public:
    Velocity() = default;
    explicit Velocity(int pixels_per_second)
        : pixelsPerSecond(pixels_per_second)
    { }
    Velocity(const Velocity&) = default;
    Velocity& operator=(const Velocity&) = default;
    int GetPixelsPerSecond() const
    { return pixelsPerSecond; }
private:
    int pixelsPerSecond = 0;
};

}

#endif // PHYSICS_BASICS_H
