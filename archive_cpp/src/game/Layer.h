#ifndef LAYER_H
#define LAYER_H

#include "Tile.h"
#include "game/WorldTransformations.h"
#include "utils/BSPTree2D.h"

#include <memory>

typedef std::shared_ptr<Tile> TilePtr;

template<typename T>
struct pos_getter {
    Point2D operator()(const T& t) const {
        return {t->GetPosition().x, t->GetPosition().y};
    }
};

typedef BSPTree2D<TilePtr, pos_getter<TilePtr>> tile_tree;

class Layer
{
public:
    Layer(int w, int h, bool repeat_horiz, bool repeat_vert, bool no_view_beyond_edge,
          bool warp_eff, unsigned tile_no);
    void Add(TilePtr t);
    const std::vector<TilePtr>& GetTiles() const;
    int GetHeight() const { return height; }
    int GetWidth() const { return width; }
    void Render(Surface &screen, const WorldTransformations& tr);
private:
    std::unique_ptr<tile_tree>  tiles;
    std::vector<TilePtr>        tiles_v;
    int width = 0;
    int height = 0;
    bool repeatHoriz = false;
    bool repeatVert = false;
    bool noViewBeyondEdge = false;
    bool warpEffect = false;    
};

#endif // LAYER_H
