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
const context = @import("ctx.zig");
const level_view = @import("level_view.zig");
const player_module = @import("player.zig");
const collision = @import("collision.zig");
const g_anim = @import("g_anim.zig");
const sound = @import("sound.zig");
const enemy_module = @import("enemy.zig");

pub const State = enum {
    menu,
    loading,
    playing,
    paused,
    level_complete,
    game_over,
};

pub const Game = struct {
    allocator: std.mem.Allocator,
    state: State,
    gfx_sys: gfx.sys,
    shell: console.Console,
    level_view: level_view.LevelView,
    level: assets.Level,
    tileset: assets.Tileset,
    animset: assets.Animset,
    palettes: [5]gfx.gl_utils.Texture1D,
    scr_w: i32,
    scr_h: i32,
    fps_counter: gfx.fps.FpsCounter,
    player: player_module.Player,
    enemies: std.ArrayList(enemy_module.Enemy),
    collision_sys: collision.CollisionSystem,
    prev_tick: u32,
    gctx: context.GameContext,
    sound_mgr: sound.SoundManager,

    pub fn init(alloc: std.mem.Allocator, j2l_path: []const u8) !Game {
        const scr_w: i32 = 1400;
        const scr_h: i32 = 800;
        const gfx_sys: gfx.sys = try .init("Jazz Jackrabbit 2", scr_w, scr_h);

        var shell = try console.Console.init(alloc, gfx_sys.sdl_window.?, @floatFromInt(scr_w), @floatFromInt(scr_h));
        shell.rect = .{ .x = 0, .y = 0, .w = @floatFromInt(scr_w), .h = @as(f32, @floatFromInt(scr_h)) / 2 };

        var level: assets.Level = try asset_reader.load_level(alloc, j2l_path);
        errdefer level.deinit();

        const dir = std.fs.path.dirname(j2l_path) orelse "";
        const tileset_path = try utils.find_file_case_insensitive(alloc, dir, std.mem.sliceTo(&level.tileset_name, 0));
        defer alloc.free(tileset_path);
        var tileset: assets.Tileset = try asset_reader.load_tileset(alloc, tileset_path);
        errdefer tileset.deinit();

        const animset_path = try utils.find_file_case_insensitive(alloc, dir, "Anims.j2a");
        defer alloc.free(animset_path);
        var animset = try asset_reader.load_animset(alloc, animset_path);
        errdefer animset.deinit();

        const lv = try level_view.LevelView.init(scr_w, scr_h);

        const palettes = [_]gfx.gl_utils.Texture1D{
            try .init_from_palette_rgba(&tileset.palette),
            try .init_from_palette_rgba(assets.generate_palette(.red_gem)),
            try .init_from_palette_rgba(assets.generate_palette(.green_gem)),
            try .init_from_palette_rgba(assets.generate_palette(.blue_gem)),
            try .init_from_palette_rgba(assets.generate_palette(.purple_gem)),
        };

        const start_pos = find_start_position(&level);
        const player = player_module.Player.init(start_pos.player_type orelse .Jazz, start_pos.x, start_pos.y);

        var game: Game = .{
            .allocator = alloc,
            .state = .playing,
            .gfx_sys = gfx_sys,
            .shell = shell,
            .level_view = lv,
            .level = level,
            .tileset = tileset,
            .animset = animset,
            .palettes = palettes,
            .scr_w = scr_w,
            .scr_h = scr_h,
            .player = player,
            .enemies = .empty,
            .prev_tick = @intCast(gfx.sdl.SDL_GetTicks()),
            .fps_counter = .init(),
            .sound_mgr = undefined,
            .collision_sys = undefined,
            .gctx = .{
                .draw_ctx = undefined,
                .cam_pos = .{
                    .x = @intFromFloat(start_pos.x),
                    .y = @intFromFloat(start_pos.y),
                },
                .show_collision_mask = false,
                .show_aabb = false,
            },
        };

        game.collision_sys = try collision.CollisionSystem.init(
            alloc,
            &game.level.layers[3],
            &game.tileset,
            &game.animset,
            game.level.animated_tiles,
            game.level.layers[3].width,
            game.level.layers[3].height,
        );

        game.sound_mgr = try sound.SoundManager.init(alloc);

        const music_basename = std.mem.sliceTo(&level.music_file_name, 0);
        if (music_basename.len > 0) {
            const music_name = try std.fmt.allocPrint(alloc, "{s}.j2b", .{music_basename});
            defer alloc.free(music_name);
            const music_path = utils.find_file_case_insensitive(alloc, dir, music_name) catch null;
            if (music_path) |mp| {
                defer alloc.free(mp);
                const music_data = utils.read_file_to_buff(alloc, mp) catch null;
                if (music_data) |md| {
                    defer alloc.free(md);
                    game.sound_mgr.begin_play_music(md) catch {};
                }
            }
        }

        {
            const event_layer = &game.level.layers[3];
            const cells = event_layer.cells.?;
            const tile_size: f32 = @floatFromInt(m.TileCoord.SIZE);
            for (cells, 0..) |row, ty| {
                for (row, 0..) |cell, tx| {
                    if (cell.event) |ev| {
                        if (asset_maps.is_enemy_event(ev.id)) {
                            const x = @as(f32, @floatFromInt(tx)) * tile_size + tile_size / 2;
                            const y = @as(f32, @floatFromInt(ty)) * tile_size + tile_size / 2;
                            if (enemy_module.Enemy.init(ev.id, x, y)) |e| {
                                game.enemies.append(alloc, e) catch {};
                            }
                        }
                    }
                }
            }
        }

        return game;
    }

    pub fn app_cast(self: *Game) app.IApp {
        self.shell.register_cmd("show", show_cmd, self);
        self.shell.register_cmd("hide", hide_cmd, self);
        return .{ .ptr = self, .vtable = &.{
            .run = run,
            .deinit = deinit,
        } };
    }

    fn deinit(ctx: *anyopaque) void {
        const self: *Game = @ptrCast(@alignCast(ctx));

        for (self.palettes) |p| p.deinit();
        self.fps_counter.deinit();
        self.level_view.deinit();
        self.tileset.deinit();
        self.animset.deinit();
        self.level.deinit();
        self.collision_sys.deinit();
        self.enemies.deinit(self.allocator);
        self.sound_mgr.deinit();
        self.shell.deinit();
        self.gfx_sys.deinit();
    }

    fn run(ctx: *anyopaque) void {
        const self: *Game = @ptrCast(@alignCast(ctx));

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

            self.update(events[0..event_count]);
            self.gfx_sys.draw();
        }
    }

    fn update(self: *@This(), events: []const sdl.SDL_Event) void {
        const tick: u64 = gfx.sdl.SDL_GetTicks();
        const tick32: u32 = @intCast(tick);
        const time_elapsed: f32 = @as(f32, @floatFromInt(tick32)) * 0.001;
        const dt: f32 = @as(f32, @floatFromInt(tick32 - self.prev_tick)) * 0.001;
        self.prev_tick = tick32;

        switch (self.state) {
            .playing => {
                const keyboard = sdl.SDL_GetKeyboardState(null);

                // Refresh collision_sys pointers — Game was moved after init,
                // so all pointers captured during CollisionSystem.init point
                // to the old stack frame.
                self.collision_sys.action_layer = &self.level.layers[3];
                self.collision_sys.tileset = &self.tileset;
                self.collision_sys.animset = &self.animset;
                self.collision_sys.animated_tiles = self.level.animated_tiles;
                self.collision_sys.time_elapsed = time_elapsed;
                self.player.update(dt, keyboard, &self.collision_sys);

                for (self.enemies.items) |*e| {
                    e.update(dt, &self.collision_sys);
                }

                self.gctx.draw_ctx = .{
                    .tileset = &self.tileset,
                    .animset = &self.animset,
                    .palettes = &self.palettes,
                    .scr_w = self.scr_w,
                    .scr_h = self.scr_h,
                };
                const cam_to_x: u32 = @intFromFloat(@max(0.0, self.player.pos_x));
                const cam_to_y: u32 = @intFromFloat(@max(0.0, self.player.pos_y));
                const w2: u32 = @intCast(@divTrunc(self.gctx.draw_ctx.scr_w, 2));
                const h2: u32 = @intCast(@divTrunc(self.gctx.draw_ctx.scr_h, 2));
                self.gctx.cam_pos.x = @max(w2, cam_to_x);
                self.gctx.cam_pos.y = @max(h2, cam_to_y);

                self.level_view.draw(&self.level, &self.gctx, time_elapsed, self.level.layers.len - 1, 3);

                self.player.draw(
                    &self.level_view.renderer,
                    &self.level_view.renderer_ind,
                    &self.gctx,
                );

                for (self.enemies.items) |*e| {
                    e.draw(
                        &self.level_view.renderer,
                        &self.level_view.renderer_ind,
                        &self.gctx,
                    );
                }

                if (self.gctx.show_aabb) {
                    const anim = &self.animset.blocks[self.player.anim_block].anims[self.player.anim_id];
                    if (anim.frames.len > 0) {
                        const frame_no = g_anim.calc_curr_frame_for_anim(self.player.anim_elapsed, anim);
                        const frame = anim.frames[frame_no];
                        const aabb = collision.frame_aabb(self.player.pos_x, self.player.pos_y, frame);
                        self.level_view.draw_aabb(aabb, &self.gctx);
                    }
                }

                self.level_view.draw(&self.level, &self.gctx, time_elapsed, 2, 0);
            },
            else => {},
        }

        self.sound_mgr.update();
        self.shell.render_shell(events);
        self.fps_counter.tick(self.allocator, self.shell.font, &self.level_view.renderer, self.scr_w);
    }
};

