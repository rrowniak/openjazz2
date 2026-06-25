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
    shell: console.Console,
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
    // FPS tracking
    frame_count: u32,
    last_fps_time: u64,
    fps: i32,
    fps_text_tex: ?gfx.gl_utils.Texture2D,
    last_rendered_fps: i32,

    /// Loads a level, its tileset, and animset; initializes graphics and renderers.
    pub fn init(alloc: std.mem.Allocator, j2l_path: []const u8) !DiagLevel {
        // init system stuff
        const scr_w: i32 = 1400;
        const scr_h: i32 = 800;
        const gfx_sys: gfx.sys = try .init("Jazz2", scr_w, scr_h);
        const vertex_sh = @embedFile("./gfx/glsl/sprite.vert.glsl");
        const fragment_sh = @embedFile("./gfx/glsl/sprite.frag.glsl");
        const fragment_sh_ind = @embedFile("./gfx/glsl/sprite_ind.frag.glsl");

        var shell = try console.Console.init(alloc, gfx_sys.sdl_window.?, @floatFromInt(scr_w), @floatFromInt(scr_h));
        shell.rect = .{ .x = 0, .y = 0, .w = @floatFromInt(scr_w), .h = @as(f32, @floatFromInt(scr_h)) / 2 };

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
            .shell = shell,
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
            .frame_count = 0,
            .last_fps_time = 0,
            .fps = 0,
            .fps_text_tex = null,
            .last_rendered_fps = -1,
        };
    }

    /// IApp deinit callback: frees palettes, tileset, animset, level, renderers, and gfx.
    fn deinit(ctx: *anyopaque) void {
        const self: *DiagLevel = @ptrCast(@alignCast(ctx));

        for (self.palettes) |p| p.deinit();

        if (self.fps_text_tex) |tex| tex.deinit();

        self.tileset.deinit();
        self.animset.deinit();
        self.level.deinit();
        self.shell.deinit();
        self.renderer_ind.deinit();
        self.renderer.deinit();
        self.gfx_sys.deinit();
    }
    /// Wraps this diagnostic viewer into the generic IApp interface.
    pub fn app_cast(self: *DiagLevel) app.IApp {
        self.shell.register_cmd("show", show_cmd, self);

        return .{ .ptr = self, .vtable = &.{
            .run = run,
            .deinit = deinit,
        } };
    }

    /// Main loop: polls events, clears screen, and draws the level.
    fn run(ctx: *anyopaque) void {
        const self: *DiagLevel = @ptrCast(@alignCast(ctx));

        while (true) {
            var events: [64]sdl.SDL_Event = undefined;
            var event_count: usize = 0;
            var ev: sdl.SDL_Event = undefined;
            while (sdl.SDL_PollEvent(&ev)) {
                if (ev.type == sdl.SDL_EVENT_QUIT) {
                    std.debug.print("Exit{s}", .{"!\n"});
                    return;
                }
                if (ev.type == sdl.SDL_EVENT_KEY_DOWN and !ev.key.repeat and ev.key.scancode == sdl.SDL_SCANCODE_GRAVE) {
                    self.shell.toggle_onoff();
                    continue;
                }
                if (event_count < events.len) {
                    events[event_count] = ev;
                    event_count += 1;
                }
            }

            //self.clear_screen();
            self.draw(events[0..event_count]);
            self.gfx_sys.draw();
        }
    }

    /// Renders visible tiles and events for the current camera position.
    fn draw(self: *@This(), events: []const sdl.SDL_Event) void {
        const time_sdl: f32 = @floatFromInt(gfx.sdl.SDL_GetTicks());
        const time_elapsed = time_sdl * 0.001; // in seconds

        self.handle_inputs();

        const w_2: f32 = @floatFromInt(@divTrunc(self.scr_w, 2));
        const h_2: f32 = @floatFromInt(@divTrunc(self.scr_h, 2));
        const cx: f32 = @floatFromInt(self.cam_pos.x);
        const cy: f32 = @floatFromInt(self.cam_pos.y);

        const base_off_x = @max(0, cx - w_2);
        const base_off_y = @max(0, cy - h_2);

        var numi: i32 = self.level.layers.len - 1;
        while (numi >= 0) : (numi -= 1) {
            const num: usize = @intCast(numi);
            const layer = &self.level.layers[num];
            if (layer.cells == null) continue;
            const cells = layer.cells.?;

            // Apply auto-scrolling
            layer.offset_x += layer.auto_speed_x * time_elapsed;
            layer.offset_y += layer.auto_speed_y * time_elapsed;

            // Compute layer-specific camera offset (parallax)
            const layer_off_x = base_off_x * layer.speed_x + layer.offset_x;
            const layer_off_y = base_off_y * layer.speed_y + layer.offset_y;

            const tile_size_f: f32 = @floatFromInt(TileCoord.SIZE);
            const scr_w_f: f32 = @floatFromInt(self.scr_w);
            const scr_h_f: f32 = @floatFromInt(self.scr_h);

            // Compute visible tile range for this layer
            const tile_start_x: i32 = @intFromFloat(@floor(layer_off_x / tile_size_f));
            const tile_start_y: i32 = @intFromFloat(@floor(layer_off_y / tile_size_f));
            const tile_end_x: i32 = @intFromFloat(@ceil((layer_off_x + scr_w_f) / tile_size_f));
            const tile_end_y: i32 = @intFromFloat(@ceil((layer_off_y + scr_h_f) / tile_size_f));

            const layer_w: i32 = @intCast(layer.width);
            const layer_h: i32 = @intCast(layer.height);
            const off_x_int: i32 = @intFromFloat(@floor(layer_off_x));
            const off_y_int: i32 = @intFromFloat(@floor(layer_off_y));

            // First pass: render tiles
            {
                const tile_size_i32: i32 = @intCast(TileCoord.SIZE);
                var ty: i32 = tile_start_y;
                while (ty < tile_end_y) : (ty += 1) {
                    var tx: i32 = tile_start_x;
                    while (tx < tile_end_x) : (tx += 1) {
                        const tile_x = if (layer.flags.repeat_x) @mod(tx, layer_w) else tx;
                        const tile_y = if (layer.flags.repeat_y) @mod(ty, layer_h) else ty;

                        if (tile_x < 0 or tile_x >= layer_w or tile_y < 0 or tile_y >= layer_h) continue;

                        const maybe_lev_tile = cells[@as(usize, @intCast(tile_y))][@as(usize, @intCast(tile_x))].tile;
                        if (maybe_lev_tile) |lev_tile| {
                            const sx = tx * tile_size_i32 - off_x_int;
                            const sy = ty * tile_size_i32 - off_y_int;

                            if (sx + tile_size_i32 < 0 or sx > self.scr_w) continue;
                            if (sy + tile_size_i32 < 0 or sy > self.scr_h) continue;

                            const idd = lev_tile.id;
                            const asset_tile = switch (idd) {
                                assets.TileId.static_tile => |id| self.tileset.tiles[id],
                                assets.TileId.anim_tile => |id| blk: {
                                    const anim = self.level.animated_tiles[id];
                                    const frame_no = g_anim.calc_curr_frame(time_elapsed, anim.frame_count, anim.speed, anim.is_ping_pong);
                                    const frame_id = anim.frames[frame_no];
                                    break :blk self.tileset.tiles[frame_id];
                                },
                            };
                            self.render_tex(asset_tile.texture, self.palettes[0], sx, sy);
                        }
                    }
                }
            }

            // Second pass: render events (only layer 3)
            if (num == 3) {
                const tile_size_i32: i32 = @intCast(TileCoord.SIZE);
                var ty: i32 = tile_start_y;
                while (ty < tile_end_y) : (ty += 1) {
                    if (ty < 0 or ty >= layer_h) continue;
                    var tx: i32 = tile_start_x;
                    while (tx < tile_end_x) : (tx += 1) {
                        if (tx < 0 or tx >= layer_w) continue;
                        if (cells[@as(usize, @intCast(ty))][@as(usize, @intCast(tx))].event) |ev| {
                            const sx = tx * tile_size_i32 - off_x_int;
                            const sy = ty * tile_size_i32 - off_y_int;

                            var palette_id: usize = 0;
                            if (@intFromEnum(ev.id) >= @intFromEnum(asset_maps.EventId.RedGemPlus1) and @intFromEnum(ev.id) <= @intFromEnum(asset_maps.EventId.PurpleGemPlus1)) {
                                palette_id = @intFromEnum(ev.id) - @intFromEnum(asset_maps.EventId.RedGemPlus1) + 1;
                            }
                            if (asset_maps.event2animsetinxd(ev.id)) |anim| {
                                const a = &self.animset.blocks[anim.animblock].anims[anim.anim];
                                const frame = g_anim.calc_curr_frame_for_anim(time_elapsed * 10.0, a);
                                const obj = a.frames[frame];
                                self.render_tex(obj.texture, self.palettes[palette_id], sx + obj.hotspotX + 16, sy + obj.hotspotY + 16);
                            }
                        }
                    }
                }
            }
        }
        self.shell.render_shell(events);

        // FPS counter (top-right corner)
        {
            const now_ms = gfx.sdl.SDL_GetTicks();
            const elapsed_ms = now_ms - self.last_fps_time;
            self.frame_count += 1;

            if (elapsed_ms >= 1000) {
                self.fps = @as(i32, @intCast(@divTrunc(self.frame_count * 1000, @max(elapsed_ms, 1))));
                self.frame_count = 0;
                self.last_fps_time = now_ms;
            }

            if (self.fps != self.last_rendered_fps) {
                if (self.fps_text_tex) |tex| {
                    tex.deinit();
                    self.fps_text_tex = null;
                }
                self.last_rendered_fps = self.fps;
            }

            if (self.fps > 0 and self.fps_text_tex == null) {
                const text = std.fmt.allocPrint(self.allocator, "FPS: {d}", .{self.fps}) catch unreachable;
                defer self.allocator.free(text);

                self.fps_text_tex = gfx.text_sdl.renderText(
                    self.allocator,
                    self.shell.font,
                    text,
                    sdl.SDL_Color{ .r = 255, .g = 255, .b = 255, .a = 255 },
                ) catch unreachable;
            }

            if (self.fps_text_tex) |tex| {
                const x = @as(f32, @floatFromInt(self.scr_w)) - @as(f32, @floatFromInt(tex.w)) - 10.0;
                const pos = gfx.math.Vec2.init(x, 10.0);
                self.renderer.draw(tex, pos, gfx.math.Vec3.init(1.0, 1.0, 1.0));
            }
        }
    }

    /// Draws a texture (indexed or direct RGBA) at the given screen position.
    fn render_tex(self: DiagLevel, tex: assets.Texture, palette: ?gfx.gl_utils.Texture1D, x: i32, y: i32) void {
        const position = gfx.math.Vec2.init(@floatFromInt(x), @floatFromInt(y));
        const color = gfx.math.Vec3.init(1.0, 1.0, 1.0);
        switch (tex) {
            .texture2d => |t| self.renderer.draw(t, position, color),
            .texture2dind => |t| self.renderer_ind.draw(t, palette.?, position, color),
        }
    }

    /// Moves the camera based on arrow key input.
    fn handle_inputs(self: *DiagLevel) void {
        const speed: u32 = 16;
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

    /// Clears the screen with a time-varying rainbow color.
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

    /// Returns the visible world rectangle centered on the camera position.
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

    /// Converts a world coordinate to a screen coordinate based on camera offset.
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

/// Console command to display debug info (e.g. camera position).
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
