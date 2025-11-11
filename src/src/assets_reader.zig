const assets = @import("assets.zig");
const easy_bit = @import("easy_bit.zig");
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

inline fn readPrim(comptime T: type, reader: anytype) !T {
    var buf: [@sizeOf(T)]u8 = undefined;

    // if (@TypeOf(reader) == *std.fs.File) {
    //     _ = try reader.read(&buf);
    //     var r = std.Io.Reader.fixed(&buf);
    //     return try easy_bit.read(T, &r);
    // }

    const read = if (@TypeOf(reader) == *std.fs.File) 
        try reader.read(&buf)
    else if (@TypeOf(reader) == *std.Io.Reader)
        try reader.readSliceShort(&buf)
    else
        @compileError("Unsupported reader type");
    if (read != buf.len)
        return error.EndOfStream;
    return std.mem.bytesToValue(T, &buf);
}

/// Reads a binary representation of a struct `T` from the given `reader`.
fn readStruct(comptime T: type, file: *std.fs.File) !T {
    // var result: T = undefined;
    //
    // const fields = std.meta.fields(T);
    // inline for (fields) |field| {
    //     const F = field.type;
    //     @field(result, field.name) = try readPrim(F, file);
    //     if (@typeInfo(F) == .@"struct")
    //         @compileError("Member structs are not allowed: " ++ @typeName(F));
    //     // TODO: more restrictions like pointers, enums, errors, arrays with non-trivial types, etc.
    // }
    // return result;

    // var buff: [@bitSizeOf(T)/8]u8 = undefined;
    // var buff: [easy_bit.size_of(T)]u8 = undefined;
    // // var reader = file.reader(&buff);
    // var reader = file.readerStreaming(&buff);
    // // try reader.seekTo(try file.getPos());
    // return try easy_bit.read(T, &reader.interface);

    // var buff: [easy_bit.size_of(T)]u8 = undefined;
    // const r = try file.read(&buff);
    // if (r != buff.len) {
    //     return error.EndOfStream;
    // }
    // var reader = std.Io.Reader.fixed(&buff);
    // return try easy_bit.read(T, &reader);
    return try easy_bit.fread(T, file);
}

/// Reads a binary representation of a struct `T` from the given `reader`.
/// This function is aware of existing slice members - they'll be populated
/// with data according to their current size
fn readStructWithSlices(comptime T: type, v: *T, reader: anytype) !void {
    _ = try easy_bit.read_dyn(T, reader, v, .little);
    // const fields = std.meta.fields(T);
    // inline for (fields) |field| {
    //     const F = field.type;
    //     const is_slice = ((F == []u8) or (F == []u16) or (F == []u32) or
    //         (F == []i8) or (F == []i16) or (F == []i32));
    //     // TODO: raise a compilation error if unsupported slice is encountered
    //     if (is_slice) {
    //         const member = @field(v, field.name);
    //         const member_bytes_len = member.len * @sizeOf(@TypeOf(member[0]));
    //         const dst_as_bytes = std.mem.sliceAsBytes(member);
    //         @memcpy(dst_as_bytes, reader.buffered()[0..member_bytes_len]);
    //         reader.toss(member_bytes_len);
    //     } else { // primitive types, static arrays
    //         @field(v, field.name) = try readPrim(F, reader);
    //     }
    //     if (@typeInfo(F) == .@"struct")
    //         @compileError("Member structs are not allowed: " ++ @typeName(F));
    //     // TODO: more restrictions like pointers, enums, errors, arrays with non-trivial types, etc.
    // }
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
    // copyright: [180]u8,
    copyright: easy_bit.marker_skip_n(180),
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
    info("Loading tileset {s}", .{path});
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
    debug("Version: {x}", .{header.version});
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
        .version = header.version,
        .palette = info_s.palette,
        .alloc = allocator,
    };
    // const s = try @import("trash.zig").paletteToString(allocator, info_s.palette);
    // defer allocator.free(s);
    // std.log.debug("Palette: {s}", .{s});

    for (0..@intCast(info_s.tile_count)) |i| {
        const image_off = info_s.img_offset[i] & ~Mask32bitTile;
        const is_32bit_tile = info_s.img_offset[i] & Mask32bitTile != 0;
        const mask_off: usize = @intCast(info_s.mask_offset[i]);
        const fmask_off = info_s.flipped_mask_offset[i];
        const alpha_off = info_s.alpha_offset[i];

        if (is_32bit_tile) {
            const img_size = 32 * 32 * 4;
            ret.tiles[i] = try .init_from_rgba8(
                img_blk[image_off..image_off + img_size],
                mask_blk[mask_off..mask_off + assets.BIT_MASK_SIZE],
                mask_blk[fmask_off..fmask_off + assets.BIT_MASK_SIZE],
            );
        } else { // indexed 8-bit
            const img_size = 32 * 32;
            ret.tiles[i] = try .init_from_indexed(
                allocator,
                img_blk[image_off..image_off + img_size],
                &info_s.palette,
                alpha_blk[alpha_off..alpha_off + assets.BIT_MASK_SIZE] ,
                mask_blk[mask_off..mask_off + assets.BIT_MASK_SIZE],
                mask_blk[fmask_off..fmask_off + assets.BIT_MASK_SIZE],
            );
        }
    }
    return ret;
}

