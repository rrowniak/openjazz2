//! This module provides utilities for reading and writing binary data in Zig.
//! It is designed to help build custom serializers and deserializers for binary formats.
//! It supports reading primitive types, arrays, structs, enums, and slices, with endianness control.

const std = @import("std");
const builtin = @import("builtin");

/// Custom error for enum conversion failures.
const Error = error{EnumConversionError};

/// Reads a value of type `T` from a file using the system's native endianness.
/// - `T`: Type to read (e.g., u32, struct, enum)
/// - `file`: Pointer to an open `std.fs.File` for reading.
/// Returns: The value of type `T` or an error.
pub fn fread(comptime T: type, file: *std.fs.File) (std.Io.Reader.Error || Error || std.posix.ReadError)!T {
    const endian = builtin.cpu.arch.endian();
    return fread_ex(T, file, endian);
}

/// Reads a value of type `T` from a file with specified endianness.
/// - `T`: Type to read
/// - `file`: Pointer to an open `std.fs.File`
/// - `endian`: Endianness to use (big or little)
pub fn fread_ex(comptime T: type, file: *std.fs.File, endian: std.builtin.Endian) (std.Io.Reader.Error || Error || std.posix.ReadError)!T {
    var buff: [size_of(T)]u8 = undefined;
    const r = try file.read(&buff);
    if (r != buff.len) {
        return error.EndOfStream;
    }
    var reader = std.Io.Reader.fixed(&buff);
    return try read_ex(T, &reader, endian);
}

/// Reads a value of type `T` from a stream using the system's native endianness.
/// - `T`: Type to read
/// - `stream`: Pointer to a `std.Io.Reader`
pub fn read(comptime T: type, stream: *std.Io.Reader) (std.Io.Reader.Error || Error)!T {
    const endian = builtin.cpu.arch.endian();
    return read_ex(T, stream, endian);
}

/// Reads a value of type `T` from a stream with specified endianness.
/// - `T`: Type to read
/// - `stream`: Pointer to a `std.Io.Reader`
/// - `endian`: Endianness to use
pub fn read_ex(comptime T: type, stream: *std.Io.Reader, endian: std.builtin.Endian) (std.Io.Reader.Error || Error)!T {
    var ret: T = undefined;
    _ = try read_dyn(T, stream, &ret, endian);
    return ret;
}

