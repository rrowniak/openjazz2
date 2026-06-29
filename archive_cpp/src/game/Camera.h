#ifndef CAMERA_H
#define CAMERA_H

#include "utils/Utils.h"

class Camera
{
public:
    Camera(int screen_width, int screen_height);

    void SetPosition(const Point2D& position_in_universe);
    Point2D Transform(const Point2D& p_from_universe);
    Rectangle2D Transform(const Rectangle2D& r_from_universe);
private:
    int dx = 0;
    int dy = 0;

    int s_width = 0;
    int s_height = 0;
};

#endif // CAMERA_H
