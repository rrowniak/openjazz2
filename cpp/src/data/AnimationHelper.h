#ifndef ANIMATIONHELPER_H
#define ANIMATIONHELPER_H

#include "data/Jazz2AnimFormat.h"
#include "gfx/Animation.h"

enum class LevelPalette
{
    global,
    red_gem,
    green_gem,
    blue_gem,
    purple_gem,
};


class AnimationHelper
{
public:
    AnimationHelper(const Jazz2AnimFormat& anim);
    AnimationHelper(const Jazz2AnimFormat &anim, bool loadFlippedAlso);
    Animation GetAnimation(int animSet, int animId);
    Animation GetAnimation(int animSet, int animId, bool flipped,
                                             LevelPalette pal) const;
private:
    const Jazz2AnimFormat&  animations;
    const bool              loadFlipped;
    Palette& generatePalette(LevelPalette pal) const;
    void MapPalette(Palette& palette, int factor) const;
};

#endif // ANIMATIONHELPER_H
