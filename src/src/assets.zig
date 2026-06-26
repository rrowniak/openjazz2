const std = @import("std");
const maps = @import("assets_maps.zig");
const gfx = @import("gfx");
const Texture2D = gfx.gl_utils.Texture2D;
const Texture2DInd = gfx.gl_utils.Texture2DInd;

pub const Texture = union(enum) {
    texture2d: Texture2D,
    texture2dind: Texture2DInd,
};

pub const JJ2Version = enum(u16) {
    Unknown = 0x0000,
    BaseGame = 0x0001, // Retail versions 1.20, 1.21, 1.22
    TSF = 0x0002, // The Secret Files v1.23 (adds Lori)
    HH = 0x0004, // Holiday Hare '98
    CC = 0x0008, // The Christmas Chronicles (holiday pack)
    PlusExtension = 0x0100, // Jazz 2 Plus (JJ2+, community patch)
    SharewareDemo = 0x0200, // Shareware Edition (BaseGame and TSF)
    All = 0xffff,

    /// Determines game version from a tileset file's version field.
    pub fn init_from_tileset(version_id: u16) JJ2Version {
        switch (version_id) {
            0...0x200 => return .BaseGame,
            0x300 => return .PlusExtension,
            else => return .TSF,
        }
    }

    /// Determines game version from a level file's version field.
    pub fn init_from_level(version_id: u16) JJ2Version {
        switch (version_id) {
            0...0x202 => return .BaseGame,
            else => return .TSF,
        }
    }
};

// Global palettes
//
pub const Palette = [256]u32;

pub const LevelPalette = enum {
    red_gem,
    green_gem,
    blue_gem,
    purple_gem,
};

var red_gem_palette: Palette = undefined;
var green_gem_palette: Palette = undefined;
var blue_gem_palette: Palette = undefined;
var purple_gem_palette: Palette = undefined;
var cached = false;

/// Packs RGBA components into a single u32 (A-B-G-R order).
inline fn to_rgba(r: u8, g: u8, b: u8, a: u8) u32 {
    const aa: u32 = a; const rr: u32 = r; const gg: u32 = g; const bb: u32 = b;
    return (aa << 24) | (bb << 16) | (gg << 8) | rr;
}

/// Generates a gem palette gradient by applying a color factor to indices 128-255.
fn map_palette(palette: *Palette, factor: u32) void {
    for (128..240) |i| {
        const count = i - 128;
        const color: u8 = @as(u8, @intFromFloat(200.0 * @as(f64, @floatFromInt(count)) / 128.0)) + 55;
        const color_r = color & ((factor >> 16) & 0xff);
        const color_g = color & ((factor >> 8) & 0xff);
        const color_b = color & (factor & 0xff);
        palette[i] = to_rgba(@intCast(color_r), @intCast(color_g), @intCast(color_b), 255);
    }
    for (240..256) |i| {
        palette[i] = to_rgba(255, 255, 255, 255);
    }
}

/// Returns a cached palette for the given gem color (red/green/blue/purple).
pub fn generate_palette(pal: LevelPalette) *Palette {
    if (!cached) {
        map_palette(&red_gem_palette, 0xff0000);
        map_palette(&green_gem_palette, 0x00ff00);
        map_palette(&blue_gem_palette, 0x0000ff);
        map_palette(&purple_gem_palette, 0xff00ff);
        cached = true;
    }
    return switch (pal) {
        .red_gem => &red_gem_palette,
        .green_gem => &green_gem_palette,
        .blue_gem => &blue_gem_palette,
        .purple_gem => &purple_gem_palette,
    };
}
// Tilesets and sprites
//
pub const TILE_SIZE: usize = 32;
pub const BIT_MASK_SIZE = TILE_SIZE * TILE_SIZE / 8;
// collision bit mask type
pub const COLL_BIT_MASK = [BIT_MASK_SIZE]u8;

