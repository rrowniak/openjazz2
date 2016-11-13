#ifndef MICROLOGGER_H
#define MICROLOGGER_H

#include <string>
#include <iostream>
#include <fstream>
#include <stdexcept>
#include <memory>
#include <vector>
#include <assert.h>

class ILogWriter
{
public:
    virtual void Write(char c) = 0;
    virtual void Write(double d) = 0;
    virtual void Write(int i) = 0;
    virtual ~ILogWriter() {}
};

class ConsoleWriter : public ILogWriter
{
public:
    virtual void Write(char c)
    {        
        std::cout << c;
    }

    virtual void Write(double d)
    {
        std::cout << d;
    }

    virtual void Write(int i)
    {
        std::cout << i;
    }
};
class FileWriter : public ILogWriter
{
public:
    FileWriter(const std::string& filename)
    {
        outputFile.open(filename);
        if (!outputFile.is_open())
        {
            throw std::runtime_error("Cannot open log file!");
        }
    }

    virtual ~FileWriter()
    {
        outputFile.close();
    }

    virtual void Write(char c)
    {
        outputFile << c;
    }

    virtual void Write(double d)
    {
        outputFile << d;
    }

    virtual void Write(int i)
    {
        outputFile << i;
    }
private:
    std::ofstream outputFile;
};

class MicroLogger
{
public:
    static MicroLogger& Instance()
    {
        static MicroLogger l;
        return l;
    }

    void AppendWriter(std::unique_ptr<ILogWriter>&& writer)
    {
        writers.push_back(std::move(writer));
    }

    void printf(const char *s)
    {
        while (*s)
        {
            if (*s == '%' && *(++s) != '%')
            {
                throw std::runtime_error("invalid format string: missing arguments");
            }
            Write(*s++);
        }
    }

    template<typename T, typename... Args>
    void printf(const char *s, T value, Args... args)
    {
        while (*s)
        {
            if (*s == '%' && *(++s) != '%')
            {
                Write(value);
                ++s;
                printf(s, args...); // call even when *s == 0 to detect extra arguments
                return;
            }
            Write(*s++);
        }
        throw std::logic_error("extra arguments provided to printf");
    }

    template <typename T>
    void Put(T t)
    {
        Write(t);
    }

    inline void Put(const char* s)
    {
        printf(s);
    }

private:
    template <typename T>
    void Write(T c)
    {
        for (auto& w : writers)
        {
            w->Write(c);
        }
    }

    void Write(const std::string& s)
    {
        for (auto c: s)
        {
            Write(c);
        }
    }

    std::vector<std::unique_ptr<ILogWriter>>    writers;
};

#define LOG (MicroLogger::Instance())

template <typename T>
inline MicroLogger& operator<<(MicroLogger& logger, T v)
{
    logger.Put(v);
    return logger;
}

#endif // MICROLOGGER_H
