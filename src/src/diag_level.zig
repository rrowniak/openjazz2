const std = @import("std");
const app = @import("app.zig");
const assets = @import("assets.zig");
const gfx = @import("gfx.zig");
const asset_reader = @import("assets_reader.zig");

/// Given a possibly case-wrong path, return the actual filename on disk.
/// Returns an allocated string containing the corrected full path.
/// Caller owns the memory.
pub fn find_file_case_insensitive(
    allocator: std.mem.Allocator,
    dirname: []const u8,
    wanted_name: []const u8,
) ![]u8 {
    var dir = try std.fs.cwd().openDir(dirname, .{ .iterate = true });
    defer dir.close();

    var it = dir.iterate();
    while (try it.next()) |entry| {
        if (std.ascii.eqlIgnoreCase(entry.name, wanted_name)) {
            // Return full corrected path (dir + real filename)
            return try std.fs.path.join(
                allocator,
                &[_][]const u8{ dirname, entry.name },
            );
        }
    }

    return error.FileNotFound;
}

const TileCoord = struct {
    const SIZE: usize = 32;
    x: usize,
    y: usize,
};

const ScreenCoord = struct {
    x: u32,
    y: u32,
};

const WorldCoord = struct {
    x: u32,
    y: u32,
};

pub const DiagLevel = struct {
    allocator: std.mem.Allocator,
    level: assets.Level,
    tileset: assets.Tileset,
    scr_w: usize,
    scr_h: usize,
    cam_x: usize,
    cam_y: usize,

    pub fn init(alloc: std.mem.Allocator, j2l_path: []const u8) !DiagLevel {
        const scr = gfx.screen_res();
        var level: assets.Level = try asset_reader.load_level(alloc, j2l_path);
        const dir = std.fs.path.dirname(j2l_path) orelse "";
        const tileset_path = try find_file_case_insensitive(alloc, dir, std.mem.sliceTo(&level.tileset_name, 0));
        defer alloc.free(tileset_path);
        const tileset: assets.Tileset = try asset_reader.load_tileset(alloc, tileset_path);
        std.log.debug("---> {any}\n", .{level});
        std.log.debug("tileset = {s}", .{level.tileset_name});
        return .{ 
            .allocator = alloc,
            .level = level, 
            .tileset = tileset,
            .scr_w = scr.w,
            .scr_h = scr.h,
            .cam_x = 0,
            .cam_y = 0,
        };
    }

    pub fn app_cast(self: *DiagLevel) app.IApp {
        return .{
            .ptr = self,
            .vtable = &.{
                .update = update,
                .deinit = deinit,
            }
        };
    }

    fn update(ctx: *anyopaque) void {
        const self: *DiagLevel = @ptrCast(@alignCast(ctx));

        self.clear_screen();

        // var x: usize = 0;
        // var y: usize = 0;
        // var block_cnt: usize = 0;
        // for (self.tileset.tiles, 0..) |t, i| {
        //     if (i != 0 and i % SPR_IN_ROW == 0) {
        //         y += t.sprite.h;
        //         x = block_cnt * SPR_IN_ROW * t.sprite.w; 
        //         if (y + t.sprite.h > self.scr_h) {
        //             block_cnt += 1;
        //             y = 0;
        //         }
        //     }
        //     t.sprite.draw(x, y);
        //     x += t.sprite.w;
        // }
    }

    fn deinit(ctx: *anyopaque) void {
        const self: *DiagLevel = @ptrCast(@alignCast(ctx));

        self.tileset.deinit();
        self.level.deinit();
    }

    fn clear_screen(self: *DiagLevel) void {
        _ = self;
        const now_: f32 = gfx.get_ticks();
        const now = now_ / 1000.0;
        const red: f32 = @floatCast(0.5 + 0.5 * std.math.sin(now));
        const green: f32 = @floatCast(0.5 + 0.5 * std.math.sin(now + std.math.pi * 2.0 / 3.0));
        const blue: f32 = @floatCast(0.5 + 0.5 * std.math.sin(now + std.math.pi * 4.0 / 3.0));

        gfx.clean_screen(red, green, blue);
    }
};
