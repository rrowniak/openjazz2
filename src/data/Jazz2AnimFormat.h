#ifndef JAZZ2ANIMFORMAT_H
#define JAZZ2ANIMFORMAT_H

#include <string>
#include <vector>
#include <memory>
#include "gfx/Animation.h"
#include "gfx/Color32.h"

// documentation: http://www.jazz2online.com/wiki/J2A+File+Format

struct J2Animation;

class Jazz2AnimFormat
{
public:
    Jazz2AnimFormat(const std::string& filename);
    ~Jazz2AnimFormat(); // in order to use J2Image as incompete type
    Animation GetAnimation(int animset, int index, bool flipped, const Palette& palette) const;
    unsigned int GetAnimationSetLength() const;
    unsigned int GetAnimationLength(int animSet) const;
private:
    std::vector<std::vector<std::unique_ptr<J2Animation>>>   _j2Animations;
};

#endif // JAZZ2ANIMFORMAT_H
