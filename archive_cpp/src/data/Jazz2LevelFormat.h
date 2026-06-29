#ifndef JAZZ2LEVELFORMAT_H
#define JAZZ2LEVELFORMAT_H

#include <string>
#include <vector>
#include <cstdint>
#include <memory>
#include "data/Jazz2TileFormat.h"
#include "data/Jazz2AnimFormat.h"
#include "utils/BinaryReader.h"
#include "gfx/Color32.h"

// doc: http://www.jazz2online.com/wiki/LEV+File+Format
// doc: http://www.jazz2online.com/wiki/J2L_File_Format

struct Animated_Tile
{
    short FrameWait;
    short RandomWait;
    short PingPongWait;
    bool PingPong;
    char Speed;
    char FrameCount;
    short Frame[64]; // this can be a flipped tile or another animated tile

    const char* read(const char* s)
    {
        using BinaryReader::read;
        s = read(s, FrameWait);
        s = read(s, RandomWait);
        s = read(s, PingPongWait);
        s = read(s, PingPong);
        s = read(s, Speed);
        s = read(s, FrameCount);
        s = read(s, Frame);
        return s;
    }
};

struct J2TileId
{
    int id;
    bool flipped;
    int x;
    int y;
    int frame;
};

struct J2Layer
{
    std::vector<J2TileId>    grid; ///< Layer tiles
    int       width = 0; ///< Width (in tiles)
    int       height = 0; ///< Height (in tiles)
    bool      tileX = false; ///< Repeat horizontally
    bool      tileY = false; ///< Repeat vertically
    bool      limit = false; ///< Do not view beyond edges
    bool      warp = false; ///< Warp effect

    void setTile (int x, int y, unsigned short int tile, bool TSF)
    {
        J2TileId ge;
        ge.x = x;
        ge.y = y;

        if (TSF)
        {
            ge.flipped = tile & 0x1000;
            ge.id = tile & 0xFFF;
        }
        else
        {
            ge.flipped = tile & 0x400;
            ge.id = tile & 0x3FF;
        }

        ge.frame = 0;

        grid.push_back(ge);
    }
};

struct J2Event
{
    /*
    Event ID: First 8 bits
    Difficulty: Next 2 bits
    Illuminate: Next 1 bit.
    Is Active: Next 1 bit.
    Parameters: The rest 20 bits
    */
    uint8_t EventId;
    char    Params[3];
    int x;
    int y;

    const char* read(const char* s);
};

class Jazz2LevelFormat
{
public:
    Jazz2LevelFormat(const std::string& filename);

    const std::vector<J2Layer>&  getLayers() const { return layers; }
    const std::vector<J2Event>& getEvents() const { return events; }
    std::string getTilesFile() const;
    std::string getAnimsFile() const;
    const std::vector<Animated_Tile>& getAnimTiles() const;

    short AnimOffset = 0;

    const Palette& getPalette() const { return levelPalette; }

    bool isTSF() const { return TSF; }
private:
    bool TSF = false;
    std::vector<J2Layer> layers;
    std::vector<J2Event> events;
    std::string tileSetName;
    std::vector<Animated_Tile> animTiles;

    Palette levelPalette;

    void ReadEvents(const char* data2, int width, int height);
    template<typename Header>
    void ReadTiles(const Header& header, const char* data3, const char* data4, bool TSF);
    template<typename Header>
    void CopyAnimTiles(const Header& h);
};

#endif // JAZZ2LEVELFORMAT_H