const AnimlibHeader = struct {
    magic: [4]u8, // "ALIB"
    signature: u32, // 0x00BEBA00
    header_size: u32,
    version: u16,
    unknown1: u16,
    f_size: u32,
    CRC32: u32,
    count: i32,
};

const AnimBlockAddr = struct { addresses: []i32, };

const AnimHeader = struct {
    magic: [4]u8,      // "ANIM"
    anim_count: u8,
    sample_count: u8,  // number of samples in the set
    frame_count: u16,
    cumulative_sample_index: u32,
    CData_info: i32,
    UData_info: i32,
    CData_frame: i32,
    UData_frame: i32,
    CData_image: i32,
    UData_image: i32,
    CData_sample: i32,
    UData_sample: i32,
};

const AnimInfo = struct {
    frame_count: u16,
    frame_rate: u16,
    unknown_1: u32,
};

const FrameInfo = struct {
    width: i16,
    height: i16,
    coldspotX: i16, // Relative to hotspot
    coldspotY: i16, // Relative to hotspot
    hotspotX: i16,
    hotspotY: i16,
    gunspotX: i16, // Relative to hotspot
    gunspotY: i16, // Relative to hotspot
    image_address: i32,
    mask_address: i32,
};

const Frame = struct {
    width: u16,
    height: u16,
    draw_transparent: bool,
    pixels: []u8,

    fn init(allocator: std.mem.Allocator, reader: *std.Io.Reader, w: u16, h: u16) !Frame {
        var frame: Frame = undefined;
        frame.width = w;
        frame.height = h;
        frame.pixels = try allocator.alloc(u8, w * h);
        @memset(frame.pixels[0..frame.pixels.len], 0);
        const width = try readPrim(u16, reader);
        _ = try readPrim(u16, reader);
        frame.draw_transparent = (width & 0x8000) > 0;

        var indx: usize = 0;
        var last_op_empty = true;
        while (indx < w * h) {
            const op = try readPrim(u8, reader);
            if (op < 0x80)  { // skip `op` pixels
                indx += op; 
            } else if (op == 0x80) { // skip to end of line
                var left_in_line: usize = (w - (indx % w));
                if ((indx % w == 0) and (!last_op_empty)) {
                    left_in_line = 0;
                }
                indx += left_in_line;
            } else { // op > 0x80 - copy `op & 127` pixels from stream
                const to_read: usize = op & 0x7F;
                try reader.readSliceAll(frame.pixels[indx..indx + to_read]);
                indx += to_read;
            }

            last_op_empty = op == 0x80;
        }
        return frame;
    }

    fn deinit(self: Frame, allocator: std.mem.Allocator) void {
        allocator.free(self.pixels);
    }
};

const SampleHeader = struct {
    total_size: i32,
    magic_RIFF: u32,
    chunk_size: i32,
    format: u32, // "ASFF" for 1.20, "AS  " for 1.24
    magic_SAMP: u32,
    sample_size: u32,
};

const SampleDetails = struct {
    sample_multiplier: u16,
    unknown_1: u16,
    pyload_size: u32,
    unknown_2: [8]u8,
    sample_rate: u32,
};

const SampleData = struct {
    data: []u8,
    unknown_1: u32,

    fn init(allocator: std.mem.Allocator, size: usize) !SampleData {
        return .{ .data = try allocator.alloc(u8, size), .unknown_1 = undefined};
    }

    fn deinit(self: SampleData, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }
};

