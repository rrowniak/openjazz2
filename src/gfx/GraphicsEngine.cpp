#include "GraphicsEngine.h"

#include <SDL2/SDL2_gfxPrimitives.h>
#include <SDL2/SDL.h>

GraphicsEngine GraphicsEngine::engine;

GraphicsEngine& GraphicsEngine::getInstance()
{
    return engine;
}

void GraphicsEngine::InitializeGfxMode(int width_, int height_)
{
    width = width_;
    height = height_;
    //auto screen_sdl = SDL_SetVideoMode(width, height, 32, SDL_SWSURFACE | SDL_DOUBLEBUF);
//    auto screen_sdl = SDL_SetVideoMode(width, height, 32, SDL_HWSURFACE | SDL_DOUBLEBUF);
    //auto screen_sdl = SDL_SetVideoMode(width, height, 32, SDL_HWSURFACE | SDL_DOUBLEBUF | SDL_FULLSCREEN);
    
//    SDL_CreateWindow()
        
//    SDL_CreateWindowAndRenderer(width, height, SDL_WINDOW_OPENGL, &sdlWindow, &sdlRenderer);
    sdlWindow = SDL_CreateWindow("OpenJazz2", 0, 0, width, height, SDL_WINDOW_OPENGL);
    
    auto s = new Surface();
    auto winSurf = SDL_GetWindowSurface(sdlWindow);
    if (winSurf == nullptr) {
        std::cout << "Unable to create window surface: " << SDL_GetError() << std::endl;
    }
    
    sdlRenderer = SDL_CreateRenderer(sdlWindow, -1, 0);
    
    s->__setNativeImplementation(winSurf, sdlRenderer);
    screen.reset(s);
}

Surface& GraphicsEngine::Screen()
{
    return *screen;
}

Palette& GraphicsEngine::GetGlobalPalette()
{
    return globalPalette;
}

void GraphicsEngine::BeginFrame()
{
    SDL_FillRect((SDL_Surface*)screen->__getNativeImplementation(), NULL, 0x000000);
}

void GraphicsEngine::Render()
{
//    SDL_Flip((SDL_Surface*)screen->__getNativeImplementation());
    SDL_UpdateWindowSurface(sdlWindow);
}

GraphicsEngine::GraphicsEngine()
{
    SDL_Init(SDL_INIT_EVERYTHING);
}

GraphicsEngine::~GraphicsEngine()
{
    SDL_FreeSurface((SDL_Surface*)screen->__getNativeImplementation());
    screen->__setNativeImplementation(nullptr, nullptr);
    SDL_Quit();
}
