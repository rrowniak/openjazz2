#include "Level.h"

#include "gfx/GraphicsEngine.h"

class ObjectLookupMap
{
public:
    ObjectLookupMap(int map_width_in_tiles, int map_height_in_tiles)
        : mapWidth(map_width_in_tiles)
        , mapHeight(map_height_in_tiles)
    {
        nodes.assign(mapWidth * mapHeight, Node());
    }
    void Add(IEvent* ev, const TileCoordinates& c)
    {
        getNodeAt(c).event = ev;
    }
    void Add(Tile* tl, const TileCoordinates& c)
    {
        getNodeAt(c).tile = tl;
    }
    IEvent* GetEventAt(const TileCoordinates& c) const
    {
        return getNodeAtC(c).event;
    }
    Tile* GetTileAt(const TileCoordinates& c) const
    {
        return getNodeAtC(c).tile;
    }
    bool IsEmpty(const TileCoordinates& c) const
    {
        return getNodeAtC(c).isEmpty();
    }
private:
    struct Node
    {
        Tile*   tile = nullptr;
        IEvent*  event = nullptr;

        bool isEmpty() const { return tile == nullptr && event == nullptr; }
    };
    Node& getNodeAt(const TileCoordinates& c)
    {
        assert(c.x + c.y * mapWidth < (int)nodes.size());
        return nodes[c.x + c.y * mapWidth];
    }
    const Node& getNodeAtC(const TileCoordinates& c) const
    {
        return const_cast<ObjectLookupMap*>(this)->getNodeAt(c);
    }

    const int mapWidth;
    const int mapHeight;

    std::vector<Node> nodes;
};

Level::Level(unsigned worldWidth, unsigned worldHeight, std::vector<Layer> ls,
             unsigned actionLayer, std::vector<EventPtr> es, const Point2D& heroStartPos)
    : layers(std::move(ls))
    , events(std::move(es))
    , heroStartPosition(heroStartPos)
    , world_width(worldWidth)
    , world_height(worldHeight)
    , action_layer(actionLayer)
{
    auto farest_point = FromUnivCoord(world_width, world_height);
    lookupMap.reset(new ObjectLookupMap{farest_point.x, farest_point.y});
    // preprocess tiles
    for (auto& t : layers[action_layer].GetTiles())
    {
        lookupMap->Add(t.get(), t->tc);
    }
    // preprocess event
    for (auto& e: events)
    {
        lookupMap->Add(e.get(), e->GetTileCoord());
    }
}

Level::~Level() { }

void Level::Render(Surface &screen, const WorldTransformations& tr)
{
    //RenderLayers(screen, layers.size() - 1, 3, tr);
    RenderLayers(screen, 3, 3, tr);

    for (auto& ev: events)
    {
        Point2D ev_pos = tr.FromUniverseToScreen({ev->getX(), ev->getY()});
        ev->Render(screen, {ev_pos.x, ev_pos.y, 32, 32});
    }

    //RenderLayers(screen, 2, 0, tr);
}

Point2D Level::GetHeroStartPosition() const
{
    return heroStartPosition;
}

Rectangle2D Level::GetUniverseSize() const
{
    return {0, 0, static_cast<int>(world_width), static_cast<int>(world_height)};
}

IEvent* Level::EventAt(int x, int y) const
{
    if (x < 0 || y < 0 || x >= world_width || y >= world_height)
    {
        return nullptr;
    }
    return lookupMap->GetEventAt(FromUnivCoord(x, y));
}

Tile* Level::TileAt(int x, int y) const
{
    if (x < 0 || y < 0 || x >= world_width || y >= world_height)
    {
        return nullptr;
    }
    return lookupMap->GetTileAt(FromUnivCoord(x, y));
}


void Level::RenderLayers(Surface& screen, int from, int to, const WorldTransformations& tr)
{
    for (int l = from; l >= to; --l)
    {
        auto& layer = layers[l];

        int X = tr.GetCurrentPositionInUniverse().x;
        int Y = tr.GetCurrentPositionInUniverse().y;

        if (world_height != layer.GetHeight() || world_width != layer.GetWidth())
        {
            double scale_x = (double)X / world_width;
            double scale_y = (double)Y / world_height;

            X = ((double)layer.GetWidth() - (double)screen.getWidth()) * scale_x;
            X = (X > 0)? X : 0;
            Y = ((double)layer.GetHeight() - (double)screen.getHeight()) * scale_y;
            Y = (Y > 0)? Y : 0;
        }

        layer.Render(screen, tr);
    }
}