/// Dynamically reads a value of type `T` from a stream, supporting arrays, structs, enums, and slices.
/// - `T`: Type to read
/// - `stream`: Pointer to a `std.Io.Reader`
/// - `value`: Pointer to the output variable
/// - `endian`: Endianness to use
/// Returns: Number of bytes read
pub fn read_dyn(comptime T: type, stream: *std.Io.Reader, value: *T, endian: std.builtin.Endian) (std.Io.Reader.Error || Error)!usize {
    switch (@typeInfo(T)) {
        .bool => value.* = try stream.takeByte() != 0,
        .int => switch (T) {
            u8 => value.* = try stream.takeByte(),
            i8 => value.* = try stream.takeByteSigned(),
            u16, i16, u32, i32, u64, i64, u128, i128 => value.* = try stream.takeInt(T, endian),
            else => @compileError("Unsupported integer type " ++ @typeName(T)),
        },
        .float => value.* = @bitCast(switch (T) {
            f16 => try stream.takeInt(u16, endian),
            f32 => try stream.takeInt(u32, endian),
            f64 => try stream.takeInt(u64, endian),
            f80 => try stream.takeInt(u80, endian),
            f128 => try stream.takeInt(u128, endian),
            else => @compileError("Unsupported floating type " ++ @typeName(T)),
        }),
        .array => |arr| {
            var read_bytes: usize = 0;
            if (arr.child == u8) {
                try stream.readSliceAll(value);
                read_bytes = arr.len;
            } else {
                for (value) |*item| {
                    read_bytes += try read_dyn(arr.child, stream, item, endian);
                }
            }
            return read_bytes;
        },
        .@"struct" => |str| {
            if (@hasDecl(T, "marker skip n")) {
                const skip_n = T.@"marker skip n";
                stream.toss(skip_n);
                return skip_n;
            }
            var read_bytes: usize = 0;
            inline for (str.fields) |field| {
                read_bytes += try read_dyn(field.type, stream, &@field(value, field.name), endian);
            }
            return read_bytes;
        },
        .@"enum" => |en| {
            switch (en.tag_type) {
                u8, u16, u32, u64 => {},
                else => @compileError("Enum tag_type " ++ @typeName(en.tag_type) ++ " not supported."),
            }
            const tag_value = try stream.takeInt(en.tag_type, endian);
            value.* = std.enums.fromInt(T, tag_value) orelse return Error.EnumConversionError;
        },
        .pointer => |ptr| {
            if (ptr.sentinel() != null) @compileError("Pointers sentinels are not supported.");
            if (ptr.size != .slice) {
                @compileError("Pointers (" ++ @typeName(T) ++ ") are not supported.");
            }
            // slices here, slice is expected to be initialized, otherwise nothing will be read
            if (value.len == 0) {
                return 0;
            }
            if (ptr.child == u8) {
                try stream.readSliceAll(value.*);
                return value.len;
            } else {
                var read_bytes: usize = 0;
                for (value.*) |*item| {
                    read_bytes += try read_dyn(ptr.child, stream, item, endian);
                }
                return read_bytes;
            }
        },
        else => @compileError("Unsupported type " ++ @typeName(T)),
    }

    return @sizeOf(T);
}

/// Returns the packed size of type `T`, ignoring alignment holes.
/// Useful for binary serialization.
/// - `T`: Type to measure
pub fn size_of(comptime T: type) usize {
    switch (@typeInfo(T)) {
        .bool, .int, .float => return @sizeOf(T),
        .array => |arr| return @sizeOf(arr.child) * arr.len,
        .@"struct" => |str| {
            if (@hasDecl(T, "marker skip n")) {
                // this is a marker struct
                return T.@"marker skip n";
            }
            var len: usize = 0;
            inline for (str.fields) |field| {
                len += size_of(field.type);
            }
            return len;
        },
        .@"enum" => |en| {
            if (en.tag_type == usize) {
                @compileError("usize enum tag type is not allowed.");
            } else {
                return @sizeOf(en.tag_type);
            }
        },
        else => @compileError("Unsupported type " ++ @typeName(T)),
    }
    unreachable;
}

/// Creates a marker struct that skips `N` bytes when reading.
/// Useful for skipping unused or reserved fields in binary formats.
pub fn marker_skip_n(comptime N: usize) type {
    return struct {
        pub const @"marker skip n" = N;
    };
}

