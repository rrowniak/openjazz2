const std = @import("std");

pub const Character = struct {
    texture_id: u32,
    size: [2]i32,
    bearing: [2]i32,
    advance: u32,
};

pub const TextRenderer = struct {
    allocator: std.mem.Allocator,
    shader: Shader,
    characters: std.AutoHashMap(u8, Character),
    vao: u32,
    vbo: u32,

    const Self = @This();

    // -------------------------
    // INIT / DEINIT
    // -------------------------
    /// Initializes the text renderer: allocates VAO/VBO for rendering quads.
    pub fn init(allocator: std.mem.Allocator, shader: Shader) !Self {
        var self = Self{
            .allocator = allocator,
            .shader = shader,
            .characters = std.AutoHashMap(u8, Character).init(allocator),
            .vao = 0,
            .vbo = 0,
        };

        // Setup VAO/VBO
        glGenVertexArrays(1, &self.vao);
        glGenBuffers(1, &self.vbo);

        glBindVertexArray(self.vao);
        glBindBuffer(GL_ARRAY_BUFFER, self.vbo);

        glBufferData(GL_ARRAY_BUFFER, 6 * 4 * @sizeOf(f32), null, GL_DYNAMIC_DRAW);

        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 4, GL_FLOAT, GL_FALSE, 4 * @sizeOf(f32), null);

        glBindBuffer(GL_ARRAY_BUFFER, 0);
        glBindVertexArray(0);

        return self;
    }

    /// Frees all character textures, the VAO, and VBO.
    pub fn deinit(self: *Self) void {
        var it = self.characters.iterator();
        while (it.next()) |entry| {
            glDeleteTextures(1, &entry.value_ptr.texture_id);
        }

        self.characters.deinit();

        glDeleteVertexArrays(1, &self.vao);
        glDeleteBuffers(1, &self.vbo);
    }

    // -------------------------
    // LOAD FONT (FreeType)
    // -------------------------
    /// Loads glyph bitmaps for ASCII characters 0-127 from a FreeType face.
    pub fn load(self: *Self, face: FT_Face) !void {
        glPixelStorei(GL_UNPACK_ALIGNMENT, 1);

        for (0..128) |c| {
            if (FT_Load_Char(face, c, FT_LOAD_RENDER) != 0) continue;

            var texture: u32 = 0;
            glGenTextures(1, &texture);
            glBindTexture(GL_TEXTURE_2D, texture);

            glTexImage2D(
                GL_TEXTURE_2D,
                0,
                GL_RED,
                face.*.glyph.*.bitmap.width,
                face.*.glyph.*.bitmap.rows,
                0,
                GL_RED,
                GL_UNSIGNED_BYTE,
                face.*.glyph.*.bitmap.buffer,
            );

            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_S, GL_CLAMP_TO_EDGE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_WRAP_T, GL_CLAMP_TO_EDGE);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_LINEAR);
            glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MAG_FILTER, GL_LINEAR);

            const ch = Character{
                .texture_id = texture,
                .size = .{
                    face.*.glyph.*.bitmap.width,
                    face.*.glyph.*.bitmap.rows,
                },
                .bearing = .{
                    face.*.glyph.*.bitmap_left,
                    face.*.glyph.*.bitmap_top,
                },
                .advance = @intCast(face.*.glyph.*.advance.x),
            };

            try self.characters.put(@intCast(c), ch);
        }

        glBindTexture(GL_TEXTURE_2D, 0);
    }

    // -------------------------
    // RENDER TEXT
    // -------------------------
    /// Renders a string at the given position with scale and color using FreeType glyphs.
    pub fn renderText(
        self: *Self,
        text: []const u8,
        x_start: f32,
        y: f32,
        scale: f32,
        color: [3]f32,
    ) void {
        var x = x_start;

        self.shader.use();
        self.shader.setVec3("textColor", color);

        glActiveTexture(GL_TEXTURE0);
        glBindVertexArray(self.vao);

        for (text) |c| {
            const ch = self.characters.get(c) orelse continue;

            const xpos = x + @as(f32, @floatFromInt(ch.bearing[0])) * scale;
            const ypos = y - (@as(f32, @floatFromInt(ch.size[1] - ch.bearing[1])) * scale);

            const w = @as(f32, @floatFromInt(ch.size[0])) * scale;
            const h = @as(f32, @floatFromInt(ch.size[1])) * scale;

            const vertices = [_][4]f32{
                .{ xpos,     ypos + h, 0.0, 0.0 },
                .{ xpos,     ypos,     0.0, 1.0 },
                .{ xpos + w, ypos,     1.0, 1.0 },

                .{ xpos,     ypos + h, 0.0, 0.0 },
                .{ xpos + w, ypos,     1.0, 1.0 },
                .{ xpos + w, ypos + h, 1.0, 0.0 },
            };

            glBindTexture(GL_TEXTURE_2D, ch.texture_id);

            glBindBuffer(GL_ARRAY_BUFFER, self.vbo);
            glBufferSubData(GL_ARRAY_BUFFER, 0, @sizeOf(@TypeOf(vertices)), &vertices);

            glDrawArrays(GL_TRIANGLES, 0, 6);

            x += (@as(f32, @floatFromInt(ch.advance >> 6))) * scale;
        }

        glBindVertexArray(0);
        glBindTexture(GL_TEXTURE_2D, 0);
    }
};
