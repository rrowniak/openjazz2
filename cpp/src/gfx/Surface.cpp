#include <stdexcept>
#include <algorithm>
#include <assert.h>
#include <SDL2/SDL.h>
#include <SDL2/SDL2_rotozoom.h>
#include <SDL2/SDL2_gfxPrimitives.h>
#include "Surface.h"

struct NativeSurface
{
    SDL_Surface* sdl_struct = nullptr;
    SDL_Renderer* renderer = nullptr;
};

Surface::Surface()
    : surface(new NativeSurface)
{ }

Surface::Surface(int width, int height, bool useAlpha)
    : Surface()
{
    Uint32 rmask, gmask, bmask, amask;

    /* SDL interprets each pixel as a 32-bit number, so our masks must depend
       on the endianness (byte order) of the machine */
#if SDL_BYTEORDER == SDL_BIG_ENDIAN
    rmask = 0xff000000;
    gmask = 0x00ff0000;
    bmask = 0x0000ff00;
    amask = 0x000000ff;
#else
    rmask = 0x000000ff;
    gmask = 0x0000ff00;
    bmask = 0x00ff0000;
    amask = 0xff000000;
#endif

    if (!useAlpha)
    {
        amask = 0;
    }

    surface->sdl_struct = SDL_CreateRGBSurface(0, width, height, 32, rmask, gmask, bmask, amask);
}

Surface::Surface(Surface&& s) noexcept
{
    surface.swap(s.surface);
}

Surface::Surface(const std::string& filename)
    : Surface()
{
    auto s_native = SDL_LoadBMP(filename.c_str());
//    s_native = SDL_DisplayFormat(s_native);
    s_native = SDL_ConvertSurfaceFormat(s_native, SDL_PIXELFORMAT_RGBA4444, 0);
    if (s_native == nullptr)
    {
        throw std::runtime_error("Surface ctor: SDL_DisplayFormat returned null pointer.");
    }
    surface->sdl_struct = s_native;
}

void Surface::swap(Surface& s) noexcept
{
    this->surface.swap(s.surface);
}

Surface::~Surface()
{
    if (surface && (surface->sdl_struct != nullptr))
    {
        SDL_FreeSurface(surface->sdl_struct);
    }
}

Surface Surface::Copy(const SurfaceCopyEffects& effects) const
{
    double hFlipFactor = effects.flipHorizontally ? -1.0 : 1.0;
    double vFlipFactor = effects.flipVertically ? -1.0 : 1.0;
    Surface s;
    s.surface->sdl_struct = rotozoomSurfaceXY(const_cast<SDL_Surface*>(this->surface->sdl_struct),
                                effects.rotationAngle,
                                effects.widthFactor * vFlipFactor,
                                effects.heightFactor * hFlipFactor,
                                SMOOTHING_ON);
    //s.surface->sdl_struct = SDL_DisplayFormatAlpha(const_cast<SDL_Surface*>(this->surface->sdl_struct));
    return s;
}

int Surface::getWidth() const
{
    return surface->sdl_struct->w;
}

int Surface::getHeight() const
{
    return surface->sdl_struct->h;
}

void Surface::MakeTransparent(int r, int g, int b)
{
    assert(surface->sdl_struct != nullptr);
    SDL_SetColorKey(surface->sdl_struct, SDL_TRUE,
                    SDL_MapRGB(surface->sdl_struct->format, r, g, b));
}

void Surface::Draw(const Surface& s, int x, int y)
{
    SDL_Surface* surfSrc = const_cast<SDL_Surface*>(s.surface->sdl_struct);
    assert(surfSrc != nullptr);

    SDL_Rect dest;
    dest.x = x;
    dest.y = y;

    SDL_BlitSurface(surfSrc, NULL, surface->sdl_struct, &dest);
}

void Surface::Draw(const Surface& s, const Point2D& p)
{
    Draw(s, p.x, p.y);
}

void Surface::Draw(const Surface& s, int x, int y, int src_x, int src_y, int src_w, int src_h)
{
    SDL_Surface* surfDest = const_cast<SDL_Surface*>(s.surface->sdl_struct);
    assert(surfDest != nullptr);

    SDL_Rect dest;
    dest.x = x;
    dest.y = y;

    SDL_Rect src;
    src.x = src_x;
    src.y = src_y;
    src.w = src_w;
    src.h = src_h;

    SDL_BlitSurface(surfDest, &src, surface->sdl_struct, &dest);
}

void Surface::PutPixel(int x, int y, const Color32& color)
{
    Uint32* pixels = (Uint32 *)surface->sdl_struct->pixels;
    Uint32 c = SDL_MapRGBA(surface->sdl_struct->format, color.GetR(), color.GetG(), color.GetB(), color.GetA());
    pixels[( y * surface->sdl_struct->w ) + x] = c;
}

void Surface::WriteText(const std::string& message, int x, int y, const Color32& c)
{
    stringRGBA(surface->renderer, x, y, message.c_str(), c.GetR(), c.GetG(), c.GetB(), c.GetA());
}

void* Surface::__getNativeImplementation()
{
    return surface->sdl_struct;
}

void Surface::__setNativeImplementation(void* native, void* rend)
{
    surface->sdl_struct = static_cast<SDL_Surface*>(native);
    surface->renderer = static_cast<SDL_Renderer*>(rend);
}
