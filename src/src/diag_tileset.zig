const std = @import("std");
const app = @import("app.zig");
const assets = @import("assets.zig");
const gfx = @import("gfx.zig");
const asset_reader = @import("assets_reader.zig");

const SPR_IN_ROW: usize = 10;

pub const DiagTileset = struct {
    allocator: std.mem.Allocator,
    tileset: assets.Tileset,
    scr_w: usize,
    scr_h: usize,

    pub fn init(alloc: std.mem.Allocator, j2t_path: []const u8) !DiagTileset {
        const scr = gfx.screen_res();
        return .{ 
            .allocator = alloc,
            .tileset = try asset_reader.load_tileset(alloc, j2t_path),
            .scr_w = scr.w,
            .scr_h = scr.h,
        };
    }
    pub fn app_cast(self: *DiagTileset) app.IApp {
        return .{
            .ptr = self,
            .vtable = &.{
                .update = update,
                .deinit = deinit,
            }
        };
    }

    fn update(ctx: *anyopaque) void {
        const self: *DiagTileset = @ptrCast(@alignCast(ctx));

        self.clear_screen();

        var x: usize = 0;
        var y: usize = 0;
        var block_cnt: usize = 0;
        for (self.tileset.tiles, 0..) |t, i| {
            if (i != 0 and i % SPR_IN_ROW == 0) {
                y += t.sprite.h;
                x = block_cnt * SPR_IN_ROW * t.sprite.w; 
                if (y + t.sprite.h > self.scr_h) {
                    block_cnt += 1;
                    y = 0;
                }
            }
            t.sprite.draw(@intCast(x), @intCast(y));
            x += t.sprite.w;
        }
    }

    fn deinit(ctx: *anyopaque) void {
        const self: *DiagTileset = @ptrCast(@alignCast(ctx));

        self.tileset.deinit();
    }

    fn clear_screen(self: *DiagTileset) void {
        _ = self;
        const now_: f32 = gfx.get_ticks();
        const now = now_ / 1000.0;
        const red: f32 = @floatCast(0.5 + 0.5 * std.math.sin(now));
        const green: f32 = @floatCast(0.5 + 0.5 * std.math.sin(now + std.math.pi * 2.0 / 3.0));
        const blue: f32 = @floatCast(0.5 + 0.5 * std.math.sin(now + std.math.pi * 4.0 / 3.0));

        gfx.clean_screen(red, green, blue);
    }
};
