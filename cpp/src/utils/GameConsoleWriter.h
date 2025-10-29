#ifndef SDLCONSOLEWRITER_H
#define SDLCONSOLEWRITER_H

#include "gfx/Surface.h"
#include "utils/MicroLogger.h"
#include <vector>
#include <sstream>

class GameConsoleWriter : public ILogWriter
{
public:
    GameConsoleWriter(Surface& screen_);

    virtual void Write(char c);
    virtual void Write(double d);
    virtual void Write(int i);

    void Display();
private:
    Surface&    screen;
    int         lineHeight;
    int         lineAmount;
    std::vector<std::string>   buffer;

    template <typename T>
    void WriteToBuffer(T v)
    {
        if (buffer.empty())
        {
            buffer.push_back(std::string());
        }

        while (buffer.size() > static_cast<unsigned int>(lineAmount))
        {
            buffer.erase(buffer.begin());
        }

        std::basic_stringstream<char>   ss;
        ss << v;
        buffer.back() += ss.str();
    }
};

#endif // SDLCONSOLEWRITER_H
