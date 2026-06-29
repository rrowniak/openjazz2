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
//     Time.h created 3/29/2013
//
//     Author: Rafal Rowniak
// 
**********************************************************************************************/

#ifndef TIME_H
#define TIME_H

#include <chrono>

typedef std::chrono::duration<int,std::ratio<60*60>> hours;
typedef std::chrono::duration<int,std::ratio<60>> minutes;
typedef std::chrono::duration<int> seconds;
typedef std::chrono::duration<int,std::milli> miliseconds;

class GameClock
{
public:
    typedef std::chrono::milliseconds   duration;
    typedef duration::rep               rep;
    typedef duration::period            period;
    typedef std::chrono::time_point<GameClock, duration>    time_point;

    static constexpr bool is_steady = false;
    static time_point now() noexcept;
private:
    static_assert(GameClock::duration::min() < GameClock::duration::zero(),
          "a clock's minimum duration cannot be less than its epoch");
};

typedef GameClock::time_point time_point;

#endif // TIME_H