// --- Tests ---
// The following tests demonstrate reading various types and structures from binary buffers.
// They cover booleans, integers, arrays, nested structs, and enums.
test "Read bool, u8, u16, u32, [4]u8, [2]u16, [1]u32" {
    const buff = [_]u8{
        0x01, // true
        0x00, // false
        0xFF, // true
        0xAB, // true
    };
    var r = std.Io.Reader.fixed(&buff);
    try std.testing.expect(try read(bool, &r) == true);
    try std.testing.expect(try read(bool, &r) == false);
    try std.testing.expect(try read(bool, &r) == true);
    try std.testing.expect(try read(bool, &r) == true);

    r = std.Io.Reader.fixed(&buff);
    try std.testing.expect(try read(u8, &r) == 0x01);
    try std.testing.expect(try read(u8, &r) == 0x00);
    try std.testing.expect(try read(u8, &r) == 0xFF);
    try std.testing.expect(try read(u8, &r) == 0xAB);

    r = std.Io.Reader.fixed(&buff);
    const arr = try read([4]u8, &r);
    try std.testing.expect(std.mem.eql(u8, &buff, &arr));

    if (builtin.target.cpu.arch.endian() == .little) {
        r = std.Io.Reader.fixed(&buff);
        try std.testing.expect(try read(u16, &r) == 0x0001);
        try std.testing.expect(try read(u16, &r) == 0xABFF);

        r = std.Io.Reader.fixed(&buff);
        const arru16 = try read([2]u16, &r);
        try std.testing.expect(arru16[0] == 0x0001);
        try std.testing.expect(arru16[1] == 0xABFF);

        r = std.Io.Reader.fixed(&buff);
        try std.testing.expect(try read(u32, &r) == 0xABFF0001);

        r = std.Io.Reader.fixed(&buff);
        const arru32 = try read([1]u32, &r);
        try std.testing.expect(arru32[0] == 0xABFF0001);
    } else { // .big
        r = std.Io.Reader.fixed(&buff);
        try std.testing.expect(try read(u16, &r) == 0x0100);
        try std.testing.expect(try read(u16, &r) == 0xFFAB);

        r = std.Io.Reader.fixed(&buff);
        const arru16 = try read([2]u16, &r);
        try std.testing.expect(arru16[0] == 0x0100);
        try std.testing.expect(arru16[1] == 0xFFAB);

        r = std.Io.Reader.fixed(&buff);
        try std.testing.expect(try read(u32, &r) == 0x0100FFAB);

        r = std.Io.Reader.fixed(&buff);
        const arru32 = try read([1]u32, &r);
        try std.testing.expect(arru32[0] == 0x0100FFAB);
    }
}

test "nested structs" {
    const Nested = struct {
        f1: u8,
        f2: u16,
    };

    const Root = struct {
        f1: u8,
        f2: Nested,
        f3: [2]Nested,
    };
    // Root's binary representation
    const buf = [_]u8{
        0xCD, // f1
        0x00, 0x12, 0x34, // f2
        0x14, 0x56, 0x86,
        0xA6, 0x7B, 0xBB,
    };
    var r = std.Io.Reader.fixed(&buf);
    const root = try read(Root, &r);

    try std.testing.expect(root.f1 == 0xCD);

    if (builtin.target.cpu.arch.endian() == .little) {
        try std.testing.expect(root.f2.f1 == 0x00);
        try std.testing.expect(root.f2.f2 == 0x3412);

        try std.testing.expect(root.f3[0].f1 == 0x14);
        try std.testing.expect(root.f3[0].f2 == 0x8656);

        try std.testing.expect(root.f3[1].f1 == 0xA6);
        try std.testing.expect(root.f3[1].f2 == 0xBB7B);
    } else {
        try std.testing.expect(root.f2.f1 == 0x00);
        try std.testing.expect(root.f2.f2 == 0x1234);

        try std.testing.expect(root.f3[0].f1 == 0x14);
        try std.testing.expect(root.f3[0].f2 == 0x5686);

        try std.testing.expect(root.f3[1].f1 == 0xA6);
        try std.testing.expect(root.f3[1].f2 == 0x7BBB);
    }
}

test "enums" {
    const E1 = enum(u32) {
        A,
    };
    const E2 = enum(u16) {
        A = 0x201,
        B = 0x0204,
    };
    const E3 = enum(u8) { A, _ };

    const buf = [_]u8{
        0x00, 0x00, 0x00, 0x00, // E1
        0x04, 0x02, // E2
        0x86, // E3
    };

    try std.testing.expect(std.enums.fromInt(E2, 0x0204) == E2.B);

    var r = std.Io.Reader.fixed(&buf);
    const e1 = try read(E1, &r);
    const e2 = try read(E2, &r);
    const e3 = try read(E3, &r);

    try std.testing.expect(e1 == E1.A);
    try std.testing.expect(e2 == E2.B);
    try std.testing.expect(e3 == @as(E3, @enumFromInt(0x86)));
}
