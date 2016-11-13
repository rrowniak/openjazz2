#include <zlib.h>
#include <stdexcept>
#include <vector>
#include <cstring>
#include <assert.h>

#include "Jazz2TileFormat.h"
#include "utils/BinaryReader.h"
#include "gfx/Color32.h"
#include "gfx/GraphicsEngine.h"

J2Tile::J2Tile(int32_t *palette, char *image, char* transparencyMask,
               char* collisionMask, char* flippedCollisionMask, bool flip)
{
    // check if we need to use alpha mode (it is much slower when displayed)
    bool useAlpha = false;
    for (int y = 0; y < tileSize; ++y)
    {
        for (int x = 0; x < tileSize; ++x)
        {
            unsigned int index = y*tileSize + x;
            char tmask = transparencyMask[index/8];
            int bitNo = index % 8;
            bool isTransparent = ((tmask >> bitNo) & 0x01) == 0;
            if (isTransparent)
            {
                useAlpha = true;
                break;
            }
        }
    }

    Image.reset(new Surface(tileSize, tileSize, useAlpha));

    for (int y = 0; y < tileSize; ++y)
    {
        for (int X = 0; X < tileSize; ++X)
        {
            // convert from (A)BGR to RGBA
            // A seems to be always zero
            int x = X;
            if (flip)
            {
                x = tileSize - X - 1;
            }

            unsigned int index = y*tileSize + x;
            Color32 c;
            c.SetColorRGBA(palette[(unsigned char)image[index]]);
            Color32 d;

            char tmask = transparencyMask[index/8];
            int bitNo = index % 8;
            bool isTransparent = ((tmask >> bitNo) & 0x01) == 0;

            if (isTransparent)
            {                
                d.SetColor(c.GetA(), c.GetB(), c.GetG(), 0);
            }
            else
            {
                d.SetColor(c.GetA(), c.GetB(), c.GetG(), 255);
            }
            using BinaryReader::IsBitSetAt;

            if ((!flip && IsBitSetAt(collisionMask, index))
                || (flip && IsBitSetAt(flippedCollisionMask, index)))
            {
                d.SetColor(d.GetR() / 2, d.GetG() / 2, d.GetB() / 2);
            }

            Image->PutPixel(X, y, d);
        }
    }
    // create collision map
    collisionMap.reset(new std::vector<char>(collisionMapSize, 0));
    if (!flip)
    {
        memcpy(&(*collisionMap)[0], collisionMask, collisionMapSize);
    }
    else
    {
        memcpy(&(*collisionMap)[0], flippedCollisionMask, collisionMapSize);
    }
}

// private helper structs

struct TILE_Header
{
    char Copyright[180];
    //char Magic[4] = "TILE";
    char Magic[4] = "TIL";
    int32_t Signature = 0xAFBEADDE;
    char Title[32];
    short Version;  //0x200 for v1.23 and below, 0x201 for v1.24
    uint32_t FileSize;
    int32_t CRC32;
    int32_t CData1;    //compressed size of Data1
    int32_t UData1;    //uncompressed size of Data1
    int32_t CData2;    //compressed size of Data2
    int32_t UData2;    //uncompressed size of Data2
    int32_t CData3;    //compressed size of Data3
    int32_t UData3;    //uncompressed size of Data3
    int32_t CData4;    //compressed size of Data4
    int32_t UData4;    //uncompressed size of Data4

    std::ifstream& read(std::ifstream& s)
    {
        using BinaryReader::read;
        read(s, Copyright);
        read(s, Magic);
        read(s, Signature);
        read(s, Title);
        read(s, Version);
        read(s, FileSize);
        read(s, CRC32);
        read(s, CData1);
        read(s, UData1);
        read(s, CData2);
        read(s, UData2);
        read(s, CData3);
        read(s, UData3);
        read(s, CData4);
        read(s, UData4);
        return s;
    }
};

struct TileSetInfo_123
{
    int32_t PaletteColor[256];        //arranged RGBA
    int32_t TileCount;                 //number of tiles, always a multiple of 10
    char FullyOpaque[MAX_TILES_123];    //1 if no transparency at all, otherwise 0
    char Unknown1[MAX_TILES_123];       //appears to be all zeros
    int32_t ImageAddress[MAX_TILES_123];
    int32_t Unknown2[MAX_TILES_123];       //appears to be all zeros
    int32_t TMaskAddress[MAX_TILES_123];   //Transparency masking, for bitblt
    int32_t Unknown3[MAX_TILES_123];       //appears to be all zeros
    int32_t MaskAddress[MAX_TILES_123];    //Clipping or tile mask
    int32_t FMaskAddress[MAX_TILES_123];   //flipped version of the above
};

struct TileSetInfo_124
{
    int32_t PaletteColor[256];        //arranged RGBA
    int32_t TileCount;                 //number of tiles, always a multiple of 10
    char FullyOpaque[MAX_TILES_124];    //1 if no transparency at all, otherwise 0
    char Unknown1[MAX_TILES_124];       //appears to be all zeros
    int32_t ImageAddress[MAX_TILES_124];
    int32_t Unknown2[MAX_TILES_124];       //appears to be all zeros
    int32_t TMaskAddress[MAX_TILES_124];   //Transparency masking, for bitblt
    int32_t Unknown3[MAX_TILES_124];       //appears to be all zeros
    int32_t MaskAddress[MAX_TILES_124];    //Clipping or tile mask
    int32_t FMaskAddress[MAX_TILES_124];   //flipped version of the above
};

