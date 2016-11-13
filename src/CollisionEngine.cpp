#include "CollisionEngine.h"

#include <iostream>

namespace CollisionEngine {

static constexpr double doubleEpsilonPh() // precision hight
{
    return 0.00001;
}

static constexpr double doubleEpsilonPa() // precision average
{
    return 0.0001;
}

static constexpr double doubleEpsilonPl() // precision low
{
    return 0.001;
}


template<typename T>
T SquareDistance(const Point2D_t<T>& p1, const Point2D_t<T>& p2)
{
    T a = p1.x - p2.x;
    T b = p1.y - p2.y;
    return a * a + b * b;
}
/*
inline double Sign(const Point2D_d&  p1, const Point2D_d&  p2, const Point2D_d&  p3)
{
    return (p1.x - p3.x) * (p2.y - p3.y) - (p2.x - p3.x) * (p1.y - p3.y);
}

inline bool IsPointInTriangle(const Point2D_d& a, const Point2D_d& b, const Point2D_d& c, const Point2D_d& p, double precision = doubleEpsilonPa())
{
    if (a == b || b == c || c == a)
    {
        return false;
    }
    bool b1, b2, b3;

    b1 = Sign(p, a, b) < precision;
    b2 = Sign(p, b, c) < precision;
    b3 = Sign(p, c, a) < precision;

    return (b1 == b2) && (b2 == b3);
}*/

/*inline Vector2D_t<double> CrossProduct(const Vector2D_t<double>& u, const Vector2D_t<double>& v)
{
    return {u.dy * v.dx, u.dx * v.dy};
}

inline double DotProduct(const Vector2D_t<double>& u, const Vector2D_t<double>& v)
{
    return u.dx * v.dx + u.dy * v.dy;
}

inline bool SameSide(const Point2D_d& p1, const Point2D_d& p2, const Point2D_d& a, const Point2D_d& b)
{
    auto v1 = CrossProduct({b.x - a.x, b.y - a.y}, {p1.x - a.x, p1.y - a.y});
    auto v2 = CrossProduct({b.x - a.x, b.y - a.y}, {p2.x - a.x, p2.y - a.y});

    if (DotProduct(v1, v2) >= 0)
    {
        return true;
    }
    return false;
}

inline bool IsPointInTriangle(const Point2D_d& a, const Point2D_d& b, const Point2D_d& c, const Point2D_d& p)
{
    bool b1, b2, b3;

    b1 = SameSide(p, a, b, c);
    b2 = SameSide(p, b, a, c);
    b3 = SameSide(p, c, a, b);

    return (b1 == b2) && (b2 == b3);
}*/

/*
  Returns true if given point belongs to the rectangle.
  Returns false if given point doesn't belong to the rectangle nor to its boundary.
 */
template<typename T>
bool IsPointInRectangle(const Point2D_t<T>& p, const Rectangle2D_t<T>& r)
{
    if ((p.x > r.x) && (p.x < r.x + r.w)
        && (p.y > r.y) && (p.y < r.y + r.h))
    {
        return true;
    }
    return false;
}

template<typename T>
bool IsPointInRectangleBoundary(const Point2D_t<T>& p, const Rectangle2D_t<T>& r)
{
    if ((p.x >= r.x) && (p.x <= r.x + r.w)
        && (p.y >= r.y) && (p.y <= r.y + r.h)
            && !IsPointInRectangle(p, r))
    {
        return true;
    }
    return false;
}

/*
  Returns true if given sections intersect.
  Also an intersection point will be set to res.
 */
template<typename T, typename AreEqual>
bool GetLineIntersection(const Point2D_t<T>& l1p1, const Point2D_t<T>& l1p2,
                         const Point2D_t<T>& l2p1, const Point2D_t<T>& l2p2,
                         Point2D_t<T>& res)
{
    AreEqual areEqual;
    bool uprightL1 = areEqual(l1p1.x, l1p2.x);
    bool uprightL2 = areEqual(l2p1.x, l2p2.x);

    double a1;
    double b1;
    double a2;
    double b2;

    if (uprightL1 && uprightL2)
    {
        // there is no collision!
        return false;
    }
    else if (uprightL1)
    {
        res.x = l1p1.x;
        a2 = (double)(l2p1.y - l2p2.y) / (l2p1.x - l2p2.x);
        b2 = (double)l2p1.y - a2 * l2p1.x;
        res.y = (T)(a2 * res.x + b2);
    }
    else if (uprightL2)
    {
        res.x = l2p1.x;
        a1 = (double)(l1p1.y - l1p2.y) / (l1p1.x - l1p2.x);
        b1 = (double)l1p1.y - a1 * l1p1.x;
        res.y = (T)(a1 * res.x + b1);
    }
    else
    {
        a2 = (double)(l2p1.y - l2p2.y) / (l2p1.x - l2p2.x);
        b2 = (double)l2p1.y - a2 * l2p1.x;

        a1 = (double)(l1p1.y - l1p2.y) / (l1p1.x - l1p2.x);
        b1 = (double)l1p1.y - a1 * l1p1.x;

        if (std::fabs(a1 - a2) < std::numeric_limits<double>::epsilon())
        {
            return false;
        }

        res.x = (T)((b2 - b1) / (a1 - a2));
        res.y = (T)(a1 * (b2 - b1) / (a1 - a2) + b1);
    }
    // check if collision happened

    if ((res.x >= std::min(l1p1.x, l1p2.x)) && (res.x <= std::max(l1p1.x, l1p2.x)) &&
        (res.y >= std::min(l1p1.y, l1p2.y)) && (res.y <= std::max(l1p1.y, l1p2.y)) &&
        (res.x >= std::min(l2p1.x, l2p2.x)) && (res.x <= std::max(l2p1.x, l2p2.x)) &&
        (res.y >= std::min(l2p1.y, l2p2.y)) && (res.y <= std::max(l2p1.y, l2p2.y)))
    {
        return true;
    }
    return false;
}

template<typename T, typename AreEqual>
bool IsCollision(const Point2D_t<T>& l1p1, const Point2D_t<T>& l1p2,
                         const Rectangle2D_t<T>& rect)
{
    Point2D_t<T> res;
    if (GetLineIntersection(l1p1, l1p2, {rect.x, rect.y}, {rect.x + rect.w, rect.y}, res))
    {
        return true; // collision with top boundary of the rect
    }
    if (GetLineIntersection(l1p1, l1p2, {rect.x + rect.w, rect.y}, {rect.x + rect.w, rect.y + rect.h}, res))
    {
        return true; // collision with right boundary of the rect
    }
    if (GetLineIntersection(l1p1, l1p2, {rect.x, rect.y + rect.h}, {rect.x + rect.w, rect.y + rect.h}, res))
    {
        return true; // collision with bottom boundary of the rect
    }
    if (GetLineIntersection(l1p1, l1p2, {rect.x, rect.y}, {rect.x, rect.y + rect.h}, res))
    {
        return true; // collision with left boundary of the rect
    }
    return false;
}

// This class contains "equal" operator which
// returns true if two doubles are equal in
// specified precision
class doubleEqual
{
public:
    bool operator()(double a, double b)
    {
        return fabs(a - b) < std::numeric_limits<double>::epsilon();
    }

