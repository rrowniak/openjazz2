const std = @import("std");
const app = @import("app.zig");
const assets = @import("assets.zig");
const asset_reader = @import("assets_reader.zig");
const gfx = @import("gfx");
const sdl = gfx.sdl;
const console = @import("console.zig");
const utils = @import("utils").utils;
const m = @import("g_math.zig");
const level_view = @import("level_view.zig");
const WorldCoord = m.WorldCoord;
const TileCoord = m.TileCoord;

pub const DiagLevel = struct {
    allocator: std.mem.Allocator,
    gfx_sys: gfx.sys,
    shell: console.Console,
    level_view: level_view.LevelView,
    level: assets.Level,
    tileset: assets.Tileset,
    animset: assets.Animset,
    palettes: [5]gfx.gl_utils.Texture1D,
    scr_w: i32,
    scr_h: i32,
    cam_pos: WorldCoord,
    fps_counter: gfx.fps.FpsCounter,
    show_collision_mask: bool = false,

    pub fn init(alloc: std.mem.Allocator, j2l_path: []const u8) !DiagLevel {
        const scr_w: i32 = 1400;
        const scr_h: i32 = 800;
        const gfx_sys: gfx.sys = try .init("Jazz2", scr_w, scr_h);

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

        return .{
            .allocator = alloc,
            .gfx_sys = gfx_sys,
            .shell = shell,
            .level_view = lv,
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
            .fps_counter = .init(),
        };
    }

    fn deinit(ctx: *anyopaque) void {
        const self: *DiagLevel = @ptrCast(@alignCast(ctx));

        for (self.palettes) |p| p.deinit();
        self.fps_counter.deinit();
        self.level_view.deinit();
        self.tileset.deinit();
        self.animset.deinit();
        self.level.deinit();
        self.shell.deinit();
        self.gfx_sys.deinit();
    }

    pub fn app_cast(self: *DiagLevel) app.IApp {
        self.shell.register_cmd("show", show_cmd, self);
        self.shell.register_cmd("hide", hide_cmd, self);
        return .{ .ptr = self, .vtable = &.{
            .run = run,
            .deinit = deinit,
        } };
    }

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

            self.draw(events[0..event_count]);
            self.gfx_sys.draw();
        }
    }

    fn draw(self: *@This(), events: []const sdl.SDL_Event) void {
        const time_sdl: f32 = @floatFromInt(gfx.sdl.SDL_GetTicks());
        const time_elapsed = time_sdl * 0.001;

        self.handle_inputs();

        self.level_view.draw(&self.level, &self.tileset, &self.animset, &self.palettes, self.cam_pos, self.scr_w, self.scr_h, time_elapsed, self.show_collision_mask);

        self.shell.render_shell(events);
        self.fps_counter.tick(self.allocator, self.shell.font, &self.level_view.renderer, self.scr_w);
    }

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

    if (std.mem.eql(u8, subcmd, "mask")) {
        self.tileset.ensure_mask_overlays() catch {
            return alloc.dupe(u8, "Failed to create mask overlays") catch { return null; };
        };
        self.show_collision_mask = true;
        return alloc.dupe(u8, "Collision mask overlay enabled") catch { return null; };
    }

    return std.fmt.allocPrint(alloc, "Unsupported `{s}` argument", .{subcmd}) catch {
        return null;
    };
}

fn hide_cmd(alloc: std.mem.Allocator, ctx: *anyopaque, args: []const u8) ?[]const u8 {
    const self: *DiagLevel = @ptrCast(@alignCast(ctx));
    var it = std.mem.tokenizeScalar(u8, args, ' ');
    _ = it.next();
    const subcmd = it.next() orelse {
        return alloc.dupe(u8, "Missing command argument") catch {
            return null;
        };
    };

    if (std.mem.eql(u8, subcmd, "mask")) {
        self.show_collision_mask = false;
        self.tileset.destroy_mask_overlays();
        return alloc.dupe(u8, "Collision mask overlay disabled") catch { return null; };
    }

    return std.fmt.allocPrint(alloc, "Unsupported `{s}` argument", .{subcmd}) catch {
        return null;
    };
}

test "Coord transformations" {
    const w2t_tc = [_]struct { w: WorldCoord, exp: TileCoord }{
        .{ .w = .{ .x = 0, .y = 0 }, .exp = .{ .x = 0, .y = 0 } },
        .{ .w = .{ .x = 32, .y = 32 }, .exp = .{ .x = 1, .y = 1 } },
        .{ .w = .{ .x = 64, .y = 64 }, .exp = .{ .x = 2, .y = 2 } },
        .{ .w = .{ .x = 50, .y = 66 }, .exp = .{ .x = 1, .y = 2 } },
    };

    for (w2t_tc) |tc| {
        const w = tc.w;
        const t = TileCoord.init_from_world(w);
        try std.testing.expectEqual(tc.exp.x, t.x);
        try std.testing.expectEqual(tc.exp.y, t.y);
    }
}
