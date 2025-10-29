const std = @import("std");

const TILE_SIZE: usize = 32;

pub const Tile = struct {
    pixels: [TILE_SIZE * TILE_SIZE]u8, // 8-bit indices
    mask: [TILE_SIZE * TILE_SIZE]bool,
};

pub const Tileset = struct {
    palette: [256][3]u8,
    tiles: []Tile,
    alloc: std.mem.Allocator,

    pub fn deinit(self: *Tileset) void {
        self.alloc.free(self.tiles);
    }
};
