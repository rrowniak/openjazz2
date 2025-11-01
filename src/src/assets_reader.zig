const assets = @import("assets.zig");
const std = @import("std");
const info = std.log.info;
const err = std.log.err;
const debug = std.log.debug;
const panic = std.debug.panic;
const expect = std.testing.expect;

const Mask32bitTile: usize = 0x80000000;

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

/// Reads a binary representation of a struct `T` from the given `reader`.
/// This function is aware of existing slice members - they'll be populated
/// with data according to their current size
fn readStructWithSlices(comptime T: type, v: *T, reader: anytype) !void {
    const fields = std.meta.fields(T);
    inline for (fields) |field| {
        const F = field.type;
        const is_slice = ((F == []u8) or (F == []u16) or (F == []u32) or
            (F == []i8) or (F == []i16) or (F == []i32));
        // TODO: raise a compilation error if unsupported slice is encountered
        if (is_slice) {
            const member = @field(v, field.name);
            const member_bytes_len = member.len * @sizeOf(@TypeOf(member[0]));
            const dst_as_bytes = std.mem.sliceAsBytes(member);
            @memcpy(dst_as_bytes, reader.buffered()[0..member_bytes_len]);
            reader.toss(member_bytes_len);
        } else { // primitive types, static arrays
            var bytes: [@sizeOf(F)]u8 = undefined;
            const read = try reader.readSliceShort(&bytes);
            if (read != bytes.len) {
                return error.EndOfStream;
            }
            @field(v, field.name) = std.mem.bytesToValue(F, &bytes);
        }
        if (@typeInfo(F) == .@"struct")
            @compileError("Member structs are not allowed: " ++ @typeName(F));
        // TODO: more restrictions like pointers, enums, errors, arrays with non-trivial types, etc.
    }
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
    //version: 0x200 for v1.23 and below - base game,
    // 0x201 for v1.24 - TSF
    // 0x300 for Plus Extension
    version: u16,  
    file_size: i32,
    CRC32: i32,
    // data blocks
    CData_info: i32,   // compressed size of info block
    UData_info: i32,   // uncompressed size of info block
    CData_img: i32,    // compressed size of image block
    UData_img: i32,    // uncompressed size of image block
    CData_alpha: i32,  // compressed size of alpha block
    UData_alpha: i32,  // uncompressed size of alpha block
    CData_mask: i32,   // compressed size of mask block
    UData_mask: i32,   // uncompressed size of mask
};

