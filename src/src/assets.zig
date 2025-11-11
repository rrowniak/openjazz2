const std = @import("std");
const gfx = @import("gfx.zig");

pub const JJ2Version = enum(u16) {
    Unknown = 0x0000,
    BaseGame = 0x0001,
    TSF = 0x0002,
    HH = 0x0004,
    CC = 0x0008,
    PlusExtension = 0x0100,
    SharewareDemo = 0x0200,
    All = 0xffff,
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

inline fn to_rgba(r: u8, g: u8, b: u8, a: u8) u32 {
    const aa: u32 = a; const rr: u32 = r; const gg: u32 = g; const bb: u32 = b;
    return (aa << 24) | (bb << 16) | (gg << 8) | rr;
}

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
    sprite: gfx.Sprite,
    collision_bit_mask: COLL_BIT_MASK,
    flipped_collision_bit_mask: COLL_BIT_MASK,

    inline fn get_mask_bit(mask: []u8, indx: usize) bool {
        return (mask[indx/8] >> @intCast(indx % 8) & 0x01) == 0x01;
    }

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

    pub fn init_from_rgba8(
        rgba: []const u8,
        coll_bit_mask: []u8,
        f_coll_bit_mask: []u8,
    ) !Tile {
        var t: Tile = undefined; 
        @memcpy(t.collision_bit_mask[0..BIT_MASK_SIZE], coll_bit_mask[0..BIT_MASK_SIZE]);
        @memcpy(t.flipped_collision_bit_mask[0..BIT_MASK_SIZE], f_coll_bit_mask[0..BIT_MASK_SIZE]);
       
        t.sprite = try gfx.Sprite.init_from_rgba(rgba, TILE_SIZE, TILE_SIZE);
        return t;
    }

    pub fn deinit(self: Tile) void {
        self.sprite.deinit();
    }
};

pub const Tileset = struct {
    tiles: []Tile,
    version: u16,
    palette: Palette,
    alloc: std.mem.Allocator,

    pub fn deinit(self: *Tileset) void {
        for (self.tiles) |t| {
            t.deinit();
        }
        self.alloc.free(self.tiles);
    }
};

// Animations and samples
//
pub const Frame = struct {
    sprite: gfx.IndexedSprite,
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

    pub fn deinit(self: *Animset) void {
        for (self.blocks) |b| {
            for (b.anims) |a| {
                for (a.frames) |f| {
                    f.sprite.deinit(self.alloc);
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

// Level
// 
pub const Level = struct {
    alloc: std.mem.Allocator,

    pub fn deinit(self: *Level) void {
        _ = self;
    }
};