    static constexpr double Epsilon()
    {
        return 0.00001;
    }
};

inline bool CheckForCollisionWithRect(const Point2D_d& p, Vector2D_t<double>& v, const Rectangle2D_d& r)
{
    Point2D_d a{r.x, r.y}, b{r.x + r.w, r.y}, c{r.x + r.w, r.y + r.h}, d{r.x, r.y + r.h};
    Point2D_d pp{p.x + v.dx, p.y + v.dy};
    Point2D_d tmp_1, tmp_2, tmp_3, tmp_4;
    Point2D_d* i1 = nullptr;
    Point2D_d* i2 = nullptr;
    Point2D_d* i3 = nullptr;
    Point2D_d* i4 = nullptr;

    if (GetLineIntersection<double, doubleEqual>(p, pp, a, b, tmp_1))
    {
        i1 = &tmp_1;
    }

    if (GetLineIntersection<double, doubleEqual>(p, pp, b, c, tmp_2))
    {
        i2 = &tmp_2;
    }

    if (GetLineIntersection<double, doubleEqual>(p, pp, c, d, tmp_3))
    {
        i3 = &tmp_3;
    }

    if (GetLineIntersection<double, doubleEqual>(p, pp, d, a, tmp_4))
    {
        i4 = &tmp_4;
    }

    if ((i1 == nullptr)
         && (i2 == nullptr)
         && (i3 == nullptr)
         && (i4 == nullptr))
    {
        // no collision
        return false;
    }

    bool pIsInRect = IsPointInRectangle(p, r) || IsPointInRectangleBoundary(p, r);

    if (!pIsInRect)
    {
        Point2D_d* minDistance;
        double distance = std::numeric_limits<double>::max();

        if (i1 != nullptr)
        {
            double d = SquareDistance(p, *i1);
            if (d < distance)
            {
                distance = d;
                minDistance = i1;
            }
        }

        if (i2 != nullptr)
        {
            double d = SquareDistance(p, *i2);
            if (d < distance)
            {
                distance = d;
                minDistance = i2;
            }
        }

        if (i3 != nullptr)
        {
            double d = SquareDistance(p, *i3);
            if (d < distance)
            {
                distance = d;
                minDistance = i3;
            }
        }

        if (i4 != nullptr)
        {
            double d = SquareDistance(p, *i4);
            if (d < distance)
            {
                distance = d;
                minDistance = i4;
            }
        }

        assert(minDistance != nullptr);
        v.dx = minDistance->x - p.x;
        v.dy = minDistance->y - p.y;
    }
    else
    {
        if (i1 != nullptr)
        {
        }
    }
    return true;
}

template <typename T, typename AreEqual>
bool CheckForCollisionPointToRect2(const Point2D_t<T>& p, Vector2D_t<T>& v, const Rectangle2D_t<T>& r)
{
    AreEqual areEqual;
    Point2D_t<T> destPoint{p.x + v.dx, p.y + v.dy};
    Point2D_t<T> collisionPoint{0, 0};

    bool collisionHappened = false;

    const int none = 0;
    const int top = 1;
    //const int right = 2;
    const int down = 3;
    //const int left = 4;

    std::vector<Point2D_t<T>> rect{
        Point2D_t<T>{r.x, r.y + r.h}, Point2D_t<T>{r.x + r.w, r.y + r.h},
        Point2D_t<T>{r.x + r.w, r.y + r.h}, Point2D_t<T>{r.x, r.y}
    };

    int collSide = none;

    if (IsPointInRectangle(destPoint, r))
    {
        // 100% collision

        Point2D_t<T> collisionTestPoint{0, 0};

        T lastDistance = std::numeric_limits<T>::max();
        int noIntersection = 0;

        for (int i = 0; i < 4; ++i)
        {
            if (GetLineIntersection(p, destPoint, rect[i % 4], rect[(i + 1) % 4], collisionTestPoint))
            {
                noIntersection++;
                // check distance
                T d = SquareDistance(p, collisionTestPoint);
                if (d < lastDistance)
                {
                    lastDistance = d;
                    collisionPoint = collisionTestPoint;
                    collSide = i + 1;
                }
            }
        }

        collisionHappened = true;
    }
    else
    {
        // collision might be in case of two different intersection
        Point2D_t<T> collisionTestPoint;
        T firstDistance = std::numeric_limits<T>::max();
        T lastDistance = std::numeric_limits<T>::max();
        T maxDistance = std::numeric_limits<T>::max();
        int noIntersection = 0;

        for (int i = 0; i < 4; ++i)
        {
            if (GetLineIntersection(p, destPoint, rect[i % 4], rect[(i + 1) % 4], collisionTestPoint))
            {
                // check distance
                T d = SquareDistance(p, collisionTestPoint);
                if (std::numeric_limits<T>::max() - firstDistance < 0.0001)
                {
                    firstDistance = d;
                }
                else
                {
                    lastDistance = d;
                }
                if (d < maxDistance)
                {
                    maxDistance = d;
                    collisionPoint = collisionTestPoint;
                    collSide = i + 1;
                }
                noIntersection++;
            }
        }

        if (!areEqual(firstDistance, lastDistance) && (noIntersection == 2))
        {
            collisionHappened = true;
        }
    }

    if (collisionHappened)
    {
        // round velocity vector
        // cut the vector
        if (collSide == top || collSide == down)
        {
            v.dy = collisionPoint.y - p.y;
        }
        else
        {
            v.dx = collisionPoint.x - p.x;
        }
    }

    return collisionHappened;
}

template <typename T, typename AreEqual>
bool CheckForCollisionPointToRect(const Point2D_t<T>& p, Vector2D_t<T>& v, const Rectangle2D_t<T>& r)
{
    // check if a point is in a rectangle

    /*
     *     1              2                  3
     *
     *        (1) ________________  (2)
     *            |               |
     *     8      |               |          4
     *            |               |
     *        (4) |_______________| (3)
     *
     *
     *    7              6                   5
     *
     *   (n) - boundaryPoint
     *    n - area
     *
     * */

    if ((p.x > r.x + r.w) && (p.x < r.x + r.w)
        && (p.y > r.y + r.h) && (p.y < r.y + r.h))
    {
        // point belongs to the rectangle
        return true;
    }

    AreEqual areEqual;
    Point2D_t<T> destPoint{p.x + v.dx, p.y + v.dy};

    int area = 0; // 1, 2, 3, 4, 5, 6, 7, 8
    int boundaryPoint = 0; // 1, 2, 3, 4
    int segmentCollider = 0; // 1, 2, 3, 4
    // check if point belongs to the boundary
    Point2D_t<T> a{r.x, r.y + r.h};
    Point2D_t<T> b{r.x + r.w, r.y + r.h};
    Point2D_t<T> c{r.x + r.w, r.y};
    Point2D_t<T> d{r.x, r.y};
    // check area 1
    if (p.x < a.x && p.y > a.y)
    {
        area = 1;
    }
    else if (p.x >= a.x && p.x <= b.x && p.y >= a.y)
    {
        if (areEqual(p.x, a.x) && areEqual(p.y, a.y))
        {
            boundaryPoint = 1;
        }
        else if (areEqual(p.x, b.x) && areEqual(p.y, b.y))
        {
            boundaryPoint = 2;
        }
        area = 2;
    }
    else if (p.x > b.x && p.y > b.y)
    {
        area = 3;
    }
    else if (p.x >= b.x && p.y <= b.y && p.y >= c.y)
    {
        if (areEqual(p.x, c.x) && areEqual(p.y, c.y))
        {
            boundaryPoint = 3;
        }
        area = 4;
    }
    else if (p.x < c.x && p.y < c.y)
    {
        area = 5;
    }
    else if (p.x >= d.x && p.x <= c.x && p.y <= c.y)
    {
        if (areEqual(p.x, d.x) &&  areEqual(p.y, d.y))
        {
            boundaryPoint = 4;
        }
        area = 6;
    }
    else if (p.y < d.y && p.x < d.x)
    {
        area = 7;
    }
    else
    {
        area = 8;
    }

    // check intersection two lines...
    Point2D_t<T> l1p1 = p;
    Point2D_t<T> l1p2 = destPoint;
    Point2D_t<T> l2p1;
    Point2D_t<T> l2p2;
    Point2D_t<T> l2p11;
    Point2D_t<T> l2p22;
    Point2D_t<T> resPoint;

    bool collisionHappened = false;

    if (boundaryPoint != 0)
    {
        switch (boundaryPoint)
        {
            case 1:
                if (v.dx <= 0 || v.dy >= 0)
                {
                    // assertion
                    if ((p.x + v.dx > r.x) && (p.x + v.dx < r.x + r.w)
                        && (p.y + v.dy > r.y) && (p.y + v.dy < r.y + r.h))
                    {
                        // point belongs to the rectangle
                        assert(false);
                    }
                    return false;
                }
                break;
            case 2:
                if (v.dx >= 0 || v.dy >= 0)
                {
                    // assertion
                    if ((p.x + v.dx > r.x) && (p.x + v.dx < r.x + r.w)
                        && (p.y + v.dy > r.y) && (p.y + v.dy < r.y + r.h))
                    {
                        // point belongs to the rectangle
                        assert(false);
                    }
                    return false;
                }
                break;
            case 3:
                if (v.dx >= 0 || v.dy <= 0)
                {
                    // assertion
                    if ((p.x + v.dx > r.x) && (p.x + v.dx < r.x + r.w)
                        && (p.y + v.dy > r.y) && (p.y + v.dy < r.y + r.h))
                    {
                        // point belongs to the rectangle
                        assert(false);
                    }
                    return false;
                }
                break;
            case 4:
                if (v.dx <= 0 || v.dy <= 0)
                {
                    // assertion
                    if ((p.x + v.dx > r.x) && (p.x + v.dx < r.x + r.w)
                        && (p.y + v.dy > r.y) && (p.y + v.dy < r.y + r.h))
                    {
                        // point belongs to the rectangle
                        assert(false);
                    }
                    return false;
                }
                break;
        }
    }

    if (area == 1)
    {
        // top
        l2p1 = Point2D_t<T>{r.x, r.y + r.h};
        l2p2 = Point2D_t<T>{r.x + r.w, r.y + r.h};

        // left
        l2p11 = Point2D_t<T>{r.x, r.y + r.h};
        l2p22 = Point2D_t<T>{r.x, r.y};

        if (GetLineIntersection<double, AreEqual>(l1p1, l1p2, l2p1, l2p2, resPoint))
        {
            segmentCollider = 1;
            collisionHappened = true;
        }
        else if (GetLineIntersection<double, AreEqual>(l1p1, l1p2, l2p11, l2p22, resPoint))
        {
            segmentCollider = 4;
            collisionHappened = true;
        }
    }
    else if (area == 2)
    {
        if (v.dy >= 0)
        {
            // assertion
            if ((p.x + v.dx > r.x) && (p.x + v.dx < r.x + r.w)
                && (p.y + v.dy > r.y) && (p.y + v.dy < r.y + r.h))
            {
                // point belongs to the rectangle
                assert(false);
            }
            // no collision
            return false;
        }
        // top
        l2p1 = Point2D_t<T>{r.x, p.y + p.h};
        l2p2 = Point2D_t<T>{r.x + r.w, p.y + p.h};

        if (GetLineIntersection(l1p1, l1p2, l2p1, l2p2, resPoint))
        {
            segmentCollider = 1;
            collisionHappened = true;
        }
    }
    else if (area == 3)
    {
        // top
        l2p1 = new Point2D_t<T>{r.x, p.y + p.h};
        l2p2 = new Point2D_t<T>{r.x + r.w, p.y + p.h};

        // right
        l2p11 = new Point2D_t<T>{r.x + r.w, p.y + p.h};
        l2p22 = new Point2D_t<T>{r.x + r.w, r.y};

        if (GetLineIntersection(l1p1, l1p2, l2p1, l2p2, resPoint))
        {
            collisionHappened = true;
            segmentCollider = 1;
        }
        else if (GetLineIntersection(l1p1, l1p2, l2p11, l2p22, resPoint))
        {
            segmentCollider = 2;
            collisionHappened = true;
        }
    }
    else if (area == 4)
    {
        if (v.dx >= 0)
        {
            // assertion
            if ((p.x + v.dx > r.x) && (p.x + v.dx < r.x + r.w)
                && (p.y + v.dy > r.y) && (p.y + v.dy < p.y + p.h))
            {
                // point belongs to the rectangle
                assert(false);
            }
            // no collision
            return false;
        }
        // right
        l2p1 = Point2D_t<T>{r.x + r.w, p.y + p.h};
        l2p2 = Point2D_t<T>{r.x + r.w, r.y};

        if (GetLineIntersection(l1p1, l1p2, l2p1, l2p2, resPoint))
        {
            segmentCollider = 2;
            collisionHappened = true;
        }
    }
    else if (area == 5)
    {
        // right
        l2p1 = Point2D_t<T>{r.x + r.w, p.y + p.h};
        l2p2 = Point2D_t<T>{r.x + r.w, r.y};
        // down
        l2p11 = Point2D_t<T>{r.x, r.y};
        l2p22 = Point2D_t<T>{r.x + r.w, r.y};

        if (GetLineIntersection(l1p1, l1p2, l2p1, l2p2, resPoint))
        {
            segmentCollider = 2;
            collisionHappened = true;
        }
        else if (GetLineIntersection(l1p1, l1p2, l2p11, l2p22, resPoint))
        {
            segmentCollider = 3;
            collisionHappened = true;
        }
    }
    else if (area == 6)
    {
        if (v.dy <= 0)
        {
            // assertion
            if ((p.x + v.dx > r.x) && (p.x + v.dx < r.x + r.w)
                && (p.y + v.dy > r.y) && (p.y + v.dy < p.y + p.h))
            {
                // point belongs to the rectangle
                assert(false);
            }
            // no collision
            return false;
        }
        // down
        l2p1 = Point2D_t<T>{r.x, r.y};
        l2p2 = Point2D_t<T>{r.x + r.w, r.y};
        if (GetLineIntersection(l1p1, l1p2, l2p1, l2p2, resPoint))
        {
            segmentCollider = 3;
            collisionHappened = true;
        }
    }
    else if (area == 7)
    {
        // down
        l2p1 = Point2D_t<T>{r.x, r.y};
        l2p2 = Point2D_t<T>{r.x + r.w, r.y};
        // left
        l2p11 = Point2D_t<T>{r.x, p.y + p.h};
        l2p22 = Point2D_t<T>{r.x, r.y};
        if (GetLineIntersection(l1p1, l1p2, l2p1, l2p2, resPoint))
        {
            segmentCollider = 4;
            collisionHappened = true;
        }
        else if (GetLineIntersection(l1p1, l1p2, l2p11, l2p22, resPoint))
        {
            segmentCollider = 4;
            collisionHappened = true;
        }
    }
    else if (area == 8)
    {
        if (v.dx <= 0)
        {
            // assertion
            if ((p.x + v.dx > r.x) && (p.x + v.dx < r.x + r.w)
                && (p.y + v.dy > r.y) && (p.y + v.dy < p.y + p.h))
            {
                // point belongs to the rectangle
                assert(false);
            }
            // no collision
            return false;
        }
        // left
        l2p1 = Point2D_t<T>{r.x, p.y + p.h};
        l2p2 = Point2D_t<T>{r.x, r.y};
        if (GetLineIntersection(l1p1, l1p2, l2p1, l2p2, resPoint))
        {
            segmentCollider = 4;
            collisionHappened = true;
        }
    }

    if (collisionHappened)
    {
        // cut the vector
        if (segmentCollider == 1 || segmentCollider == 3)
        {
            v.dy = resPoint.y - p.y;
        }
        else
        {
            v.dx = resPoint.x - p.x;
        }
    }

    // assertion
    if ((p.x + v.dx > r.x) && (p.x + v.dx < r.x + r.w)
        && (p.y + v.dy > r.y) && (p.y + v.dy < p.y + p.h))
    {
        // point belongs to the rectangle
        assert(false);
    }

    return collisionHappened; // no collision
}

template <typename T, typename AreEqual>
bool CheckForCollision(const Rectangle2D_t<T>& p1, const Vector2D_t<T>& v, const Rectangle2D_t<T>& p2)
{
    // check if any point is within the rectangle
    Point2D_t<T> rp1{p1.X1, p1.Y1};
    Point2D_t<T> rp2{p1.X1, p1.Y2};
    Point2D_t<T> rp3{p1.X2, p1.Y1};
    Point2D_t<T> rp4{p1.X2, p1.Y2};

    bool collision = false;

    if (CheckForCollisionPointToRect2<T, AreEqual>(rp1, v, p2))
    {
        collision = true;
    }
    if (CheckForCollisionPointToRect2<T, AreEqual>(rp2, v, p2))
    {
        collision = true;
    }
    if (CheckForCollisionPointToRect2<T, AreEqual>(rp3, v, p2))
    {
        collision = true;
    }
    if (CheckForCollisionPointToRect2<T, AreEqual>(rp4, v, p2))
    {
        collision = true;
    }

    return collision;
}      

