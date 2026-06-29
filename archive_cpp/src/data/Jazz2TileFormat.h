#ifndef JAZZ2TILEFORMAT_H
#define JAZZ2TILEFORMAT_H

#include "gfx/Surface.h"
#include "gfx/Color32.h"

#include <string>
#include <vector>
#include <fstream>
#include <memory>
#include <cstdint>

// documentation from http://www.jazz2online.com/wiki/J2T+File+Format
// how to use zlib in J2: http://www.jazz2online.com/wiki/zlib

constexpr int  MAX_TILES_123 = 1024;
// 1024 for  1.23 or 1.10o/Battery Check
constexpr int MAX_TILES_124 = 4096;
// 4096 for  1.24 or A Gigantic Adventure

class J2Tile
{
public:
    J2Tile(int32_t* palette, char* image, char* transparencyMask,
           char* collisionMask, char* flippedCollisionMask, bool flip = false);
    J2Tile(J2Tile&&) = default;
    J2Tile& operator=(J2Tile&&) = default;
    static constexpr int tileSize = 32;
    SurfaceSharedPtr Image; // always 32x32
    static constexpr unsigned int collisionMapSize = 128;
    std::shared_ptr<std::vector<char>> collisionMap;
};

class Jazz2TileFormat
{
public:
    Jazz2TileFormat(const std::string& filename);

    const Palette& getPalette() const { return palette; }
    const std::vector<J2Tile>& GetTileSet() const { return tiles; }
    const std::vector<J2Tile>& GetFlippedTileSet() const { return flippedTiles; }
private:
    void ReadFromFile(const std::string& filename);
    template<typename TileSetStruct, typename GenericTileSetStruct>
    GenericTileSetStruct ReadTileSetStruct(const TileSetStruct& s);  

    Palette palette;

    std::vector<J2Tile> tiles;
    std::vector<J2Tile> flippedTiles;

};

#endif // JAZZ2TILEFORMAT_H