const TilesetInfo = struct {
    palette: [256]u32,  // arranged as RGBA
    tile_count: i32,    // number of tiles, multiple of 10
    tile_opaque: []u8,  // 1 if no transparency at all, otherwise 0
    unknown_1: []u8,    // appears to be all zeros
    img_offset: []u32,  // image offsets
    unknown_2: []u32,   // appears to be all zeros 
    alpha_offset: []u32,// transparency masking for bitblt
    unknown_3: []u32,   // appears to be all zeros
    mask_offset: []u32, // clipping or tile mask
    flipped_mask_offset: []u32,

    fn init_arrays_only(allocator: std.mem.Allocator, version: u16) !TilesetInfo {
        const size: usize = if (version <= 0x200) 1024 else 4096; 
        return .{
            .palette = undefined,
            .tile_count = undefined,
            .tile_opaque = try allocator.alloc(u8, size),
            .unknown_1 = try allocator.alloc(u8, size),
            .img_offset = try allocator.alloc(u32, size),
            .unknown_2 = try allocator.alloc(u32, size),
            .alpha_offset = try allocator.alloc(u32, size),
            .unknown_3 = try allocator.alloc(u32, size),
            .mask_offset = try allocator.alloc(u32, size),
            .flipped_mask_offset = try allocator.alloc(u32, size),
        }; 
    }

    fn deinit(self: TilesetInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.tile_opaque);
        allocator.free(self.unknown_1);
        allocator.free(self.img_offset);
        allocator.free(self.unknown_2);
        allocator.free(self.alpha_offset);
        allocator.free(self.unknown_3);
        allocator.free(self.mask_offset);
        allocator.free(self.flipped_mask_offset);
    }
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
    // read & decompress blocks 
    debug("Reading info block: cdata={}, udata={}", .{header.CData_info, header.UData_info});
    const info_blk = try decompress(allocator, &file, @intCast(header.CData_info), @intCast(header.UData_info));
    defer allocator.free(info_blk);

    debug("Reading img block: cdata={}, udata={}", .{header.CData_img, header.UData_img});
    const img_blk = try decompress(allocator, &file, @intCast(header.CData_img), @intCast(header.UData_img));
    defer allocator.free(img_blk);

    debug("Reading alpha block: cdata={}, udata={}", .{header.CData_alpha, header.UData_alpha});
    const alpha_blk = try decompress(allocator, &file, @intCast(header.CData_alpha), @intCast(header.UData_alpha));
    defer allocator.free(alpha_blk);

    debug("Reading mask block: cdata={}, udata={}", .{header.CData_mask, header.UData_mask});
    const mask_blk = try decompress(allocator, &file, @intCast(header.CData_mask), @intCast(header.UData_mask));
    defer allocator.free(mask_blk);

    // at this point no further file read operations are required
    // just process data blocks
    var info_s: TilesetInfo = try .init_arrays_only(allocator, header.version);
    defer info_s.deinit(allocator);
    var r = std.Io.Reader.fixed(info_blk);
    try readStructWithSlices(TilesetInfo, &info_s, &r);
    // extract & process images
    var ret: assets.Tileset = .{
        .tiles = try allocator.alloc(assets.Tile, @intCast(info_s.tile_count)),
        .alloc = allocator,
    };
    for (0..@intCast(info_s.tile_count)) |i| {
        const image_off = info_s.img_offset[i] & ~Mask32bitTile;
        const is_32bit_tile = info_s.img_offset[i] & Mask32bitTile != 0;
        const mask_off: usize = @intCast(info_s.mask_offset[i]);
        const fmask_off = info_s.flipped_mask_offset[i];

        if (is_32bit_tile) {
            const img_size = 32 * 32 * 4;
            ret.tiles[i] = try .init_from_rgba8(
                img_blk[image_off..image_off + img_size],
                mask_blk[mask_off..mask_off + assets.BIT_MASK_SIZE],
                mask_blk[fmask_off..fmask_off + assets.BIT_MASK_SIZE],
            );
        } else {
            const img_size = 32 * 32;
            ret.tiles[i] = try .init_from_indexed(
                allocator,
                img_blk[image_off..image_off + img_size], &info_s.palette,
                mask_blk[mask_off..mask_off + assets.BIT_MASK_SIZE],
                mask_blk[fmask_off..fmask_off + assets.BIT_MASK_SIZE],
            );
        }
    }
    return ret;
}

test "struct from memory" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var alloc = gpa.allocator();

    const TestStruct = struct {
        f1: u8,
        f2: [4]u8,
        f3: u32,
        f4: []u32,
        f5: u16,
    };

    const flat_bin_repr = [_]u8 {
        0xab, // f1
        0x01, 0x33, 0x45, 0x88, // f2
        0xff, 0xab, 0x00, 0xbc, // f3
        0xcd, 0xef, 0x00, 0x12, 0xff, 0x00, 0x5c, 0x8d, // f4
        0x12, 0x34, // f5
    };

    var tc :TestStruct = undefined;
    tc.f4 = try alloc.alloc(u32, 2);
    defer alloc.free(tc.f4);
    var r = std.Io.Reader.fixed(&flat_bin_repr);
    try readStructWithSlices(TestStruct, &tc, &r); 

    // std.debug.print("\nf1={x}\n", .{tc.f1});
    try expect(tc.f1 == 0xab);
    try expect(tc.f2[0] == 0x01);
    try expect(tc.f2[1] == 0x33);
    try expect(tc.f2[2] == 0x45);
    try expect(tc.f2[3] == 0x88);
    // std.debug.print("\nf3={x}\n", .{tc.f3});
    try expect(tc.f3 == 0xbc00abff);
    try expect(tc.f4[0] == 0x1200efcd);
    try expect(tc.f4[1] == 0x8d5c00ff);
    // std.debug.print("\nf5={x}\n", .{tc.f5});
    try expect(tc.f5 == 0x3412);
}

test "Loading tileset" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var a = try load_tileset(gpa.allocator(), "/home/rr/Games/Jazz2/Jungle1.j2t");
    defer a.deinit();
    // try expect(false);
}