pub const Tile = struct {
    texture: Texture,
    collision_bit_mask: COLL_BIT_MASK,
    flipped_collision_bit_mask: COLL_BIT_MASK,

    /// Reads a single bit from a packed byte mask at position indx.
    inline fn get_mask_bit(mask: []u8, indx: usize) bool {
        return (mask[indx/8] >> @intCast(indx % 8) & 0x01) == 0x01;
    }

    /// Creates a tile from 8-bit indexed pixel data and a palette, applying transparency.
    pub fn init_from_indexed(
        allocator: std.mem.Allocator,
        indices: []const u8, 
        palette: *const [256]u32,
        transparency_mask: []u8, // 0 - transparent, 1 - opaque
        coll_bit_mask: []u8,
        f_coll_bit_mask: []u8,
    ) !Tile {
        const rgba = try allocator.alloc(u8, indices.len * 4);
        defer allocator.free(rgba);

        for (indices, 0..) |idx, i| {
            const transp = !get_mask_bit(transparency_mask, i);
            const color = if (transp) 0x00_00_00_00 else palette[idx] | 0xFF000000;
            const buf = rgba[i*4..];
            std.mem.writeInt(u32, buf[0..4], color, .little);
            // rgba[i * 4 + 0] = @intCast(color & 0x000000FF);
            // rgba[i * 4 + 1] = @intCast(color & 0x0000FF00 >> 8);
            // rgba[i * 4 + 2] = @intCast(color & 0x00FF0000 >> 16);
            // rgba[i * 4 + 3] = 255;
        }

        return try .init_from_rgba8(rgba, coll_bit_mask, f_coll_bit_mask);
    }

    /// Creates a tile from pre-multiplied RGBA pixel data and collision masks.
    pub fn init_from_rgba8(
        rgba: []const u8,
        coll_bit_mask: []u8,
        f_coll_bit_mask: []u8,
    ) !Tile {
        var t: Tile = undefined; 
        @memcpy(t.collision_bit_mask[0..BIT_MASK_SIZE], coll_bit_mask[0..BIT_MASK_SIZE]);
        @memcpy(t.flipped_collision_bit_mask[0..BIT_MASK_SIZE], f_coll_bit_mask[0..BIT_MASK_SIZE]);
       
        t.texture = .{ .texture2d = try Texture2D.init_from_rgba(rgba, TILE_SIZE, TILE_SIZE)};
        return t;
    }

    /// Frees the tile's texture (both 2D and indexed variants).
    pub fn deinit(self: Tile) void {
        switch (self.texture) {
            .texture2d => |t| t.deinit(),
            .texture2dind => |t| t.deinit(),
        }
    }
};

pub const Tileset = struct {
    tiles: []Tile,
    version: u16,
    palette: Palette,
    alloc: std.mem.Allocator,
    mask_overlays: ?[]gfx.gl_utils.Texture2D = null,

    /// Generates RGBA mask overlay textures from collision bitmasks.
    pub fn ensure_mask_overlays(self: *Tileset) !void {
        if (self.mask_overlays != null) return;
        const texs = try self.alloc.alloc(gfx.gl_utils.Texture2D, self.tiles.len);
        errdefer self.alloc.free(texs);

        var rgba = try self.alloc.alloc(u8, TILE_SIZE * TILE_SIZE * 4);
        defer self.alloc.free(rgba);

        for (self.tiles, 0..) |*t, i| {
            for (0..TILE_SIZE) |y| {
                for (0..TILE_SIZE) |x| {
                    const bit_idx = y * TILE_SIZE + x;
                    const byte_idx = bit_idx / 8;
                    const bit_off = @as(u3, @intCast(bit_idx % 8));
                    const set = (t.collision_bit_mask[byte_idx] >> bit_off) & 1 == 1;
                    const offset = (y * TILE_SIZE + x) * 4;
                    if (set) {
                        rgba[offset + 0] = 180;
                        rgba[offset + 1] = 180;
                        rgba[offset + 2] = 180;
                        rgba[offset + 3] = 200;
                    } else {
                        rgba[offset + 0] = 0;
                        rgba[offset + 1] = 0;
                        rgba[offset + 2] = 0;
                        rgba[offset + 3] = 0;
                    }
                }
            }
            texs[i] = try gfx.gl_utils.Texture2D.init_from_rgba(rgba, TILE_SIZE, TILE_SIZE);
        }
        self.mask_overlays = texs;
    }

    /// Frees all mask overlay textures.
    pub fn destroy_mask_overlays(self: *Tileset) void {
        if (self.mask_overlays) |overlays| {
            for (overlays) |*o| o.deinit();
            self.alloc.free(overlays);
            self.mask_overlays = null;
        }
    }

    /// Deinitializes all tiles in the tileset and frees the tile array.
    pub fn deinit(self: *Tileset) void {
        self.destroy_mask_overlays();
        for (self.tiles) |t| {
            t.deinit();
        }
        self.alloc.free(self.tiles);
    }
};

