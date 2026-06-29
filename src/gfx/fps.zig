const std = @import("std");
const gfx = @import("root.zig");
const sdl = gfx.sdl;

pub const FpsCounter = struct {
    frame_count: u32,
    last_fps_time: u64,
    fps: i32,
    text_tex: ?gfx.gl_utils.Texture2D,
    last_rendered_fps: i32,

    pub fn init() FpsCounter {
        return .{
            .frame_count = 0,
            .last_fps_time = 0,
            .fps = 0,
            .text_tex = null,
            .last_rendered_fps = -1,
        };
    }

    pub fn deinit(self: *@This()) void {
        if (self.text_tex) |tex| tex.deinit();
    }

    pub fn tick(
        self: *@This(),
        allocator: std.mem.Allocator,
        font: *sdl.TTF_Font,
        renderer: *gfx.gl_utils.SpriteRenderer,
        scr_w: i32,
    ) void {
        const now_ms = gfx.sdl.SDL_GetTicks();
        const elapsed_ms = now_ms - self.last_fps_time;
        self.frame_count += 1;

        if (elapsed_ms >= 1000) {
            self.fps = @as(i32, @intCast(@divTrunc(self.frame_count * 1000, @max(elapsed_ms, 1))));
            self.frame_count = 0;
            self.last_fps_time = now_ms;
        }

        if (self.fps != self.last_rendered_fps) {
            if (self.text_tex) |tex| {
                tex.deinit();
                self.text_tex = null;
            }
            self.last_rendered_fps = self.fps;
        }

        if (self.fps > 0 and self.text_tex == null) {
            const text = std.fmt.allocPrint(allocator, "FPS: {d}", .{self.fps}) catch unreachable;
            defer allocator.free(text);
            self.text_tex = gfx.text_sdl.renderText(
                allocator,
                font,
                text,
                sdl.SDL_Color{ .r = 255, .g = 255, .b = 255, .a = 255 },
            ) catch unreachable;
        }

        if (self.text_tex) |tex| {
            const x = @as(f32, @floatFromInt(scr_w)) - @as(f32, @floatFromInt(tex.w)) - 10.0;
            const pos = gfx.math.Vec2.init(x, 10.0);
            renderer.draw(tex, pos, gfx.math.Vec3.init(1.0, 1.0, 1.0));
        }
    }
};
