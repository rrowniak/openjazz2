#ifndef GAME_H
#define GAME_H

#include "Level.h"
#include "IStoryBoard.h"
#include "game/Camera.h"
#include "game/Hero.h"
#include "game/WorldTransformations.h"

#include <memory>

class Game : public IStoryBoard
{
public:
    Game(const std::string& firstLev);
    virtual ~Game() {}
    void UpdateState(long currentTime);
    void Render(long currentTime);

    virtual void Up() override;
    virtual void Down() override;
    virtual void Left() override;
    virtual void Right() override;
    virtual void HeroJump() override;
    virtual void HeroCrunch() override;
    virtual void HeroLeft() override;
    virtual void HeroRight() override;
private:
    Camera                  camera;    
    LevelPtr                currentLevel;
    std::unique_ptr<Hero>   hero;
    WorldTransformations    transformer;
};

#endif // GAME_H