// Animations and samples
//
pub const Frame = struct {
    texture: Texture,
    width: i16,
    height: i16,
    coldspotX: i16, // Relative to hotspot, collision point?
    coldspotY: i16, // Relative to hotspot
    hotspotX: i16, // the main anchor of the sprite
    hotspotY: i16, // the main anchor of the sprite
    gunspotX: i16, // Relative to hotspot, gun attached?
    gunspotY: i16, // Relative to hotspot
};

pub const Anim = struct {
    frame_rate: u16,
    frames: []Frame,
};

pub const Sample = struct {
    sample_rate: u32,
    multiplier: u16,
    data: []u8,
};

pub const AnimBlock = struct {
    anims: []Anim,
    samples: []Sample,
};

pub const Animset = struct {
    blocks: []AnimBlock,
    alloc: std.mem.Allocator,

    /// Frees all animation blocks, frames, samples and their data.
    pub fn deinit(self: *Animset) void {
        for (self.blocks) |b| {
            for (b.anims) |a| {
                for (a.frames) |f| {
                    switch (f.texture) {
                        .texture2d => |t| t.deinit(),
                        .texture2dind => |t| t.deinit(),
                    }
                }
                self.alloc.free(a.frames);
            }
            self.alloc.free(b.anims);

            for (b.samples) |s| {
                self.alloc.free(s.data);
            }
            self.alloc.free(b.samples);
        }
        self.alloc.free(self.blocks);
    }
};

pub const AnimsetIndex = struct {animblock: usize, anim: usize};

// Events
//
pub const Event = struct {
    id: maps.EventId,
};
// Level
//
pub const LayerFlags = packed struct {
    repeat_x: bool,
    repeat_y: bool,
    use_inherent_offset: bool,
    unknown: bool,
    parallax_stars: bool,
};

pub const TileId = union(enum) {
    static_tile: usize, // points to Tileset.tiles[id]
    anim_tile: usize, // points to animated_tiles then to the tileset 
};

pub const LayerTile = struct {
    id: TileId,
    flip_x: bool,
    flip_y: bool,
};

pub const Cell = struct { tile: ?LayerTile, event: ?Event};

pub const Layer = struct {
    cells: ?[][]Cell,
    width: usize,
    height: usize,
    flags: LayerFlags,
    type_id: u8,
    z_axis: i32,
    offset_x: f32,
    offset_y: f32,
    speed_x: f32,
    speed_y: f32,
    auto_speed_x: f32,
    auto_speed_y: f32,
    texture_bg_type: u8,
    texture_params_rgb: [3]u8,
};

pub const Level = struct {
    alloc: std.mem.Allocator,
    // name: []u8,
    tileset_name: [32]u8,
    // bonus_level_name: []u8,
    // next_level_name: []u8,
    // secret_level_name: []u8,
    // music_file_name: []u8,
    layers: [8]Layer,
    animated_tiles: []@import("assets_reader.zig").AnimatedTile,

    /// Frees all layer cells and animated tile data associated with the level.
    pub fn deinit(self: *Level) void {

        for (&self.layers) |*l| {
            if (l.cells) |t| {
                for (t) |tt| {
                    self.alloc.free(tt);
                }
                self.alloc.free(t);
            }  
        }
        self.alloc.free(self.animated_tiles);
    }
};