    inline double LineTest(const Point2D_d& p1, const Point2D_d& p2, const Point2D_d& test)
    {
        return (p2.y - p1.y) * (test.x - p1.x) + (p1.x - p2.x) * (test.y - p1.y);
    }

    // Returns true if given point p is within a triangle a,b,c. Even if the point lays on
    // triangle's boundary function returns true.
    inline bool IsPointInTriangle(const Point2D_d& a, const Point2D_d& b, const Point2D_d& c, const Point2D_d& p)
    {
        if (p == a || p == b || p == c)
        {
            return true;
        }

        if (a == b || b == c || c == a)
        {
            return false;
        }
        auto lt1 = LineTest(a, b, p);
        auto lt2 = LineTest(b, c, p);
        auto lt3 = LineTest(c, a, p);

        bool b1, b2, b3;

        b1 = lt1 < 0;
        b2 = lt2 < 0;
        b3 = lt3 < 0;

        if (lt1 == 0.0)
        {
            return b2 == b3;
        }
        else if (lt2 == 0.0)
        {
            return b1 == b3;
        }
        else if (lt3 == 0.0)
        {
            return b1 == b2;
        }

        return (b1 == b2) && (b2 == b3);
    }


    // Gets a line intersection which is written in a point res. If no intersection found
    // the function returns false. An intersection is found if and only if a resulting point
    // lays between l1p1 and l1p2.
    inline bool GetLineIntersection(const Point2D_d& l1p1, const Point2D_d& l1p2,
                             const Point2D_d& l2p1, const Point2D_d& l2p2,
                             Point2D_d& res, double epsilon = 0)
    {
        doubleEqual areEqual;
        bool uprightL1 = areEqual(l1p1.x, l1p2.x);
        bool uprightL2 = areEqual(l2p1.x, l2p2.x);

        double a1;
        double b1;
        double a2;
        double b2;

        if (uprightL1 && uprightL2)
        {
            // there is no collision!
            return false;
        }
        else if (uprightL1)
        {
            res.x = l1p1.x;
            a2 = (double)(l2p1.y - l2p2.y) / (l2p1.x - l2p2.x);
            b2 = (double)l2p1.y - a2 * l2p1.x;
            res.y = a2 * res.x + b2;
        }
        else if (uprightL2)
        {
            res.x = l2p1.x;
            a1 = (double)(l1p1.y - l1p2.y) / (l1p1.x - l1p2.x);
            b1 = (double)l1p1.y - a1 * l1p1.x;
            res.y = a1 * res.x + b1;
        }
        else
        {
            a2 = (double)(l2p1.y - l2p2.y) / (l2p1.x - l2p2.x);
            b2 = (double)l2p1.y - a2 * l2p1.x;

            a1 = (double)(l1p1.y - l1p2.y) / (l1p1.x - l1p2.x);
            b1 = (double)l1p1.y - a1 * l1p1.x;

            if (areEqual(a1, a2))
            {
                return false;
            }

            res.x = (b2 - b1) / (a1 - a2);
            res.y = a1 * (b2 - b1) / (a1 - a2) + b1;
        }
        // check if collision happened

        if ((res.x >= std::min(l1p1.x, l1p2.x) - epsilon) && (res.x <= std::max(l1p1.x, l1p2.x) + epsilon) &&
            (res.y >= std::min(l1p1.y, l1p2.y) - epsilon) && (res.y <= std::max(l1p1.y, l1p2.y) + epsilon) &&
            (res.x >= std::min(l2p1.x, l2p2.x) - epsilon) && (res.x <= std::max(l2p1.x, l2p2.x) + epsilon) &&
            (res.y >= std::min(l2p1.y, l2p2.y) - epsilon) && (res.y <= std::max(l2p1.y, l2p2.y) + epsilon))
        {
            return true;
        }
        return false;
    }

