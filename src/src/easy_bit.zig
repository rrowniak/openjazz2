//! This module provides functions for reading and writing binary data.
//! This is not a serializer, it's more like a facility to build a serializer.
const std = @import("std");
const builtin = @import("builtin");

const Error = error {EnumConversionError};

/// Reads a value of type `T` from the `file`.
/// Current cpu endian is assumed. Use `fread_ex` for contolling this parameter.
/// - `T`: the type to deserialize 
/// - `file`: an instance of `std.fs.File`. Must be open for reading.
pub fn fread(comptime T: type, file: *std.fs.File) 
   (std.Io.Reader.Error || Error || std.posix.ReadError)!T {
    const endian = builtin.cpu.arch.endian();
    return fread_ex(T, file, endian);
}

/// Reads a value of type `T` from the `file`.
/// Current cpu endian is assumed. Use `fread_ex` for contolling this parameter.
/// - `T`: the type to deserialize 
/// - `file`: an instance of `std.fs.File`. Must be open for reading.
/// - `endian`: endianness
pub fn fread_ex(comptime T: type, file: *std.fs.File, endian: std.builtin.Endian) 
   (std.Io.Reader.Error || Error || std.posix.ReadError)!T {
    var buff: [size_of(T)]u8 = undefined;
    const r = try file.read(&buff);
    if (r != buff.len) {
        return error.EndOfStream;
    }
    var reader = std.Io.Reader.fixed(&buff);
    return try read_ex(T, &reader, endian);
}

/// Reads a value of type `T` from the `stream`.
/// Current cpu endian is assumed. Use `read_ex` for contolling this parameter.
/// - `T`: the type to deserialize 
/// - `stream`: an instance of `std.Io.Reader`
pub fn read(comptime T: type, stream: *std.Io.Reader) 
    (std.Io.Reader.Error || Error)!T {
    const endian = builtin.cpu.arch.endian();
    return read_ex(T, stream, endian);
}

/// Reads a value of type `T` from the `stream`.
/// - `T`: the type to deserialize 
/// - `stream`: an instance of `std.Io.Reader`
/// - `endian`: endianness
pub fn read_ex(comptime T: type, stream: *std.Io.Reader, endian: std.builtin.Endian)
    (std.Io.Reader.Error || Error)!T {
    switch (@typeInfo(T)) {
        .bool => return try stream.takeByte() != 0,
        .int => switch (T) {
            u8 => return try stream.takeByte(),
            i8 => return try stream.takeByteSigned(),
            u16, i16, u32, i32, u64, i64, u128, i128 => return try stream.takeInt(T, endian),
            else => @compileError("Unsupported integer type " ++ @typeName(T)),
        },
        .float => return @bitCast(switch (T) {
            f16 => try stream.takeInt(u16, endian),
            f32 => try stream.takeInt(u32, endian),
            f64 => try stream.takeInt(u64, endian),
            f80 => try stream.takeInt(u80, endian),
            f128 => try stream.takeInt(u128, endian),
            else => @compileError("Unsupported floating type " ++ @typeName(T)),
        }),
        .array => |arr| { 
            var ret_arr: T = undefined;
            if (arr.child == u8) {
                try stream.readSliceAll(&ret_arr);
            } else {
                for (&ret_arr) |*item| {
                    item.* = try read_ex(arr.child, stream, endian);
                }
            }
            return ret_arr;
        },
        .@"struct" => |str| {
            if (@hasDecl(T, "marker_skip_n")) {
                const skip_n = T.marker_skip_n;
                stream.toss(skip_n);
                return undefined;
            }
            var s: T = undefined;
            inline for (str.fields) |field| {
                @field(s, field.name) = try read_ex(field.type, stream, endian);
            }
            return s;
        },
        .@"enum" => |en| {
            switch (en.tag_type) {
                u8, u16, u32, u64 => {},
                else => @compileError("Enum tag_type " ++ @typeName(en.tag_type) ++ " not supported."),
            }
            const tag_value = try stream.takeInt(en.tag_type, endian);
            var ret: T = undefined;
            ret = std.enums.fromInt(T, tag_value) orelse return Error.EnumConversionError;
            return ret;
        },
        .pointer => @compileError("Pointers, slices (" ++ @typeName(T) ++ ") are not supported by 'static' read function."),
        else => @compileError("Unsupported type " ++ @typeName(T)),
    }
    unreachable;
}

/// Return size of `T` skipping any potential holes related to the alignment.
/// The size should be equal to `T` if it was packed.
pub fn size_of(comptime T: type) usize {
    switch (@typeInfo(T)) {
        .bool, .int, .float => return @sizeOf(T),
        .array => |arr| return @sizeOf(arr.child) * arr.len,
        .@"struct" => |str| {
            if (@hasDecl(T, "marker_skip_n")) {
                // this is a marker struct
                return T.marker_skip_n;
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

/// Creates a marker structure.
pub fn marker_skip_n(comptime N: usize) type { 
    return struct {
        pub const marker_skip_n = N;
    };
}

test "Read bool, u8, u16, u32, [4]u8, [2]u16, [1]u32" {
    const buff = [_]u8 {
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
    const buf = [_]u8 {
        0xCD, // f1
        0x00, 0x12, 0x34, // f2
        0x14, 0x56, 0x86, 0xA6, 0x7B, 0xBB,
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

    const buf = [_]u8 {
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
