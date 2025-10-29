#ifndef ANIMATION_H
#define ANIMATION_H

#include <vector>
#include <string>
#include "AnimationCalculator.h"
#include "Surface.h"

struct AnimFrameInfo
{
    bool Enabled = false;
    short ColdspotX;    // Relative to hotspot
    short ColdspotY;    // Relative to hotspot
    short HotspotX;
    short HotspotY;
    short GunspotX;     // Relative to hotspot
    short GunspotY;     // Relative to hotspot
};

enum class AnimationStrategy
{
    Normal,
    Oscillate, // 1234321 patern
    OnlyFirtsFrame,
    AnimateTillLastFrame
};

class Animation
{
public:
    explicit Animation(double fps);
    Animation(std::initializer_list<std::string> frames);
    Animation(const Animation&);
    Animation(Animation&&) = default;
    Animation& operator=(const Animation&);
    Animation& operator=(Animation&&) = default;
    // gets current frame, in order to proper working Update() method
    // has to be frequently called
    const Surface& GetCurrentFrame() const;
    const Surface& GetCurrentFrameMirrored() const;
    void SetStrategy(AnimationStrategy s);
    // adds a new frame (if you use mirroed frames
    // then SetUpMirroredFrames() need to be called
    void PushFrame(const SurfaceSharedPtr& frame);
    void PushFrame(const SurfaceSharedPtr& frame, const AnimFrameInfo& info);
    // updates the internal frame calculator
    void Update(const time_point& timeTick);
    // prepare mirrored frames (corresponds to GetCurrentFrameMirrored())
    void SetUpMirroredFrames();
    inline unsigned int FrameCount() const
    { return _frames.size(); }
    int GetMaxWidth() const { return _maxWidth; }
    int GetMaxHeight() const { return _maxHeight; }
    bool IsFinished() const;
protected:
    std::unique_ptr<IAnimationStrategy> _strategy;
    std::vector<SurfaceSharedPtr>   _frames;
    std::vector<SurfaceSharedPtr>   _mirroredFrames;
    std::vector<AnimFrameInfo>      _framesInfo;

    double _fps = 0;
    int _maxWidth = 0;
    int _maxHeight = 0;
};

#endif // ANIMATION_H
