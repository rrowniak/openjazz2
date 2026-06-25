const std = @import("std");
const gfx = @import("gfx");
const sdl = gfx.sdl;
const gl = gfx.gl;
const gl_utils = gfx.gl_utils;

const FONT_PATH = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf";
const PROMPT = "jazz2> ";

const Command = struct {
    fun: CommandFn,
    ctx: *anyopaque,
};

const CommandFn = *const fn (alloc: std.mem.Allocator, ctx: *anyopaque, args: []const u8) ?[]const u8;

fn help(alloc: std.mem.Allocator, ctx: *anyopaque, args: []const u8) ?[]const u8 {
    _ = args;
    const self: *Console = @ptrCast(@alignCast(ctx));
    _ = self;
    return alloc.dupe(u8, "Help") catch {
        return null;
    };
}

const Lines = struct {
    alloc: std.mem.Allocator,
    lines: std.array_list.Managed([]const u8),
    limit: usize = 255,

    fn init(alloc: std.mem.Allocator) @This() {
        return .{
            .alloc = alloc,
            .lines = .init(alloc),
        };
    }

    fn deinit(self: *@This()) void {
        for (self.lines.items) |l| {
            self.alloc.free(l);
        }
        self.lines.deinit();
    }

    fn append_line(self: *@This(), line: []const u8) !void {
        try self.lines.append(try self.alloc.dupe(u8, line));
        self.maintain_limit();
    }

    fn maintain_limit(self: *@This()) void {
        if (self.lines.items.len > self.limit) {
            const remove = self.lines.items.len - self.limit;
            for (0..remove) |_| {
                const s = self.lines.orderedRemove(0);
                self.alloc.free(s);
            }
        }
    }
};

