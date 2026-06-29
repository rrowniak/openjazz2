#ifndef ISTORYBOARD_H
#define ISTORYBOARD_H

struct IStoryBoard
{
    virtual ~IStoryBoard();
    virtual void UpdateState(long currentTime) = 0;
    virtual void Render(long currentTime) = 0;

    virtual void Up() = 0;
    virtual void Down() = 0;
    virtual void Left() = 0;
    virtual void Right() = 0;

    virtual void HeroJump();
    virtual void HeroCrunch();
    virtual void HeroLeft();
    virtual void HeroRight();
};

#endif // ISTORYBOARD_H
