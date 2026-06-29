#ifndef BINARYREADER_H
#define BINARYREADER_H

#include <fstream>
#include <cstring>
#include <memory>
#include <zlib.h>
#include <assert.h>
#include "utils/Mpl.h"

namespace BinaryReader
{

inline std::unique_ptr<char[]> ReadAndDecompress(std::ifstream& fileStream, unsigned long compressSize,
                                                           unsigned long uncompressSize)
{
    std::unique_ptr<char[]> c_data(new char[compressSize]);
    std::unique_ptr<char[]> u_data(new char[uncompressSize]);
    fileStream.read(&c_data[0], compressSize);
    assert((unsigned char)c_data[0] == 0x78);
    assert((unsigned char)c_data[1] == 0xda);
    ::uncompress((unsigned char*)&u_data[0], &uncompressSize, (const unsigned char*)&c_data[0], compressSize);
    return std::move(u_data);
}

template <typename T>
inline std::ifstream& read(std::ifstream& s, T& member)
{
    s.read((char*)&member, sizeof(T));
    return s;
}

template <>
inline std::ifstream& read(std::ifstream &s, NULL_type&)
{
    return s;
}

template <>
inline std::ifstream& read(std::ifstream &s, NULL_type*&)
{
    return s;
}

template <>
inline std::ifstream& read(std::ifstream &s, NULL_type**&)
{
    return s;
}

template <typename T>
inline const char* read(const char* s, T& member)
{
    ::memcpy((char*)&member, s, sizeof(T));
    return s + sizeof(T);
}

template <>
inline const char* read(const char* s, NULL_type&)
{
    return s;
}

template <>
inline const char* read(const char* s, NULL_type*&)
{
    return s;
}

template <>
inline const char* read(const char* s, NULL_type**&)
{
    return s;
}

template <typename T>
T ReadNumericLittleEndian(std::ifstream& file)
{
    T t();
    char buffer[sizeof(T)];
    file.read(buffer, sizeof(T));
    for (int i = 0; i < sizeof(T); ++i)
    {
        t |= (buffer[sizeof(T) - i]) << i * 8;
    }
    return t;
}

inline bool IsBitSetAt(const void* buff, unsigned int bitNumber)
{
    unsigned int byte = bitNumber / 8;
    unsigned int bit = bitNumber % 8;
    assert(byte * 8 + bit == bitNumber);
    unsigned char c = static_cast<const unsigned char*>(buff)[byte];
    //bool isSet = (c >> bit) & 0b0001; // this is a gcc extencion
    bool isSet = (c >> bit) & 1;
    return isSet;
}

}


#endif // BINARYREADER_H
