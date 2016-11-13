#include "ResourceFactory.h"

#include "data/Jazz2TileFormat.h"
#include "data/Jazz2AnimFormat.h"
#include "data/Jazz2LevelFormat.h"
#include "data/JJ2LevelBuilder.h"
#include "data/JJ2HeroAnimMap.h"
#include "utils/MicroLogger.h"

#include <map>

// ResourceFactoryImpl implementation

class ResourceFactoryImpl
{
public:
    ResourceFactoryImpl(const std::string& pathToResources);
    const SurfaceSharedPtr LoadSurface(const std::string& resourceName);
    const SurfaceSharedPtr LoadSurface(const std::string& resourceName,
                                       int transparency_r, int transparency_g, int transparency_b);
    LevelPtr LoadLevel(const std::string& levelFilename);
    ResourceDbg* LoadDeveloperPreview(const std::string& filename);
    Hero BuildHero();
private:
    const Jazz2TileFormat& LoadTileSet(const std::string& tileName);
    const Jazz2AnimFormat& LoadAnimSet(const std::string& animName);
    const Jazz2LevelFormat& LoadJJ2Level(const std::string& levelName);

    SurfaceSharedPtr LoadSurfaceInternal(const std::string& resourceName);
    std::string     _path;

    typedef std::map<std::string, SurfaceSharedPtr> SurfaceMap;
    SurfaceMap      _surfaces;

    typedef std::map<std::string, std::unique_ptr<Jazz2TileFormat>> Tiles;
    Tiles           _tiles;

    typedef std::map<std::string, std::unique_ptr<Jazz2AnimFormat>> Anims;
    Anims           _anims;

    typedef std::map<std::string, std::unique_ptr<Jazz2LevelFormat>> Levels;
    Levels          _levels;

    template <typename ResourceMap>
    const typename ResourceMap::mapped_type::element_type& LoadResource(ResourceMap& coll, const std::string& id);
};

ResourceFactoryImpl::ResourceFactoryImpl(const std::string &pathToResources)
    : _path(pathToResources)
{ }


const SurfaceSharedPtr ResourceFactoryImpl::LoadSurface(const std::string& resourceName)
{
    return LoadSurfaceInternal(resourceName);
}

const SurfaceSharedPtr ResourceFactoryImpl::LoadSurface(const std::string& resourceName,
                                   int transparency_r, int transparency_g, int transparency_b)
{
    auto s = LoadSurfaceInternal(resourceName);
    s->MakeTransparent(transparency_r, transparency_g, transparency_b);
    return s;
}

LevelPtr ResourceFactoryImpl::LoadLevel(const std::string& levelFilename)
{
    constexpr unsigned int action_layer_id = 3;
    auto& jj2lev = LoadJJ2Level(levelFilename);
    const auto& anim = LoadAnimSet(jj2lev.getAnimsFile());
    const auto& tiles = LoadTileSet(jj2lev.getTilesFile());

    JJ2LevelBuilder converter(jj2lev, anim);

    const auto layer_count = jj2lev.getLayers().size();

    std::vector<Layer> layers;
    layers.reserve(layer_count);

    unsigned world_width = 0;
    unsigned world_height = 0;

    for (unsigned int l = 0; l < layer_count; ++l)
    {
        auto* jj2_layer = &jj2lev.getLayers()[l];
        layers.push_back(converter.ConvertFromJJ2Layer(*jj2_layer));

        if (l == action_layer_id)
        {
            world_width = layers[l].GetWidth();
            world_height = layers[l].GetHeight();
        }

        for (uint32_t i = 0; i < jj2_layer->grid.size(); ++i)
        {
            auto* tileOnMap = &jj2_layer->grid[i];
            if (tileOnMap->id != 0)
            {
                TilePtr t(new Tile{converter.ConvertFromJJ2Tile(*tileOnMap, tiles)});
                layers[l].Add(t);
            }
        }
    }

    auto entities = converter.LoadEvents();

    auto l =  LevelPtr{new Level(world_width, world_height, std::move(layers),
                                action_layer_id, std::move(entities.events),
                                entities.heroStartPosition)};

    return l;
}

ResourceDbg* ResourceFactoryImpl::LoadDeveloperPreview(const std::string& filename)
{
    auto& jj2lev = LoadJJ2Level(filename);
    ResourceDbg* dbg = new ResourceDbg();
    // tiles
    const auto& tiles = LoadTileSet(jj2lev.getTilesFile());
    for (const auto& t : tiles.GetTileSet())
    {
        dbg->AddTile(t.Image);
    }
    // animations
    const auto& anim = LoadAnimSet(jj2lev.getAnimsFile());
    AnimationHelper animHelper(anim);
    std::vector<std::vector<Animation>> animations;
    animations.reserve(anim.GetAnimationSetLength());
    for (unsigned i = 0; i < anim.GetAnimationSetLength(); ++i)
    {
        animations.push_back(std::vector<Animation>());
        animations[i].reserve(anim.GetAnimationLength(i));
        for (unsigned j = 0; j < anim.GetAnimationLength(i); ++j)
        {
            animations[i].push_back(animHelper.GetAnimation(i, j, false,
                                                            LevelPalette::global));
        }
    }
    dbg->SetAnimations(animations);
    return dbg;
}

