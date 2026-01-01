const std = @import("std");
const gfx = @import("gfx.zig");
const sdl = gfx.sdl;

pub const VarPtr = union(enum) {
    usize_ptr: *usize,
};

const FONT_PATH = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf";

pub const Console = struct {
    alloc: std.mem.Allocator,
    variables: std.StringHashMap(VarPtr),
    enabled: bool = false,
    // graphics
    rect: sdl.SDL_FRect = .{ .x= 0, .y = 0, .w = 800, .h = 600},
    bg_color: sdl.SDL_Color = .{ .r = 0, .g = 0, .b = 0, .a = 200 },
    font: *sdl.TTF_Font,
    line_height: f32 = 16,
    lines: []const []const u8,

    pub fn init(alloc: std.mem.Allocator) !@This() {
        return .{
            .alloc = alloc,
            .variables = .init(alloc),
            .font = sdl.TTF_OpenFont(FONT_PATH, 14) orelse return error.FontLoadFailed,
            .lines = &[_][]const u8 { "Jazz Jackrabbit 2 Console",
                "------------------------",
                "help",
                "map castle1",
                "godmode on",
            },
        };
    }

    pub fn deinit(self: *@This()) void {
        self.variables.deinit();
    }

    pub fn toggle_onoff(self: *@This()) void {
        self.enabled = !self.enabled;
        // std.debug.print("Toggle {s}", .{"shell"});
    }

    pub fn register(self: *@This(), name: []const u8, variable: anytype) void {
        const T = @TypeOf(variable);
        var value: ?VarPtr = null;
        switch (@typeInfo(T)) {
            .pointer => |ptr| {
                if (ptr.sentinel() != null) 
                    @compileError("Pointers sentinels are not supported.");
                if (ptr.size == .slice)
                    @compileError("Slices (" ++ @typeName(T) ++ ") are not supported.");
                switch (ptr.child) {
                    usize => value = .{.usize_ptr = variable },
                    else => @compileError("Unuspportet pointer type " ++ @typeName(ptr.child)),
                }
            },
            else => @compileError("Unsupported type " ++ @typeName(T)),
        }

        if (value) |v| {
            if (self.variables.getOrPut(name)) |entry| {
                entry.value_ptr.* = v;
            }
        }
    }

    pub fn render_shell(self: @This()) void {
        if (self.enabled) {
            // process inputs
            // render shell background
            _ = sdl.SDL_SetRenderDrawBlendMode(gfx.get_renderer(), sdl.SDL_BLENDMODE_BLEND);
            _ = sdl.SDL_SetRenderDrawColor(
                gfx.get_renderer(),
                self.bg_color.r,
                self.bg_color.g,
                self.bg_color.b,
                self.bg_color.a,
            );
            _ = sdl.SDL_RenderFillRect(gfx.get_renderer(), &self.rect);
            // render shell text
            const text_color = sdl.SDL_Color{ .r = 255, .g = 255, .b = 255, .a = 255 };

            var y: f32 = self.rect.y + 5;

            for (self.lines) |line| {
                if (line.len == 0) {
                    y += self.line_height;
                    continue;
                }

                const surface = sdl.TTF_RenderText_Blended(
                    self.font,
                    line.ptr,
                    line.len,
                    text_color,
                ) orelse continue;

                defer sdl.SDL_DestroySurface(surface);

                const texture = sdl.SDL_CreateTextureFromSurface(gfx.get_renderer(), surface)
                    orelse continue;
                defer sdl.SDL_DestroyTexture(texture);

                const dst = sdl.SDL_FRect{
                    .x = self.rect.x + 5,
                    .y = y,
                    .w = @floatFromInt(surface.*.w),
                    .h = @floatFromInt(surface.*.h),
                };

                _ = sdl.SDL_RenderTexture(gfx.get_renderer(), texture, null, &dst);

                y += self.line_height;

                // stop if outside console
                if (y > self.rect.y + self.rect.h)
                    break;
            }
        }
        self.render_runtime();
    }
    pub fn render_runtime(self: @This()) void {
        _ = self;
    }
};
