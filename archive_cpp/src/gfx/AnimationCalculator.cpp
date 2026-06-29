#include "AnimationCalculator.h"

#include <assert.h>

IAnimationStrategy::~IAnimationStrategy() { }

NormalAnimationStrategy::NormalAnimationStrategy(double fps, int frame_count)
    : timer(fps)
    , frameCount(frame_count)
{
    assert(frameCount != 0);
    assert(fps != 0.0);
}

int NormalAnimationStrategy::GetCurrentFrame() const
{
    return currentFrame;
}

bool NormalAnimationStrategy::IsFinished() const
{
    return false;
}

void NormalAnimationStrategy::Restart(const time_point& current)
{
    currentFrame = 0;
    timer.Restart(current);
}

void NormalAnimationStrategy::Update(const time_point& current)
{
    if (timer.IsNextFrame(current))
    {
        ++currentFrame;
        if (currentFrame >= frameCount)
        {
            currentFrame = 0;
        }
    }
}

IAnimationStrategy* NormalAnimationStrategy::Clone() const
{
    return new NormalAnimationStrategy(*this);
}

OscillateAnimationStrategy::OscillateAnimationStrategy(double fps, int frame_count)
    : timer(fps)
    , frameCount(frame_count)
{
    assert(fps != 0.0);
    assert(frameCount != 0);
}

int OscillateAnimationStrategy::GetCurrentFrame() const
{
    return currentFrame;
}

bool OscillateAnimationStrategy::IsFinished() const
{
    return false;
}

void OscillateAnimationStrategy::Restart(const time_point& current)
{
    currentFrame = 0;
    countDirection = true;
    timer.Restart(current);
}

void OscillateAnimationStrategy::Update(const time_point& current)
{
    if (timer.IsNextFrame(current))
    {
        if (countDirection)
        {
            ++currentFrame;
        }
        else
        {
            --currentFrame;
        }

        if (currentFrame >= frameCount)
        {
            auto new_frame = frameCount - 2;
            currentFrame = (new_frame >= 0)? new_frame : 0;
        }
        else if (currentFrame < 0)
        {
            auto new_frame = 1;
            currentFrame = (new_frame >= frameCount)? 0 : new_frame;
        }
    }
}

IAnimationStrategy* OscillateAnimationStrategy::Clone() const
{
    return new OscillateAnimationStrategy(*this);
}

int AnimateOnlyFirtsFrame::GetCurrentFrame() const
{
    return 0;
}

bool AnimateOnlyFirtsFrame::IsFinished() const
{
    return false;
}

void AnimateOnlyFirtsFrame::Restart(const time_point&)
{ }

void AnimateOnlyFirtsFrame::Update(const time_point&)
{ }

IAnimationStrategy* AnimateOnlyFirtsFrame::Clone() const
{
    return new AnimateOnlyFirtsFrame(*this);
}

AnimateTillTheEnd::AnimateTillTheEnd(double fps, int frame_count)
    : timer(fps)
    , frameCount(frame_count)
{
    assert(fps != 0.0);
    assert(frameCount != 0);
}

int AnimateTillTheEnd::GetCurrentFrame() const
{
    return currentFrame;
}

bool AnimateTillTheEnd::IsFinished() const
{
    return currentFrame >= frameCount - 1;
}

void AnimateTillTheEnd::Restart(const time_point& current)
{
    currentFrame = 0;
    timer.Restart(current);
}

void AnimateTillTheEnd::Update(const time_point& current)
{
    if (timer.IsNextFrame(current))
    {
        if (currentFrame < frameCount - 1)
        {
            ++currentFrame;
        }
    }
}

IAnimationStrategy* AnimateTillTheEnd::Clone() const
{
    return new AnimateTillTheEnd(*this);
}
/*
void AnimationCalculator::SetCurrentFrame(int Frame)
{
    if ((Frame < 0) || (Frame >= MaxFrame))
    {
        return;
    }

    CurrentFrame = Frame;
}

int AnimationCalculator::GetCurrentFrame() const
{
    return CurrentFrame;
}

void AnimationCalculator::OnAnimate(long timeTick)
{
    if (OldTime + FrameRate > timeTick)
    {
        return;
    }

    OldTime = timeTick;

    CurrentFrame += FrameInc;

    if (Oscillate)
    {
        if (FrameInc > 0)
        {
            if (CurrentFrame >= MaxFrame)
            {
                FrameInc = -FrameInc;
            }
        }
        else
        {
            if (CurrentFrame <= 0)
            {
                FrameInc = -FrameInc;
            }
        }
    }
    else
    {
        if (CurrentFrame >= MaxFrame) {
            CurrentFrame = 0;
        }
    }
}
*/
