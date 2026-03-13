const std = @import("std");
const gfx = @import("gfx");

pub const IApp = struct {
    ptr: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        run: *const fn (*anyopaque) void,
        deinit: *const fn (*anyopaque) void,
    };

    pub fn run(self: *IApp) void {
        self.vtable.run(self.ptr);
    }

    pub fn deinit(self: *IApp) void {
        self.vtable.deinit(self.ptr);
    }
};

pub fn handle_inputs_simple(speed: f32) gfx.math.Vec2 {
    const keyboard = gfx.sdl.SDL_GetKeyboardState(null);
    var pos_delta: gfx.math.Vec2 = .init(0.0, 0.0);

    if (keyboard[gfx.sdl.SDL_SCANCODE_LEFT]) {
        pos_delta.v[0] -= speed;
    }
    if (keyboard[gfx.sdl.SDL_SCANCODE_RIGHT]) {
        pos_delta.v[0] += speed;
    }
    if (keyboard[gfx.sdl.SDL_SCANCODE_UP]) {
        pos_delta.v[1] -= speed;
    }
    if (keyboard[gfx.sdl.SDL_SCANCODE_DOWN]) {
        pos_delta.v[1] += speed;
    }
    return pos_delta;
}
