const std = @import("std");
const app = @import("app.zig");
const assets = @import("assets.zig");
const gfx = @import("gfx.zig");
const asset_reader = @import("assets_reader.zig");

pub const DiagAnimset = struct {
    allocator: std.mem.Allocator,
    animset: assets.Animset,
    scr_w: usize,
    scr_h: usize,

    pub fn init(alloc: std.mem.Allocator, j2a_path: []const u8) !DiagAnimset {
        const scr = gfx.screen_res();
        _ = j2a_path;
        return .{ 
            .allocator = alloc,
            // .animset = try asset_reader.load_animset(alloc, j2a_path),
            .animset = undefined,
            .scr_w = scr.w,
            .scr_h = scr.h,
        };
    }
    pub fn app_cast(self: *DiagAnimset) app.IApp {
        return .{
            .ptr = self,
            .vtable = &.{
                .update = update,
                .deinit = deinit,
            }
        };
    }

    fn update(ctx: *anyopaque) void {
        const self: *DiagAnimset = @ptrCast(@alignCast(ctx));

        self.clear_screen();

    }

    fn deinit(ctx: *anyopaque) void {
        const self: *DiagAnimset = @ptrCast(@alignCast(ctx));

        self.animset.deinit();
    }

    fn clear_screen(self: *DiagAnimset) void {
        _ = self;
        const now_: f32 = gfx.get_ticks();
        const now = now_ / 1000.0;
        const red: f32 = @floatCast(0.5 + 0.5 * std.math.sin(now));
        const green: f32 = @floatCast(0.5 + 0.5 * std.math.sin(now + std.math.pi * 2.0 / 3.0));
        const blue: f32 = @floatCast(0.5 + 0.5 * std.math.sin(now + std.math.pi * 4.0 / 3.0));

        gfx.clean_screen(red, green, blue);
    }
};
