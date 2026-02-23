const std = @import("std");
const app = @import("app.zig");
const assets = @import("assets.zig");
const gfx = @import("gfx").gfx;
const asset_reader = @import("assets_reader.zig");
const asset_maps = @import("assets_maps.zig");
const sdl = gfx.sdl;
const console = @import("console.zig");
const utils = @import("utils").utils;
const m = @import("g_math.zig");
const g_anim = @import("g_anim.zig");
const WorldCoord = m.WorldCoord;
const TileCoord = m.TileCoord;
const ScreenCoord = m.ScreenCoord;

pub const DiagLevel = struct {
    allocator: std.mem.Allocator,
    level: assets.Level,
    tileset: assets.Tileset,
    animset: assets.Animset,
    animset_conv: g_anim.ConvertedAnimset,
    scr_w: u32,
    scr_h: u32,
    cam_pos: WorldCoord,
    shell: console.Console,

    pub fn init(alloc: std.mem.Allocator, j2l_path: []const u8) !DiagLevel {
        const scr = gfx.screen_res();
        var level: assets.Level = try asset_reader.load_level(alloc, j2l_path);
        const dir = std.fs.path.dirname(j2l_path) orelse "";
        const tileset_path = try utils.find_file_case_insensitive(alloc, dir, std.mem.sliceTo(&level.tileset_name, 0));
        defer alloc.free(tileset_path);
        const tileset: assets.Tileset = try asset_reader.load_tileset(alloc, tileset_path);
        // load animsets
        const animset_path = try utils.find_file_case_insensitive(alloc, dir, "Anims.j2a");
        defer alloc.free(animset_path);
        const animset = try asset_reader.load_animset(alloc, animset_path);
        const animset_conv = try g_anim.ConvertedAnimset.init(alloc, &animset, tileset.palette);
        return .{
            .allocator = alloc,
            .level = level,
            .tileset = tileset,
            .animset = animset,
            .animset_conv = animset_conv,
            .scr_w = @intCast(scr.w),
            .scr_h = @intCast(scr.h),
            .cam_pos = .{ .x = 1000, .y = 400 },
            .shell = try .init(alloc),
        };
    }

    pub fn app_cast(self: *DiagLevel) app.IApp {
        // register shell commands
        // at this point the address of the DiagLevel
        // should be fixed
        self.shell.register_cmd("show", show_cmd, self);

        return .{ .ptr = self, .vtable = &.{
            .update = update,
            .deinit = deinit,
        } };
    }

    fn update(ctx: *anyopaque) void {
        const self: *DiagLevel = @ptrCast(@alignCast(ctx));

        const time_elapsed = gfx.get_ticks() * 0.001; // in seconds

        self.clear_screen();
        self.handle_inputs();
        // Coordinate system transformations
        // 1. cam_pos to visible rectangle in WorldCoord
        const visible_rect = self.cam_to_world_rect();
        // 2. Visible rectangle in WorldCoord to TileCoord
        const tile_top_left = TileCoord.init_from_world_tl(visible_rect.top_left);
        const tile_bottom_right = TileCoord.init_from_world_br(visible_rect.bottom_right);
        // 3. for each tile in the rectangle:
        for (self.level.layers, 0..) |layer, num| {
            if (layer.cells == null) {
                continue;
            }
            if (num != 3) {
                continue;
            }

            for (tile_top_left.y..tile_bottom_right.y) |y| {
                if (y >= layer.cells.?.len) {
                    break;
                }
                for (tile_top_left.x..tile_bottom_right.x) |x| {
                    if (x >= layer.cells.?[y].len) {
                        break;
                    }
                    const lev_tile = layer.cells.?[y][x].tile.?;
                    // convert back to the WorldCoord
                    const tile_word = WorldCoord{ .x = @intCast(x * TileCoord.SIZE), .y = @intCast(y * TileCoord.SIZE) };
                    // convert to the Screen Coord
                    const scr_coord = self.world_to_screen(tile_word);
                    // render if on the screen
                    if (scr_coord) |scr| {
                        const idd = lev_tile.id;
                        const asset_tile = switch (idd) {
                            assets.TileId.static_tile => |id| blk: {
                                break :blk self.tileset.tiles[id];
                            },
                            assets.TileId.anim_tile => |id| blk: {
                                // calculate current frame number
                                var frame_no: usize = 0;
                                const anim = self.level.animated_tiles[id];
                                const ttimef = @as(f32, @floatFromInt(anim.speed)) * time_elapsed;
                                const ttimei = @as(usize, @intFromFloat(@round(ttimef)));
                                if (anim.is_ping_pong) {
                                    frame_no = ttimei % (anim.frame_count * 2 - 2);
                                    if (frame_no >= anim.frame_count) {
                                        frame_no = (2 * anim.frame_count) - frame_no - 1;
                                    }
                                } else {
                                    frame_no = ttimei % anim.frame_count;
                                }
                                const frame_id = anim.frames[frame_no];
                                break :blk self.tileset.tiles[frame_id];
                            },
                        };
                        asset_tile.sprite.draw_i32(scr.x, scr.y);

                        if (layer.cells.?[y][x].event) |ev| {
                            //render event
                            // std.debug.print("Try Draw {s}", .{"event"});
                            if (asset_maps.event2animsetinxd(ev.id)) |anim| {
                                const a = &self.animset_conv.blocks[anim.animblock][anim.anim];
                                a.set_frame(time_elapsed);
                                a.draw(scr.x, scr.y);
                                // std.debug.print("Draw {s}", .{"event"});
                            }
                        }
                    }
                }
            }
        }
        // render console
        self.shell.render_shell();
    }

    fn deinit(ctx: *anyopaque) void {
        const self: *DiagLevel = @ptrCast(@alignCast(ctx));

        self.tileset.deinit();
        self.animset.deinit();
        self.animset_conv.deinit(self.allocator);
        self.level.deinit();
        self.shell.deinit();
    }

    fn handle_inputs(self: *DiagLevel) void {
        const cam_pos_x_min = self.scr_w / 2;
        const cam_pos_y_min = self.scr_h / 2;
        const keyboard = sdl.SDL_GetKeyboardState(null);

        if (keyboard[sdl.SDL_SCANCODE_LEFT] and self.cam_pos.x > cam_pos_x_min) {
            self.cam_pos.x -= 1;
        }
        if (keyboard[sdl.SDL_SCANCODE_RIGHT]) {
            self.cam_pos.x += 1;
        }
        if (keyboard[sdl.SDL_SCANCODE_UP] and self.cam_pos.y > cam_pos_y_min) {
            self.cam_pos.y -= 1;
        }
        if (keyboard[sdl.SDL_SCANCODE_DOWN]) {
            self.cam_pos.y += 1;
        }

        for (gfx.get_events()) |ev| {
            switch (ev.type) {
                sdl.SDL_EVENT_KEY_DOWN => {
                    const key = ev.key;
                    if (key.repeat) break;
                    if (key.scancode == sdl.SDL_SCANCODE_GRAVE) {
                        self.shell.toggle_onoff();
                    }
                },
                else => {},
            }
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

    fn cam_to_world_rect(self: *DiagLevel) struct { top_left: WorldCoord, bottom_right: WorldCoord } {
        const w_2 = self.scr_w / 2;
        const h_2 = self.scr_h / 2;
        const x1 = if (self.cam_pos.x <= w_2) 0 else self.cam_pos.x - w_2;
        const y1 = if (self.cam_pos.y <= h_2) 0 else self.cam_pos.y - h_2;
        return .{
            .top_left = .{ .x = x1, .y = y1 },
            .bottom_right = .{ .x = x1 + self.scr_w, .y = y1 + self.scr_h },
        };
    }

    fn world_to_screen(self: DiagLevel, world: WorldCoord) ?ScreenCoord {
        const w_2 = self.scr_w / 2;
        const h_2 = self.scr_h / 2;
        const cx = self.cam_pos.x;
        const cy = self.cam_pos.y;

        const offset_x = if (cx < w_2) 0 else cx - w_2;

        const offset_y = if (cy < h_2) 0 else cy - h_2;

        // if (offset_x > world.x or offset_y > world.y) {
        //     return null;
        // }

        return ScreenCoord{
            .x = @as(i32, @intCast(world.x)) - @as(i32, @intCast(offset_x)),
            .y = @as(i32, @intCast(world.y)) - @as(i32, @intCast(offset_y)),
        };
    }
};

fn show_cmd(alloc: std.mem.Allocator, ctx: *anyopaque, args: []const u8) ?[]const u8 {
    const self: *DiagLevel = @ptrCast(@alignCast(ctx));
    var it = std.mem.tokenizeScalar(u8, args, ' ');
    _ = it.next();
    const subcmd = it.next() orelse {
        return alloc.dupe(u8, "Missing command argument") catch {
            return null;
        };
    };

    if (std.mem.eql(u8, subcmd, "cam_pos")) {
        return std.fmt.allocPrint(alloc, "x={d} y={d}", .{ self.cam_pos.x, self.cam_pos.y }) catch {
            return null;
        };
    }

    return std.fmt.allocPrint(alloc, "Unsupported `{s}` argument", .{subcmd}) catch {
        return null;
    };
}

test "Coord transformations" {
    // World to Tile
    const w2t_tc = [_]struct { w: WorldCoord, exp: TileCoord }{
        .{ .w = .{ .x = 0, .y = 0 }, .exp = .{ .x = 0, .y = 0 } },
        .{ .w = .{ .x = 32, .y = 32 }, .exp = .{ .x = 1, .y = 1 } },
        .{ .w = .{ .x = 64, .y = 64 }, .exp = .{ .x = 2, .y = 2 } },
        .{ .w = .{ .x = 50, .y = 66 }, .exp = .{ .x = 1, .y = 2 } },
    };

    for (w2t_tc) |tc| {
        const w = tc.w;
        const t = TileCoord.init_from_world(w);
        //                          expected, actual
        try std.testing.expectEqual(tc.exp.x, t.x);
        try std.testing.expectEqual(tc.exp.y, t.y);
    }
}
