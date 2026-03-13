const std = @import("std");
const app = @import("app.zig");
const assets = @import("assets.zig");
const gfx = @import("gfx");
const sdl = gfx.sdl;
const gl = gfx.gl;
const Vec2 = gfx.math.Vec2;
const Vec3 = gfx.math.Vec3;
const asset_reader = @import("assets_reader.zig");
const g_anim = @import("g_anim.zig");
const m = @import("g_math.zig");
const WorldCoord = m.WorldCoord;
const TileCoord = m.TileCoord;
const ScreenCoord = m.ScreenCoord;

const default_palette: [256]u32 = .{ 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0xFFB3E3, 0x576972, 0x74A2EA, 0x5C6E77, 0x8AADE7, 0xFFFFFF, 0xFFC7, 0xDF93, 0xBF6B, 0xA347, 0x832B, 0x6713, 0x3707, 0xB00, 0xFF, 0xE3, 0xC7, 0xAB, 0x8F, 0x73, 0x3F, 0xB, 0xFFE3BB, 0xFFC77B, 0xFFAB3B, 0xFF8B00, 0xCB6B00, 0x974F00, 0x4F2F00, 0xB0700, 0xFFFF, 0xC7FF, 0x93FF, 0x5FFF, 0x37CB, 0x1B9B, 0x753, 0xB, 0xB78BFB, 0x975BF7, 0x7B2BF3, 0x6300EF, 0x4B00BF, 0x370093, 0x230063, 0x130037, 0x812D65, 0xFFE01F64, 0x667881, 0xC3DB, 0x93BB, 0x6B9B, 0x3753, 0x70B, 0xD3F3FF, 0xAFCFDB, 0x93AFBB, 0x738B9B, 0x576B77, 0x3F4B57, 0x1F232F, 0x7070B, 0xFFE7D3, 0xDBC3AB, 0xBB9F8B, 0x9B7F6B, 0x775F4B, 0x573F33, 0x2F1F1B, 0xB0707, 0xA3FF00, 0x7FE300, 0x5FC707, 0x43AB07, 0x2F8F0B, 0x1F770B, 0x73F00, 0xB00, 0xFF77E7, 0xEF47E7, 0xCF1FDF, 0xA300CF, 0x7F00A3, 0x5B0077, 0x2B003F, 0x7000B, 0xFFFBBF, 0xF3E7AB, 0xE7D397, 0xDBBF83, 0xCFAB73, 0xC39363, 0xB77F53, 0xAB6B47, 0x975B3F, 0x834B37, 0x6F3B2F, 0x5F2F23, 0x4B231F, 0x371717, 0x230F0F, 0x130707, 0x73BB00, 0x5BA300, 0x478B00, 0x377300, 0x275F00, 0x1B4700, 0xF2F00, 0x71B00, 0x8AB900, 0x24287, 0x6B7D86, 0xA0CF16, 0x738AB5, 0x2161A6, 0x70828B, 0x442101, 0xA3D7FF, 0x87BFEF, 0x6FA7DF, 0x5B93D3, 0x477BC3, 0x3367B7, 0x2353A7, 0x17439B, 0xF3387, 0xB2777, 0x71B67, 0x71357, 0xB43, 0x733, 0x23, 0x13, 0xD700, 0xBC700, 0x1BB700, 0x23AB00, 0x2B9B00, 0x338F00, 0x377F00, 0x3B7300, 0x3B6700, 0x3B5B00, 0x374F00, 0x334300, 0x2B3700, 0x232B00, 0x1B1F00, 0x131300, 0xCB77AF, 0xBB67A3, 0xAF5B97, 0x9F4F8B, 0x93477F, 0x833B73, 0x773367, 0x6B2B5F, 0x5B2353, 0x4F1B47, 0x43173B, 0x37132F, 0x270B23, 0x1B0717, 0xB000B, 0x0, 0xDFDB07, 0xD7D307, 0xD3CB07, 0xCBC307, 0xC7BF0B, 0xBFB70B, 0xBBAF0B, 0xB3A70B, 0xAF9F0B, 0xA79B0B, 0xA3930B, 0x9B8F0B, 0x97870B, 0x93830B, 0x8B7B0B, 0x87770B, 0x7F6F0B, 0x7B6B0B, 0x73670B, 0x6F5F0B, 0x675B0B, 0x63570B, 0x5F4F0B, 0x574B0B, 0x53430B, 0x4B3F0B, 0x473B0B, 0x3F3707, 0x3B2F07, 0x372B07, 0x2F2707, 0x2B2307, 0xB6E52C, 0x3474B9, 0x758790, 0xA9CD06, 0x5D7A93, 0xFFFFFFA5, 0x5696DB, 0x7A8C95, 0x739B00, 0x6F9700, 0x6F8F00, 0x6B8B00, 0x6B8700, 0x677F00, 0x677B00, 0x637700, 0x5F6F00, 0x5F6B00, 0x5B6700, 0x575F00, 0x535B00, 0x535700, 0x4F5300, 0x4B4B00, 0x474700, 0x433F00, 0x3B3B00, 0x373300, 0x332F00, 0x2B2700, 0x272300, 0x231F00, 0xFFFFFA41, 0x67A7EC, 0x7F919A, 0xFFE10E56, 0x78B8FD, 0x633406, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0x0, 0xFFFFFF };

