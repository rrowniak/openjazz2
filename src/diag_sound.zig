const std = @import("std");
const app = @import("app.zig");
const gfx = @import("gfx");
const sdl = gfx.sdl;
const gl = gfx.gl;
const utils = @import("utils").utils;
const sound = @import("sound.zig");

pub const DiagSound = struct {
    allocator: std.mem.Allocator,
    gfx_sys: gfx.sys,
    sound_mgr: sound.SoundManager,

    pub fn init(alloc: std.mem.Allocator, j2b_path: []const u8) !DiagSound {
        const gfx_sys: gfx.sys = try .init("Jazz2 Sound", 640, 480);

        var sound_mgr = try sound.SoundManager.init(alloc);

        const file_data = try utils.read_file_to_buff(alloc, j2b_path);
        defer alloc.free(file_data);
        sound_mgr.begin_play_music(file_data) catch {};

        return .{
            .allocator = alloc,
            .gfx_sys = gfx_sys,
            .sound_mgr = sound_mgr,
        };
    }

    pub fn app_cast(self: *DiagSound) app.IApp {
        return .{ .ptr = self, .vtable = &.{
            .run = run,
            .deinit = deinit,
        } };
    }

    fn run(ctx: *anyopaque) void {
        const self: *DiagSound = @ptrCast(@alignCast(ctx));

        while (true) {
            var ev: sdl.SDL_Event = undefined;
            while (sdl.SDL_PollEvent(&ev)) {
                switch (ev.type) {
                    sdl.SDL_EVENT_QUIT => return,
                    else => {},
                }
            }

            self.clear_screen();
            self.sound_mgr.update();
            self.gfx_sys.draw();
        }
    }

    fn deinit(ctx: *anyopaque) void {
        const self: *DiagSound = @ptrCast(@alignCast(ctx));
        self.sound_mgr.deinit();
        self.gfx_sys.deinit();
    }

    fn clear_screen(self: *DiagSound) void {
        _ = self;
        const now_: f32 = @floatFromInt(sdl.SDL_GetTicks());
        const now = now_ / 1000.0;
        const red: f32 = @floatCast(0.5 + 0.5 * std.math.sin(now));
        const green: f32 = @floatCast(0.5 + 0.5 * std.math.sin(now + std.math.pi * 2.0 / 3.0));
        const blue: f32 = @floatCast(0.5 + 0.5 * std.math.sin(now + std.math.pi * 4.0 / 3.0));

        gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);
        gl.glClearColor(red, green, blue, 1.0);
    }
};
