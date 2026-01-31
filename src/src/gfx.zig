pub const sdl = @cImport({
    @cInclude("SDL3/SDL.h");
    @cInclude("SDL3_ttf/SDL_ttf.h");
});
const std = @import("std");

var g_sdl_window: ?*sdl.SDL_Window = undefined;
var g_sdl_renderer: ?*sdl.SDL_Renderer = undefined;
var g_is_running = true;
var g_screen_w: c_int = 1400;
var g_screen_h: c_int = 800;

var g_sdl_events: std.array_list.Managed(sdl.SDL_Event) = undefined;
var g_alloc = std.heap.GeneralPurposeAllocator(.{}){};

pub fn screen_res() struct {w: usize, h: usize} {
    return .{.w = @intCast(g_screen_w), .h = @intCast(g_screen_h)};
}

pub fn get_renderer() *sdl.SDL_Renderer {
    return g_sdl_renderer.?;
}

pub fn get_window() *sdl.SDL_Window {
    return g_sdl_window.?;
}

pub fn init() !void {
    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO | sdl.SDL_INIT_AUDIO)) {
        std.debug.print("SDL init failed: {s}\n", .{sdl.SDL_GetError()});
        return error.InitFailed;
    }

    _ = sdl.TTF_Init();

    g_sdl_events = .init(g_alloc.allocator());
}

pub fn init_window() void {
     const r = sdl.SDL_CreateWindowAndRenderer(
        "OpenJazz", 
        g_screen_w, g_screen_h, 
        sdl.SDL_WINDOW_RESIZABLE, // | sdl.SDL_WINDOW_OPENGL | sdl.SDL_WINDOW_TRANSPARENT,
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

    // if (!sdl.SDL_SetRenderDrawBlendMode(g_sdl_renderer, sdl.SDL_BLENDMODE_BLEND)) {
    //     std.debug.print("{s} failed", .{"SetRenderDrawBlendMode"});
    // }
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
        g_sdl_events.append(sdl_event) catch {};
    }
}

pub fn get_events() []const sdl.SDL_Event {
    return g_sdl_events.items[0..];
}

pub fn render() void {
    _ = sdl.SDL_RenderPresent(g_sdl_renderer);
    g_sdl_events.clearRetainingCapacity();
}

