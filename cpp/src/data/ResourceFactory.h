#ifndef RESOURCEBUILDER_H
#define RESOURCEBUILDER_H

#include <memory>

#include "game/Layer.h"
#include "game/Level.h"
#include "game/Hero.h"
#include "gfx/Surface.h"
// for debug only
#include "game/ResourceDbg.h"

class ResourceFactoryImpl;

class ResourceFactory
{
public:
    static ResourceFactory& GetInstance();
    const SurfaceSharedPtr LoadSurface(const std::string& resourceName);
    const SurfaceSharedPtr LoadSurface(const std::string& resourceName,
                                       int transparency_r, int transparency_g, int transparency_b);
    LevelPtr LoadLevel(const std::string& levelFilename);
    Hero BuildHero();

    // only for debug purpose
    ResourceDbg* LoadDeveloperPreview(const std::string& filename);
private:
    ResourceFactory(const std::string& pathToResources);
    ~ResourceFactory();    
    std::unique_ptr<ResourceFactoryImpl>    pimpl;
};

#endif // RESOURCEBUILDER_H
