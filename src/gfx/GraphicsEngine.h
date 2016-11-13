#ifndef GRAPHICSENGINE_H
#define GRAPHICSENGINE_H

#include <memory>
#include "gfx/Surface.h"
#include "gfx/Color32.h"
#include <SDL2/SDL.h>

class GraphicsEngine
{
public:
    static GraphicsEngine& getInstance();

    void InitializeGfxMode(int width_, int height_);
    Surface& Screen();
    Palette& GetGlobalPalette();
    void BeginFrame();
    void Render();
    int Width() const { return width; }
    int Height() const { return height; }
private:
    static GraphicsEngine       engine;

    Palette                     globalPalette;
    std::unique_ptr<Surface>    screen;
    SDL_Window*                 sdlWindow = nullptr;
    SDL_Renderer*               sdlRenderer = nullptr;
    int width;
    int height;
public:
    GraphicsEngine();
    ~GraphicsEngine();
};

#endif // GRAPHICSENGINE_H
