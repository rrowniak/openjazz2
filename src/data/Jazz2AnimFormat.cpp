#include "Jazz2AnimFormat.h"
#include "utils/BinaryReader.h"
#include <fstream>
#include <stdexcept>
#include <vector>
#include <assert.h>
#include <cstdint>

// helper structs

struct ALIB_Header
{
    //char Magic[4] = "ALIB";     // Magic number
    char Magic[4];
    int32_t Unknown1 = 0x00BEBA00; // Little endian, unknown purpose
    int32_t HeaderSize;            // Equals 464 bytes for v1.23 Anims.j2a
    short Version = 0x0200;     // Probably means v2.0
    short Unknown2 = 0x1808;    // Unknown purpose
    int32_t FileSize;              // Equals 8182764 bytes for v1.23 anims.j2a
    int32_t CRC32;                 // Note: CRC buffer starts after the end of header
    int32_t SetCount;              // Number of sets in the Anims.j2a (109 in v1.23)
    std::vector<int32_t> SetAddress;  // Each set's starting address within the file

    std::ifstream& read(std::ifstream& s)
    {
        using BinaryReader::read;
        read(s, Magic);
        read(s, Unknown1);
        read(s, HeaderSize);
        read(s, Version);
        read(s, Unknown2);
        read(s, FileSize);
        read(s, CRC32);
        read(s, SetCount);
        SetAddress.reserve(SetCount);
        for (int i = 0; i < SetCount; ++i)
        {
            int32_t sa;
            read(s, sa);
            SetAddress.push_back(sa);
        }
        return s;
    }
};

struct ANIM_Header
{
    //char Magic[4] = "ANIM";         // Magic number
    char Magic[4];
    unsigned char AnimationCount;   // Number of animations in set
    unsigned char SampleCount;      // Number of sound samples in set
    short FrameCount;               // Total number of frames in set
    int32_t SampleUnknown;             // Unknown, possibly related to sound
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
        read(s, Magic);
        read(s, AnimationCount);
        read(s, SampleCount);
        read(s, FrameCount);
        read(s, SampleUnknown);
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

struct AnimInfo
{
    short FrameCount;   // Number of frames for this particular animation
    short FPS;          // Most likely frames per second
    int32_t Reserved;      // Used internally by Jazz2.exe

    const char* read(const char* s)
    {
        using BinaryReader::read;
        s = read(s, FrameCount);
        s = read(s, FPS);
        s = read(s, Reserved);
        return s;
    }
};

struct FrameInfo
{
    short Width;
    short Height;
    short ColdspotX;    // Relative to hotspot
    short ColdspotY;    // Relative to hotspot
    short HotspotX;
    short HotspotY;
    short GunspotX;     // Relative to hotspot
    short GunspotY;     // Relative to hotspot
    int32_t ImageAddress;  // Address in Data3 where image starts
    int32_t MaskAddress;   // Address in Data3 where mask starts

    const char* read(const char* s)
    {
        using BinaryReader::read;
        s = read(s, Width);
        s = read(s, Height);
        s = read(s, ColdspotX);
        s = read(s, ColdspotY);
        s = read(s, HotspotX);
        s = read(s, HotspotY);
        s = read(s, GunspotX);
        s = read(s, GunspotY);
        s = read(s, ImageAddress);
        s = read(s, MaskAddress);
        return s;
    }
};

struct J2Image
{
    enum { skipped_pixel = 256 };
    unsigned short width;
    unsigned short height;
    std::unique_ptr<int[]> pixels;

    int32_t imageAddress;

    J2Image() : width(0), height(0), imageAddress(0) { }
    J2Image(int width_, int height_)
        : width(width_)
        , height(height_)
        , imageAddress(0)
    { }

    J2Image(J2Image&& img)
        : width(img.width)
        , height(img.height)
        , pixels(std::move(img.pixels))
        , imageAddress(img.imageAddress)
    { }

    const char* read(const char* s)
    {
        using BinaryReader::read;
        pixels.reset(new int[width*height]);

        int pixel_index = 0;
        while (pixel_index < width*height)
        {
            unsigned char code;
            s = read(s, code);
            if (code < 0x80)
            {
                // skip code pixels
                for (int i = 0; i < code && pixel_index < width*height; ++i)
                {
                    pixels[pixel_index++] = skipped_pixel;
                    assert(pixel_index <= width*height);
                }
            }
            else if (code > 0x80)
            {
                unsigned char read_pixels = code & 127;
                for (int i = 0; i < read_pixels && pixel_index < width*height; ++i)
                {
                    unsigned char pixel;
                    s = read(s, pixel);
                    pixels[pixel_index++] = pixel;
                    assert(pixel_index <= width*height);
                }
            }
            else // code == 0x80
            {
                if (pixel_index % width != 0)
                {
                    int skip_n_pixels = width - pixel_index % width;
                    for (int i = 0; i < skip_n_pixels; ++i)
                    {
                        pixels[pixel_index++] = skipped_pixel;
                        assert(pixel_index <= width*height);
                    }
                }
            }
            assert(((code != 0x80) || (pixel_index % width == 0)) && "Image reading error.");
        }
        assert(pixel_index == width*height);
        // for debug purpose
        for (int i = 0; i < width * height; ++i)
        {
            assert(pixels[i] <= 256);
            assert(pixels[i] >= 0);
        }
        return s;
    }

};

struct J2Frame
{
    FrameInfo info;
    J2Image image;