    class Line
    {
    public:
        Line(const Point2D_d& a, const Point2D_d& b)
        {
            if (a.x == b.x)
            {
                // vertical line
                A = 1.0;
                B = 0.0;
                C = -a.x;
            }
            else if (a.y == b.y)
            {
                // horizontal line
                A = 0.0;
                B = 1.0;
                C = -a.y;
            }
            else
            {
                // regular line
                A = -(b.y - a.y) / (b.x - a.x);
                B = 1.0;
                C = -A * a.x - a.y;
            }
        }
        bool isHorizontal() const
        {
            return A == 0.0;
        }
        bool isVertical() const
        {
            return B == 0.0;
        }
        double GetTgAlfa() const
        {
            return -A/B;
        }
        double X(double y) const
        {
            return (-C - y*B) / A;
        }
        double Y(double x) const
        {
            return (-C -x*A) / B;
        }
    private:
        // we represent a line using following equation:
        // Ax + By + C = 0
        double A;
        double B;
        double C;
    };

    // Checks for collision with given line (points a, b) and cut respectively a velocity vector v.
    // planeDir vector is used for indicating where is a plane whithing any movement is not allowed.
    inline bool CheckForCollisionWithSemiPlane(const Point2D_d& a, const Point2D_d& b, const Vector2D_t<double>& planeDir,
                                               const Point2D_d& position, Vector2D_t<double>& v)
    {
        // is a given point in collision plane?
        auto test1 = LineTest(a, b, position);
        auto test2 = LineTest(a, b, {position.x + v.dx, position.y + v.dy});
        auto test3 = LineTest(a, b, {a.x + planeDir.dx, a.y + planeDir.dy});

        assert(test3 != 0.0 && "Invalid direction vector!");
        bool collision = false;
        if ((test3 < 0) && (test1 < 0 || test2 < 0))
        {
            collision = true;
        }
        if ((test3 > 0) && (test1 > 0 || test2 > 0))
        {
            collision = true;
        }
        if (collision)
        {
            // check for collision with semiline
            Point2D_d l2p1{position.x, position.y};
            Point2D_d l2p2{position.x + v.dx, position.y + v.dy};
            Point2D_d res;
            if (GetLineIntersection(a, b, l2p1, l2p2, res, 0.01))
            {
                Line l(a, b);
                if ((test1 == 0.0) && !l.isVertical() && (fabs(l.GetTgAlfa()) < tan(pi/2)))
                {
                    // allow to run over the edge
                    double new_x = position.x + v.dx;
                    double new_y = l.Y(new_x);
                    v.dx = new_x - position.x;
                    v.dy = new_y - position.y;
                }
                else
                {
                    v.dx = res.x - position.x;
                    v.dy = res.y - position.y;
                }
                return true;
            }
        }
        return false;
    }