pub const DiagAnimset = struct {
    allocator: std.mem.Allocator,
    gfx_sys: gfx.sys,
    renderer: gfx.gl_utils.IndexedSpriteRenderer,
    animset: assets.Animset,
    default_p: gfx.gl_utils.Texture1D,
    scr_w: usize,
    scr_h: usize,
    anim_time: f32,

    pub fn init(alloc: std.mem.Allocator, j2a_path: []const u8) !DiagAnimset {
        const gfx_sys: gfx.sys = try .init("Jazz2", 1400, 800);
        const vertex_sh = @embedFile("./gfx/glsl/sprite.vert.glsl");
        const fragment_sh = @embedFile("./gfx/glsl/sprite_ind.frag.glsl");
        const renderer: gfx.gl_utils.IndexedSpriteRenderer = try .init(vertex_sh, fragment_sh, 1400, 800);
        const animset = try asset_reader.load_animset(alloc, j2a_path);
        // calculate animation count
        var anim_count: usize = 0;
        for (animset.blocks) |b| {
            anim_count += b.anims.len;
        }

        return .{
            .allocator = alloc,
            .gfx_sys = gfx_sys,
            .renderer = renderer,
            .animset = animset,
            .default_p = try .init_from_palette_rgba(&default_palette),
            .scr_w = gfx_sys.screen_w,
            .scr_h = gfx_sys.screen_h,
            .anim_time = 1000.0,
        };
    }

    fn deinit(ctx: *anyopaque) void {
        const self: *DiagAnimset = @ptrCast(@alignCast(ctx));

        self.renderer.deinit();
        self.animset.deinit();
        self.gfx_sys.deinit();
    }

    pub fn app_cast(self: *DiagAnimset) app.IApp {
        return .{ .ptr = self, .vtable = &.{
            .run = run,
            .deinit = deinit,
        } };
    }

    fn run(ctx: *anyopaque) void {
        const self: *DiagAnimset = @ptrCast(@alignCast(ctx));
        // main loop
        while (true) {
            var ev: sdl.SDL_Event = undefined;
            while (sdl.SDL_PollEvent(&ev)) {
                switch (ev.type) {
                    sdl.SDL_EVENT_QUIT => return,
                    sdl.SDL_EVENT_KEY_DOWN => {
                        const key = ev.key;
                        if (key.repeat) return;

                        switch (key.scancode) {
                            sdl.SDL_SCANCODE_PAGEUP => self.anim_time += 1.0,
                            sdl.SDL_SCANCODE_PAGEDOWN => self.anim_time -= 1.0,
                            else => {},
                        }
                    },

                    else => {},
                }
            }

            // handle inputs
            const speed: f32 = 8.0;
            self.renderer.set_cam_delta(app.handle_inputs_simple(speed));

            self.clear_screen();
            self.draw();
            self.gfx_sys.draw();
        }
    }

    fn draw(self: *DiagAnimset) void {
        // const time_sdl: f32 = @floatFromInt(gfx.sdl.SDL_GetTicks());
        // const time_elapsed = time_sdl * 0.001 / 10;
        // const keyboard = gfx.sdl.SDL_GetKeyboardState(null);
        // if (keyboard[gfx.sdl.SDL_SCANCODE_PAGEUP]) {
        //     self.anim_time += 1.0;
        // }
        //
        // if (keyboard[gfx.sdl.SDL_SCANCODE_PAGEDOWN]) {
        //     self.anim_time -= 1.0;
        // }
        const time_elapsed = self.anim_time;
        // const time_elapsed: f32 = 10.0;
        var y: i32 = 0;
        for (self.animset.blocks) |*b| {
            if (b.anims.len == 0) {
                continue;
            }
            var y_offset: i32 = 0;

            var x: i32 = 0;
            for (b.anims) |*anim| {
                // get max w and max h
                var x_offset: i32 = 0;
                for (anim.frames) |*f| {
                    if (y_offset < f.height) y_offset = f.height;
                    if (x_offset < f.width) x_offset = f.width;
                }
                // get current frame
                const f_indx = g_anim.calc_curr_frame_for_anim(time_elapsed, anim);
                // finally draw a frame
                const brightness: f32 = 1.0;
                const position = Vec2.init(@floatFromInt(x), @floatFromInt(y));
                const rotate: f32 = 0;
                const color = Vec3.init(brightness, brightness, brightness);
                self.renderer.draw(anim.frames[f_indx].texture, self.default_p, position, rotate, color);

                x += x_offset;
            }
            y += y_offset;
        }
    }

    fn clear_screen(self: *DiagAnimset) void {
        _ = self;
        // const now_: f32 = @floatFromInt(sdl.SDL_GetTicks());
        // const now = now_ / 1000.0;
        // const red: f32 = @floatCast(0.5 + 0.5 * std.math.sin(now));
        // const green: f32 = @floatCast(0.5 + 0.5 * std.math.sin(now + std.math.pi * 2.0 / 3.0));
        // const blue: f32 = @floatCast(0.5 + 0.5 * std.math.sin(now + std.math.pi * 4.0 / 3.0));

        const red: f32 = 0.0;
        const green: f32 = 0.0;
        const blue: f32 = 0.0;
        gl.glClear(gl.GL_COLOR_BUFFER_BIT | gl.GL_DEPTH_BUFFER_BIT);
        gl.glClearColor(red, green, blue, 1.0);
    }
};

test "to_rgba" {}
