#ifndef LEVEL_H
#define LEVEL_H

#include "gfx/Surface.h"
#include "game/WorldTransformations.h"
#include "Layer.h"
#include "Event.h"
#include <vector>
#include <memory>
#include <assert.h>

class ObjectLookupMap;
/*
 * Responsibilities:
 * - contains all objects which belong to specified level
 * - implements (if needed) space partition optimalization
 * - loads objects from file (todo)
 */
class Level
{
public:
    Level(unsigned worldWidth, unsigned worldHeight, std::vector<Layer> ls,
          unsigned actionLayer, std::vector<EventPtr> es, const Point2D& heroStartPos);
    ~Level();
    void Render(Surface& screen, const WorldTransformations& tr);
    Point2D GetHeroStartPosition() const;
    Rectangle2D GetUniverseSize() const;
    IEvent* EventAt(int x, int y) const;
    Tile* TileAt(int x, int y) const;
private:   
    std::vector<Layer>      layers;
    std::vector<EventPtr>   events;

    Point2D heroStartPosition;

    std::unique_ptr<ObjectLookupMap>     lookupMap;
    const int world_width = 0;
    const int world_height = 0;
    const int action_layer = 0;

    void RenderLayers(Surface& screen, int from, int to, const WorldTransformations& tr);
};

typedef std::shared_ptr<Level> LevelPtr;

#endif // LEVEL_H
