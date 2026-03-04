const std = @import("std");
const gl = @import("system.zig").gl;
const math = @import("math.zig");
const Mat4x4 = math.Mat4x4;
const Vec2 = math.Vec2;
const Vec3 = math.Vec3;

comptime {
    if (gl.GLfloat != f32) {
        @compileError("GLfloat is not f32");
    }
}

pub const Texture2D = struct {
    const Self = Texture2D;
    tex_id: gl.GLuint,
    w: i32,
    h: i32,

    pub fn init_from_rgba(buf: []const u8, w: anytype, h: anytype) !Self {
        const w_ = if (@TypeOf(w) == i32) w else @as(i32, @intCast(w));
        const h_ = if (@TypeOf(h) == i32) h else @as(i32, @intCast(h));
        var tex_id: gl.GLuint = 0;
        gl.glGenTextures(1, &tex_id);
        gl.glBindTexture(gl.GL_TEXTURE_2D, tex_id);
        defer gl.glBindTexture(gl.GL_TEXTURE_2D, 0);

        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_S, gl.GL_CLAMP_TO_EDGE);
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_WRAP_T, gl.GL_CLAMP_TO_EDGE);
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MIN_FILTER, gl.GL_NEAREST_MIPMAP_LINEAR);
        gl.glTexParameteri(gl.GL_TEXTURE_2D, gl.GL_TEXTURE_MAG_FILTER, gl.GL_NEAREST);
        gl.glTexImage2D(gl.GL_TEXTURE_2D, 0, gl.GL_RGBA, w_, h_, 0, gl.GL_RGBA, gl.GL_UNSIGNED_BYTE, buf.ptr);
        gl.glGenerateMipmap(gl.GL_TEXTURE_2D);

        return .{ .tex_id = tex_id, .w = w_, .h = h_ };
    }

    pub fn bind(self: Self) void {
        gl.glBindTexture(gl.GL_TEXTURE_2D, self.tex_id);
    }

    pub fn deinit(self: Self) void {
        gl.glDeleteTextures(1, &self.tex_id);
    }
};

pub fn ShaderProgram(comptime Uniforms: type) type {
    const UniformsLen = @typeInfo(Uniforms).@"enum".fields.len;

    return struct {
        const Self = @This();
        program_id: gl.GLuint,
        uniforms_map: [UniformsLen]gl.GLint,

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
            const program_id = gl.glCreateProgram();
            gl.glAttachShader(program_id, vertex_shader);
            gl.glAttachShader(program_id, fragment_shader);

            var geometry_shader: gl.GLuint = 0;

            if (geometry_code != null) {
                geometry_shader = gl.glCreateShader(gl.GL_GEOMETRY_SHADER);
                if (geometry_shader == 0) {
                    return error.glCreateShader_failed;
                }

                try compile(geometry_shader, geometry_code.?);

                gl.glAttachShader(program_id, geometry_shader);
            }

            gl.glLinkProgram(program_id);

            try shader_status("Program link error", program_id, gl.GL_LINK_STATUS);

            // not needed anymore
            gl.glDeleteShader(vertex_shader);
            gl.glDeleteShader(fragment_shader);
            if (geometry_shader != 0) {
                gl.glDeleteShader(geometry_shader);
            }

            var uniforms_map: [UniformsLen]gl.GLint = undefined;
            inline for (@typeInfo(Uniforms).@"enum".fields) |field| {
                const name = @as([*c]const u8, @ptrCast(field.name));
                uniforms_map[field.value] = gl.glGetUniformLocation(program_id, name);
                if (uniforms_map[field.value] == -1) {
                    std.debug.print("program({d}): location '{s}' does not correspond to an active uniform variable in program", .{ program_id, field.name });
                    return error.UniformMismatch;
                }
            }

            return .{
                .program_id = program_id,
                .uniforms_map = uniforms_map,
            };
        }

        fn compile(shader_id: gl.GLuint, shader_code: [*c]const u8) !void {
            gl.glShaderSource(
                shader_id,
                1,
                &shader_code,
                null,
            );

            gl.glCompileShader(shader_id);

            // check if there are compilation errors
            try shader_status("Shader compile error", shader_id, gl.GL_COMPILE_STATUS);
        }

        fn shader_status(pref: []const u8, shader_id: gl.GLuint, status: gl.GLenum) !void {
            var success: gl.GLint = 0;

            var buff: [1024]u8 = undefined;

            if (status == gl.GL_COMPILE_STATUS) {
                gl.glGetShaderiv(shader_id, status, &success);
                if (success == 1) return;
                gl.glGetShaderInfoLog(shader_id, buff.len, null, &buff);
            } else {
                gl.glGetProgramiv(shader_id, status, &success);
                if (success == 1) return;
                gl.glGetProgramInfoLog(shader_id, buff.len, null, &buff);
            }
            std.debug.print("program id={d}\n", .{shader_id});
            std.debug.print("{s}: {d} {s}\n", .{ pref, gl.glGetError(), @as([*:0]const u8, @ptrCast(&buff)) });
            return error.ShaderError;
            // }
        }

        pub fn deinit(self: Self) void {
            _ = self;
        }

        pub fn use_prog(self: Self) void {
            gl.glUseProgram(self.program_id);
        }

        pub fn setMat4(self: Self, comptime uniform: Uniforms, mat: [16]gl.GLfloat) void {
            gl.glUniformMatrix4fv(self.uniforms_map[@intFromEnum(uniform)], 1, 0, &mat);
        }

        pub fn setVec2(self: Self, comptime uniform: Uniforms, vec: [2]gl.GLfloat) void {
            gl.glUniform2fv(self.uniforms_map[@intFromEnum(uniform)], 1, &vec);
        }

        pub fn setVec3(self: Self, comptime uniform: Uniforms, vec: [3]gl.GLfloat) void {
            gl.glUniform3fv(self.uniforms_map[@intFromEnum(uniform)], 1, &vec);
        }

        pub fn setVec4(self: Self, comptime uniform: Uniforms, vec: [4]gl.GLfloat) void {
            gl.glUniform4fv(self.uniforms_map[@intFromEnum(uniform)], 1, &vec);
        }

        pub fn setInt(self: Self, comptime uniform: Uniforms, i: gl.GLint) void {
            gl.glUniform1i(self.uniforms_map[@intFromEnum(uniform)], i);
        }

        pub fn setFloat(self: Self, comptime uniform: Uniforms, f: f64) void {
            gl.glUniform1f(self.uniforms_map[@intFromEnum(uniform)], f);
        }
    };
}
pub const SpriteUniforms = enum { image, spriteColor, model, projection };

