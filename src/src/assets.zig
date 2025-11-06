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
       
        t.sprite = try gfx.create_sprite_from_rgba(rgba, TILE_SIZE, TILE_SIZE);
        return t;
    }

    pub fn deinit(self: Tile) void {
        self.sprite.deinit();
    }
};

pub const Tileset = struct {
    tiles: []Tile,
    version: u16,
    alloc: std.mem.Allocator,

    pub fn deinit(self: *Tileset) void {
        for (self.tiles) |t| {
            t.deinit();
        }
        self.alloc.free(self.tiles);
    }
};
pub const Frame = struct {
    sprite: gfx.Sprite,
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

pub const Animset = struct {
    anims: []Anim,
    samples: []Sample,
    alloc: std.mem.Allocator,

    pub fn deinit(self: *Animset) void {
        self.alloc.free(self.anims);
        self.alloc.free(self.samples);
    }
};
