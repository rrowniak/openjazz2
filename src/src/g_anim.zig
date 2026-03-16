const std = @import("std");
const gfx = @import("gfx").gfx;
const assets = @import("assets.zig");

pub fn calc_curr_frame_for_anim(elapsed_in_sec: f32, anim: *const assets.Anim) usize {
    // return calc_curr_frame(elapsed_in_sec, anim.frames.len, anim.frame_rate, false);
    const frame_rate = @as(f32, @floatFromInt(anim.frame_rate));
    const ttimef = elapsed_in_sec * frame_rate / 12;
    const ttimei = @as(usize, @intFromFloat(@round(ttimef)));

    return ttimei % anim.frames.len;
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
