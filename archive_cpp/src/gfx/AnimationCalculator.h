#ifndef ANIMATION_CALCULATOR_H
#define ANIMATION_CALCULATOR_H

#include "utils/Time.h"

class FrameCalcHelper
{
public:
    FrameCalcHelper(double fps_)
        : fps(fps_)
        , frame_period(static_cast<int>(1000.0 / fps_))
    { }
    void Restart(const time_point& current)
    {
        time = current;
    }
    bool IsNextFrame(const time_point& current)
    {
        miliseconds diff = current - time;

        if (diff >= frame_period)
        {
            time = current;
            return true;
        }

        return false;
    }
private:
    const double        fps;
    time_point          time;
    const miliseconds   frame_period;
};

struct IAnimationStrategy
{
    virtual ~IAnimationStrategy();
    virtual int GetCurrentFrame() const = 0;
    virtual bool IsFinished() const = 0;
    virtual void Restart(const time_point& current) = 0;
    virtual void Update(const time_point& current) = 0;
    virtual IAnimationStrategy* Clone() const = 0;
};

class NormalAnimationStrategy : public IAnimationStrategy
{
public:
    NormalAnimationStrategy(double fps, int frame_count);
    virtual int GetCurrentFrame() const override;
    virtual bool IsFinished() const override;
    virtual void Restart(const time_point& current) override;
    virtual void Update(const time_point& current) override;
    virtual IAnimationStrategy* Clone() const override;
private:
    FrameCalcHelper timer;
    int             frameCount;
    int             currentFrame = 0;
};

class OscillateAnimationStrategy : public IAnimationStrategy
{
public:
    OscillateAnimationStrategy(double fps, int frame_count);
    virtual int GetCurrentFrame() const override;
    virtual bool IsFinished() const override;
    virtual void Restart(const time_point& current) override;
    virtual void Update(const time_point& current) override;
    virtual IAnimationStrategy* Clone() const override;
private:
    FrameCalcHelper timer;
    const int       frameCount;
    int             currentFrame = 0;
    bool            countDirection = true;
};

class AnimateOnlyFirtsFrame : public IAnimationStrategy
{
public:
    virtual int GetCurrentFrame() const override;
    virtual bool IsFinished() const override;
    virtual void Restart(const time_point& current) override;
    virtual void Update(const time_point& current) override;
    virtual IAnimationStrategy* Clone() const override;
private:
};

class AnimateTillTheEnd : public IAnimationStrategy
{
public:
    AnimateTillTheEnd(double fps, int frame_count);
    virtual int GetCurrentFrame() const override;
    virtual bool IsFinished() const override;
    virtual void Restart(const time_point& current) override;
    virtual void Update(const time_point& current) override;
    virtual IAnimationStrategy* Clone() const override;
private:
    FrameCalcHelper timer;
    const int       frameCount;
    int             currentFrame = 0;
};
/*
class AnimationCalculator
{
public:
    void SetCurrentFrame(int Frame);
    int GetCurrentFrame() const;

    void OnAnimate(long timeTick);

    int     FrameInc = 1;
    int     FrameRate = 100; //Milliseconds
    long    OldTime = 0;
    int     MaxFrame = 0;
    bool    Oscillate = false;
private:
    int     CurrentFrame = 0;
};
*/
#endif // ANIMATION_CALCULATOR_H
