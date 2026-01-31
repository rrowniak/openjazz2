const std = @import("std");
const gfx = @import("gfx.zig");
const assets = @import("assets.zig");

pub const Animation = struct {
    block_index: usize,
    anim_index: usize,
    curr_fr_indx: usize,
    frame_sprites: []gfx.Sprite,

    pub fn init(allocator: std.mem.Allocator, animset: *const assets.Animset, 
        block_index: usize, anim_index: usize, palette: [256]u32) !Animation {
        const anim: *assets.Anim = &animset.*.blocks[block_index].anims[anim_index];
        const ret: Animation = .{
            .block_index = block_index,
            .anim_index = anim_index,
            .curr_fr_indx = 0,
            .frame_sprites = try allocator.alloc(gfx.Sprite, anim.frames.len)
        };
        for (0..anim.frames.len) |i| {
            try anim.frames[i].sprite.set_palette(palette);
            ret.frame_sprites[i] = try anim.frames[i].sprite.to_sprite();
        }
        return ret;
    }

    pub fn draw(self: *Animation, x: usize, y: usize) void {
        self.frame_sprites[self.curr_fr_indx].draw(x, y);
    }

    pub fn next_frame(self: *Animation) void {
        self.curr_fr_indx += 1;
        if (self.curr_fr_indx >= self.frame_sprites.len) {
            self.curr_fr_indx = 0;
        }
    }

    pub fn get_wh(self: Animation) struct {w: usize, h: usize} {
        return .{.w = self.frame_sprites[self.curr_fr_indx].w,
            .h = self.frame_sprites[self.curr_fr_indx].h};
    }

    pub fn deinit(self: Animation, allocator: std.mem.Allocator) void {
        for (self.frame_sprites) |f| {
            f.deinit();
        }
        allocator.free(self.frame_sprites);
    }
};