pub fn load_animset(allocator: std.mem.Allocator, path: []const u8) !assets.Animset {
    info("Loading animset {s}", .{path});
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const header = try readStruct(AnimlibHeader, &file);
    if (!std.mem.eql(u8, &header.magic, "ALIB")) {
        err("Loading animlib {s} error: expected magic ALIB, got '{s}'", .{path, header.magic});
        return error.InvalidFormat;
    }
    
    if (header.signature != 0x00BEBA00) {
        err("Incorrect file signature: expected 0x00BEBA00, got {x}", .{header.signature} );
        return error.InvalidFormat;
    }

    var anim_blocks: AnimBlockAddr = .{ 
        .addresses = try allocator.alloc(i32, @intCast(header.count)),
    };
    defer allocator.free(anim_blocks.addresses);

    var ret: assets.Animset = .{
        .blocks = try allocator.alloc(assets.AnimBlock, @intCast(header.count)),
        .alloc = allocator,
    };
   
    _ = try file.read(std.mem.sliceAsBytes(anim_blocks.addresses));
    for (anim_blocks.addresses, 0..) |a, i| {
        // read set
        try file.seekTo(@intCast(a));
        const anim_header = try readStruct(AnimHeader, &file);

        if (!std.mem.eql(u8, &anim_header.magic, "ANIM")) {
            err("Loading animheader block #{d} error: expected magic ANIM, got '{s}'", .{i, anim_header.magic});
            return error.InvalidFormat;
        }
        // read & decompress blocks 
        // debug("Reading info block: cdata={}, udata={}", .{anim_header.CData_info, anim_header.UData_info});
        const info_blk = try decompress(allocator, &file, @intCast(anim_header.CData_info), @intCast(anim_header.UData_info));
        defer allocator.free(info_blk);

        const frame_blk = try decompress(allocator, &file, @intCast(anim_header.CData_frame), @intCast(anim_header.UData_frame));
        defer allocator.free(frame_blk);

        const image_blk = try decompress(allocator, &file, @intCast(anim_header.CData_image), @intCast(anim_header.UData_image));
        defer allocator.free(image_blk);

        const sample_blk = try decompress(allocator, &file, @intCast(anim_header.CData_sample), @intCast(anim_header.UData_sample));
        defer allocator.free(sample_blk);

        var info_blk_reader = std.Io.Reader.fixed(info_blk);
        var frame_blk_reader = std.Io.Reader.fixed(frame_blk);

        ret.blocks[i].anims = try allocator.alloc(assets.Anim, @intCast(anim_header.anim_count));
        for (0..anim_header.anim_count) |j| {
            // read animation
            var anim_info: AnimInfo = undefined;
            try readStructWithSlices(AnimInfo, &anim_info, &info_blk_reader);
            ret.blocks[i].anims[j].frame_rate = anim_info.frame_rate;
            ret.blocks[i].anims[j].frames = try allocator.alloc(assets.Frame, anim_info.frame_count);
            for (0..anim_info.frame_count) |k| {
                // read frame
                var frame_info: FrameInfo = undefined;
                try readStructWithSlices(FrameInfo, &frame_info, &frame_blk_reader);
                var r = std.Io.Reader.fixed(image_blk[@intCast(frame_info.image_address)..]);
                var f = try Frame.init(
                    allocator,
                    &r,
                    @intCast(frame_info.width), @intCast(frame_info.height)
                );
                defer f.deinit(allocator);
                
                const f_ptr = &ret.blocks[i].anims[j].frames[k];
                f_ptr.height = frame_info.height;
                f_ptr.width = frame_info.width;
                f_ptr.coldspotX = frame_info.coldspotX;
                f_ptr.coldspotY = frame_info.coldspotY;
                f_ptr.hotspotX = frame_info.hotspotX;
                f_ptr.hotspotY = frame_info.hotspotY;
                f_ptr.gunspotX = frame_info.gunspotX;
                f_ptr.gunspotY = frame_info.gunspotY;
                f_ptr.sprite = try .init(allocator, @intCast(f_ptr.width), @intCast(f_ptr.height), f.pixels);
            }
        }
    
        var sample_blk_reader = std.Io.Reader.fixed(sample_blk);

        ret.blocks[i].samples = try allocator.alloc(assets.Sample, @intCast(anim_header.sample_count));

        for (0..anim_header.sample_count) |j| {
            var sample_header: SampleHeader = undefined;
            try readStructWithSlices(SampleHeader, &sample_header, &sample_blk_reader);

            if (sample_header.format != 0x46465341 and sample_header.format != 0x20205341) {
                err("Invalid sound format expected 0x46465341 or 0x20205341, got 0x{x}", .{sample_header.format});
                return error.InvalidFormat;
            }
            if (sample_header.magic_RIFF != 0x46464952 or sample_header.magic_SAMP != 0x504D4153) {
                err("Invalid sound format got: magic RIFF = 0x{x}, magic SAMP 0x{x}", .{sample_header.magic_RIFF, sample_header.magic_SAMP});
                return error.InvalidFormat;
            }

            const is_asff = (sample_header.format == 0x46465341);

            // padding or unknown data
            var discard_bytes: usize = 40;
            if (is_asff) discard_bytes = discard_bytes - 12;
            sample_blk_reader.toss(discard_bytes);
            
            var sample_details: SampleDetails = undefined;
            try readStructWithSlices(SampleDetails, &sample_details, &sample_blk_reader);

            if (is_asff) {
                sample_details.sample_multiplier = 0;
            }

            ret.blocks[i].samples[j].sample_rate = sample_details.sample_rate;
            ret.blocks[i].samples[j].multiplier = sample_details.sample_multiplier;
            
            // padding
            const data_size = if (is_asff)
                sample_header.chunk_size - 76 + 12 
                else sample_header.chunk_size - 76 + 0;
            // sample data
            var sample_data: SampleData = try .init(allocator, @intCast(data_size));
            // defer sample_data.deinit(allocator);
            // don't defer, just reassing to the destination structure
            try readStructWithSlices(SampleData, &sample_data, &sample_blk_reader);
            ret.blocks[i].samples[j].data = sample_data.data;
            // padding
            if (sample_header.total_size > sample_header.chunk_size + 12) {
                sample_blk_reader.toss(
                    @intCast(sample_header.total_size - sample_header.chunk_size - 12)
                );
            }
        }
    }

    return ret;
}

