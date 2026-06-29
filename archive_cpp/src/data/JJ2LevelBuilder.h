#ifndef JJ2LEVCONVERTER_H
#define JJ2LEVCONVERTER_H

#include "game/Level.h"
#include "game/Event.h"
#include "data/AnimationHelper.h"
#include "data/Jazz2LevelFormat.h"

/// Look-up table for ammo animations (in animSet 0)
const unsigned ammoAnims[] = {
    29, // Ice
    25, // Bouncer
    34, // Seeker
    49, // RF
    57, // Toaster
    59, // TNT
    62, // Pellets
    69 // Sparks
};


struct EventAnim
{
    typedef std::vector<std::pair<int, int>> AnimationV;
    EventAnim(int id, const AnimationV& v, const AnimationV& v_tfs = AnimationV())
        : eventId(id), animations(v), tfsAnimations(v_tfs)
    {
        if (tfsAnimations.empty())
        {
            tfsAnimations.reserve(animations.size());
            for (const auto& a: animations)
            {
                if (a.first == 67)
                {
                    tfsAnimations.push_back({71, a.second});
                }
                else
                {
                    tfsAnimations.push_back(a);
                }
            }
        }
    }
    int             eventId = 0;
    std::vector<std::pair<int, int>> animations; // anim_set, anim_id
    std::vector<std::pair<int, int>> tfsAnimations;
};

enum EventId
{
    NoEvent         = 0,
    HeroStartPos    = 29,
    SilverCoin      = 44,
    GoldCoin        = 45,
    IceCrate        = 53,
    BouncerCrate    = 54,
    SeekerCrate     = 55,
    RFCrate         = 56,
    ToasterCrate    = 57,
    ArmedTNT        = 58,
    Board           = 59,
    FrozenGreenSpring = 60,
    RapidFire       = 61,
    SpringCrate     = 62,
    RedGem          = 63,
    GreenGem        = 64,
    BlueGem         = 65,
    PurpleGem       = 66,
    LargeRedGem     = 67,
    AmmoBarrel      = 69,
    Energy          = 72,
    FullEnergy      = 73,
    FireShield      = 74,
    BubbleShield    = 75,
    PlasmaShield    = 76,
    HightJump       = 79,
    LiveBonus       = 80,
    ExitSignPost    = 81,
    CheckPoint      = 83,
    RedSpring       = 85,
    GreenSpring     = 86,
    BlueSpring      = 87,
    ExtraTime       = 89,
    Freeze          = 90,
    TriggerCrate    = 95,
    NormTurtl       = 117, // enemy
    BlasterPU       = 131,
    BouncerPU       = 132,
    IcePU           = 133,
    SeekerPU        = 134,
    RFPU            = 135,
    ToasterPU       = 136,
    Apple           = 141,
    Banana          = 142,
    Cherry          = 143,
    Orange          = 144,
    Pear            = 145,
    Pretzel         = 146,
    Strawberry      = 147,
    Lemon           = 154,
    Lime            = 155,
    Thing           = 156,
    Watermelon      = 157,
    Peach           = 158,
    Grapes          = 159,
    Lettuce         = 160,
    Aubergine       = 161,
    Cucumber        = 162,
    Jazzade         = 163,
    Cola            = 164,
    Milk            = 165,
    Tart            = 166,
    Cake            = 167,
    Doughnut        = 168,
    Cupcake         = 169,
    Crisps          = 170,
    Sweet           = 171,
    Chocolate       = 172,
    IceCream        = 173,
    Burger          = 174,
    Pizza           = 175,
    Chips           = 176,
    ChickenDrumstick= 177,
    Sandwich        = 178,
    Taco            = 179,
    HotDog          = 180,
    Ham             = 181,
    Cheese          = 182,
    Generator       = 216,
    PelletPU        = 220,
    SparksPU        = 221
};

enum Generators
{
    FastFire       = 61,
    ShieldWater    = 75
};

struct LevelEntities
{
    std::vector<EventPtr>   events;
    Point2D                 heroStartPosition;
};

struct JJ2LevelBuilder
{
public:
    JJ2LevelBuilder(const Jazz2LevelFormat& lev, const Jazz2AnimFormat& anim);
    Layer ConvertFromJJ2Layer(const J2Layer& jj2_layer) const;
    Tile ConvertFromJJ2Tile(const J2TileId& jj2_tile_id,
                            const Jazz2TileFormat& tileset) const;            
    LevelEntities LoadEvents();    
private:
    static std::vector<EventAnim>   JJ2EvAnims;
    const Jazz2LevelFormat&         level;
    AnimationHelper                 animations;

    EventPtr ConvertFromJJ2Event(const J2Event& jj2_ev) const;
    bool isBonusEvent(int jje_ev_id) const;
    LevelPalette SelectPaletteForEvent(int eventId) const;
    Animation GetAnimatedTile(int tileId, const Jazz2TileFormat& tileset) const;
    Animation GetAnimationFromMap(int eventId, bool isFlipped,
                                  LevelPalette pal = LevelPalette::global) const;

    struct EventHeader
    {
        int difficulty = 0;
        bool iluminate = false;
        bool is_active = false;

        void read(const char* mem)
        {
            unsigned char b1 = *mem;
            difficulty =  b1 & 0x3;
            iluminate = (b1 & 0x4) >> 3;
            is_active = (b1 & 0x8) >> 4;
        }
    };
};


#endif // JJ2LEVCONVERTER_H