    // This function checks whether point is in shifted rectangle (it is a rectangle which is moved by vector p and we
    // consider original rectangle, rectrangle after movements and trace.
    inline bool IsPointInShiftedRectangle(const Rectangle2D_d& r, const Vector2D_t<double>& v,  const Point2D_d& p)
    {
        Point2D_d a, b, c, d, e, f;

        if (v.dx > 0)
        {
            if (v.dy > 0)
            {
                a = {r.x,       r.y + r.h};
                b = {r.x,       r.y};
                c = {r.x + r.w, r.y};
                e = {r.x + r.w, r.y + r.h};
            }
            else
            {
                a = {r.x + r.w, r.y + r.h};
                b = {r.x,       r.y + r.h};
                c = {r.x + r.w, r.y};
                e = {r.x + r.w, r.y};
            }
        }
        else
        {
            if (v.dy > 0)
            {
                a = {r.x,       r.y};
                b = {r.x + r.w, r.y};
                c = {r.x + r.w, r.y + r.h};
                e = {r.x,       r.y + r.h};
            }
            else
            {
                a = {r.x + r.w, r.y};
                b = {r.x + r.w, r.y + r.h};
                c = {r.x,       r.y + r.h};
                e = {r.x,       r.y};
            }
        }
        d = {c.x + v.dx, c.y + v.dy};
        e = {e.x + v.dx, e.y + v.dy};
        f = {a.x + v.dx, a.y + v.dy};

        if (IsPointInTriangle(a, b, c, p))
        {
            return true;
        }
        if (IsPointInTriangle(a, c, f, p))
        {
            return true;
        }
        if (IsPointInTriangle(c, d, f, p))
        {
            return true;
        }
        if (IsPointInTriangle(d, e, f, p))
        {
            return true;
        }
        return false;
    }
/*
private void PrecalculateCollision(IMovableObject current, rm_List<IMovableObject>.iterator movBegin,
            rm_List<IMovableObject>.iterator movEnd,
            rm_List<IStaticObject>.iterator statBegin, rm_List<IStaticObject>.iterator statEnd)
        {
            // compare spheres...
            _tmpMovCollPrecalc.Clear();
            _tmpStatCollPrecalc.Clear();

            rm_Circle c1 = new rm_Circle();
            rm_Circle c2 = new rm_Circle();

            current.GetConvexHullCircle(ref c1);
            // for each movable object
            for (; movBegin != movEnd; ++movBegin)
            {
                // check for collisions
                movBegin.GetObj().GetConvexHullCircle(ref c2);

                int dist2 = (c1.Radius + c2.Radius) * (c1.Radius + c2.Radius);
                if (dist2 < rm_Math.SquareDistance(c1.X, c1.Y, c2.X, c2.Y))
                {
                    _tmpMovCollPrecalc.Add(movBegin.GetObj());
                }
            }
            // for each static object
            while (!statBegin.Outside())
            {
                // check for collisions
                statBegin.GetObj().GetConvexHullCircle(ref c2);

                int dist2 = (c1.Radius + c2.Radius) * (c1.Radius + c2.Radius);
                if (dist2 >= rm_Math.SquareDistance(c1.X, c1.Y, c2.X, c2.Y))
                {
                    _tmpStatCollPrecalc.Add(statBegin.GetObj());
                }
                ++statBegin;
            }
        }
*/