const LevelHeader = struct {
    copyright: [180]u8,
    magic: [4]u8,
    password_hash: [3]u8, // 0xBEBA00 if no password
    hide_level: u8,
    level_name: [32]u8,
    version: u16,
    file_size: i32,
    CRC: u32,
    CData_info: i32,
    UData_info: i32,
    CData_events: i32,
    UData_events: i32,
    CData_dict: i32,
    UData_dict: i32,
    CData_layout: i32,
    UData_layout: i32,
};

const LevelInfo = struct {
    jc_horizontal_offset: u16, // in pixels
    security_1: u16, // 0xBA00 if passworded, 0x0000 otherwise
    jc_vertical_offset: u16, // in pixels
    security_2: u16, // 0xBA00 if passworded, 0x0000 otherwise
    sec_and_layer: u8, //  Upper 4 bits are set if passworded, zero otherwise. Lower 4 bits represent the layer number as last saved in JCS.
    lighting_min: u8, // Multiply by 1.5625 to get value seen in JCS
    lighting_start: u8, // Multiply by 1.5625 to get value seen in JCS
    anim_count: u16,
    vertical_split_screen: bool,
    is_multiplier_level: bool,
    buffer_size: i32,
    level_name: [32]u8,
    tileset: [32]u8,
    bonus_level: [32]u8,
    next_level: [32]u8,
    secret_level: [32]u8,
    music_file: [32]u8,
    help_string: [16][512]u8,
    // TODO: sound effects for AGA version: [48][64]u8
    layer_flags: [8]u32, // Bit flags in the following order: Tile Width, Tile Height, Limit Visible Region, Texture Mode, Parallax Stars. This leaves 27 (32-5) unused bits?
    layer_type: [8]u8,
    layer_main: [8]bool, // true for layer 4
    layer_width: [8]i32,
    layer_internal_width: [8]i32,
    layer_height: [8]i32,
    layer_z_axis: [8]i32,
    layer_detail: [8]u8,
    layer_offset_x: [8]i32, // divide by 65536 to get the value
    layer_offset_y: [8]i32, // divide by 65536 to get the value
    layer_speed_x: [8]i32, // divide by 65536 to get the value
    layer_speed_y: [8]i32, // divide by 65536 to get the value
    layer_auto_speed_x: [8]i32, // divide by 65536 to get the value
    layer_auto_speed_y: [8]i32, // divide by 65536 to get the value
    layer_texture_background_type: [8]u8,
    layer_texture_params_rgb: [8][3]u8,
    anim_offset: u16, // MAX_TILES minus AnimCount, also called StaticTiles
    tileset_events:[]i32, // size: version <= 0x202? 1024:4096
    tile_flipped: []bool, // size: version <= 0x202? 1024:4096
    tile_types: []u8, // size: version <= 0x202? 1024:4096
    tile_x_mask: []u8, // size: version <= 0x202? 1024:4096
    
    fn init(allocator: std.mem.Allocator, version: u16) !LevelInfo {
        const tile_count = if (version <= 0x202) 1024 else 4096;
        var ret: LevelInfo = undefined;
        ret.tileset_events = try allocator.alloc(i32, tile_count);
        ret.tile_flipped = try allocator.alloc(bool, tile_count);
        ret.tile_types = try allocator.alloc(u8, tile_count);
        ret.tile_x_mask = try allocator.alloc(u8, tile_count);
        return ret;
    }

    fn deinit(self: *TilesetInfo, allocator: std.mem.Allocator) void {
        allocator.free(self.tileset_events);
        allocator.free(self.tile_flipped);
        allocator.free(self.tile_types);
        allocator.free(self.tile_x_mask);
    }
};

