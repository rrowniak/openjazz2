#ifndef COLOR32_H
#define COLOR32_H

class Color32
{
public:
    typedef unsigned int ColorType;

    Color32();
    Color32(int r, int g, int b);
    Color32(int r, int g, int b, int a);

    void SetColorRGBA(ColorType color) { colorRGBA = color; }
    void SetColor(int r, int g, int b) { SetColor(r, g, b, 255); }
    void SetColor(int r, int g, int b, int a)
    {
        colorRGBA = 0;
        colorRGBA |= r << 24;
        colorRGBA |= g << 16;
        colorRGBA |= b << 8;
        colorRGBA |= a;
    }

    int GetR() const { return colorRGBA >> 24; }
    int GetG() const { return (colorRGBA >> 16) & 0xff; }
    int GetB() const { return (colorRGBA >> 8) & 0xff; }
    int GetA() const { return colorRGBA & 0xff; }
    int GetRGBA() const { return colorRGBA; }
private:
    static_assert(sizeof(ColorType) >= 4, "RGBA cannot be stored in variable of size less than 4 bytes");
    ColorType colorRGBA;
};

struct Palette
{
    Palette()
    { }
    union
    {
        unsigned int palette[256];
        Color32 colors[256];
    };
};

#endif // COLOR32_H
