const std = @import("std");
const gl = @import("system.zig").gl;
const Self = @This();
const gluint = gl.GLuint;

program_id: gluint,

pub fn init(
    vertex_code: [:0]const u8,
    fragment_code: [:0]const u8,
    geometry_code: ?[:0]const u8,
) !Self {
    // create vertex shader
    const vertex_shader = gl.glCreateShader(gl.GL_VERTEX_SHADER);
    if (vertex_shader == 0) {
        return error.glCreateShared_failed;
    }

    try compile(vertex_shader, vertex_code);

    // create fragment shader
    const fragment_shader = gl.glCreateShader(gl.GL_FRAGMENT_SHADER);
    if (fragment_shader == 0) {
        return error.glCreateShared_failed;
    }

    try compile(fragment_shader, fragment_code);

    // create program and link shaders
    const shader_program = gl.glCreateProgram();
    gl.glAttachShader(shader_program, vertex_shader);
    gl.glAttachShader(shader_program, fragment_shader);

    var geometry_shader: gluint = 0;

    if (geometry_code != null) {
        geometry_shader = gl.glCreateShader(gl.GL_GEOMETRY_SHADER);
        if (geometry_shader == 0) {
            return error.glCreateShader_failed;
        }

        try compile(geometry_shader, geometry_code.?);

        gl.glAttachShader(shader_program, geometry_shader);
    }

    gl.glLinkProgram(shader_program);

    var success: gluint = 0;
    gl.glGetProgramiv(shader_program, gl.GL_LINK_STATUS, @ptrCast(&success));
    if (success == 0) {
        var buff: [1024]u8 = undefined;
        var log_len: gluint = undefined;
        gl.glGetShaderInfoLog(shader_program, 1024, @ptrCast(&log_len), @ptrCast(&buff));
        buff[@intCast(log_len)] = 0;
        std.debug.print("program link error: {s}", .{buff});
        return error.glGetProgramiv_failed;
    }

    // not needed anymore
    gl.glDeleteShader(vertex_shader);
    gl.glDeleteShader(fragment_shader);
    if (geometry_shader != 0) {
        gl.glDeleteShader(geometry_shader);
    }

    return .{
        .program_id = shader_program,
    };
}

fn compile(shader_id: gluint, shader_code: [:0]const u8) !void {
    gl.glShaderSource(
        shader_id,
        1,
        @ptrCast(@alignCast(shader_code.ptr)),
        null,
    );

    gl.glCompileShader(shader_id);

    // check if there are compilation errors
    var success: gluint = 0;
    gl.glGetShaderiv(shader_id, gl.GL_COMPILE_STATUS, @ptrCast(&success));

    if (success == 0) {
        var buff: [1024]u8 = undefined;
        var log_len: gluint = undefined;
        gl.glGetShaderInfoLog(shader_id, 1024, @ptrCast(&log_len), @ptrCast(&buff));
        buff[@intCast(log_len)] = 0;
        std.debug.print("Shader compile error: {s}", .{buff});
    }
}
