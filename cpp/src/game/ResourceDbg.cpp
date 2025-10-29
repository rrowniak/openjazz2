#include "ResourceDbg.h"
#include "gfx/GraphicsEngine.h"
#include "data/ResourceFactory.h"

#include <boost/lexical_cast.hpp>

std::string to_string(int i)
{
    return boost::lexical_cast<std::string>(i);
}

ResourceDbg::ResourceDbg()
{ }

void ResourceDbg::AddTile(SurfaceSharedPtr tile)
{
    tiles.push_back(tile);
}

void ResourceDbg::UpdateState(long /*currentTime*/)
{ }

void ResourceDbg::Render(long /*currentTime*/)
{
    auto& screen = GraphicsEngine::getInstance().Screen();
    DisplayTileSets(screen);
    DisplayAnimations(screen);
    DisplayEvents(screen);
}

void ResourceDbg::Up()
{
    dy += 20;
}

void ResourceDbg::Down()
{
    dy -= 20;
}

void ResourceDbg::Left()
{
    dx += 20;
}

void ResourceDbg::Right()
{
    dx -= 20;
}

void ResourceDbg::DisplayTileSets(Surface& screen)
{
    int x = 0;
    int y = 0;
    for (auto& t: tiles)
    {
        screen.Draw(*t, x + dx, y + dy);
        x += t->getWidth();
        if (x % (t->getWidth() * 10) == 0)
        {
            x = 0;
            y += t->getHeight();
        }
    }
}

void ResourceDbg::DisplayAnimations(Surface& screen)
{
    int set_id = 0;
    int y = 0;
    for (auto& v : animations)
    {
        int max_height = 15;
        int x = 350;
        screen.WriteText(to_string(set_id), x + dx - 20, y + dy, {0, 255, 0});
        int anim_id = 0;
        for (auto& a : v)
        {
            a.Update(GameClock::now());
            auto&s = a.GetCurrentFrame();
            screen.Draw(s, x + dx, y + dy);
            if (anim_id % 10 == 0)
            {
                screen.WriteText(to_string(anim_id),
                             x + dx + s.getWidth() / 2,
                             y + dy + s.getHeight() / 2,
                            {255, 255, 255, 255});
            }
            x += a.GetMaxWidth();
            max_height = std::max(max_height, a.GetMaxHeight());
            ++anim_id;
        }
        y += max_height;
        ++set_id;
    }
}

void ResourceDbg::DisplayEvents(Surface& /*screen*/)
{ }
