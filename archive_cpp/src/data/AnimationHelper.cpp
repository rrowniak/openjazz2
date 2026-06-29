#include "AnimationHelper.h"

#include "gfx/GraphicsEngine.h"

AnimationHelper::AnimationHelper(const Jazz2AnimFormat& anim)
    : AnimationHelper(anim, false)
{ }

AnimationHelper::AnimationHelper(const Jazz2AnimFormat &anim, bool loadFlippedAlso)
    : animations(anim)
    , loadFlipped(loadFlippedAlso)
{ }

Animation AnimationHelper::GetAnimation(int animSet, int animId, bool flipped,
                                         LevelPalette pal) const
{
    Palette& palette =  generatePalette(pal)       ;
    auto a = animations.GetAnimation(animSet, animId, flipped, palette);
    if (loadFlipped)
    {
        a.SetUpMirroredFrames();
    }
    return a;
}

Animation AnimationHelper::GetAnimation(int animSet, int animId)
{
    return GetAnimation(animSet, animId, false, LevelPalette::global);
}

Palette& AnimationHelper::generatePalette(LevelPalette pal) const
{
    if (pal == LevelPalette::global)
    {
        return GraphicsEngine::getInstance().GetGlobalPalette();
    }

    static bool cached = false;
    static Palette red_gem_pal;
    static Palette green_gem_pal;
    static Palette blue_gem_pal;
    static Palette purple_gem_pal;

    if (!cached)
    {
        MapPalette(red_gem_pal, 0xff0000);
        MapPalette(green_gem_pal, 0x00ff00);
        MapPalette(blue_gem_pal, 0x0000ff);
        MapPalette(purple_gem_pal, 0xff00ff);
        cached = true;
    }

    if (pal == LevelPalette::red_gem)
    {
        return red_gem_pal;
    }
    else if (pal == LevelPalette::green_gem)
    {
        return green_gem_pal;
    }
    else if (pal == LevelPalette::blue_gem)
    {
        return blue_gem_pal;
    }
    else if (pal == LevelPalette::purple_gem)
    {
        return purple_gem_pal;
    }

    return GraphicsEngine::getInstance().GetGlobalPalette();
}

void AnimationHelper::MapPalette(Palette& palette, int factor) const
{
    int count;

    for (count = 0; count < 112; ++count)
    {
        int color = 55 +  200.0 * count / 128.0;
        int color_r = color & ((factor & 0xff0000) >> 16);
        int color_g = color & ((factor & 0x00ff00) >> 8);
        int color_b = color & ((factor & 0x0000ff));
        palette.colors[count + 128].SetColor(color_r, color_g, color_b);
    }
    for (; count < 128; ++count)
    {
        palette.colors[count + 128].SetColor(255, 255, 255);
    }
}
