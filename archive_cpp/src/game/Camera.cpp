#include "Camera.h"

Camera::Camera(int screen_width, int screen_height)
    : s_width(screen_width)
    , s_height(screen_height)
{ }

void Camera::SetPosition(const Point2D &position_in_universe)
{
    dx = -position_in_universe.x + s_width / 2;
    dy = -position_in_universe.y + s_height / 2;
}

Point2D Camera::Transform(const Point2D &p_from_universe)
{
    return {p_from_universe.x + dx, p_from_universe.y + dy};
}

Rectangle2D Camera::Transform(const Rectangle2D& r_from_universe)
{
    return {r_from_universe.x + dx, r_from_universe.y + dy, r_from_universe.w, r_from_universe.h};
}
