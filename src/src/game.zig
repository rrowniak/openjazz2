const std = @import("std");
const app = @import("app.zig");

const gfx = @import("gfx");
const sdl = gfx.sdl;

/// High-level states the game can be in during its lifetime.
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

    pub fn init(alloc: std.mem.Allocator) !Game {
        const gfx_sys: gfx.sys = try .init("Jazz Jackrabbit 2", 1400, 800);
        return .{
            .allocator = alloc,
            .state = .menu,
            .gfx_sys = gfx_sys,
        };
    }

    pub fn app_cast(self: *Game) app.IApp {
        return .{ .ptr = self, .vtable = &.{
            .run = run,
            .deinit = deinit,
        } };
    }

    fn run(ctx: *anyopaque) void {
        const self: *Game = @ptrCast(@alignCast(ctx));

        while (true) {
            var ev: sdl.SDL_Event = undefined;
            while (sdl.SDL_PollEvent(&ev)) {
                switch (ev.type) {
                    sdl.SDL_EVENT_QUIT => return,
                    else => {},
                }
            }
            self.gfx_sys.draw();
        }
    }

    fn deinit(ctx: *anyopaque) void {
        const self: *Game = @ptrCast(@alignCast(ctx));
        self.gfx_sys.deinit();
    }
};
