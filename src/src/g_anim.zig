const std = @import("std");
const gfx = @import("gfx").gfx;
const assets = @import("assets.zig");

pub const ConvertedAnimset = struct {
    // blocks: [][]Animation,

    pub fn init(allocator: std.mem.Allocator, animset: *const assets.Animset, palette: [256]u32) !@This() {
        _ = allocator;
        _ = animset;
        _ = palette;
        const ret: @This() = .{
            // .blocks = undefined,
        };
        // ret.blocks = try allocator.alloc([]Animation, animset.blocks.len);
        // for (0..ret.blocks.len) |blk_ind| {
        //     ret.blocks[blk_ind] = try allocator.alloc(Animation, animset.blocks[blk_ind].anims.len);
        //     for (0..ret.blocks[blk_ind].len) |anim_ind| {
        //         ret.blocks[blk_ind][anim_ind] = try .init(allocator, animset, blk_ind, anim_ind, palette);
        //     }
        // }
        return ret;
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        _ = self;
        _ = allocator;
        // for (self.blocks) |b| {
        //     for (b) |anim| {
        //         anim.deinit(allocator);
        //     }
        //     allocator.free(b);
        // }
        // allocator.free(self.blocks);
    }
};

pub fn calc_curr_frame_for_anim(elapsed_in_sec: f32, anim: *const assets.Anim) usize {
    return calc_curr_frame(elapsed_in_sec, anim.frames.len, 1, false);
    // return calc_curr_frame(elapsed_in_sec, anim.frames.len, anim.frame_rate, false);
}

pub fn calc_curr_frame(elapsed_in_sec: f32, frames_len: usize, anim_speed: u16, ping_pong: bool) usize {
    var frame_no: usize = 0;
    const ttimef = @as(f32, @floatFromInt(anim_speed)) * elapsed_in_sec;
    const ttimei = @as(usize, @intFromFloat(@round(ttimef)));
    if (ping_pong) {
        frame_no = ttimei % (frames_len * 2 - 2);
        if (frame_no >= frames_len) {
            frame_no = (2 * frames_len) - frame_no - 1;
        }
    } else {
        frame_no = ttimei % frames_len;
    }
    return frame_no;
}
