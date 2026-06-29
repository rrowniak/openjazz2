#ifndef APP_H
#define APP_H

#include "utils/SdlEventConsumer.h"
#include "utils/GameConsoleWriter.h"
#include "game/IStoryBoard.h"
#include "utils/Utils.h"

#include <SDL2/SDL2_framerate.h>
#include <memory>
#include <vector>

class App : protected SdlEventConsumer
{
public:
    App();
    ~App();
    void Run();
private:
    bool isRunning = true;
    unsigned currentStoryBoardIndx = 0;
    std::vector<std::unique_ptr<IStoryBoard>>   storyBoards;
    FPSCounter              frameCounter;
    FPSmanager              fpsManager;
    // Events
    virtual void OnExit();
    bool upKey = false;
    bool downKey = false;
    bool leftKey = false;
    bool rightKey = false;
    bool heroUp = false;
    bool heroDown = false;
    bool heroLeft = false;
    bool heroRight = false;
    virtual void OnKeyDown(SDL_Keycode sym, Uint16 /*mod*/, Uint16 /*unicode*/);
    virtual void OnKeyUp(SDL_Keycode sym, Uint16 /*mod*/, Uint16 /*unicode*/);
    void HandleInput();
    long oldTime = 0;
    GameConsoleWriter*   logWriter;
    bool                printLoggerOnScreen = true;
};

#endif // APP_H