const StartPos = struct {
    x: f32,
    y: f32,
    player_type: ?player_module.PlayerType,
};

fn find_start_position(level: *const assets.Level) StartPos {
    const tile_size: f32 = @floatFromInt(m.TileCoord.SIZE);
    for (&level.layers) |*layer| {
        const cells = layer.cells orelse continue;
        for (cells, 0..) |row, ty| {
            for (row, 0..) |cell, tx| {
                if (cell.event) |ev| {
                    if (player_module.Player.start_tile(ev.id)) |pt| {
                        return .{
                            .x = @as(f32, @floatFromInt(tx)) * tile_size + tile_size / 2,
                            .y = @as(f32, @floatFromInt(ty)) * tile_size + tile_size / 2,
                            .player_type = pt,
                        };
                    }
                }
            }
        }
    }
    return .{ .x = 100, .y = 100, .player_type = .Jazz };
}

fn show_cmd(alloc: std.mem.Allocator, ctx: *anyopaque, args: []const u8) ?[]const u8 {
    const self: *Game = @ptrCast(@alignCast(ctx));
    var it = std.mem.tokenizeScalar(u8, args, ' ');
    _ = it.next();
    const subcmd = it.next() orelse {
        return alloc.dupe(u8, "Missing command argument") catch { return null; };
    };

    if (std.mem.eql(u8, subcmd, "mask")) {
        self.tileset.ensure_mask_overlays() catch {
            return alloc.dupe(u8, "Failed to create mask overlays") catch { return null; };
        };
        self.gctx.show_collision_mask = true;
        return alloc.dupe(u8, "Collision mask overlay enabled") catch { return null; };
    }

    if (std.mem.eql(u8, subcmd, "aabb")) {
        self.gctx.show_aabb = true;
        return alloc.dupe(u8, "Player AABB overlay enabled") catch { return null; };
    }

    return std.fmt.allocPrint(alloc, "Unsupported `{s}` argument", .{subcmd}) catch { return null; };
}

fn hide_cmd(alloc: std.mem.Allocator, ctx: *anyopaque, args: []const u8) ?[]const u8 {
    const self: *Game = @ptrCast(@alignCast(ctx));
    var it = std.mem.tokenizeScalar(u8, args, ' ');
    _ = it.next();
    const subcmd = it.next() orelse {
        return alloc.dupe(u8, "Missing command argument") catch { return null; };
    };

    if (std.mem.eql(u8, subcmd, "mask")) {
        self.gctx.show_collision_mask = false;
        self.tileset.destroy_mask_overlays();
        return alloc.dupe(u8, "Collision mask overlay disabled") catch { return null; };
    }

    if (std.mem.eql(u8, subcmd, "aabb")) {
        self.gctx.show_aabb = false;
        return alloc.dupe(u8, "Player AABB overlay disabled") catch { return null; };
    }

    return std.fmt.allocPrint(alloc, "Unsupported `{s}` argument", .{subcmd}) catch { return null; };
}