const AnimatedTile = struct {
    delay: u16, // frame wait
    delay_jitter: u16,
    reverse_delay: u16,
    is_ping_pong: bool,
    speed: u8,
    frame_count: u8,
    frames: [64]u16,
};

pub fn load_level(allocator: std.mem.Allocator, path: []const u8) !assets.Level {
    info("Loading level {s}", .{path});
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const header = try readStruct(LevelHeader, &file);
    if (!std.mem.eql(u8, &header.magic, "LEVL")) {
        err("Loading level {s} error: expected LEVL, got '{s}'", .{path, header.magic});
        return error.InvalidFormat;
    }

    debug("Reading info block: cdata={}, udata={}", .{header.CData_info, header.UData_info});
    const info_blk = try decompress(allocator, &file, @intCast(header.CData_info), @intCast(header.UData_info));
    defer allocator.free(info_blk);

    debug("Reading event block: cdata={}, udata={}", .{header.CData_events, header.UData_events});
    const event_block = try decompress(allocator, &file, @intCast(header.CData_events), @intCast(header.UData_events));
    defer allocator.free(event_block);

    debug("Reading dictionary block: cdata={}, udata={}", .{header.CData_dict, header.UData_dict});
    const dict_block = try decompress(allocator, &file, @intCast(header.CData_dict), @intCast(header.UData_dict));
    defer allocator.free(dict_block);
    
    debug("Reading layout block: cdata={}, udata={}", .{header.CData_layout, header.UData_layout});
    const layout_blk = try decompress(allocator, &file, @intCast(header.CData_layout), @intCast(header.UData_layout));
    defer allocator.free(layout_blk);


    const ret: assets.Level = .{
        .alloc = allocator,
    };

    return ret;
}

const TEST_DATA_TILES = "test_data1/v123";
// const TEST_DATA_TILES = "test_data1/v888";
const TEST_DATA_ANIMS = "test_data1/v123";
// test utility functions
comptime {
    if (@import("builtin").is_test) {
    }
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
    const gfx = @import("gfx.zig");
    try gfx.init();
    gfx.init_window(); 
    defer gfx.deinit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var a = try load_tileset(gpa.allocator(), "/home/rr/Games/Jazz2/Jungle1.j2t");
    defer a.deinit();
}

test "Loading anims" {
    const gfx = @import("gfx.zig");
    try gfx.init();
    gfx.init_window(); 
    defer gfx.deinit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var a = try load_animset(gpa.allocator(), "/home/rr/Games/Jazz2/Anims.j2a");
    defer a.deinit();
}


test "Load all .j2t tilesets from TEST_DATA_TILES "  {
    const allocator = std.testing.allocator;
    const dir_path = TEST_DATA_TILES;
    const gfx = @import("gfx.zig");
    try gfx.init();
    gfx.init_window();
    defer gfx.deinit();

    // Try opening the directory
    var dir = std.fs.cwd().openDir(dir_path, .{ .iterate = true }) catch |d_err| {
        if (d_err == error.FileNotFound) {
            std.debug.print("Skipping test: directory '{s}' not found.\n", .{dir_path});
            return; // gracefully skip test if folder missing
        }
        return d_err; // fail for other errors
    };
    defer dir.close();

    var it = dir.iterate();
    while (try it.next()) |entry| {
        // We only want regular files with .j2t extension
        if (entry.kind != .file) continue;
        if (!std.mem.endsWith(u8, entry.name, ".j2t")
            and !std.mem.endsWith(u8, entry.name, ".J2T")) 
            continue;

        // Build the full path (dir_path + "/" + entry.name)
        const full_path = try std.fs.path.join(allocator, &.{ dir_path, entry.name });
        defer allocator.free(full_path);
        // std.debug.print("Loading {s}..", .{full_path});
        // Call your function — expect it not to fail
        var t = try load_tileset(allocator, full_path);
        defer t.deinit();

        try expect(t.version == 0x200 or t.version == 0x201);
    }
}

test "Loading level" {
    const gfx = @import("gfx.zig");
    try gfx.init();
    gfx.init_window();
    defer gfx.deinit();
    var alloc = std.heap.DebugAllocator(.{}){};
    defer _ = alloc.deinit();
    var l = try load_level(alloc.allocator(), "/home/rr/Games/Jazz2/Castle1.j2l");
    defer l.deinit();
}
