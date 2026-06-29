#ifndef RESOURCEDBG_H
#define RESOURCEDBG_H

#include "IStoryBoard.h"
#include "gfx/Surface.h"
#include "gfx/Animation.h"

#include <memory>
#include <vector>

class ResourceDbg : public IStoryBoard
{
public:
    ResourceDbg();
    void AddTile(SurfaceSharedPtr tile);
    void SetAnimations(std::vector<std::vector<Animation>> v) { animations = std::move(v); }
    virtual ~ResourceDbg() {}
    void UpdateState(long currentTime);
    void Render(long currentTime);

    void Up();
    void Down();
    void Left();
    void Right();
private:
    int dx = 0;
    int dy = 0;

    std::vector<SurfaceSharedPtr> tiles;
    std::vector<std::vector<Animation>> animations;

    void DisplayTileSets(Surface& screen);
    void DisplayAnimations(Surface& screen);
    void DisplayEvents(Surface& screen);
};

typedef std::shared_ptr<ResourceDbg> ResourceDbgPtr;

#endif // RESOURCEDBG_H