pub const Console = struct {
    alloc: std.mem.Allocator,
    commands: std.StringHashMap(Command),
    enabled: bool = false,
    rect: struct { x: f32, y: f32, w: f32, h: f32 },
    font: *sdl.TTF_Font,
    renderer: gl_utils.SpriteRenderer,
    bg_tex: gl_utils.Texture2D,
    window: *sdl.SDL_Window,
    window_h: f32,
    line_height: f32 = 16,
    text: Lines,
    input: std.array_list.Managed(u8),
    cursor_visible: bool = true,
    last_blink_ms: u64 = 0,

    const vertex_sh = @embedFile("./gfx/glsl/sprite.vert.glsl");
    const fragment_sh = @embedFile("./gfx/glsl/sprite.frag.glsl");

    pub fn init(alloc: std.mem.Allocator, window: *sdl.SDL_Window, scr_w: f32, scr_h: f32) !@This() {
        var lines = Lines.init(alloc);
        try lines.append_line("Jazz Jackrabbit 2 Console");
        try lines.append_line("------------------------");
        const bg_pixel = [4]u8{ 0, 0, 0, 200 };
        var c = @This(){
            .alloc = alloc,
            .commands = .init(alloc),
            .rect = .{ .x = 0, .y = 0, .w = scr_w, .h = scr_h / 2 },
            .font = sdl.TTF_OpenFont(FONT_PATH, 14) orelse return error.FontLoadFailed,
            .renderer = try .init(vertex_sh, fragment_sh, scr_w, scr_h),
            .bg_tex = try .init_from_rgba(bg_pixel[0..], 1, 1),
            .window = window,
            .window_h = scr_h,
            .text = lines,
            .input = .init(alloc),
        };
        c.register_cmd("help", help, &c);
        return c;
    }

    pub fn deinit(self: *@This()) void {
        self.bg_tex.deinit();
        self.commands.deinit();
        self.text.deinit();
        self.input.deinit();
    }

    pub fn toggle_onoff(self: *@This()) void {
        self.enabled = !self.enabled;

        if (self.enabled) {
            _ = sdl.SDL_StartTextInput(self.window);
            self.cursor_visible = true;
            self.last_blink_ms = sdl.SDL_GetTicks();
        } else {
            _ = sdl.SDL_StopTextInput(self.window);
        }
    }

    pub fn register_cmd(self: *@This(), name: []const u8, cmd: CommandFn, ctx: *anyopaque) void {
        var entry = self.commands.getOrPut(name) catch {
            return;
        };
        entry.value_ptr.* = .{ .fun = cmd, .ctx = ctx };
    }

    pub fn render_shell(self: *@This(), events: []const sdl.SDL_Event) void {
        if (!self.enabled)
            return;

        self.update_cursor();

        for (events) |ev| {
            self.handle_event(&ev);
        }

        const white = gfx.math.Vec3.init(1.0, 1.0, 1.0);

        self.renderer.shader.use_prog();
        var model = gfx.math.Mat4x4.init_ident();
        model = model.translate(gfx.math.Vec3.init(self.rect.x, self.rect.y, 0.0));
        model = model.scale(gfx.math.Vec3.init(self.rect.w, self.rect.h, 1.0));
        self.renderer.shader.setMat4(.model, model.m);
        self.renderer.shader.setMat4(.view, self.renderer.view.m);
        self.renderer.shader.setMat4(.projection, self.renderer.projection.m);
        self.renderer.shader.setVec3(.spriteColor, white.v);

        gl.glActiveTexture(gl.GL_TEXTURE0);
        self.bg_tex.bind();
        gl.glBindVertexArray(self.renderer.quadVAO);
        gl.glDrawArrays(gl.GL_TRIANGLES, 0, 6);
        gl.glBindVertexArray(0);

        const text_color = white;

        const render_lines = self.build_render_lines() catch {
            return;
        };
        defer {
            for (render_lines) |l| self.alloc.free(l);
            self.alloc.free(render_lines);
        }

        const max_lines = @as(usize, @intFromFloat((self.rect.h - 5) / self.line_height));
        const start_line = if (render_lines.len > max_lines) render_lines.len - max_lines else 0;

        var y: f32 = self.rect.y + 5;

        for (render_lines[start_line..]) |line| {
            if (y + self.line_height > self.rect.y + self.rect.h)
                break;

            if (line.len == 0) {
                y += self.line_height;
                continue;
            }

            const surface = sdl.TTF_RenderText_Blended(
                self.font,
                line.ptr,
                line.len,
                sdl.SDL_Color{ .r = 255, .g = 255, .b = 255, .a = 255 },
            ) orelse continue;
            defer sdl.SDL_DestroySurface(surface);

            const rgba_surface = sdl.SDL_ConvertSurface(surface, sdl.SDL_PIXELFORMAT_RGBA32) orelse continue;
            defer sdl.SDL_DestroySurface(rgba_surface);

            const w: usize = @intCast(rgba_surface.*.w);
            const h: usize = @intCast(rgba_surface.*.h);
            const pitch: usize = @intCast(rgba_surface.*.pitch);
            const src: [*]u8 = @ptrCast(rgba_surface.*.pixels);

            const pixels = self.alloc.alloc(u8, w * h * 4) catch continue;
            defer self.alloc.free(pixels);

            {
                var row: usize = 0;
                while (row < h) : (row += 1) {
                    const src_row = src[row * pitch .. row * pitch + w * 4];
                    const dst_row = pixels[row * w * 4 .. (row + 1) * w * 4];
                    @memcpy(dst_row, src_row);
                }
            }

            const tex = gl_utils.Texture2D.init_from_rgba(pixels, w, h) catch continue;
            defer tex.deinit();

            const pos = gfx.math.Vec2.init(self.rect.x + 5, y);
            self.renderer.draw(tex, pos, 0.0, text_color);

            y += self.line_height;
        }

        const now = sdl.SDL_GetTicks();
        if (now - self.last_blink_ms > 500) {
            self.cursor_visible = !self.cursor_visible;
            self.last_blink_ms = now;
        }
    }

    fn handle_event(self: *@This(), event: *const sdl.SDL_Event) void {
        switch (event.type) {
            sdl.SDL_EVENT_TEXT_INPUT => {
                const text = std.mem.span(event.text.text);
                self.input.appendSlice(text) catch {};
            },

            sdl.SDL_EVENT_KEY_DOWN => {
                const key = event.key;
                if (key.repeat) return;

                switch (key.scancode) {
                    sdl.SDL_SCANCODE_BACKSPACE => {
                        if (self.input.items.len > 0) {
                            _ = self.input.pop();
                        }
                    },

                    sdl.SDL_SCANCODE_RETURN, sdl.SDL_SCANCODE_KP_ENTER => {
                        self.submit_line();
                    },

                    else => {},
                }
            },

            else => {},
        }
    }

    fn submit_line(self: *@This()) void {
        if (self.input.items.len == 0)
            return;

        const line = self.alloc.alloc(u8, self.input.items.len + PROMPT.len) catch return;
        defer self.alloc.free(line);

        @memcpy(line[0..PROMPT.len], PROMPT);
        @memcpy(line[PROMPT.len..], self.input.items);

        self.text.append_line(line) catch {};
        self.execute_command();
        self.input.clearRetainingCapacity();
    }

    fn execute_command(self: *@This()) void {
        var it = std.mem.tokenizeScalar(u8, self.input.items, ' ');
        if (it.next()) |cmd| {
            if (self.commands.getEntry(cmd)) |c| {
                const r = c.value_ptr.fun(self.alloc, c.value_ptr.ctx, self.input.items);
                if (r) |s| {
                    defer self.alloc.free(s);
                    self.text.append_line(s) catch {};
                }
            } else {
                self.text.append_line("Unknown command") catch {};
            }
        }
    }

    fn update_cursor(self: *@This()) void {
        const now = sdl.SDL_GetTicks();
        if (now - self.last_blink_ms > 500) {
            self.cursor_visible = !self.cursor_visible;
            self.last_blink_ms = now;
        }
    }

    fn build_render_lines(
        self: *@This(),
    ) ![]const []const u8 {
        var list = std.array_list.Managed([]const u8).init(self.alloc);

        for (self.text.lines.items) |line| {
            try list.append(try self.alloc.dupe(u8, line));
        }

        var temp = std.array_list.Managed(u8).init(self.alloc);
        defer temp.deinit();

        try temp.appendSlice(PROMPT);

        try temp.appendSlice(self.input.items);

        if (self.cursor_visible) {
            try temp.append('_');
        }

        const rendered = try self.alloc.alloc(u8, temp.items.len);
        std.mem.copyForwards(u8, rendered, temp.items);

        try list.append(rendered);

        return list.toOwnedSlice();
    }
};
