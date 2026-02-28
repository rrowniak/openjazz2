const std = @import("std");
const app = @import("app.zig");

const gfx = @import("gfx");
const sdl = gfx.sdl;
const gl = gfx.gl;

pub const DiagGfx = struct {
    allocator: std.mem.Allocator,
    gfx_sys: gfx.sys,
    const Uniforms = enum { color };

    pub fn init(alloc: std.mem.Allocator) !DiagGfx {
        const gfx_sys: gfx.sys = try .init("Jazz2", 1400, 800);
        const fs = @embedFile("./gfx/glsl/test.frag.glsl");
        const vs = @embedFile("./gfx/glsl/test.vert.glsl");
        _ = try gfx.gl_utils.ShaderProgram(Uniforms).init(vs, fs, null);
        return .{
            .allocator = alloc,
            .gfx_sys = gfx_sys,
        };
    }
    pub fn app_cast(self: *DiagGfx) app.IApp {
        return .{ .ptr = self, .vtable = &.{
            .update = update,
            .deinit = deinit,
        } };
    }

    fn update(ctx: *anyopaque) void {
        const self: *DiagGfx = @ptrCast(@alignCast(ctx));

        // main loop
        while (true) {
            var ev: sdl.SDL_Event = undefined;
            while (sdl.SDL_PollEvent(&ev)) {
                switch (ev.type) {
                    sdl.SDL_EVENT_QUIT => return,
                    else => {},
                }
            }
            gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);
            gl.glClearColor(1.0, 0.0, 1.0, 1.0);
            self.gfx_sys.draw();
        }
    }

    fn deinit(ctx: *anyopaque) void {
        const self: *DiagGfx = @ptrCast(@alignCast(ctx));
        self.gfx_sys.deinit();
    }
};
