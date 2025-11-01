const std = @import("std");
const sokol = @import("sokol");
const sg = sokol.gfx;

pub const TILE_SIZE: usize = 32;
pub const BIT_MASK_SIZE = TILE_SIZE * TILE_SIZE / 8;
// collision bit mask type
pub const COLL_BIT_MASK = [BIT_MASK_SIZE]u8;

pub const Tile = struct {
    // pixels: [TILE_SIZE * TILE_SIZE]u8, // 8-bit indices
    img: sg.Image,
    collision_bit_mask: COLL_BIT_MASK,
    flipped_collision_bit_mask: COLL_BIT_MASK,

    pub fn init_from_indexed(
        allocator: std.mem.Allocator,
        indices: []const u8, 
        palette: *const [256]u32,
        coll_bit_mask: []u8,
        f_coll_bit_mask: []u8,
    ) !Tile {
        const rgba = try allocator.alloc(u8, indices.len * 4);
        defer allocator.free(rgba);

        for (indices, 0..) |idx, i| {
            const color = palette[idx];
            rgba[i * 4 + 0] = @intCast(color & 0x000000FF);
            rgba[i * 4 + 1] = @intCast(color & 0x0000FF00 >> 8);
            rgba[i * 4 + 2] = @intCast(color & 0x00FF0000 >> 16);
            rgba[i * 4 + 3] = 255;
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
       
        t.img = sg.makeImage(.{
            .width = TILE_SIZE,
            .height = TILE_SIZE,
            .pixel_format = .RGBA8,
            .data = .{
                .mip_levels = .{
                    .{
                        .{ .ptr = rgba.ptr, .size = rgba.len },
                    }
                },
            },
        });
        return t;
    }
};

pub const Tileset = struct {
    // palette: [256][3]u8,
    tiles: []Tile,
    alloc: std.mem.Allocator,

    pub fn deinit(self: *Tileset) void {
        self.alloc.free(self.tiles);
    }
};