pub const SpriteRenderer = struct {
    const Self = @This();
    const Shader = ShaderProgram(SpriteUniforms);
    quadVAO: gl.GLuint,
    shader: Shader,
    projection: Mat4x4,

    pub fn init(vertex_sh: [:0]const u8, fragment_sh: [:0]const u8, w: f32, h: f32) !Self {
        var ret: Self = undefined;
        ret.projection = .init_ortho(0.0, w, h, 0.0, -1.0, 1.0);
        ret.shader = try .init(vertex_sh, fragment_sh, null);
        ret.shader.use_prog();
        // set texture channel to zero aka GL_TEXTURE0
        ret.shader.setInt(.image, 0);
        ret.shader.setMat4(.projection, ret.projection.m);

        // zig fmt: off
        const vertices = [_]f32 { 
            // pos      // tex
            0.0, 1.0,   0.0, 1.0,
            1.0, 0.0,   1.0, 0.0,
            0.0, 0.0,   0.0, 0.0, 
        
            0.0, 1.0,   0.0, 1.0,
            1.0, 1.0,   1.0, 1.0,
            1.0, 0.0,   1.0, 0.0
        };
        // zig fmt: on

        gl.glGenVertexArrays(1, &ret.quadVAO);
        var VBO: gl.GLuint = 0;
        gl.glGenBuffers(1, &VBO);

        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, VBO);
        gl.glBufferData(gl.GL_ARRAY_BUFFER, @sizeOf(@TypeOf(vertices)), &vertices, gl.GL_STATIC_DRAW);

        gl.glBindVertexArray(ret.quadVAO);
        gl.glEnableVertexAttribArray(0);
        gl.glVertexAttribPointer(0, 4, gl.GL_FLOAT, gl.GL_FALSE, 4 * @sizeOf(f32), null);
        gl.glBindBuffer(gl.GL_ARRAY_BUFFER, 0);
        gl.glBindVertexArray(0);

        return ret;
    }

    pub fn deinit(self: Self) void {
        gl.glDeleteVertexArrays(1, &self.quadVAO);
        self.shader.deinit();
    }

    pub fn draw(self: Self, texture: Texture2D, position: Vec2, rotate: f32, color: Vec3) void {
        // prepare transformations
        self.shader.use_prog();

        var model = Mat4x4.init_ident();
        const size_x: f32 = @floatFromInt(texture.w);
        const size_y: f32 = @floatFromInt(texture.h);

        model = model.translate(Vec3.init(position.x(), position.y(), 0.0));

        model = model.translate(Vec3.init(0.5 * size_x, 0.5 * size_y, 0.0));
        model = model.rotate(std.math.degreesToRadians(rotate), Vec3.init(0.0, 0.0, 1.0));
        model = model.translate(Vec3.init(-0.5 * size_x, -0.5 * size_y, 0.0));

        model = model.scale(Vec3.init(size_x, size_y, 1.0));

        self.shader.setMat4(.model, model.m);
        self.shader.setVec3(.spriteColor, color.v);

        gl.glActiveTexture(gl.GL_TEXTURE0);
        texture.bind();

        gl.glBindVertexArray(self.quadVAO);
        gl.glDrawArrays(gl.GL_TRIANGLES, 0, 6);
        gl.glBindVertexArray(0);
    }
};
