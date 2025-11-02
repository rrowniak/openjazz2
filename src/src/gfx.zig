const sdl = @cImport({
    @cInclude("SDL3/SDL.h");
});
const std = @import("std");

var g_sdl_window: ?*sdl.SDL_Window = undefined;
var g_sdl_renderer: ?*sdl.SDL_Renderer = undefined;
var g_is_running = true;
var g_screen_w: c_int = 1400;
var g_screen_h: c_int = 800;

pub fn screen_res() struct {w: usize, h: usize} {
    return .{.w = @intCast(g_screen_w), .h = @intCast(g_screen_h)};
}

pub fn init() !void {
    // std.debug.print("Calling SDL_init...{s}\n", .{"x"});
    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO | sdl.SDL_INIT_AUDIO)) {
        std.debug.print("SDL init failed: {s}\n", .{sdl.SDL_GetError()});
        return error.InitFailed;
    }
}

pub fn init_window() void {
     const r = sdl.SDL_CreateWindowAndRenderer(
        "OpenJazz", 
        g_screen_w, g_screen_h, 
        sdl.SDL_WINDOW_RESIZABLE,
        &g_sdl_window,
        &g_sdl_renderer
    );
    if (!r) {
        std.debug.print("SDL_CreateWindow failed: {s}\n", .{sdl.SDL_GetError()});
    }
    _ = sdl.SDL_SetRenderLogicalPresentation(
        g_sdl_renderer, 
        g_screen_w, g_screen_h, 
        sdl.SDL_LOGICAL_PRESENTATION_LETTERBOX
    );
}

pub fn is_running() bool {
    return g_is_running;
}

pub fn update_frame() void {
    var sdl_event: sdl.SDL_Event = undefined;
    while (sdl.SDL_PollEvent(&sdl_event)) {
        switch (sdl_event.type) {
            sdl.SDL_EVENT_QUIT => g_is_running = false,
            else => {},
        }
    }

    test_();
}

pub fn render() void {
    _ = sdl.SDL_RenderPresent(g_sdl_renderer);
}

pub const Sprite = struct {
    texture: *sdl.SDL_Texture,
    w: usize,
    h: usize,

    pub fn draw(self: Sprite, x: usize, y: usize) void {
        const dst: sdl.SDL_FRect = .{
            .x =  @floatFromInt(x),
            .y = @floatFromInt(y),
            .w = @floatFromInt(self.w),
            .h = @floatFromInt(self.h),
        };
        _ = sdl.SDL_RenderTexture(g_sdl_renderer, self.texture, null, &dst);
    }

    pub fn deinit(self: Sprite) void {
        sdl.SDL_DestroyTexture(self.texture);
    }
};

pub fn create_sprite_from_rgba(buf: []const u8, w: usize, h: usize) !Sprite {
    const surface = sdl.SDL_CreateSurfaceFrom(
        @intCast(w), @intCast(h),
        sdl.SDL_PIXELFORMAT_RGBA32,
        @constCast(buf.ptr),
        @intCast(w * 4)
    );
    defer sdl.SDL_DestroySurface(surface);
    var r:  Sprite = undefined;
    r.texture = sdl.SDL_CreateTextureFromSurface(g_sdl_renderer, surface);
    r.w = w;
    r.h = h;
    return r;
}

fn test_() void {
    const now_: f32 = @floatFromInt(sdl.SDL_GetTicks());
    const now = now_ / 1000.0;
    const red: f32 = @floatCast(0.5 + 0.5 * sdl.SDL_sin(now));
    const green: f32 = @floatCast(0.5 + 0.5 * sdl.SDL_sin(now + sdl.SDL_PI_D * 2 / 3));
    const blue: f32 = @floatCast(0.5 + 0.5 * sdl.SDL_sin(now + sdl.SDL_PI_D * 4 / 3));
    _ = sdl.SDL_SetRenderDrawColorFloat(g_sdl_renderer, red, green, blue, sdl.SDL_ALPHA_OPAQUE_FLOAT); 
    _ = sdl.SDL_RenderClear(g_sdl_renderer);
}

pub fn deinit() void {
    if (g_sdl_renderer != null) {
        sdl.SDL_DestroyRenderer(g_sdl_renderer);
    }
    if (g_sdl_window != null) {
        sdl.SDL_DestroyWindow(g_sdl_window);
    }
    sdl.SDL_Quit();
}
