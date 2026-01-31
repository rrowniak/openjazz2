const std = @import("std");
const gfx = @import("gfx.zig");
const sdl = gfx.sdl;

const Command = struct {
    fun: CommandFn,
    ctx: *anyopaque,
};

const CommandFn = *const fn (alloc: std.mem.Allocator, ctx: *anyopaque, args: []const u8) ?[]const u8;

const FONT_PATH = "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf";
const PROMPT = "jazz2> ";

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
    // graphics
    rect: sdl.SDL_FRect = .{ .x = 0, .y = 0, .w = 800, .h = 600 },
    bg_color: sdl.SDL_Color = .{ .r = 0, .g = 0, .b = 0, .a = 200 },
    font: *sdl.TTF_Font,
    line_height: f32 = 16,
    // lines
    text: Lines,
    input: std.array_list.Managed(u8),
    cursor_visible: bool = true,
    last_blink_ms: u64 = 0,

    pub fn init(alloc: std.mem.Allocator) !@This() {
        var lines = Lines.init(alloc);
        try lines.append_line("Jazz Jackrabbit 2 Console");
        try lines.append_line("------------------------");
        var c = @This(){
            .alloc = alloc,
            .commands = .init(alloc),
            .font = sdl.TTF_OpenFont(FONT_PATH, 14) orelse return error.FontLoadFailed,
            .text = lines,
            .input = .init(alloc),
        };
        // register help command
        c.register_cmd("help", help, &c);
        return c;
    }

    pub fn deinit(self: *@This()) void {
        self.commands.deinit();
        self.text.deinit();
        self.input.deinit();
    }

    pub fn toggle_onoff(self: *@This()) void {
        self.enabled = !self.enabled;

        if (self.enabled) {
            _ = sdl.SDL_StartTextInput(gfx.get_window());
            self.cursor_visible = true;
            self.last_blink_ms = sdl.SDL_GetTicks();
        } else {
            _ = sdl.SDL_StopTextInput(gfx.get_window());
        }
    }

    pub fn register_cmd(self: *@This(), name: []const u8, cmd: CommandFn, ctx: *anyopaque) void {
        var entry = self.commands.getOrPut(name) catch {
            return;
        };
        entry.value_ptr.* = .{ .fun = cmd, .ctx = ctx };
    }

    pub fn render_shell(self: *@This()) void {
        if (self.enabled) {
            self.update_cursor();

            // process inputs
            for (gfx.get_events()) |ev| {
                self.handle_event(&ev);
            }
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

            const render_lines = self.build_render_lines() catch {
                return;
            };
            defer {
                for (render_lines) |l| self.alloc.free(l);
                self.alloc.free(render_lines);
            }

            var y: f32 = self.rect.y + 5;

            for (render_lines) |line| {
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

                const texture = sdl.SDL_CreateTextureFromSurface(gfx.get_renderer(), surface) orelse continue;
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

            // render cursor
            const now = sdl.SDL_GetTicks();
            if (now - self.last_blink_ms > 500) {
                self.cursor_visible = !self.cursor_visible;
                self.last_blink_ms = now;
            }
        }
        self.render_runtime();
    }

    fn render_runtime(self: @This()) void {
        _ = self;
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

        // history
        for (self.text.lines.items) |line| {
            try list.append(try self.alloc.dupe(u8, line));
        }

        // input line
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
