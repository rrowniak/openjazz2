const assets = @import("assets.zig");
const std = @import("std");
const info = std.log.info;
const err = std.log.err;
const debug = std.log.debug;
const panic = std.debug.panic;
const expect = std.testing.expect;

comptime {
    if (@import("builtin").target.cpu.arch.endian() != .little) {
        @compileError("Jazz Jackrabbit 2 resource files require Little Endian byte order.");
    }
}

/// Reads a binary representation of a struct `T` from the given `reader`.
fn readStruct(comptime T: type, reader: anytype) !T {
    var result: T = undefined;

    const fields = std.meta.fields(T);
    inline for (fields) |field| {
        const F = field.type;
        var bytes: [@sizeOf(F)]u8 = undefined;
        const read = try reader.read(&bytes);
        if (read != bytes.len) {
            return error.EndOfStream;
        }
        @field(result, field.name) = std.mem.bytesToValue(F, &bytes);
        if (@typeInfo(F) == .@"struct")
            @compileError("Member structs are not allowed: " ++ @typeName(F));
        // TODO: more restrictions like pointers, enums, errors, arrays with non-trivial types, etc.
    }
    return result;
}

fn decompress(allocator: std.mem.Allocator, file: anytype, c_size: usize, u_size: usize) ![]u8 {
    // read c_size bytes from the file
    const input: []u8 = try allocator.alloc(u8, c_size);
    defer allocator.free(input); 

    const read = try file.read(input);
    if (read != c_size) {
        std.debug.panic("Reading compressed block failed - read {} - expected {}", .{read, c_size});
    }
    var in: std.Io.Reader = .fixed(input);
    // prepare output buffer and writer
    const result: []u8 = try allocator.alloc(u8, u_size);
    var aw: std.Io.Writer = .fixed(result);
    // decompress
    var d: std.compress.flate.Decompress = .init(&in, .zlib, &.{});
    const d_len = try d.reader.streamRemaining(&aw);
    try aw.flush();
    if (d_len != u_size) {
        std.debug.panic("Decompressed {} bytes, expected {} bytes", .{d_len, u_size});
    }

    return result;
}

const TilesetHeader = struct {
    copyright: [180]u8,
    magic: [4]u8,            // "TILE"
    signature: u32,
    title: [32]u8,
    version: u16,  //0x200 for v1.23 and below, 0x201 for v1.24
    file_size: i32,
    CRC32: i32,
    // data blocks
    CData_info: i32,    //compressed size of Data1
    UData_info: i32,    //uncompressed size of Data1
    CData_img: i32,    //compressed size of Data2
    UData_img: i32,    //uncompressed size of Data2
    CData_alpha: i32,    //compressed size of Data3
    UData_alpha: i32,    //uncompressed size of Data3
    CData_mask: i32,    //compressed size of Data4
    UData_mask: i32,    //uncompressed size of Data4
};

pub fn load_tileset(allocator: std.mem.Allocator, path: []const u8) !assets.Tileset {
    info("Loading {s}", .{path});
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const header = try readStruct(TilesetHeader, &file);

    // check invariants
    if (!std.mem.eql(u8, &header.magic, "TILE")) {
        err("Loading tileset {s} error: expected magic TILE, got '{s}'", .{path, header.magic});
        return error.InvalidFormat;
    }

    if (header.signature != 0xAFBEADDE) {
        err("Incorrect file signature: expected 0xAFBEADDE, got {x}", .{header.signature} );
        return error.InvalidFormat;
    }
    
    debug("Decompressing info block: cdata={}, udata={}", .{header.CData_info, header.UData_info});
    const info_blk = try decompress(allocator, &file, @intCast(header.CData_info), @intCast(header.UData_info));
    allocator.free(info_blk);

    debug("Decompressing img block: cdata={}, udata={}", .{header.CData_img, header.UData_img});
    const img_blk = try decompress(allocator, &file, @intCast(header.CData_img), @intCast(header.UData_img));
    allocator.free(img_blk);

    debug("Decompressing alpha block: cdata={}, udata={}", .{header.CData_alpha, header.UData_alpha});
    const alpha_blk = try decompress(allocator, &file, @intCast(header.CData_alpha), @intCast(header.UData_alpha));
    allocator.free(alpha_blk);

    debug("Decompressing mask block: cdata={}, udata={}", .{header.CData_mask, header.UData_mask});
    const mask_blk = try decompress(allocator, &file, @intCast(header.CData_mask), @intCast(header.UData_mask));
    allocator.free(mask_blk);

    return assets.Tileset {
        .palette = undefined,
        .tiles = &.{},
        .alloc = allocator,
    };
}

test "Loading tileset" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const a = try load_tileset(gpa.allocator(), "/home/rr/Games/Jazz2/Jungle1.j2t");
    _ = a;
    // try expect(false);
}