    class Test
    {
    public:
        Test()
        {
            // test case 1
            TestSquareDistance();
            // test case 2
            TestPointBelongsToRect();
            // test case 3
            TestGetLineIntersection();
            // test case 4
            TestIsPointInRect();
            // test case 5
            TestSemiPlaneCollision();
        }
    private:
        void TestSquareDistance()
        {
            double squareDistance = SquareDistance<double>({1.0, 0}, {0, 0});
            assert(squareDistance == 1.0);

            squareDistance = SquareDistance<double>({1.0, 1.0}, {0, 0});
            assert(squareDistance == 2.0);

            squareDistance = SquareDistance<double>({-1.0, -1.0}, {0, 0});
            assert(squareDistance == 2.0);

            squareDistance = SquareDistance<double>({-2.0, 1.0}, {3, -6.0});
            assert(squareDistance == 74.0);
        }
        void TestPointBelongsToRect()
        {
            // double
            {
                Point2D_t<double> p {0, 0};
                Rectangle2D_t<double> r{1, 1, 2, 2};
                bool res = IsPointInRectangle<double>(p, r);
                assert(res == false);
                //
                p = {1, 1};
                r = {0, 0, 2, 2};
                res = IsPointInRectangle<double>(p, r);
                assert(res == true);
            }
            // int
            {
                Point2D_t<int> p {0, 0};
                Rectangle2D_t<int> r{1, 1, 2, 2};
                bool res = IsPointInRectangle<int>(p, r);
                assert(res == false);
            }
        }

