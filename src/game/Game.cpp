#include "Game.h"

#include "gfx/GraphicsEngine.h"
#include "data/ResourceFactory.h"
#include "CollisionEngine.h"
#include "utils/Utils.h"

#include <assert.h>

struct TerrainFunctor
{
    TerrainFunctor(const Level& l)
        : lev(l)
    { }
    TerrainFunctor(const TerrainFunctor& fn)
        : lev(fn.lev)
    { }
    bool operator()(int x, int y) const
    {
        Tile* t = lev.TileAt(x, y);
        if (t == nullptr)
        {
            return false;
        }
        return t->IsCollidableAt(x - t->x, y - t->y);
    }
private:
    const Level& lev;
};

Game::Game(const std::string& firstLev)
    : camera(GraphicsEngine::getInstance().Width(), GraphicsEngine::getInstance().Height())
{    
    currentLevel = ResourceFactory::GetInstance().LoadLevel(firstLev);
    hero.reset(new Hero(ResourceFactory::GetInstance().BuildHero()));
    hero->SetPosition(currentLevel->GetHeroStartPosition());
    transformer.SetUniverseSize(currentLevel->GetUniverseSize().w, currentLevel->GetUniverseSize().h);
    transformer.SetScreenSize(GraphicsEngine::getInstance().Screen().getWidth(),
                              GraphicsEngine::getInstance().Screen().getHeight());
    transformer.SetCameraPositionInUniverse(currentLevel->GetHeroStartPosition(), PositionAnchor::Centered);
}

void Game::UpdateState(long)
{
    // calculate hero position
    Point2D heroPos{ hero->GetPosition().x, hero->GetPosition().y };
    Vector2D heroVec = hero->GetMovementVector();

    CollisionEngine::NeighborhoodStats stat, stat_tmp;
    for (const auto& p : hero->GetConvexHull())
    {
        // check collisions
        CollisionEngine::AdjustMovementVector(TerrainFunctor(*currentLevel), p, heroVec);
        CollisionEngine::GetStatistics(TerrainFunctor(*currentLevel), p, stat_tmp);
        // update stats
        stat.onTheGround |= stat_tmp.onTheGround;
        stat.inFrontOfLeftWall |= stat_tmp.inFrontOfLeftWall;
        stat.inFrontOfRightWall |= stat_tmp.inFrontOfRightWall;
        stat.touchCeiling |= stat_tmp.touchCeiling;
    }
    hero->SetMovementVector({0, 0}, stat);
    hero->SetPosition({heroPos.x + heroVec.dx, heroPos.y + heroVec.dy});
    // check collisions against events
    for (const auto& p : hero->GetConvexHull())
    {
        auto* ev = currentLevel->EventAt(p.x, p.y);
        if (ev != nullptr)
        {
            auto cmd = ev->CollisionWihtHero(p);

            if (cmd.type == EventCommandType::Spring)
            {
                hero->BigJump();
            }
        }
    }
    // update hero logic
    hero->UpdateState(GameClock::now());
}

void Game::Render(long /*currentTime*/)
{
    // render level + level background background
    currentLevel->Render(GraphicsEngine::getInstance().Screen(), transformer);
    // render hero
    Point2D heroPos{ hero->GetPosition().x, hero->GetPosition().y };
    heroPos = transformer.FromUniverseToScreen(heroPos);
    hero->Render(GraphicsEngine::getInstance().Screen(), {heroPos.x, heroPos.y, 32, 32});
    // TODO: render level foreground
}

void Game::Up()
{
    transformer.MoveCameraPositionInUniverse({0, -60});
}

void Game::Down()
{
    transformer.MoveCameraPositionInUniverse({0, 60});
}

void Game::Left()
{
    transformer.MoveCameraPositionInUniverse({-60, 0});
}

void Game::Right()
{
    transformer.MoveCameraPositionInUniverse({60, 0});
}

void Game::HeroJump()
{
    hero->Jump();
}

void Game::HeroCrunch()
{
    hero->Ground();
}

void Game::HeroLeft()
{
    hero->MoveLeft();
}

void Game::HeroRight()
{
    hero->MoveRight();
}
