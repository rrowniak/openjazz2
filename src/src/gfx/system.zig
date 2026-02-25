const std = @import("std");

pub const sdl = @cImport({
    @cInclude("SDL3/SDL.h");
});

pub const gl = @cImport({
    @cDefine("GL_GLEXT_PROTOTYPES", ""); // needed for some functions like glCreateShader
    @cInclude("GL/gl.h");
});

const Self = @This();
const print = std.debug.print;

sdl_window: ?*sdl.SDL_Window = null,
gl_context: sdl.SDL_GLContext = null,
screen_w: u16 = 0,
screen_h: u16 = 0,

pub fn init(window_name: [*c]const u8, width: u16, height: u16) !Self {
    if (!sdl.SDL_Init(sdl.SDL_INIT_VIDEO | sdl.SDL_INIT_AUDIO)) {
        print("SDL_Init failed: {s}\n", .{sdl.SDL_GetError()});
        return error.SDL_Init_Failed;
    }

    // looking for OpenGL 3.3
    if (!sdl.SDL_GL_SetAttribute(sdl.SDL_GL_CONTEXT_MAJOR_VERSION, 3)) {
        print("SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 3) failed\n", .{});
        return error.SDL_OpenGL_Init_Failed;
    }

    if (!sdl.SDL_GL_SetAttribute(sdl.SDL_GL_CONTEXT_MINOR_VERSION, 3)) {
        print("SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 3) failed\n", .{});
        return error.SDL_OpenGL_Init_Failed;
    }

    if (!sdl.SDL_GL_SetAttribute(sdl.SDL_GL_CONTEXT_PROFILE_MASK, sdl.SDL_GL_CONTEXT_PROFILE_CORE)) {
        print("SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK,SDL_GL_CONTEXT_PROFILE_CORE) failed\n", .{});
        return error.SDL_OpenGL_Init_Failed;
    }

    // NOTE: needed only if stencil buffer is used
    if (!sdl.SDL_GL_SetAttribute(sdl.SDL_GL_STENCIL_SIZE, 1)) {
        print("SDL_GL_SetAttribute(SDL_GL_STENCIL_SIZE, 1) failed\n", .{});
        return error.SDL_OpenGL_Init_Failed;
    }

    const window = sdl.SDL_CreateWindow(window_name, width, height, sdl.SDL_WINDOW_OPENGL | sdl.SDL_WINDOW_RESIZABLE);
    if (window == null) {
        print("SDL_CreateWindow failed: {s}\n", .{sdl.SDL_GetError()});
        return error.SDL_CreateWindow_Failed;
    }
    errdefer sdl.SDL_DestroyWindow(window);

    const gl_ctx = sdl.SDL_GL_CreateContext(window);
    if (gl_ctx == null) {
        print("SDL_GL_CreateContext failed: {s}\n", .{sdl.SDL_GetError()});
        return error.SDL_GL_CreateContext_Failed;
    }
    errdefer _ = sdl.SDL_GL_DestroyContext(gl_ctx);

    if (!sdl.SDL_GL_SetSwapInterval(1)) {
        print("SDL_GL_SetSwapInterval failed: {s}\n", .{sdl.SDL_GetError()});
        return error.SDL_GL_Error;
    }

    gl.glViewport(0, 0, width, height);
    gl.glEnable(gl.GL_DEPTH_TEST);

    return .{
        .sdl_window = window,
        .gl_context = gl_ctx,
        .screen_w = width,
        .screen_h = height,
    };
}

pub fn deinit(self: Self) void {
    _ = sdl.SDL_GL_DestroyContext(self.gl_context);
    sdl.SDL_DestroyWindow(self.sdl_window);
    sdl.SDL_Quit();
}

pub fn draw(self: Self) void {
    _ = sdl.SDL_GL_SwapWindow(self.sdl_window);
}