Hero ResourceFactoryImpl::BuildHero()
{
    const auto& anim = LoadAnimSet("Anims.j2a");
    AnimationHelper animHelper(anim, true);
    /*
     *AnimationState(int uid, Animation a, bool restartAnim = true,
                   SelfInterruptMode intMode = SelfInterruptMode::NoSelfInterruption,
                   std::vector<EventT> evs = std::vector<EventT>(),
                   miliseconds msec = miliseconds())
     */
    Hero h{ContrAnim<HeroEvent>{
            // STATES
            {
                // State Idle
                {HeroAnimFrameId::Idle,
                    {animHelper.GetAnimation(HeroAnimSet::Jazz, HeroAnimFrameId::Idle)}},
                // State RunningNormal
                {HeroAnimFrameId::RunningNormal,
                    {animHelper.GetAnimation(HeroAnimSet::Jazz, HeroAnimFrameId::RunningNormal)}}
            },
            // TRANSITIONS
            {
                // source state                            event                     destination state
                {HeroAnimFrameId::Idle,             HeroEvent::InputRun,           HeroAnimFrameId::RunningNormal},
                {HeroAnimFrameId::RunningNormal,    HeroEvent::NoInput,            HeroAnimFrameId::Idle}
            }
        }
    };
    return h;
}

const Jazz2TileFormat& ResourceFactoryImpl::LoadTileSet(const std::string &tileName)
{
    return LoadResource<Tiles>(_tiles, tileName);
}

const Jazz2AnimFormat& ResourceFactoryImpl::LoadAnimSet(const std::string &tileName)
{
    return LoadResource<Anims>(_anims, tileName);
}

const Jazz2LevelFormat& ResourceFactoryImpl::LoadJJ2Level(const std::string& levelName)
{
    return LoadResource<Levels>(_levels, levelName);
}

SurfaceSharedPtr ResourceFactoryImpl::LoadSurfaceInternal(const std::string &resourceName)
{
    SurfaceMap::iterator it = _surfaces.find(resourceName);
    if (it != _surfaces.end())
    {
        return it->second;
    }
    else
    {
        SurfaceSharedPtr resource(new Surface(_path + resourceName));
        auto ret = _surfaces.insert(SurfaceMap::value_type{resourceName, std::move(resource)});
        return ret.first->second;
    }
}

template <typename ResourceMap>
const typename ResourceMap::mapped_type::element_type&
ResourceFactoryImpl::LoadResource(ResourceMap& coll, const std::string& id)
{
    auto it = coll.find(id);
    if (it != coll.end())
    {
        return *it->second;
    }

    typename ResourceMap::mapped_type resource(new typename ResourceMap::mapped_type::element_type(_path + id));
    auto ret = coll.insert(typename ResourceMap::value_type{id, std::move(resource)});
    return *ret.first->second;
}

// ResourceFactory implementation

ResourceFactory &ResourceFactory::GetInstance()
{
    // TODO: path should be get from config
    static ResourceFactory builder("media/");
    return builder;
}

const SurfaceSharedPtr ResourceFactory::LoadSurface(const std::string &resourceName)
{
    LOG << "Loading surface (with transparency)"  << resourceName << "\n";
    return pimpl->LoadSurface(resourceName);
}

const SurfaceSharedPtr ResourceFactory::LoadSurface(const std::string& resourceName,
                                                    int transparency_r, int transparency_g, int transparency_b)
{
    LOG << "Loading surface "  << resourceName << "\n";
    return pimpl->LoadSurface(resourceName, transparency_r, transparency_g, transparency_b);
}

LevelPtr ResourceFactory::LoadLevel(const std::string& levelFilename)
{
    LOG << "Loading level " << levelFilename << "\n";
    return pimpl->LoadLevel(levelFilename);
}

Hero ResourceFactory::BuildHero()
{
    LOG << "Building a hero \n";
    return pimpl->BuildHero();
}

ResourceDbg* ResourceFactory::LoadDeveloperPreview(const std::string& filename)
{
    return pimpl->LoadDeveloperPreview(filename);
}

ResourceFactory::ResourceFactory(const std::string &pathToResources)
    : pimpl(new ResourceFactoryImpl(pathToResources))
{ }

ResourceFactory::~ResourceFactory()
{ }
