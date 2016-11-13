#include "JJ2LevelBuilder.h"

#include "game/WorldTransformations.h"
#include "game/events/UnknownEvent.h"
#include "game/events/StandardEvent.h"
#include "game/events/BonusItem.h"
#include "game/events/SpringEvent.h"
#include "gfx/GraphicsEngine.h"

#include <boost/format.hpp>

std::vector<EventAnim> JJ2LevelBuilder::JJ2EvAnims =
{
    {SilverCoin,        {{67, 84}}},
    {GoldCoin,          {{67, 37}}},
    {IceCrate,          {{67, 55}}},
    {BouncerCrate,      {{67, 54}}},
    {SeekerCrate,       {{67, 56}}},
    {RFCrate,           {{67, 57}}},
    {ToasterCrate,      {{67, 58}}},
    {ArmedTNT,          {{67, 90}}},
    {Board,             {{67, 36}}},
    {FrozenGreenSpring, {{92, 5}},      {{96, 5}}},
    {RapidFire,         {{67, 29}}},
    {FrozenGreenSpring, {{92, 0}},      {{96, 0}}},
    {RedGem,            {{67, 35}}},
    {GreenGem,          {{67, 35}}},
    {BlueGem,           {{67, 35}}},
    {PurpleGem,         {{67, 35}}},
    {LargeRedGem,       {{67, 34}}},
    {AmmoBarrel,        {{67, 3}}},
    {Energy,            {{67, 82}}},
    {FullEnergy,        {{67, 72}}},
    {FireShield,        {{67, 31}}},
    {BubbleShield,      {{67, 10}}},
    {PlasmaShield,      {{67, 51}}},
    {HightJump,         {{67, 33}}},
    {LiveBonus,         {{67, 0}}},
    {ExitSignPost,      {{67, 28}}},
    {CheckPoint,        {{67, 14}}},
    {RedSpring,         {{92, 7}},      {{96, 7}}},
    {GreenSpring,       {{92, 5}},      {{96, 5}}},
    {BlueSpring,        {{92, 0}},      {{96, 0}}},
    {ExtraTime,         {{67, 87}}},
    {Freeze,            {{67, 42}}},
    {TriggerCrate,      {{67, 52}}},
    {NormTurtl,         {{99, 7}}},
    {BlasterPU,         {{67, 60}}},
    {BouncerPU,         {{67, 61}}},
    {IcePU,             {{67, 62}}},
    {SeekerPU,          {{67, 63}}},
    {RFPU,              {{67, 64}}},
    {ToasterPU,         {{67, 65}}},
    {Apple,             {{67, 1}}},
    {Banana,            {{67, 2}}},
    {Cherry,            {{67, 16}}},
    {Orange,            {{67, 71}}},
    {Pear,              {{67, 74}}},
    {Pretzel,           {{67, 79}}},
    {Strawberry,        {{67, 81}}},
    {Lemon,             {{67, 48}}},
    {Lime,              {{67, 50}}},
    {Thing,             {{67, 89}}},
    {Watermelon,        {{67, 92}}},
    {Peach,             {{67, 73}}},
    {Grapes,            {{67, 38}}},
    {Lettuce,           {{67, 49}}},
    {Aubergine,         {{67, 26}}},
    {Cucumber,          {{67, 23}}},
    {Jazzade,           {{67, 75}}},
    {Cola,              {{67, 20}}},
    {Milk,              {{67, 53}}},
    {Tart,              {{67, 76}}},
    {Cake,              {{67, 12}}},
    {Doughnut,          {{67, 25}}},
    {Cupcake,           {{67, 24}}},
    {Crisps,            {{67, 18}}},
    {Sweet,             {{67, 13}}},
    {Chocolate,         {{67, 19}}},
    {IceCream,          {{67, 43}}},
    {Burger,            {{67, 11}}},
    {Pizza,             {{67, 77}}},
    {Chips,             {{67, 32}}},
    {ChickenDrumstick,  {{67, 17}}},
    {Sandwich,          {{67, 80}}},
    {Taco,              {{67, 88}}},
    {HotDog,            {{67, 91}}},
    {Ham,               {{67, 39}}},
    {Cheese,            {{67, 15}}},
    {PelletPU,          {{67, 61}}},
    {SparksPU,          {{67, 75}}}
};

JJ2LevelBuilder::JJ2LevelBuilder(const Jazz2LevelFormat& lev, const Jazz2AnimFormat& anim)
    : level(lev)
    , animations(anim)
{ }

