#ifndef SURFACE_H
#define SURFACE_H

#include <string>
#include <memory>
#include "gfx/Color32.h"
#include "utils/Utils.h"

struct SurfaceCopyEffects
{
    bool flipHorizontally = false;
    bool flipVertically = false;
    double rotationAngle = 0;  // in radians
    double widthFactor = 1.0;
    double heightFactor = 1.0;
};

struct NativeSurface;

class Surface
{
public:
    Surface();
    Surface(int width, int height, bool useAlpha = true);
    Surface(Surface&&) noexcept;
    explicit Surface(const std::string& filename);
    void swap(Surface& s) noexcept;
    ~Surface();

    Surface(const Surface&) = delete;

    Surface Copy(const SurfaceCopyEffects& effects) const;

    int getWidth() const;
    int getHeight() const;

    void MakeTransparent(int r, int g, int b);
    // Draw given surface on the current
    void Draw(const Surface& s, int x, int y);
    void Draw(const Surface& s, const Point2D& p);
    void Draw(const Surface& s, int x, int y, int src_x, int src_y, int src_w, int src_h);

    void PutPixel(int x, int y, const Color32& color);
    void WriteText(const std::string& message, int x, int y, const Color32& c);
private:
    friend class GraphicsEngine;
    void* __getNativeImplementation();
    void __setNativeImplementation(void* native, void* rend);
    std::unique_ptr<NativeSurface>    surface;
};

typedef std::shared_ptr<Surface> SurfaceSharedPtr;

#endif // SURFACE_H
