#include "App.h"
#include "utils/MicroLogger.h"
#include "gfx/GraphicsEngine.h"
#include "game/Game.h"
#include "game/ResourceDbg.h"
#include "data/ResourceFactory.h"

#include <stdlib.h>
#include <time.h>
#include <SDL2/SDL2_gfxPrimitives.h>

#include <boost/format.hpp>

App::App()
{
    // Initialize gfx
    GraphicsEngine::getInstance().InitializeGfxMode(1024, 768);
    // initialize rng
    srand(time(NULL));
    // initialize fps routines
    SDL_initFramerate(&fpsManager);
    SDL_setFramerate(&fpsManager, FPS_UPPER_LIMIT);
    // initialize logger
    LOG.AppendWriter(std::unique_ptr<ConsoleWriter>{new ConsoleWriter()});
    logWriter = new GameConsoleWriter(GraphicsEngine::getInstance().Screen());
    LOG.AppendWriter(
        std::unique_ptr<GameConsoleWriter>{logWriter}
    );
    // initialize few default story boards
    storyBoards.reserve(5);
    const std::string firstLev = "Castle1.j2l";
    storyBoards.push_back(std::unique_ptr<IStoryBoard>{new Game(firstLev)});
    storyBoards.push_back(std::unique_ptr<IStoryBoard>{
                              ResourceFactory::GetInstance().LoadDeveloperPreview(firstLev)});
}

App::~App()
{ }

void App::Run()
{
    static const long updateStateDelay = 30;
    LOG.printf("Press F2 to change the view\n");
    SDL_Event Event;
    while (isRunning)
    {
        while (SDL_PollEvent(&Event))
        {
            OnEvent(&Event);
        }        
        long time = SDL_GetTicks();
        if (time - oldTime > updateStateDelay)
        {
            HandleInput();
            storyBoards[currentStoryBoardIndx]->UpdateState(time);
            oldTime = time;
        }
        GraphicsEngine::getInstance().BeginFrame();

        long currentTime = SDL_GetTicks();

        storyBoards[currentStoryBoardIndx]->Render(currentTime);

        frameCounter.Tick(currentTime);
        std::string fps_mess = (boost::format("FPS = %|-5.1f|") % frameCounter.GetFPS()).str();
        GraphicsEngine::getInstance().Screen().WriteText(fps_mess, 300, 30, {255, 255, 255, 160});

        if (printLoggerOnScreen)
        {
            logWriter->Display();
        }

        GraphicsEngine::getInstance().Render();
    }
}

void App::OnExit()
{
    isRunning = false;
}

void App::OnKeyDown(SDL_Keycode sym, Uint16 /*mod*/, Uint16 /*unicode*/)
{
    switch (sym)
    {
    case SDLK_UP:
        upKey = true;
        break;
    case SDLK_DOWN:
        downKey = true;
        break;
    case SDLK_LEFT:
        leftKey = true;
        break;
    case SDLK_RIGHT:
        rightKey = true;
        break;
    case SDLK_F1:
        printLoggerOnScreen = !printLoggerOnScreen;
        break;
    case SDLK_F2:
        ++currentStoryBoardIndx;
        if (currentStoryBoardIndx >= storyBoards.size())
        {
            currentStoryBoardIndx = 0;
        }
        break;
    case SDLK_w:
        heroUp = true;
        break;
    case SDLK_s:
        heroDown = true;
        break;
    case SDLK_a:
        heroLeft = true;
        break;
    case SDLK_d:
        heroRight = true;
        break;
    default:
        break;
    }
}

void App::OnKeyUp(SDL_Keycode sym, Uint16 /*mod*/, Uint16 /*unicode*/)
{
    switch (sym)
    {
    case SDLK_UP:
        upKey = false;
        break;
    case SDLK_DOWN:
        downKey = false;
        break;
    case SDLK_LEFT:
        leftKey = false;
        break;
    case SDLK_RIGHT:
        rightKey = false;
        break;
    case SDLK_w:
        heroUp = false;
        break;
    case SDLK_s:
        heroDown = false;
        break;
    case SDLK_a:
        heroLeft = false;
        break;
    case SDLK_d:
        heroRight = false;
        break;
    default:
        break;
    }
}

void App::HandleInput()
{
    auto& game = storyBoards[currentStoryBoardIndx];
    if (upKey)
    {
        game->Up();
    }
    if (downKey)
    {
        game->Down();
    }
    if (rightKey)
    {
        game->Right();
    }
    if (leftKey)
    {
        game->Left();
    }
    if (heroDown)
    {
        game->HeroCrunch();
    }
    if (heroUp)
    {
        game->HeroJump();
    }
    if (heroLeft)
    {
        game->HeroLeft();
    }
    if (heroRight)
    {
        game->HeroRight();
    }
}

IStoryBoard::~IStoryBoard() { }

void IStoryBoard::HeroJump() {}
void IStoryBoard::HeroCrunch() {}
void IStoryBoard::HeroLeft() {}
void IStoryBoard::HeroRight() {}