Layer JJ2LevelBuilder::ConvertFromJJ2Layer(const J2Layer& jj2_layer) const
{
    Layer layer{jj2_layer.width * 32, jj2_layer.height * 32,
                jj2_layer.tileX, jj2_layer.tileY, jj2_layer.limit,
                jj2_layer.warp, static_cast<unsigned>(jj2_layer.grid.size())};

    return layer;
}

Tile JJ2LevelBuilder::ConvertFromJJ2Tile(const J2TileId& jj2_tile_id,
                                          const Jazz2TileFormat& tileset) const
{
    Tile rm2tile;

    rm2tile.tc = {jj2_tile_id.x, jj2_tile_id.y};
    int x = rm2tile.tc.ToUnivCoord().x;
    int y = rm2tile.tc.ToUnivCoord().y;
    rm2tile.x = x;
    rm2tile.y = y;

    const J2Tile* tile_res = nullptr;
    auto maxTiles = tileset.GetTileSet().size();
    if (jj2_tile_id.flipped)
    {
        if (jj2_tile_id.id < static_cast<int>(maxTiles))
        {
            tile_res = &tileset.GetFlippedTileSet()[jj2_tile_id.id];
            rm2tile.SetCollisionMap(tile_res->collisionMap);
            rm2tile.AddSurface(tile_res->Image);
        }
        else
        {
            // TODO: Add collision data in case of anim tiles
            rm2tile.AddAnimation(GetAnimatedTile(jj2_tile_id.id, tileset));
        }
    }
    else
    {
        if (jj2_tile_id.id < static_cast<int>(maxTiles))
        {
            tile_res = &tileset.GetTileSet()[jj2_tile_id.id];
            rm2tile.SetCollisionMap(tile_res->collisionMap);
            rm2tile.AddSurface(tile_res->Image);
        }
        else
        {
            // TODO: Add collision data in case of anim tiles
            rm2tile.AddAnimation(GetAnimatedTile(jj2_tile_id.id, tileset));
        }
    }

    return rm2tile;
}

LevelEntities JJ2LevelBuilder::LoadEvents()
{
    LevelEntities en;
    en.events.reserve(level.getEvents().size());
    for (auto& j2ev: level.getEvents())
    {
        if (j2ev.EventId == HeroStartPos)
        {
            TileCoordinates tc{j2ev.x, j2ev.y};
            en.heroStartPosition = tc.ToUnivCoord();
            continue;
        }
        if (j2ev.EventId != NoEvent)
        {
            en.events.push_back(ConvertFromJJ2Event(j2ev));
        }
    }
    return en;
}

EventPtr JJ2LevelBuilder::ConvertFromJJ2Event(const J2Event& jj2_ev) const
{
    IEvent* ev = nullptr;

    if ((jj2_ev.EventId < 33)
        || ((jj2_ev.EventId >= 206) && (jj2_ev.EventId <= 208))
        || (jj2_ev.EventId == 230)
        || (jj2_ev.EventId == 240)
        || (jj2_ev.EventId == 245))
    {
        auto* ev_ = new UnknownEvent;
        ev_->SetDisplayMessage((boost::format("id%1%") % (int)jj2_ev.EventId).str());
        ev = ev_;
    }


    bool isFlipped = false;

    if (jj2_ev.EventId <= 40 && jj2_ev.EventId >= 33)
    {
        // Ammo
        auto* ev_ = new StandardEvent;
        ev_->AddAnimation(animations.GetAnimation(0, ammoAnims[jj2_ev.EventId - 33], isFlipped,
                        SelectPaletteForEvent(jj2_ev.EventId)));
        ev = ev_;
    }
    else if (isBonusEvent(jj2_ev.EventId))
    {
        auto* ev_ = new BonusItem;
        ev_->AddAnimation(GetAnimationFromMap(jj2_ev.EventId,
                                             isFlipped,
                                             SelectPaletteForEvent(jj2_ev.EventId))
                         );
        ev = ev_;
    }
    else if (jj2_ev.EventId == RedSpring || jj2_ev.EventId == GreenSpring || jj2_ev.EventId == BlueSpring)
    {
        auto* ev_ = new SpringEvent(GetAnimationFromMap(jj2_ev.EventId,
                                                        isFlipped,
                                                        SelectPaletteForEvent(jj2_ev.EventId)));
        ev = ev_;
    }
    else if (jj2_ev.EventId == Generator)
    {
        unsigned char b1 = jj2_ev.Params[0];
        unsigned char b2 = jj2_ev.Params[1];
        unsigned char b3 = jj2_ev.Params[2];
        int ev_id =               (b1 & 0xf0) >> 4;
        ev_id |=                  (b2 & 0xf) << 4;
        int delay =               (b2 & 0xf0) >> 4;
        delay |=                  (b3 & 0x1) << 4;
        auto* ev_ = new UnknownEvent;
        ev_->SetDisplayMessage((boost::format("G %1% %2%") % ev_id % delay).str() );
        ev = ev_;
    }
    else
    {
        auto a = GetAnimationFromMap(jj2_ev.EventId, isFlipped);
        if (a.FrameCount() > 0)
        {
            auto* ev_ = new StandardEvent;
            ev_->AddAnimation(GetAnimationFromMap(jj2_ev.EventId, isFlipped));
            ev_->SetDisplayMessage((boost::format("S %1%") % (int)jj2_ev.EventId).str());
            ev = ev_;
        }
        else
        {
            auto* ev_ = new UnknownEvent;
            ev_->SetDisplayMessage((boost::format("U %1%") % (int)jj2_ev.EventId).str());
            ev = ev_;
        }
    }

    TileCoordinates tc{jj2_ev.x, jj2_ev.y};
    ev->SetPosition(tc.ToUnivCoord(), tc);
    ev->SetId(jj2_ev.EventId);

    return EventPtr{ev};
}

