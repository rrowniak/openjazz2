/**********************************************************************************************
//     Copyright 2013 Rafal Rowniak
//     
//     This software is distributed in the hope that it will be useful,
//     but WITHOUT ANY WARRANTY; without even the implied warranty of
//     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
// 
//     Additional license information:
//     This software can be used and/or modified only for NON-COMMERCIAL purposes.
//
//     Additional information:
//     Math.h created 3/29/2013
//
//     Author: Rafal Rowniak
// 
**********************************************************************************************/

#ifndef MATH_H
#define MATH_H

constexpr double pi = 3.1415;

template <typename T>
struct Point2D_t
{
    T x;
    T y;
};

template<typename T>
bool operator==(const Point2D_t<T>& p1, const Point2D_t<T>& p2)
{
    return p2.x == p1.x && p2.y == p1.y;
}

typedef Point2D_t<double> Point2D_d;
typedef Point2D_t<int32_t> Point2D_i;
typedef Point2D_t<int32_t> Point2D;

template <typename T>
struct Rectangle2D_t
{
    T x;
    T y;
    T w;
    T h;
};

typedef Rectangle2D_t<double> Rectangle2D_d;
typedef Rectangle2D_t<int32_t> Rectangle2D_i;
typedef Rectangle2D_t<int32_t> Rectangle2D;

template <typename T>
struct Vector2D_t
{
    T dx;
    T dy;
    T SquareNorm() const { return dx * dx + dy * dy; }
};

typedef Vector2D_t<int32_t> Vector2D_i;
typedef Vector2D_t<int32_t> Vector2D;

template <typename P, typename R>
bool PointInsideRect(const P& p, const R& r)
{
    if (p.x >= r.x && p.x <= r.x + r.w
            && p.y >= r.y && p.y <= r.y + r.h)
    {
        return true;
    }
    return false;
}

inline int abs_i(int i)
{
    return (i > 0)? i : -i;
}

inline int sign_i(int i)
{
    return (i >= 0)? 1 : -1;
}

// OPERATORS

inline Point2D operator+(const Point2D& p, const Vector2D& v)
{
    return {p.x + v.dx, p.y + v.dy};
}

inline Vector2D operator-(const Point2D& p1, const Point2D& p2)
{
    return {p1.x - p2.x, p1.y - p2.y};
}

inline Point2D& operator+=(Point2D& p, const Vector2D& v)
{
    p.x += v.dx;
    p.y += v.dy;
    return p;
}

inline Point2D& operator-=(Point2D& p, const Vector2D& v)
{
    p.x -= v.dx;
    p.y -= v.dy;
    return p;
}


#endif // MATH_H
