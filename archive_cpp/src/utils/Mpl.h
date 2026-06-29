#ifndef MPL_H
#define MPL_H

// MPL support

struct NULL_type { };

template <bool, typename T1, typename T2>
struct TernaryOp
{
    typedef T1 type;
};

template <typename T1, typename T2>
struct TernaryOp<false, T1, T2>
{
    typedef T2 type;
};

template <typename C>
struct ContainsHashFunctor
{
private:
    typedef char _1[1];
    typedef char _2[2];
    template <typename T>
    static _1& __foo(typename T::hash*);
    template <typename T>
    static _2& __foo(...);
public:
    static constexpr bool value = sizeof(__foo<C>(nullptr)) == sizeof(_1);
};

#endif // MPL_H

// only documetation of c++11
/*
Defined in header <cstdint>
int8_t
int16_t
int32_t
int64_t 	signed integer type with width of
exactly 8, 16, 32 and 64 bits respectively
with no padding bits and using 2's complement for negative values
(provided only if the implementation directly supports the type)
int_fast8_t
int_fast16_t
int_fast32_t
int_fast64_t 	fastest signed signed integer type with width of
at least 8, 16, 32 and 64 bits respectively
int_least8_t
int_least16_t
int_least32_t
int_least64_t 	smallest signed integer type with width of
at least 8, 16, 32 and 64 bits respectively
intmax_t 	maximum width integer type
intptr_t 	integer type capable of holding a pointer
uint8_t
uint16_t
uint32_t
uint64_t 	unsigned integer type with width of
exactly 8, 16, 32 and 64 bits respectively
(provided only if the implementation directly supports the type)
uint_fast8_t
uint_fast16_t
uint_fast32_t
uint_fast64_t 	fastest unsigned unsigned integer type with width of
at least 8, 16, 32 and 64 bits respectively
uint_least8_t
uint_least16_t
uint_least32_t
uint_least64_t 	smallest unsigned integer type with width of
at least 8, 16, 32 and 64 bits respectively
uintmax_t 	maximum width unsigned integer type
uintptr_t 	unsigned integer type capable of holding a pointer

*/
