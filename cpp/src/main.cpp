#include <stdexcept>
#include <iostream>
#include "App.h"

int GameMain(int /*argc*/, char** /*argv[]*/)
{
    try
    {
        App gameApplication;
        gameApplication.Run();
    }
    catch (const std::exception& ex)
    {
        std::cout << "An exception thrown by the game: " << ex.what() <<std::endl;
    }

    return 0;
}
