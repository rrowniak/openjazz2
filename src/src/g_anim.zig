const std = @import("std");
const gfx = @import("gfx.zig");
const assets = @import("assets.zig");

pub const ConvertedAnimset = struct {
    blocks: [][]Animation,

    pub fn init(allocator: std.mem.Allocator, animset: *const assets.Animset, palette: [256]u32) !@This() {
        var ret: @This() = .{
            .blocks = undefined,
        };
        ret.blocks = try allocator.alloc([]Animation, animset.blocks.len);
        for (0..ret.blocks.len) |blk_ind| {
            ret.blocks[blk_ind] = try allocator.alloc(Animation, animset.blocks[blk_ind].anims.len);
            for (0..ret.blocks[blk_ind].len) |anim_ind| {
                ret.blocks[blk_ind][anim_ind] = try .init(allocator, animset, blk_ind, anim_ind, palette);
            }
        }
        return ret;
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        for (self.blocks) |b| {
            for (b) |anim| {
                anim.deinit(allocator);
            }
            allocator.free(b);
        }
        allocator.free(self.blocks);
    }
};

pub const Animation = struct {
    block_index: usize,
    anim_index: usize,
    curr_fr_indx: usize,
    frame_sprites: []gfx.Sprite,
    frame_rate: u16,

    pub fn init(allocator: std.mem.Allocator, animset: *const assets.Animset, block_index: usize, anim_index: usize, palette: [256]u32) !Animation {
        const anim: *assets.Anim = &animset.*.blocks[block_index].anims[anim_index];
        const ret: Animation = .{ .block_index = block_index, .anim_index = anim_index, .curr_fr_indx = 0, .frame_sprites = try allocator.alloc(gfx.Sprite, anim.frames.len), .frame_rate = anim.frame_rate };
        for (0..anim.frames.len) |i| {
            try anim.frames[i].sprite.set_palette(palette);
            ret.frame_sprites[i] = try anim.frames[i].sprite.to_sprite();
        }
        return ret;
    }

    pub fn draw(self: *Animation, x: i32, y: i32) void {
        self.frame_sprites[self.curr_fr_indx].draw(x, y);
    }

    pub fn set_frame(self: *Animation, time_elapsed: f32) void {
        const ttimef = @as(f32, @floatFromInt(self.frame_rate)) * time_elapsed;
        const ttimei = @as(usize, @intFromFloat(@round(ttimef)));
        // if (anim.is_ping_pong) {
        //     frame_no = ttimei % (anim.frame_count * 2 - 2);
        //     if (frame_no >= anim.frame_count) {
        //         frame_no = (2 * anim.frame_count) - frame_no - 1;
        //     }
        // } else {
            const frame_no = ttimei % self.frame_sprites.len;
        // }
        self.curr_fr_indx = frame_no;
    }

    pub fn next_frame(self: *Animation) void {
        self.curr_fr_indx += 1;
        if (self.curr_fr_indx >= self.frame_sprites.len) {
            self.curr_fr_indx = 0;
        }
    }

    pub fn get_wh(self: Animation) struct { w: usize, h: usize } {
        return .{ .w = self.frame_sprites[self.curr_fr_indx].w, .h = self.frame_sprites[self.curr_fr_indx].h };
    }

    pub fn deinit(self: Animation, allocator: std.mem.Allocator) void {
        for (self.frame_sprites) |f| {
            f.deinit();
        }
        allocator.free(self.frame_sprites);
    }
};