        void TestGetLineIntersection()
        {
            Point2D_t<double> l1p1{0, 0};
            Point2D_t<double> l1p2{2, 0};
            Point2D_t<double> l2p1{1, -1};
            Point2D_t<double> l2p2{1, 1};
            Point2D_t<double> res;

            bool result = GetLineIntersection<double, doubleEqual>(l1p1, l1p2, l2p1, l2p2, res);
            assert(res.x == 1 && res.y == 0);
            assert(result == true);

            result = GetLineIntersection<double, doubleEqual>(l2p1, l2p2, l1p1, l1p2, res);
            assert(res.x == 1 && res.y == 0);
            assert(result == true);
        }

        void TestIsPointInRect()
        {
            Rectangle2D_d r{0.0, 0.0, 1.0, 1.0};
            Vector2D_t<double> v{0.0, 0.0};
            assert(IsPointInTriangle({0.0, 0.0}, {0.0, 1.0}, {1.0, 1.0}, {0.1, 0.9}));
            assert(IsPointInTriangle({0.0, 0.0}, {0.0, 1.0}, {1.0, 1.0}, {0.5, 0.5}));
            //assert(!(Sign({0.499, 0.501}, {0.0, 1.0}, {0.0, 0.0}) <= doubleEpsilonPl()) && 1);
            //double sx = Sign({0.499, 0.501}, {0.0, 0.0}, {1.0, 0.0});
            //assert(!(sx <= doubleEpsilonPl()) && 2);
            //std::cout << Sign({0.499, 0.501}, {1.0, 0.0}, {0.0, 1.0});
            //assert(!(Sign({0.499, 0.501}, {1.0, 0.0}, {0.0, 1.0}) <= doubleEpsilonPl()) && 3);
            //IsPointInTriangle({0.0, 1.0}, {0.0, 0.0}, {1.0, 0.0}, {0.499, 0.501})
            //auto lt1 = LineTest({0.0, 1.0}, {0.0, 0.0}, {0.499, 0.501});
            //std::cout << lt1 << std::endl;
            //auto lt2 = LineTest({0.0, 0.0}, {1.0, 0}, {0.499, 0.501});
            //std::cout << lt2 << std::endl;
            //auto lt3 = LineTest({1.0, 0.0}, {0.0, 1.0}, {0.499, 0.501});
            //std::cout << lt3 << std::endl;
            assert(IsPointInTriangle({0.0, 1.0}, {0.0, 0.0}, {1.0, 0.0}, {0.499, 0.501}));
            assert(IsPointInShiftedRectangle(r, v, {0.6, 0.6}) == true);
            assert(IsPointInShiftedRectangle(r, v, {1.6, 1.6}) == false);
            assert(IsPointInShiftedRectangle(r, v, {0.499, 0.499}) == true);
            assert(IsPointInShiftedRectangle(r, v, {0.499, 0.501}) == true);
            assert(IsPointInShiftedRectangle(r, v, {0.501, 0.499}) == true);
            assert(IsPointInShiftedRectangle(r, v, {0.501, 0.501}) == true);
            assert(IsPointInShiftedRectangle(r, v, {0.5, 0.5}) == true);
        }

        void TestSemiPlaneCollision()
        {
            Point2D_d a{0, 1};
            Point2D_d b{5, 1};
            Vector2D_t<double> dir{1, -1};
            Point2D_d p{1, 1};
            Vector2D_t<double> v {1, -2};
            auto result = CheckForCollisionWithSemiPlane(a, b, dir, p, v);
            assert(result == true);
            //assert(v.dx == 0);
            assert(v.dy == 0);
        }
    };
    static Test t_;
}