    J2Frame() = default;
    J2Frame(J2Frame&& f)
        : info(f.info)
        , image(std::move(f.image))
    { }
};

struct J2Animation
{
    AnimInfo info;
    std::vector<J2Frame> frames;

    J2Animation() = default;
    J2Animation(J2Animation&& anim)
        : info(anim.info)
        , frames(std::move(anim.frames))
    { }
};

Jazz2AnimFormat::Jazz2AnimFormat(const std::string& filename)
{
    std::ifstream file(filename.c_str(), std::ios_base::in | std::ios_base::binary);
    if (!file.is_open())
    {
        throw std::runtime_error("Animation file " + filename + " not found.");
    }

    ALIB_Header header;
    header.read(file);

    _j2Animations.reserve(header.SetCount);

    for (int set_counter = 0; set_counter < header.SetCount; ++set_counter)
    {
        file.seekg(header.SetAddress[set_counter]);
        ANIM_Header anim_header;
        anim_header.read(file);
        // Data1 (Animation Info)
        auto data1 = BinaryReader::ReadAndDecompress(file, anim_header.CData1, anim_header.UData1);
        // Data2 (Frame Info)
        auto data2 = BinaryReader::ReadAndDecompress(file, anim_header.CData2, anim_header.UData2);
        // Data3 (Image Data)
        auto data3 = BinaryReader::ReadAndDecompress(file, anim_header.CData3, anim_header.UData3);
        // Data4 (Sample Data)
        auto data4 = BinaryReader::ReadAndDecompress(file, anim_header.CData4, anim_header.UData4);

        const char* d1 = &data1[0];
        const char* d2 = &data2[0];
        const char* d3 = &data3[0];

        _j2Animations.push_back({});
        auto& animVec = _j2Animations[set_counter];
        animVec.reserve(anim_header.AnimationCount);

        for (int anim = 0; anim < anim_header.AnimationCount; ++anim)
        {
            J2Animation animation;
            d1 = animation.info.read(d1);

            if (animation.info.FrameCount ==  224)
            {
                // Fonts are loaded separately
                animation.info.FrameCount = 1;
            }                        

            for (int i = 0; i < animation.info.FrameCount; ++i)
            {
                J2Frame frame;
                d2 = frame.info.read(d2);
                assert(frame.info.Width >= 0);
                assert(frame.info.Height >= 0);
                if (frame.info.Width == 0 || frame.info.Height == 0)
                {
                    continue;
                }

                frame.image.width = frame.info.Width;
                frame.image.height = frame.info.Height;
                frame.image.read(d3 + frame.info.ImageAddress);
                animation.frames.push_back(std::move(frame));
            }
            animVec.push_back(std::unique_ptr<J2Animation>{new J2Animation(std::move(animation))});
        }

    }
}

Jazz2AnimFormat::~Jazz2AnimFormat() { }

Animation Jazz2AnimFormat::GetAnimation(int animset, int index, bool flipped, const Palette& palette) const
{
    assert(animset < (int)_j2Animations.size());
    assert(index < (int)_j2Animations[animset].size());
    auto& animation = _j2Animations[animset][index];
    Animation anim(animation->info.FPS);
    for (auto& frame: animation->frames)
    {
        SurfaceSharedPtr s(new Surface(frame.info.Width, frame.info.Height));
        for (int y = 0; y < frame.info.Height; ++y)
        {
            for (int x = 0; x < frame.info.Width; ++x)
            {
                int* p = &frame.image.pixels[0];
                int paletteIndex = p[x + y*frame.info.Width];
                assert(paletteIndex >= 0);
                assert(paletteIndex < 257);
                if (paletteIndex > 255 || paletteIndex < 0)
                {
                    paletteIndex = 0;
                }
                int X = x;
                if (flipped)
                {
                    X = frame.info.Height - x - 1;
                }
                s->PutPixel(X, y, palette.colors[paletteIndex]);
            }
        }
        AnimFrameInfo fi;
        fi.Enabled = true;
        fi.ColdspotX = frame.info.ColdspotX;
        fi.ColdspotY = frame.info.ColdspotY;
        fi.GunspotX = frame.info.GunspotX;
        fi.GunspotY = frame.info.GunspotY;
        fi.HotspotX = frame.info.HotspotX;
        fi.HotspotY = frame.info.HotspotY;
        anim.PushFrame(s, fi);
    }
    anim.SetStrategy(AnimationStrategy::Normal);
    return anim;
}

unsigned int Jazz2AnimFormat::GetAnimationSetLength() const
{
    return _j2Animations.size();
}

unsigned int Jazz2AnimFormat::GetAnimationLength(int animSet) const
{
    return _j2Animations[animSet].size();
}