bool JJ2LevelBuilder::isBonusEvent(int jje_ev_id) const
{
    switch (jje_ev_id)
    {
    case RedGem:
    case GreenGem:
    case BlueGem:
    case PurpleGem:
    case SilverCoin:
    case GoldCoin:
    case Energy:
    case FullEnergy:
    case Apple:
    case Banana:
    case Cherry:
    case Orange:
    case Pear:
    case Pretzel:
    case Strawberry:
    case Lemon:
    case Lime:
    case Thing:
    case Watermelon:
    case Peach:
    case Grapes:
    case Lettuce:
    case Aubergine:
    case Cucumber:
    case Jazzade:
    case Cola:
    case Milk:
    case Tart:
    case Cake:
    case Doughnut:
    case Cupcake:
    case Crisps:
    case Sweet:
    case Chocolate:
    case IceCream:
    case Burger:
    case Pizza:
    case Chips:
    case ChickenDrumstick:
    case Sandwich:
    case Taco:
    case HotDog:
    case Ham:
    case Cheese:
        return true;
    }

    return false;
}

LevelPalette JJ2LevelBuilder::SelectPaletteForEvent(int eventId) const
{
    switch (eventId)
    {
    case RedGem:
        return LevelPalette::red_gem;
    case GreenGem:
        return LevelPalette::green_gem;
    case BlueGem:
        return LevelPalette::blue_gem;
    case PurpleGem:
        return LevelPalette::purple_gem;
    }
    return LevelPalette::global;
}

Animation JJ2LevelBuilder::GetAnimatedTile(int tileId, const Jazz2TileFormat& tileset) const
{
    //unsigned int tileCount = level.getTiles().tiles.size();
    auto& animationSet = level.getAnimTiles();
    //int animId = tileId % tileCount % animationSet.size();
    int animId = tileId - level.AnimOffset;
    assert(animId < (int)animationSet.size());
    auto& jj2AnimTile = animationSet[animId];

    const auto& tiles = tileset.GetTileSet();

    Animation anim(jj2AnimTile.Speed);

    for (int f = 0; f < jj2AnimTile.FrameCount; ++f)
    {
        if (jj2AnimTile.Frame[f] != 0)
        {
            anim.PushFrame(tiles[jj2AnimTile.Frame[f]].Image);
        }
        else
        {
            anim.PushFrame(SurfaceSharedPtr());
        }
    }

    assert(anim.FrameCount() > 0);
    if (jj2AnimTile.Speed == 0)
    {
        anim.SetStrategy(AnimationStrategy::OnlyFirtsFrame);
    }
    else if (jj2AnimTile.PingPong)
    {
        anim.SetStrategy(AnimationStrategy::Oscillate);
    }
    else
    {
        anim.SetStrategy(AnimationStrategy::Normal);
    }

    return std::move(anim);
}

Animation JJ2LevelBuilder::GetAnimationFromMap(int eventId, bool isFlipped,
                                                LevelPalette pal) const
{
    auto it = std::find_if(JJ2EvAnims.begin(), JJ2EvAnims.end(),
                           [eventId] (const EventAnim& a) {
        if (a.eventId == eventId) return true; return false;
    });

    if (it != JJ2EvAnims.end())
    {
        if (level.isTSF())
        {
            return animations.GetAnimation(it->tfsAnimations[0].first, it->tfsAnimations[0].second,
                    isFlipped, pal);
        }
        else
        {
            return animations.GetAnimation(it->animations[0].first, it->animations[0].second,
                    isFlipped, pal);
        }
    }
    return {};
}
