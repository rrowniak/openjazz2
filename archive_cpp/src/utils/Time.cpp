/**********************************************************************************************
//     Copyright 2013 Rafal Rowniak
//     
//     This software is distributed in the hope that it will be useful,
//     but WITHOUT ANY WARRANTY; without even the implied warranty of
//     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
// 
//     Additional license information:
//     This software can be used and/or modified only for NON-COMMERCIAL purposes.
//
//     Additional information:
//     Time.cpp created 3/29/2013
//
//     Author: Rafal Rowniak
// 
**********************************************************************************************/

#include "Time.h"

#include <SDL2/SDL.h>

GameClock::time_point GameClock::now() noexcept
{
    auto sdl_time = SDL_GetTicks();
    return time_point(duration(sdl_time));
}
