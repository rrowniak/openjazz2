const std = @import("std");
const gfx = @import("root.zig");
const sdl = gfx.sdl;
const gl_utils = gfx.gl_utils;

/// Renders a text string using SDL_ttf into an RGBA OpenGL texture.
/// The caller owns the returned Texture2D and must call `.deinit()` on it.
pub fn renderText(alloc: std.mem.Allocator, font: *sdl.TTF_Font, text: []const u8, color: sdl.SDL_Color) !gl_utils.Texture2D {
    const surface = sdl.TTF_RenderText_Blended(
        font,
        text.ptr,
        text.len,
        color,
    ) orelse return error.TextRenderingFailed;
    defer sdl.SDL_DestroySurface(surface);

    const rgba = sdl.SDL_ConvertSurface(surface, sdl.SDL_PIXELFORMAT_RGBA32) orelse return error.TextRenderingFailed;
    defer sdl.SDL_DestroySurface(rgba);

    const w: usize = @intCast(rgba.*.w);
    const h: usize = @intCast(rgba.*.h);
    const pitch: usize = @intCast(rgba.*.pitch);
    const src: [*]u8 = @ptrCast(rgba.*.pixels);

    const pixels = try alloc.alloc(u8, w * h * 4);
    defer alloc.free(pixels);

    {
        var row: usize = 0;
        while (row < h) : (row += 1) {
            const src_row = src[row * pitch .. row * pitch + w * 4];
            const dst_row = pixels[row * w * 4 .. (row + 1) * w * 4];
            @memcpy(dst_row, src_row);
        }
    }

    return try gl_utils.Texture2D.init_from_rgba(pixels, w, h);
}
