#include "GameConsoleWriter.h"

GameConsoleWriter::GameConsoleWriter(Surface& screen_)
    : screen(screen_)
    , lineHeight(10)
    , lineAmount(20)
{
}

void GameConsoleWriter::Write(char c)
{
    if (c == '\n')
    {
        buffer.push_back(std::string());
        return;
    }
    WriteToBuffer(c);
}

void GameConsoleWriter::Write(double d)
{
    WriteToBuffer(d);
}

void GameConsoleWriter::Write(int i)
{
    WriteToBuffer(i);
}

void GameConsoleWriter::Display()
{
    int current_line = 1;
    for (auto& l : buffer)
    {
        int line_coord_y = current_line * lineHeight;
        screen.WriteText(l, 10, line_coord_y, {255, 255, 255, 160});
        current_line++;
    }
}
