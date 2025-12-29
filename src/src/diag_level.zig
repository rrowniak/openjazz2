const std = @import("std");
const app = @import("app.zig");
const assets = @import("assets.zig");
const gfx = @import("gfx.zig");
const asset_reader = @import("assets_reader.zig");
const sdl = gfx.sdl;
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
    // usize types because `x` and `y` are indices of array
    x: usize,
    y: usize,

    fn init_from_world(world: WorldCoord) TileCoord {
        return .{ 
            .x = @as(usize, @intCast(world.x)) / TileCoord.SIZE,
            .y = @as(usize, @intCast(world.y)) / TileCoord.SIZE,
        };
    }
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
    scr_w: u32,
    scr_h: u32,
    cam_pos: WorldCoord,

    pub fn init(alloc: std.mem.Allocator, j2l_path: []const u8) !DiagLevel {
        const scr = gfx.screen_res();
        var level: assets.Level = try asset_reader.load_level(alloc, j2l_path);
        const dir = std.fs.path.dirname(j2l_path) orelse "";
        const tileset_path = try find_file_case_insensitive(alloc, dir, std.mem.sliceTo(&level.tileset_name, 0));
        defer alloc.free(tileset_path);
        const tileset: assets.Tileset = try asset_reader.load_tileset(alloc, tileset_path);
        // std.log.debug("---> {any}\n", .{level});
        // std.log.debug("tileset = {s}", .{level.tileset_name});
        return .{ 
            .allocator = alloc,
            .level = level, 
            .tileset = tileset,
            .scr_w = @intCast(scr.w),
            .scr_h = @intCast(scr.h),
            .cam_pos = .{.x = 1000, .y = 400},
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
        self.handle_inputs(); 
        // Coordinate system transformations
        // 1. cam_pos to visible rectangle in WorldCoord
        const visible_rect = self.cam_to_world_rect();
        // 2. Visible rectangle in WorldCoord to TileCoord
        const tile_top_left = TileCoord.init_from_world(visible_rect.top_left);
        const tile_bottom_right = TileCoord.init_from_world(visible_rect.bottom_right);
        // 3. for each tile in the rectangle:
        for (self.level.layers, 0..) |layer, num| {
            if (layer.tiles == null) {
                continue;
            }
            if (num != 3) {
                continue;
            }
            
            for (tile_top_left.y..tile_bottom_right.y) |y| {
                if (y >= layer.tiles.?.len) {
                    break;
                }
                for (tile_top_left.x..tile_bottom_right.x) |x| {
                    if (x >= layer.tiles.?[y].len) {
                        break;
                    } 
                    const lev_tile = layer.tiles.?[y][x].?;
                    const id = lev_tile.id;
                    if (id >= self.tileset.tiles.len) {
                        // TODO: Fix this case
                        continue;
                    }
                    const asset_tile = self.tileset.tiles[id];
                    // convert back to the WorldCoord
                    const tile_word = WorldCoord {
                            .x = @intCast(x * TileCoord.SIZE),
                            .y = @intCast(y * TileCoord.SIZE)
                    };
                    // convert to the Screen Coord
                    const scr_coord = self.world_to_screen(tile_word); 
                    // render if on the screen
                        // std.log.debug("Drawing {s}", .{"dd"});
                    if (scr_coord) |scr| {
                        // std.log.debug("Drawing {s}", .{"dd"});
                        // asset_tile.sprite.draw(100, 100);
                        // _ = scr;
                        asset_tile.sprite.draw(scr.x, scr.y);
                    }
                }
            }
        }
    }

    fn deinit(ctx: *anyopaque) void {
        const self: *DiagLevel = @ptrCast(@alignCast(ctx));

        self.tileset.deinit();
        self.level.deinit();
    }

    fn handle_inputs(self: *DiagLevel) void {
        const keyboard = sdl.SDL_GetKeyboardState(null);

        if (keyboard[sdl.SDL_SCANCODE_LEFT] and self.cam_pos.x > 0) {
            self.cam_pos.x -= 1;
        }
        if (keyboard[sdl.SDL_SCANCODE_RIGHT]) {
            self.cam_pos.x += 1;
        }
        if (keyboard[sdl.SDL_SCANCODE_UP] and self.cam_pos.y > 0) {
            self.cam_pos.y -= 1;
        }
        if (keyboard[sdl.SDL_SCANCODE_DOWN]) {
            self.cam_pos.y += 1;
        }
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

    fn cam_to_world_rect(self: *DiagLevel) 
        struct {top_left: WorldCoord, bottom_right: WorldCoord} {
        const w_2 = self.scr_w / 2;
        const h_2 = self.scr_h / 2;
        const x1 = if (self.cam_pos.x <= w_2) 0 else self.cam_pos.x - w_2; 
        const y1 = if (self.cam_pos.y <= h_2) 0 else self.cam_pos.y - h_2; 
        return .{
            .top_left = .{ .x = x1, .y = y1},
            .bottom_right = .{.x = self.cam_pos.x + w_2, .y = self.cam_pos.y + h_2},
        };
    }

    fn world_to_screen(self: DiagLevel, world: WorldCoord) ?ScreenCoord {
        const w_2 = self.scr_w / 2;
        const h_2 = self.scr_h / 2;
        const cx = self.cam_pos.x;
        const cy = self.cam_pos.y;

        const offset_x = if (cx < w_2) 0 else cx - w_2;
        
        const offset_y = if (cy < h_2) 0 else cy - h_2;

        if (offset_x > world.x or offset_y > world.y) {
            return null;
        }
        
        return ScreenCoord {
            .x = world.x - offset_x,
            .y = world.y - offset_y,
        };
    }
};

test "Coord transformations" {
    // World to Tile
    const w2t_tc = [_]struct {w: WorldCoord, exp: TileCoord} {
        .{.w = .{.x = 0, .y = 0}, .exp = .{.x = 0, .y = 0 }},
        .{.w = .{.x = 32, .y = 32}, .exp = .{.x = 1, .y = 1 }},
        .{.w = .{.x = 64, .y = 64}, .exp = .{.x = 2, .y = 2 }},
        .{.w = .{.x = 50, .y = 66}, .exp = .{.x = 1, .y = 2 }},
    };

    for (w2t_tc) |tc| {
        const w = tc.w;
        const t = TileCoord.init_from_world(w);
        //                          expected, actual
        try std.testing.expectEqual(tc.exp.x, t.x);
        try std.testing.expectEqual(tc.exp.y, t.y);
    }
}
