#include "Jazz2LevelFormat.h"

#include <fstream>
#include <stdexcept>
#include <string>
#include "data/ResourceFactory.h"

enum LevelVersion
{
    v_123 = 514, // 1.23, 1.10o, and Battery Check levels
    v_TSF = 515, // TFS levels
    v_AGA = 256, // A Gigantic Adventure levels
};

struct LevelHeader
{
    char Copyright[180];
    char Magic[4]; // "LEVL"
    char PasswordHash[3]; // 0xBEBA00 for no password
    char HideLevel;
    char LevelName[32];
    short Version;  // see LevelVersion enum
    int32_t FileSize;
    int32_t CRC32;
    int32_t CData1;                    // Compressed size of Data1
    int32_t UData1;                    // Uncompressed size of Data1
    int32_t CData2;                    // Compressed size of Data2
    int32_t UData2;                    // Uncompressed size of Data2
    int32_t CData3;                    // Compressed size of Data3
    int32_t UData3;                    // Uncompressed size of Data3
    int32_t CData4;                    // Compressed size of Data4
    int32_t UData4;                    // Uncompressed size of Data4

    std::ifstream& read(std::ifstream& s)
    {
        using BinaryReader::read;
        read(s, Copyright);
        read(s, Magic);
        read(s, PasswordHash);
        read(s, HideLevel);
        read(s, LevelName);
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

template <int Version>
struct VersionSpecificParms
{
    typedef NULL_type SoundEffectPointerType;
    enum { DONT_READ_SND_EFF = 1 };
    typedef NULL_type UnknownAGAType;
    enum { DONT_READ_UNN_AGA = 1 };
    enum { Animated_Tile_Size = 128 };    
    enum { MAX_TILES = MAX_TILES_123 };
};

template <>
struct VersionSpecificParms<v_TSF>
{
    typedef NULL_type SoundEffectPointerType;
    enum { DONT_READ_SND_EFF = 1 };
    typedef NULL_type UnknownAGAType;
    enum { DONT_READ_UNN_AGA = 1 };
    enum { Animated_Tile_Size = 256 };
    enum { MAX_TILES = MAX_TILES_123 };
};

template <>
struct VersionSpecificParms<v_AGA>
{
    typedef char SoundEffectPointerType;
    enum { DONT_READ_SND_EFF = 0 };
    typedef char UnknownAGAType;
    enum { DONT_READ_UNN_AGA = 0 };
    enum { Animated_Tile_Size = 128 };
    enum { MAX_TILES = MAX_TILES_124 };
};

template <typename VParms>
struct J2L_Data1
{
    static const int MAX_TILES = VParms::MAX_TILES;

    short JCSHorizontalOffset; // In pixels
    short Security1; // 0xBA00 if passworded, 0x0000 otherwise
    short JCSVerticalOffset; // In pixels
    short Security2; // 0xBE00 if passworded, 0x0000 otherwise
    char SecAndLayer; // Upper 4 bits are set if passworded, zero otherwise. Lower 4 bits represent the layer number as last saved in JCS.
    char MinLight; // Multiply by 1.5625 to get value seen in JCS
    char StartLight; // Multiply by 1.5625 to get value seen in JCS
    short AnimCount;
    bool VerticalSplitscreen;
    bool IsLevelMultiplayer;
    int32_t BufferSize;
    char LevelName[32];
    char Tileset[32];
    char BonusLevel[32];
    char NextLevel[32];
    char SecretLevel[32];
    char MusicFile[32];
    char HelpString[16][512];
    typename VParms::SoundEffectPointerType SoundEffectPointer[48][64]; // only in version 256 (AGA)
    int32_t LayerMiscProperties[8]; // Each property is a bit in the following order: Tile Width, Tile Height, Limit Visible Region, Texture Mode, Parallax Stars. This leaves 27 (32-5) unused bits for each layer?
    char Type[8]; // name from Michiel; function unknown
    bool DoesLayerHaveAnyTiles[8]; // must always be set to true for layer 4, or JJ2 will crash
    int32_t LayerWidth[8];
    int32_t LayerRealWidth[8]; // for when "Tile Width" is checked. The lowest common multiple of LayerWidth and 4.
    int32_t LayerHeight[8];
    int32_t LayerZAxis[8] = {-300, -200, -100, 0, 100, 200, 300, 400}; // nothing happens when you change these
    char DetailLevel[8]; // is set to 02 for layer 5 in Battle1 and Battle3, but is 00 the rest of the time, at least for JJ2 levels. No clear effect of altering. Name from Michiel.
    int WaveX[8]; // name from Michiel; function unknown
    int WaveY[8]; // name from Michiel; function unknown
    int32_t LayerXSpeed[8]; // Divide by 65536 to get value seen in JCS
    int32_t LayerYSpeed[8]; // Divide by 65536 to get value seen in JCSvalue
    int32_t LayerAutoXSpeed[8]; // Divide by 65536 to get value seen in JCS
    int32_t LayerAutoYSpeed[8]; // Divide by 65536 to get value seen in JCS
    char LayerTextureMode[8];
    char LayerTextureParams[8][3]; // Red, Green, Blue
    short AnimOffset; // MAX_TILES minus AnimCount, also called StaticTiles
    int32_t TilesetEvents[MAX_TILES]; // same format as in Data2, for tiles
    bool IsEachTileFlipped[MAX_TILES]; // set to 1 if a tile appears flipped anywhere in the level
    char TileTypes[MAX_TILES]; // translucent=1 or caption=4, basically. Doesn't work on animated tiles.
    char XMask[MAX_TILES]; // tested to equal all zeroes in almost 4000 different levels, and editing it has no appreciable effect.  // Name from Michiel, who claims it is totally unused.
    typename VParms::UnknownAGAType UnknownAGA[32768]; // only in version 256 (AGA)
    Animated_Tile Anim[VParms::Animated_Tile_Size]; // or [256] in TSF.
                             // only the first [AnimCount] are needed; JCS will save all 128/256, but JJ2 will run your level either way.
    char Padding[512]; //all zeroes; only in levels saved with JCS

    const char* read(const char* s)
    {
        using BinaryReader::read;
        s = read(s, JCSHorizontalOffset);
        s = read(s, Security1);
        s = read(s, JCSVerticalOffset);
        s = read(s, Security2);
        s = read(s, SecAndLayer);
        s = read(s, MinLight);
        s = read(s, StartLight);
        s = read(s, AnimCount);
        s = read(s, VerticalSplitscreen);
        s = read(s, IsLevelMultiplayer);
        s = read(s, BufferSize);
        s = read(s, LevelName);
        s = read(s, Tileset);
        s = read(s, BonusLevel);
        s = read(s, NextLevel);
        s = read(s, SecretLevel);
        s = read(s, MusicFile);
        s = read(s, HelpString);
        if (VParms::DONT_READ_SND_EFF == 0)
            s = read(s, SoundEffectPointer);
        s = read(s, LayerMiscProperties);
        s = read(s, Type);
        s = read(s, DoesLayerHaveAnyTiles);
        s = read(s, LayerWidth);
        s = read(s, LayerRealWidth);
        s = read(s, LayerHeight);
        s = read(s, LayerZAxis);
        s = read(s, DetailLevel);
        s = read(s, WaveX);
        s = read(s, WaveY);
        s = read(s, LayerXSpeed);
        s = read(s, LayerYSpeed);
        s = read(s, LayerAutoXSpeed);
        s = read(s, LayerAutoYSpeed);
        s = read(s, LayerTextureMode);
        s = read(s, LayerTextureParams);
        s = read(s, AnimOffset);
        s = read(s, TilesetEvents);
        s = read(s, IsEachTileFlipped);
        s = read(s, TileTypes);
        s = read(s, XMask);
        if (VParms::DONT_READ_UNN_AGA == 0)
            s = read(s, UnknownAGA);
        for (unsigned int i = 0; i < sizeof(Anim) / sizeof(Animated_Tile); ++i)
        {
            s = Anim[i].read(s);
        }
        return s;
    }
};

const char* J2Event::read(const char* s)
{
    using BinaryReader::read;
    s = read(s, EventId);
    s = read(s, Params);
    return s;
}

struct J2EventHeader_AGA
{
    int16_t NumberOfDistinctEvents;
    std::vector<std::string> Events;

    const char* read(const char* s)
    {
        using BinaryReader::read;
        s = read(s, NumberOfDistinctEvents);
        Events.reserve(NumberOfDistinctEvents);
        for (int i = 0; i < NumberOfDistinctEvents; ++i)
        {
            char buffer[64];
            s = read(s, buffer);
            Events.push_back({buffer});
        }
        return s;
    }
};

struct AGAString
{
    int32_t StringLength;   //including null byte
    std::string String;     //ends with a null byte

    const char* read(const char* s)
    {
        using BinaryReader::read;
        s = read(s, StringLength);
        String.append(StringLength + 1, '\0');
        for (int32_t i = 0; i < StringLength; ++i)
        {
            char c;
            s = read(s, c);
            String[i] = c;
        }
        return s;
    }
};

struct AGAEvent
{
    int16_t XPos;
    int16_t YPos;
    int16_t EventID;
    int32_t Marker;
    //the rest of the structure is only included if the highest bit of Marker is set.
    int32_t LengthOfParameterSection; //including its own four bytes
    int16_t AreThereStrings; //02 if yes, 00 otherwise?
    int16_t NumberOfLongs;
    std::vector<int32_t> Parameter;
    std::vector<std::string> AGAStrings; //I guess it just keeps looking for strings until it hits the LengthOfParameterSection length?

    const char* read(const char* s, unsigned int bufferSize)
    {
        using BinaryReader::read;
        const char* begin = s;
        s = read(s, XPos);
        s = read(s, YPos);
        s = read(s, EventID);
        s = read(s, Marker);
        s = read(s, LengthOfParameterSection);
        s = read(s, AreThereStrings);
        s = read(s, NumberOfLongs);
        for (int i = 0; i < NumberOfLongs * 2; ++i)
        {
            int32_t param;
            s = read(s, param);
        }
        while (s - begin < static_cast<int32_t>(bufferSize))
        {
            AGAString str;
            s = str.read(s);
            AGAStrings.push_back(str.String);
        }
        return s;
    }
};

void Jazz2LevelFormat::ReadEvents(const char* data2, int width, int height)
{
    for (int y = 0; y < height; ++y)
    {
        for (int x = 0; x < width; ++x)
        {
            J2Event ev;
            ev.x = x;
            ev.y = y;
            data2 = ev.read(data2);
            events.push_back(ev);
        }
    }
}

template<typename Header>
void Jazz2LevelFormat::ReadTiles(const Header& header, const char* data3, const char* data4, bool TSF)
{
    using BinaryReader::read;
    int16_t* quadRefs = (int16_t*) data4;
    for (int count = 0; count < 8; ++count)
    {
        int32_t flags = header.LayerMiscProperties[count];
        int32_t width = header.LayerWidth[count];
        int32_t pitch = header.LayerRealWidth[count];
        int32_t height = header.LayerHeight[count];

        if (pitch & 3)
            pitch += 4;

        J2Layer layer;
        if (header.DoesLayerHaveAnyTiles[count])
        {
            layer.width = width;
            layer.height = height;
            layer.tileX = flags & 1;
            layer.tileY = flags & 2;
            layer.limit = flags & 4;
            layer.warp = flags & 8;

            unsigned char tileQuad[8];            

            for (int y = 0; y < height; ++y)
            {
                for (int x = 0; x < width; ++x)
                {
                    if ((x & 3) == 0)
                    {
                        memcpy(tileQuad, data3 + (quadRefs[x >> 2] << 3), 8);
                    }
                    uint16_t tileId = 0;
                    read((char*)tileQuad + ((x & 3) << 1), tileId);
                    layer.setTile(x, y, tileId, TSF);
                }
                quadRefs += pitch >> 2;
            }
        }
        layers.push_back(layer);
    }

    tileSetName = header.Tileset;    
}

template<typename Header>
void Jazz2LevelFormat::CopyAnimTiles(const Header& h)
{
    animTiles.reserve(h.AnimCount);
    AnimOffset = h.AnimOffset;
    for (int i = 0; i < h.AnimCount; ++i)
    {
        animTiles.push_back(h.Anim[i]);
    }
}

Jazz2LevelFormat::Jazz2LevelFormat(const std::string& filename)
{
    std::ifstream file(filename.c_str(), std::ios_base::in | std::ios_base::binary);
    if (!file.is_open())
    {
        throw std::runtime_error("Level file " + filename + " not found.");
    }

    LevelHeader header;
    header.read(file);

    // Data1 (General Level Data)
    auto data1 = BinaryReader::ReadAndDecompress(file, header.CData1, header.UData1);
    // Data2 (Event Map)
    // Data2 (Event Map, AGA Style)
    auto data2 = BinaryReader::ReadAndDecompress(file, header.CData2, header.UData2);
    // Data3 (Dictionary)
    auto data3 = BinaryReader::ReadAndDecompress(file, header.CData3, header.UData3);
    // Data4
    auto data4 = BinaryReader::ReadAndDecompress(file, header.CData4, header.UData4);

    if (header.Version == LevelVersion::v_123)
    {
        J2L_Data1<VersionSpecificParms<v_123>> data1_123;
        data1_123.read(&data1[0]);
        // read events, amount = (Layer4Width * Layer4Height * 4)
        ReadEvents(&data2[0], data1_123.LayerWidth[3], data1_123.LayerHeight[3]);
        // read tiles
        ReadTiles(data1_123, &data3[0], &data4[0], TSF);
        CopyAnimTiles(data1_123);
    }
    else if (header.Version == LevelVersion::v_TSF)
    {
        TSF = true;
        J2L_Data1<VersionSpecificParms<v_TSF>> data1_tfs;
        data1_tfs.read(&data1[0]);
        // read events, amount = (Layer4Width * Layer4Height * 4)
        ReadEvents(&data2[0], data1_tfs.LayerWidth[3], data1_tfs.LayerHeight[3]);
        // read tiles
        ReadTiles(data1_tfs, &data3[0], &data4[0], TSF);
        CopyAnimTiles(data1_tfs);
    }
    else if (header.Version == LevelVersion::v_AGA)
    {
        J2L_Data1<VersionSpecificParms<v_AGA>> data1_aga;
        data1_aga.read(&data1[0]);
        J2EventHeader_AGA ev_header;
        const char* buff = ev_header.read(&data2[0]);
        AGAEvent ev;
        ev.read(buff, header.UData2 - (buff - &data2[0]));
        // finished?
        // read tiles
        ReadTiles(data1_aga, &data3[0], &data4[0], TSF);
        CopyAnimTiles(data1_aga);
        assert(false);
    }
    else
    {
        throw std::runtime_error("Unsupported level file.");
    }
}

std::string Jazz2LevelFormat::getTilesFile() const
{ return tileSetName; }

std::string Jazz2LevelFormat::getAnimsFile() const
{ return "Anims.j2a"; }

const std::vector<Animated_Tile>& Jazz2LevelFormat::getAnimTiles() const
{ return animTiles; }
