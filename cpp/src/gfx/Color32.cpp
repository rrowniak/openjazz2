#include "Color32.h"

Color32::Color32()
    : colorRGBA(0)
{
}

Color32::Color32(int r, int g, int b)
{
    SetColor(r, g, b);
}

Color32::Color32(int r, int g, int b, int a)
{
    SetColor(r, g, b, a);
}