template <typename TileSet>
const char* readTile(const char* s, TileSet& t)
{
    using BinaryReader::read;
    s = read(s, t.PaletteColor);
    s = read(s, t.TileCount);
    s = read(s, t.FullyOpaque);
    s = read(s, t.Unknown1);
    s = read(s, t.ImageAddress);
    s = read(s, t.Unknown2);
    s = read(s, t.TMaskAddress);
    s = read(s, t.Unknown3);
    s = read(s, t.MaskAddress);
    s = read(s, t.FMaskAddress);
    return s;
}

struct TileSetInfo
{
    int32_t PaletteColor[256];        //arranged RGBA
    int32_t TileCount;                 //number of tiles, always a multiple of 10
    std::vector<char> FullyOpaque;    //1 if no transparency at all, otherwise 0
    std::vector<char> Unknown1;       //appears to be all zeros
    std::vector<int32_t> ImageAddress;
    std::vector<int32_t> Unknown2;       //appears to be all zeros
    std::vector<int32_t> TMaskAddress;   //Transparency masking, for bitblt
    std::vector<int32_t> Unknown3;       //appears to be all zeros
    std::vector<int32_t> MaskAddress;    //Clipping or tile mask
    std::vector<int32_t> FMaskAddress;   //flipped version of the above
};

Jazz2TileFormat::Jazz2TileFormat(const std::string &filename)
{
    ReadFromFile(filename);
}

void Jazz2TileFormat::ReadFromFile(const std::string &filename)
{
    using BinaryReader::ReadAndDecompress;
    std::ifstream file(filename.c_str(), std::ios_base::in | std::ios_base::binary);
    if (!file.is_open())
    {
        throw std::runtime_error("Cannot open Jazz2Tile file " + filename);
    }

    static_assert(sizeof(int32_t) == 4, "int32_t == 4 bytes");
    TILE_Header header;
    header.read(file);

    unsigned long size = 0;

    std::unique_ptr<char[]> u_data1(new char[header.UData1]);

    {
        std::unique_ptr<char[]> c_data1(new char[header.CData1]);
        file.read(&c_data1[0], header.CData1);
        size = header.UData1;
        ::uncompress((unsigned char*)&u_data1[0], &size, (const unsigned char*)&c_data1[0], header.CData1);
    }

    TileSetInfo tileSetInfo;
    assert(header.Version == 0x200 || header.Version == 0x201);
    if (header.Version == 0x200)
    {
        using BinaryReader::read;
        TileSetInfo_123 info;
        readTile(&u_data1[0], info);
        tileSetInfo = ReadTileSetStruct<TileSetInfo_123, TileSetInfo>(info);
    }
    else if (header.Version == 0x201)
    {
        using BinaryReader::read;
        TileSetInfo_124 info;
        readTile(&u_data1[0], info);
        tileSetInfo = ReadTileSetStruct<TileSetInfo_124, TileSetInfo>(info);
    }

    auto data2 = ReadAndDecompress(file, header.CData2, header.UData2); // image
    auto data3 = ReadAndDecompress(file, header.CData3, header.UData3); // transparency mask
    auto data4 = ReadAndDecompress(file, header.CData4, header.UData4); // clipping mask

    assert(tiles.empty() == true);
    tiles.reserve(tileSetInfo.TileCount);
    for (int i = 0; i < tileSetInfo.TileCount; ++i)
    {
        tiles.push_back({tileSetInfo.PaletteColor,
                        &data2[0] + tileSetInfo.ImageAddress[i],
                        &data3[0] + tileSetInfo.TMaskAddress[i],
                        &data4[0] + tileSetInfo.MaskAddress[i],
                        &data4[0] + tileSetInfo.FMaskAddress[i]
        });

        flippedTiles.push_back({tileSetInfo.PaletteColor,
                        &data2[0] + tileSetInfo.ImageAddress[i],
                        &data3[0] + tileSetInfo.TMaskAddress[i],
                        &data4[0] + tileSetInfo.MaskAddress[i],
                        &data4[0] + tileSetInfo.FMaskAddress[i],
                        true
        });
    }

    // convert palette
    for (int i = 0; i < 256; ++i)
    {
        unsigned char alpha = 255;
        if (i == 0)
        {
            alpha = 0;
        }
        Color32 c;
        c.SetColorRGBA(tileSetInfo.PaletteColor[i]);
        palette.colors[i].SetColor(c.GetA(), c.GetB(), c.GetG(), alpha);
    }
    memcpy(&GraphicsEngine::getInstance().GetGlobalPalette(),
           &palette, sizeof(palette));
}

template<typename TileSetStruct, typename GenericTileSetStruct>
GenericTileSetStruct Jazz2TileFormat::ReadTileSetStruct(const TileSetStruct& s)
{
    GenericTileSetStruct g;
    memcpy(g.PaletteColor, s.PaletteColor, sizeof(s.PaletteColor));
    g.TileCount = s.TileCount;
    g.FullyOpaque.reserve(s.TileCount);
    g.Unknown1.reserve(s.TileCount);
    g.ImageAddress.reserve(s.TileCount);
    g.Unknown2.reserve(s.TileCount);
    g.TMaskAddress.reserve(s.TileCount);
    g.Unknown3.reserve(s.TileCount);
    g.MaskAddress.reserve(s.TileCount);
    g.FMaskAddress.reserve(s.TileCount);
    for (int32_t i = 0; i < s.TileCount; ++i)
    {
        g.FullyOpaque.push_back(s.FullyOpaque[i]);
        g.Unknown1.push_back(s.Unknown1[i]);
        g.ImageAddress.push_back(s.ImageAddress[i]);
        g.Unknown2.push_back(s.Unknown2[i]);
        g.TMaskAddress.push_back(s.TMaskAddress[i]);
        g.Unknown3.push_back(s.Unknown3[i]);
        g.MaskAddress.push_back(s.MaskAddress[i]);
        g.FMaskAddress.push_back(s.FMaskAddress[i]);
    }

    return std::move(g);
}
