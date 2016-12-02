#include "Layer.h"

#include <type_traits>

Layer::Layer(int w, int h, bool repeat_horiz, bool repeat_vert, bool no_view_beyond_edge,
             bool warp_eff, unsigned tile_no)
    : width(w)
    , height(h)
    , repeatHoriz(repeat_horiz)
    , repeatVert(repeat_vert)
    , noViewBeyondEdge(no_view_beyond_edge)
    , warpEffect(warp_eff)
{
    Rectangle2D world { 0, 0, 0, 0 };
    world.w = width;
    world.h = height;
    // TODO: find out better approximation
    tiles.reset(new tile_tree{world, 2000, 2000});
    tiles_v.reserve(tile_no);
}

void Layer::Add(TilePtr t)
{
    tiles->Insert(t);
    tiles_v.push_back(t);
}

const std::vector<TilePtr>& Layer::GetTiles() const
{
    return tiles_v;
}

void Layer::Render(Surface &screen, const WorldTransformations& tr)
{
    if (width == 0 || height == 0)
    {
        return;
    }
    int layer_x = tr.GetCameraPositionInUniverse(PositionAnchor::LeftTop).x;
    int layer_y = tr.GetCameraPositionInUniverse(PositionAnchor::LeftTop).y;
    std::vector<Point2D> points{
        {layer_x, layer_y},
        {layer_x, layer_y + screen.getHeight()},
        {layer_x + screen.getWidth(), layer_y + screen.getHeight()},
        {layer_x + screen.getWidth(), layer_y}
    };
    typename std::remove_reference<decltype(tiles->GetEntitles(points[0]))>::type* entitles_set[4];
    int i = 0;
    for (const auto& p: points)
    {
        entitles_set[i] = &tiles->GetEntitles(p);
        bool found_duplicate = false;
        for (int k = 0; k < i; ++k)
        {
            if (entitles_set[k] == entitles_set[i])
            {
                found_duplicate = true;
                break;
            }
        }
        if (found_duplicate)
        {
            ++i;
            continue;
        }
        for (auto& t_ptr: *entitles_set[i])
        {
            Tile& t = *t_ptr;
            auto pp = tr.FromUniverseToScreen({t.x, t.y});
            int x1 = pp.x;
            int y1 = pp.y;
            int x2 = x1 + 32;
            int y2 = y1 + 32;

            if (x2 < 0 || y2 < 0)
                continue;

            if (x1 > screen.getWidth() || y1 > screen.getHeight())
                continue;

            int repeatH = 0;
            int repeatV = 0;
            if (repeatHoriz)
            {
                repeatH = screen.getWidth() / width;
            }
            if (repeatVert)
            {
                repeatV = screen.getHeight() / height;
            }

            for (int h = 0; h <= repeatH; ++h)
            {
                for (int v = 0; v <= repeatV; ++v)
                {
                    int X = x1 + h * width;
                    int Y = y1 + v * height;
                    if (X < -32 || Y < -32 || X > screen.getWidth() || Y > screen.getHeight())
                        continue;
                    t.Render(screen, {X, Y, 32, 32});
                }
            }
        }
        ++i;
    }
}