pub const Sprite = struct {
    texture: *sdl.SDL_Texture,
    w: usize,
    h: usize,

    pub fn init_from_rgba(buf: []const u8, w: usize, h: usize) !Sprite {
        const surface = sdl.SDL_CreateSurfaceFrom(
            @intCast(w), @intCast(h),
            sdl.SDL_PIXELFORMAT_RGBA32,
            @constCast(buf.ptr),
            @intCast(w * 4)
        );
        defer sdl.SDL_DestroySurface(surface);
        var r:  Sprite = undefined;
        r.texture = sdl.SDL_CreateTextureFromSurface(g_sdl_renderer, surface);
    //     r.texture = sdl.SDL_CreateTexture(
    //         g_sdl_renderer,
    //         sdl.SDL_PIXELFORMAT_RGBA32,
    //         sdl.SDL_TEXTUREACCESS_STATIC,
    //         @intCast(w), @intCast(h)
    // );
        // _ = sdl.SDL_UpdateTexture(r.texture, null, surface.*.pixels, surface.*.pitch);
        // _ = sdl.SDL_SetTextureBlendMode(r.texture, sdl.SDL_BLENDMODE_BLEND);
        r.w = w;
        r.h = h;

        return r;
    }

    pub fn draw(self: Sprite, x: usize, y: usize) void {

        const dst: sdl.SDL_FRect = .{
            .x =  @floatFromInt(x),
            .y = @floatFromInt(y),
            .w = @floatFromInt(self.w),
            .h = @floatFromInt(self.h),
        };
        _ = sdl.SDL_RenderTexture(g_sdl_renderer, self.texture, null, &dst);
    }

    pub fn draw_i32(self: Sprite, x: i32, y: i32) void {

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

pub const IndexedSprite = struct {
    pixels: []const u8,
    surface: *sdl.SDL_Surface,
    w: usize,
    h: usize,
   
    pub fn init(allocator: std.mem.Allocator, 
        w: usize, h: usize, indexes: []const u8) !IndexedSprite {
        const pixels: [] u8 = try allocator.alloc(u8, w * h);
        @memcpy(pixels, indexes);

        const surface = sdl.SDL_CreateSurfaceFrom(@intCast(w), @intCast(h), 
                sdl.SDL_PIXELFORMAT_INDEX8,
                @constCast(pixels.ptr),
                @intCast(w))
            orelse return error.SurfaceCreateFailed;
        // needed for transparency
        _ = sdl.SDL_SetSurfaceBlendMode(surface, sdl.SDL_BLENDMODE_BLEND);
        const ret: IndexedSprite = .{
            .pixels = pixels,
            .surface = surface,
            .w = w,
            .h = h,
        };
        return ret;
    }

    pub fn set_palette(self: IndexedSprite, palette: [256]u32) !void {
        const pal = sdl.SDL_CreatePalette(256) orelse return error.PaletteCreateFailed;
        defer sdl.SDL_DestroyPalette(pal);

        var colors: [256]sdl.SDL_Color = undefined;
        for (palette, 0..) |c, i| {
            // colors[i] = c;
            colors[i].r = @intCast((c >> 24) & 0xff);
            colors[i].g = @intCast((c >> 16) & 0xff);
            colors[i].b = @intCast((c >> 8) & 0xff);
            colors[i].a = @intCast(c & 0xff);
        }

        if (!sdl.SDL_SetPaletteColors(pal, &colors, 0, 256)) return error.PaletteSetFailed;
        if (!sdl.SDL_SetSurfacePalette(self.surface, pal)) return error.SetSurfacePaletteFailed;
        
    }

    pub fn to_sprite(self: IndexedSprite) !Sprite {
        return .{
            .texture = sdl.SDL_CreateTextureFromSurface(g_sdl_renderer, self.surface) orelse
                return error.TextureCreateFailed,
            .w = self.w,
            .h = self.h,
        };
    }

    pub fn to_sprite_debug(self: IndexedSprite) !Sprite {
        self.print_pixels();       
        return .{
            .texture = sdl.SDL_CreateTextureFromSurface(g_sdl_renderer, self.surface) orelse
                return error.TextureCreateFailed,
            .w = self.w,
            .h = self.h,
        };
    }

    pub fn deinit(self: IndexedSprite, allocator: std.mem.Allocator) void {
        sdl.SDL_DestroySurface(self.surface); 
        allocator.free(self.pixels); 
    }

    pub fn print_pixels(self: IndexedSprite) void {
        const w = self.surface.w;
        const h = self.surface.h;
        const pitch = self.surface.pitch;

        const format = self.surface.format;
        std.debug.print("Surface: {d}x{d}, pitch={d}, format={d}\n", .{ w, h, pitch, format });

        const pixels_ptr: [*]u8 = @ptrCast(self.surface.pixels);
        switch (format) {
            sdl.SDL_PIXELFORMAT_INDEX8 => {
                for (0..@intCast(h)) |y| {
                    const row = pixels_ptr[y * @as(usize, @intCast(pitch)) .. y * @as(usize, @intCast(pitch)) + @as(usize, @intCast(w))];
                    std.debug.print("{d}: ", .{ y });
                    for (row) |val| {
                        std.debug.print("{X} ", .{ val });
                    }
                    std.debug.print("\n", .{});
                }
            },
            sdl.SDL_PIXELFORMAT_ARGB8888, sdl.SDL_PIXELFORMAT_RGBA8888, sdl.SDL_PIXELFORMAT_ABGR8888 => {
                const pixels32: [*]u32 = @ptrCast(@alignCast(self.surface.pixels));
                for (0..@intCast( h)) |y| {
                    const row_start = (y * @as(usize, @intCast(pitch))) / 4; // 4 bytes per pixel
                    std.debug.print("{d}: ", .{ y });
                    for (0..@intCast( w)) |x| {
                        const color = pixels32[row_start + x];
                        std.debug.print("0x{X} ", .{ color });
                    }
                    std.debug.print("\n", .{});
                }
            },
            else => {
                std.debug.print("Unsupported pixel format: {d}\n", .{ format });
            },
        }

    }
};

pub fn get_ticks() f32 {
    return @floatFromInt(sdl.SDL_GetTicks());
}

pub fn clean_screen(r: f32, g: f32, b: f32) void {
    _ = sdl.SDL_SetRenderDrawColorFloat(g_sdl_renderer, r, g, b, sdl.SDL_ALPHA_OPAQUE_FLOAT); 
    _ = sdl.SDL_RenderClear(g_sdl_renderer);
}

pub fn deinit() void {
    sdl.TTF_Quit();
    if (g_sdl_renderer != null) {
        sdl.SDL_DestroyRenderer(g_sdl_renderer);
    }
    if (g_sdl_window != null) {
        sdl.SDL_DestroyWindow(g_sdl_window);
    }
    sdl.SDL_Quit();

    g_sdl_events.deinit();
}

fn test_audio(sample_rate: u32, data: []const u8) void {
    // ... prerequisite: initialize SDL with SDL_Init(SDL_INIT_AUDIO);
    const bytesPerSample = 1; //???
    var spec: sdl.SDL_AudioSpec = undefined;
    spec.freq = sample_rate;
    spec.format = if (bytesPerSample == 1) sdl.SDL_AUDIO_U8 else sdl.SDL_AUDIO_S16LSB;
    spec.channels = 1;
    spec.samples = 4096; // buffer size, can be tuned

    const dev: sdl.SDL_AudioDeviceID = sdl.SDL_OpenAudioDevice(&spec, null) orelse return;
    // if (dev == 0) {
    //     // handle error
    // }

    sdl.SDL_QueueAudio(dev, data, data.len);
    sdl.SDL_ResumeAudioDevice(dev);

    // Wait until done (or use a callback/event)
    sdl.SDL_Delay((data.len * 1000) / (sample_rate * bytesPerSample));

    // Cleanup
    sdl.SDL_CloseAudioDevice(dev);
}
