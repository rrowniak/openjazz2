#include "Animation.h"
#include "data/ResourceFactory.h"
#include <assert.h>
#include <limits>
#include <memory>

Animation::Animation(double fps)
    : _fps(fps)
{ }

Animation::Animation(std::initializer_list<std::string> frames)
{
    for (auto& f: frames)
    {
        _frames.push_back({ResourceFactory::GetInstance().LoadSurface(f, 255, 0, 255)});
        _framesInfo.push_back({});
    }

    if (_frames.size() != 0)
    {
        _strategy.reset(new NormalAnimationStrategy(10, _frames.size()));
    }

    for (auto& f: _frames)
    {
        _maxWidth = std::max(f->getWidth(), _maxWidth);
        _maxHeight = std::max(f->getHeight(), _maxHeight);
    }
}

Animation::Animation(const Animation& a)
    : _frames(a._frames)
    , _mirroredFrames(a._mirroredFrames)
    , _framesInfo(a._framesInfo)
    , _fps(a._fps)
    , _maxWidth(a._maxWidth)
    , _maxHeight(a._maxHeight)
{
    _strategy.reset(a._strategy->Clone());
}

Animation& Animation::operator=(const Animation& a)
{
    _frames = a._frames;
    _mirroredFrames = a._mirroredFrames;
    _framesInfo = a._framesInfo;
    _fps = a._fps;
    _maxWidth = a._maxWidth;
    _maxHeight = a._maxHeight;
    _strategy.reset(a._strategy->Clone());
    return *this;
}

const Surface& Animation::GetCurrentFrame() const
{
    assert(_strategy.get() != nullptr && "No animation strategy assigned!");
    assert(_frames.size() > (unsigned int)_strategy->GetCurrentFrame());
    return *(_frames[_strategy->GetCurrentFrame()].get());
}

const Surface& Animation::GetCurrentFrameMirrored() const
{
    assert(_strategy.get() != nullptr && "No animation strategy assigned!");
    assert(_mirroredFrames.size() > (unsigned int)_strategy->GetCurrentFrame());
    return *(_mirroredFrames[_strategy->GetCurrentFrame()].get());
}

void Animation::SetStrategy(AnimationStrategy s)
{
    switch (s)
    {
    case AnimationStrategy::Normal:
        _strategy.reset(new NormalAnimationStrategy(_fps, _frames.size()));
        break;
    case AnimationStrategy::Oscillate:
        _strategy.reset(new OscillateAnimationStrategy(_fps, _frames.size()));
        break;
    case AnimationStrategy::OnlyFirtsFrame:
        _strategy.reset(new AnimateOnlyFirtsFrame);
        break;
    case AnimationStrategy::AnimateTillLastFrame:
        _strategy.reset(new AnimateTillTheEnd(_fps, _frames.size()));
        break;
    }
}

void Animation::PushFrame(const SurfaceSharedPtr& frame)
{
    PushFrame(frame, {});
}

void Animation::PushFrame(const SurfaceSharedPtr& frame, const AnimFrameInfo& info)
{
    _frames.push_back(frame);
    _framesInfo.push_back(info);
    _maxWidth = std::max(frame->getWidth(), _maxWidth);
    _maxHeight = std::max(frame->getHeight(), _maxHeight);
}

void Animation::Update(const time_point& timeTick)
{
    _strategy->Update(timeTick);
}

void Animation::SetUpMirroredFrames()
{
    SurfaceCopyEffects eff;
    eff.flipVertically = true;
    for (const auto& f: _frames)
    {
        Surface s = f->Copy(eff);
        SurfaceSharedPtr sptr = std::make_shared<Surface>(Surface());
        sptr->swap(s);
        _mirroredFrames.push_back(sptr);
    }
}

bool Animation::IsFinished() const
{
    assert(_strategy.get() != nullptr);
    return _strategy->IsFinished();
}
