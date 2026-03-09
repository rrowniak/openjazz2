const std = @import("std");
const app = @import("app.zig");
const assets = @import("assets.zig");
const gfx = @import("gfx");
const sdl = gfx.sdl;
const gl = gfx.gl;
const Vec2 = gfx.math.Vec2;
const Vec3 = gfx.math.Vec3;
const asset_reader = @import("assets_reader.zig");

const SPR_IN_ROW: i32 = 10;

pub const DiagTileset = struct {
    allocator: std.mem.Allocator,
    gfx_sys: gfx.sys,
    renderer: gfx.gl_utils.SpriteRenderer,
    tileset: assets.Tileset,
    scr_w: usize,
    scr_h: usize,

    pub fn init(alloc: std.mem.Allocator, j2t_path: []const u8) !DiagTileset {
        const gfx_sys: gfx.sys = try .init("Jazz2", 1400, 800);
        const vertex_sh = @embedFile("./gfx/glsl/sprite.vert.glsl");
        const fragment_sh = @embedFile("./gfx/glsl/sprite.frag.glsl");
        return .{ 
            .allocator = alloc,
            .gfx_sys = gfx_sys,
            .renderer = try .init(vertex_sh, fragment_sh, 1400, 800),
            .tileset = try asset_reader.load_tileset(alloc, j2t_path),
            .scr_w = gfx_sys.screen_w,
            .scr_h = gfx_sys.screen_h,
        };
    }

    fn deinit(ctx: *anyopaque) void {
        const self: *DiagTileset = @ptrCast(@alignCast(ctx));

        self.tileset.deinit();
        self.renderer.deinit();
        self.gfx_sys.deinit();
    }

    pub fn app_cast(self: *DiagTileset) app.IApp {
        return .{
            .ptr = self,
            .vtable = &.{
                .run = run,
                .deinit = deinit,
            }
        };
    }

    fn run(ctx: *anyopaque) void {
        const self: *DiagTileset = @ptrCast(@alignCast(ctx));
        // main loop
        while (true) {
            var ev: sdl.SDL_Event = undefined;
            while (sdl.SDL_PollEvent(&ev)) {
                switch (ev.type) {
                    sdl.SDL_EVENT_QUIT => return,
                    else => {},
                }
            }
            self.clear_screen();
            self.draw();
            self.gfx_sys.draw();
        }
    }

    fn draw(self: *DiagTileset) void {
        var x: i32 = 0;
        var y: i32 = 0;
        const time: f32 = @floatFromInt(sdl.SDL_GetTicks());
        const brightness: f32 = (std.math.sin(time/1000) + 1) / 2;
        var block_cnt: i32 = 0;
        for (self.tileset.tiles, 0..) |t, i| {
            if (i != 0 and i % SPR_IN_ROW == 0) {
                y += t.texture.h;
                x = block_cnt * SPR_IN_ROW * t.texture.w; 
                if (y + t.texture.h > self.scr_h) {
                    block_cnt += 1;
                    y = 0;
                }
            }
            // t.sprite.draw(@intCast(x), @intCast(y));
            const position = Vec2.init(@floatFromInt(x), @floatFromInt(y));
            const rotate: f32 = 0;
            const color = Vec3.init(brightness, brightness, brightness);
            self.renderer.draw(t.texture, position, rotate, color);
            x += t.texture.w;
        }
    }

    fn clear_screen(self: *DiagTileset) void {
        _ = self;
        const now_: f32 = @floatFromInt(sdl.SDL_GetTicks());
        const now = now_ / 1000.0;
        const red: f32 = @floatCast(0.5 + 0.5 * std.math.sin(now));
        const green: f32 = @floatCast(0.5 + 0.5 * std.math.sin(now + std.math.pi * 2.0 / 3.0));
        const blue: f32 = @floatCast(0.5 + 0.5 * std.math.sin(now + std.math.pi * 4.0 / 3.0));

        gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);
        gl.glClearColor(red, green, blue, 1.0);
        // gfx.clean_screen(red, green, blue);
    }
};
