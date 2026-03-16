const std = @import("std");
const app = @import("app.zig");
const assets = @import("assets.zig");
const asset_reader = @import("assets_reader.zig");
const asset_maps = @import("assets_maps.zig");
const gfx = @import("gfx");
const sdl = gfx.sdl;
const console = @import("console.zig");
const utils = @import("utils").utils;
const m = @import("g_math.zig");
const g_anim = @import("g_anim.zig");
const WorldCoord = m.WorldCoord;
const TileCoord = m.TileCoord;
const ScreenCoord = m.ScreenCoord;

pub const DiagLevel = struct {
    // system stuff
    allocator: std.mem.Allocator,
    gfx_sys: gfx.sys,
    // shell: console.Console,
    renderer: gfx.gl_utils.SpriteRenderer,
    renderer_ind: gfx.gl_utils.IndexedSpriteRenderer,
    // assets
    level: assets.Level,
    tileset: assets.Tileset,
    animset: assets.Animset,
    palettes: [5]gfx.gl_utils.Texture1D,
    // runtimes
    scr_w: i32,
    scr_h: i32,
    cam_pos: WorldCoord,

    pub fn init(alloc: std.mem.Allocator, j2l_path: []const u8) !DiagLevel {
        // init system stuff
        const scr_w: i32 = 1400;
        const scr_h: i32 = 800;
        const gfx_sys: gfx.sys = try .init("Jazz2", scr_w, scr_h);
        const vertex_sh = @embedFile("./gfx/glsl/sprite.vert.glsl");
        const fragment_sh = @embedFile("./gfx/glsl/sprite.frag.glsl");
        const fragment_sh_ind = @embedFile("./gfx/glsl/sprite_ind.frag.glsl");
        // load resources
        var level: assets.Level = try asset_reader.load_level(alloc, j2l_path);

        const dir = std.fs.path.dirname(j2l_path) orelse "";
        const tileset_path = try utils.find_file_case_insensitive(alloc, dir, std.mem.sliceTo(&level.tileset_name, 0));
        defer alloc.free(tileset_path);
        const tileset: assets.Tileset = try asset_reader.load_tileset(alloc, tileset_path);

        const animset_path = try utils.find_file_case_insensitive(alloc, dir, "Anims.j2a");
        defer alloc.free(animset_path);
        const animset = try asset_reader.load_animset(alloc, animset_path);

        return .{
            .allocator = alloc,
            .gfx_sys = gfx_sys,
            .renderer = try .init(vertex_sh, fragment_sh, scr_w, scr_h),
            .renderer_ind = try .init(vertex_sh, fragment_sh_ind, scr_w, scr_h),
            .level = level,
            .tileset = tileset,
            .animset = animset,
            .palettes = [_]gfx.gl_utils.Texture1D{
                try .init_from_palette_rgba(&tileset.palette),
                try .init_from_palette_rgba(assets.generate_palette(.red_gem)),
                try .init_from_palette_rgba(assets.generate_palette(.green_gem)),
                try .init_from_palette_rgba(assets.generate_palette(.blue_gem)),
                try .init_from_palette_rgba(assets.generate_palette(.purple_gem)),
            },
            .scr_w = scr_w,
            .scr_h = scr_h,
            .cam_pos = .{ .x = 1000, .y = 400 },
            // .shell = try .init(alloc),
        };
    }

    fn deinit(ctx: *anyopaque) void {
        const self: *DiagLevel = @ptrCast(@alignCast(ctx));

        for (self.palettes) |p| p.deinit();

        self.tileset.deinit();
        self.animset.deinit();
        self.level.deinit();
        // self.shell.deinit();
        self.renderer_ind.deinit();
        self.renderer.deinit();
        self.gfx_sys.deinit();
    }
    pub fn app_cast(self: *DiagLevel) app.IApp {
        // register shell commands
        // at this point the address of the DiagLevel
        // should be fixed
        // self.shell.register_cmd("show", show_cmd, self);

        return .{ .ptr = self, .vtable = &.{
            .run = run,
            .deinit = deinit,
        } };
    }

    fn run(ctx: *anyopaque) void {
        const self: *DiagLevel = @ptrCast(@alignCast(ctx));

        while (true) {
            var ev: sdl.SDL_Event = undefined;
            while (sdl.SDL_PollEvent(&ev)) {
                switch (ev.type) {
                    sdl.SDL_EVENT_QUIT => {
                        std.debug.print("Exit{s}", .{"!\n"});
                        return;
                    },
                    sdl.SDL_EVENT_KEY_DOWN => {
                        const key = ev.key;
                        if (key.repeat) break;
                        if (key.scancode == sdl.SDL_SCANCODE_GRAVE) {
                            // self.shell.toggle_onoff();
                        }
                    },
                    else => {},
                }
            }

            self.clear_screen();
            self.draw();
            self.gfx_sys.draw();
        }
    }

    fn draw(self: *@This()) void {
        const time_sdl: f32 = @floatFromInt(gfx.sdl.SDL_GetTicks());
        const time_elapsed = time_sdl * 0.001; // in seconds

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
                                const anim = self.level.animated_tiles[id];
                                const frame_no = g_anim.calc_curr_frame(time_elapsed, anim.frame_count, anim.speed, anim.is_ping_pong);
                                const frame_id = anim.frames[frame_no];
                                break :blk self.tileset.tiles[frame_id];
                            },
                        };
                        self.render_tex(asset_tile.texture, self.palettes[0], scr.x, scr.y);
                    }
                }
            }

            for (tile_top_left.y..tile_bottom_right.y) |y| {
                if (y >= layer.cells.?.len) {
                    break;
                }
                for (tile_top_left.x..tile_bottom_right.x) |x| {
                    if (x >= layer.cells.?[y].len) {
                        break;
                    }
                    // convert back to the WorldCoord
                    const tile_word = WorldCoord{ .x = @intCast(x * TileCoord.SIZE), .y = @intCast(y * TileCoord.SIZE) };
                    // convert to the Screen Coord
                    const scr_coord = self.world_to_screen(tile_word);
                    // render if on the screen
                    if (scr_coord) |scr| {
                        if (layer.cells.?[y][x].event) |ev| {
                            //render event
                            var palette_id: usize = 0;
                            if (@intFromEnum(ev.id) >= @intFromEnum(asset_maps.EventId.RedGemPlus1) and @intFromEnum(ev.id) <= @intFromEnum(asset_maps.EventId.PurpleGemPlus1)) {
                                palette_id = @intFromEnum(ev.id) - @intFromEnum(asset_maps.EventId.RedGemPlus1) + 1;
                            }
                            if (asset_maps.event2animsetinxd(ev.id)) |anim| {
                                const a = &self.animset.blocks[anim.animblock].anims[anim.anim];
                                const frame = g_anim.calc_curr_frame_for_anim(time_elapsed * 10.0, a);
                                self.render_tex(a.frames[frame].texture, self.palettes[palette_id], scr.x, scr.y);
                            }
                        }
                    }
                }
            }
        }
        // render console
        // self.shell.render_shell();
    }

    fn render_tex(self: DiagLevel, tex: assets.Texture, palette: ?gfx.gl_utils.Texture1D, x: i32, y: i32) void {
        const position = gfx.math.Vec2.init(@floatFromInt(x), @floatFromInt(y));
        const rotate: f32 = 0;
        const color = gfx.math.Vec3.init(1.0, 1.0, 1.0);
        switch (tex) {
            .texture2d => |t| self.renderer.draw(t, position, rotate, color),
            .texture2dind => |t| self.renderer_ind.draw(t, palette.?, position, rotate, color),
        }
    }

    fn handle_inputs(self: *DiagLevel) void {
        const speed: u32 = 8;
        const cam_pos_x_min = @divTrunc(self.scr_w, 2);
        const cam_pos_y_min = @divTrunc(self.scr_h, 2);
        const keyboard = sdl.SDL_GetKeyboardState(null);

        if (keyboard[sdl.SDL_SCANCODE_LEFT] and self.cam_pos.x > cam_pos_x_min) {
            self.cam_pos.x -= speed;
        }
        if (keyboard[sdl.SDL_SCANCODE_RIGHT]) {
            self.cam_pos.x += speed;
        }
        if (keyboard[sdl.SDL_SCANCODE_UP] and self.cam_pos.y > cam_pos_y_min) {
            self.cam_pos.y -= speed;
        }
        if (keyboard[sdl.SDL_SCANCODE_DOWN]) {
            self.cam_pos.y += speed;
        }
    }

    fn clear_screen(self: *DiagLevel) void {
        _ = self;
        // const now_: f32 = gfx.get_ticks();
        // const now = now_ / 1000.0;
        const now: f32 = 0.0;
        const red: f32 = @floatCast(0.5 + 0.5 * std.math.sin(now));
        const green: f32 = @floatCast(0.5 + 0.5 * std.math.sin(now + std.math.pi * 2.0 / 3.0));
        const blue: f32 = @floatCast(0.5 + 0.5 * std.math.sin(now + std.math.pi * 4.0 / 3.0));

        gfx.gl.glClear(gfx.gl.GL_COLOR_BUFFER_BIT | gfx.gl.GL_DEPTH_BUFFER_BIT);
        gfx.gl.glClearColor(red, green, blue, 1.0);
    }

    fn cam_to_world_rect(self: *DiagLevel) struct { top_left: WorldCoord, bottom_right: WorldCoord } {
        const w_2: u32 = @intCast(@divTrunc(self.scr_w, 2));
        const h_2: u32 = @intCast(@divTrunc(self.scr_h, 2));
        const x1 = if (self.cam_pos.x <= w_2) 0 else self.cam_pos.x - w_2;
        const y1 = if (self.cam_pos.y <= h_2) 0 else self.cam_pos.y - h_2;
        return .{
            .top_left = .{ .x = x1, .y = y1 },
            .bottom_right = .{ .x = x1 + @as(u32, @intCast(self.scr_w)), .y = y1 + @as(u32, @intCast(self.scr_h)) },
        };
    }

    fn world_to_screen(self: DiagLevel, world: WorldCoord) ?ScreenCoord {
        // const w_2 = self.scr_w / 2;
        // const h_2 = self.scr_h / 2;
        const w_2: u32 = @intCast(@divTrunc(self.scr_w, 2));
        const h_2: u32 = @intCast(@divTrunc(self.scr_h, 2));
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
