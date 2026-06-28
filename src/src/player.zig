const assets = @import("assets.zig");
const asset_maps = @import("assets_maps.zig");
const gfx = @import("gfx");
const g_anim = @import("g_anim.zig");
const m = @import("g_math.zig");

pub const PlayerType = enum(u8) {
    Jazz,
    Spaz,
};

pub const Orientation = enum {
    Left,
    Right,
};

pub const MoveState = enum(u8) {
    Idle,
    Walk,
    Run,
    Jump,
    Fall,
    Buttstomp,
    Hurt,
};

pub const Player = struct {
    player_type: PlayerType,
    pos_x: f32,
    pos_y: f32,
    vel_x: f32,
    vel_y: f32,
    orientation: Orientation,
    move_state: MoveState,
    on_ground: bool,
    anim_block: usize,
    anim_id: usize,
    anim_elapsed: f32,
    jump_held: bool,

    pub fn init(player_type: PlayerType, start_x: f32, start_y: f32) Player {
        const anim_block = switch (player_type) {
            .Jazz => asset_maps.ANIM_SET_JAZZ,
            .Spaz => asset_maps.ANIM_SET_SPAZ,
        };
        return .{
            .player_type = player_type,
            .pos_x = start_x,
            .pos_y = start_y,
            .vel_x = 0,
            .vel_y = 0,
            .orientation = .Right,
            .move_state = .Idle,
            .on_ground = true,
            .anim_block = anim_block,
            .anim_id = ANIM_IDLE,
            .anim_elapsed = 0,
            .jump_held = false,
        };
    }

    pub fn update(self: *Player, dt: f32, keyboard: [*c]const bool, level: *const assets.Level) void {
        self.handle_input(dt, keyboard);
        self.apply_physics(dt, level);
        self.update_animation(dt);
    }

    fn handle_input(self: *Player, dt: f32, keyboard: [*c]const bool) void {
        _ = dt;
        const move_speed: f32 = 200.0;
        const jump_power: f32 = -420.0;

        if (keyboard[gfx.sdl.SDL_SCANCODE_LEFT]) {
            self.vel_x = -move_speed;
            self.orientation = .Left;
        } else if (keyboard[gfx.sdl.SDL_SCANCODE_RIGHT]) {
            self.vel_x = move_speed;
            self.orientation = .Right;
        } else {
            self.vel_x = 0;
        }

        if (keyboard[gfx.sdl.SDL_SCANCODE_UP] or keyboard[gfx.sdl.SDL_SCANCODE_SPACE]) {
            if (self.on_ground and !self.jump_held) {
                self.vel_y = jump_power;
                self.on_ground = false;
            }
            self.jump_held = true;
        } else {
            self.jump_held = false;
        }

        if (keyboard[gfx.sdl.SDL_SCANCODE_DOWN]) {
            if (!self.on_ground) {
                self.move_state = .Buttstomp;
            }
        }
    }

    fn apply_physics(self: *Player, dt: f32, level: *const assets.Level) void {
        _ = level;
        const gravity: f32 = 1200.0;

        self.vel_y += gravity * dt;

        const max_fall: f32 = 900.0;
        if (self.vel_y > max_fall) {
            self.vel_y = max_fall;
        }

        self.pos_x += self.vel_x * dt;
        self.pos_y += self.vel_y * dt;

        const floor_y: f32 = 400.0;
        if (self.pos_y >= floor_y) {
            self.pos_y = floor_y;
            self.vel_y = 0;
            self.on_ground = true;
        }
    }

    fn update_animation(self: *Player, dt: f32) void {
        const prev_state = self.move_state;

        if (!self.on_ground) {
            if (self.vel_y < 0) {
                self.move_state = .Jump;
            } else {
                self.move_state = .Fall;
            }
        } else if (@abs(self.vel_x) > 100) {
            self.move_state = .Run;
        } else if (@abs(self.vel_x) > 0) {
            self.move_state = .Walk;
        } else {
            self.move_state = .Idle;
        }

        if (prev_state != self.move_state) {
            self.anim_elapsed = 0;
            self.anim_id = switch (self.player_type) {
                .Jazz => jazz_anim_for_state(self.move_state),
                .Spaz => spaz_anim_for_state(self.move_state),
            };
        }

        self.anim_elapsed += dt;
    }

    pub fn draw(
        self: *Player,
        renderer: *gfx.gl_utils.SpriteRenderer,
        renderer_ind: *gfx.gl_utils.IndexedSpriteRenderer,
        animset: *const assets.Animset,
        palettes: []const gfx.gl_utils.Texture1D,
        cam_pos: m.WorldCoord,
        scr_w: i32,
        scr_h: i32,
    ) void {
        const anim = &animset.blocks[self.anim_block].anims[self.anim_id];
        if (anim.frames.len == 0) return;

        const frame_no = g_anim.calc_curr_frame_for_anim(self.anim_elapsed, anim);
        const frame = anim.frames[frame_no];

        const cx: f32 = @floatFromInt(cam_pos.x);
        const cy: f32 = @floatFromInt(cam_pos.y);
        const sw: f32 = @floatFromInt(scr_w);
        const sh: f32 = @floatFromInt(scr_h);
        const base_off_x = @max(0, cx - sw / 2);
        const base_off_y = @max(0, cy - sh / 2);

        const screen_x = @as(i32, @intFromFloat(self.pos_x - base_off_x));
        const screen_y = @as(i32, @intFromFloat(self.pos_y - base_off_y));

        const palette_id: usize = 0;

        switch (self.orientation) {
            .Right => {
                const dx = screen_x - frame.hotspotX;
                const dy = screen_y - frame.hotspotY;
                render_tex(renderer, renderer_ind, frame.texture, palettes[palette_id], dx, dy, frame.width, frame.height);
            },
            .Left => {
                const dx = screen_x + frame.width - frame.hotspotX;
                const dy = screen_y - frame.hotspotY;
                render_tex_mirrored(renderer, renderer_ind, frame.texture, palettes[palette_id], dx, dy, frame.width, frame.height);
            },
        }
    }

    pub fn start_tile(event_id: asset_maps.EventId) ?PlayerType {
        return switch (event_id) {
            .JazzLevelStart => .Jazz,
            .SpazLevelStart => .Spaz,
            else => null,
        };
    }
};

fn jazz_anim_for_state(state: MoveState) usize {
    return switch (state) {
        .Idle => asset_maps.ANIM_JAZZ_IDLE1,
        .Walk => asset_maps.ANIM_JAZZ_WALKING,
        .Run => asset_maps.ANIM_JAZZ_RUNNING,
        .Jump => asset_maps.ANIM_JAZZ_JUMP,
        .Fall => asset_maps.ANIM_JAZZ_ASCENDING,
        .Buttstomp => asset_maps.ANIM_JAZZ_BUTTSTOMP,
        .Hurt => asset_maps.ANIM_JAZZ_HURT,
    };
}

fn spaz_anim_for_state(state: MoveState) usize {
    return switch (state) {
        .Idle => asset_maps.ANIM_JAZZ_IDLE1,
        .Walk => asset_maps.ANIM_JAZZ_WALKING,
        .Run => asset_maps.ANIM_JAZZ_RUNNING,
        .Jump => asset_maps.ANIM_JAZZ_JUMP,
        .Fall => asset_maps.ANIM_JAZZ_ASCENDING,
        .Buttstomp => asset_maps.ANIM_JAZZ_BUTTSTOMP,
        .Hurt => asset_maps.ANIM_JAZZ_HURT,
    };
}

fn render_tex(renderer: *gfx.gl_utils.SpriteRenderer, renderer_ind: *gfx.gl_utils.IndexedSpriteRenderer, tex: assets.Texture, palette: gfx.gl_utils.Texture1D, x: i32, y: i32, w: i32, h: i32) void {
    _ = w;
    _ = h;
    const position = gfx.math.Vec2.init(@floatFromInt(x), @floatFromInt(y));
    const color = gfx.math.Vec3.init(1.0, 1.0, 1.0);
    switch (tex) {
        .texture2d => |t| renderer.draw(t, position, color),
        .texture2dind => |t| renderer_ind.draw(t, palette, position, color),
    }
}

fn render_tex_mirrored(renderer: *gfx.gl_utils.SpriteRenderer, renderer_ind: *gfx.gl_utils.IndexedSpriteRenderer, tex: assets.Texture, palette: gfx.gl_utils.Texture1D, x: i32, y: i32, w: i32, h: i32) void {
    const color = gfx.math.Vec3.init(1.0, 1.0, 1.0);
    const position = gfx.math.Vec2.init(@floatFromInt(x), @floatFromInt(y));
    const size = gfx.math.Vec2.init(-@as(f32, @floatFromInt(w)), @as(f32, @floatFromInt(h)));
    switch (tex) {
        .texture2d => |t| draw_mirrored(renderer, t, position, size, color),
        .texture2dind => |t| draw_mirrored_ind(renderer_ind, t, palette, position, size, color),
    }
}

fn draw_mirrored(renderer: *gfx.gl_utils.SpriteRenderer, texture: gfx.gl_utils.Texture2D, position: gfx.math.Vec2, size: gfx.math.Vec2, color: gfx.math.Vec3) void {
    renderer.shader.use_prog();
    renderer.shader.set_vec2(.pos, [2]f32{ position.x(), position.y() });
    renderer.shader.set_vec2(.spriteSize, [2]f32{ size.x(), size.y() });
    renderer.shader.set_vec3(.spriteColor, color.v);

    gfx.gl.glActiveTexture(gfx.gl.GL_TEXTURE0);
    texture.bind();

    gfx.gl.glBindVertexArray(renderer.quadVAO);
    gfx.gl.glDrawArrays(gfx.gl.GL_TRIANGLES, 0, 6);
    gfx.gl.glBindVertexArray(0);
}

fn draw_mirrored_ind(renderer: *gfx.gl_utils.IndexedSpriteRenderer, texture: gfx.gl_utils.Texture2DInd, palette: gfx.gl_utils.Texture1D, position: gfx.math.Vec2, size: gfx.math.Vec2, color: gfx.math.Vec3) void {
    renderer.shader.use_prog();
    renderer.shader.set_vec2(.pos, [2]f32{ position.x(), position.y() });
    renderer.shader.set_vec2(.spriteSize, [2]f32{ size.x(), size.y() });
    renderer.shader.set_vec3(.spriteColor, color.v);

    gfx.gl.glActiveTexture(gfx.gl.GL_TEXTURE0);
    texture.bind();

    gfx.gl.glActiveTexture(gfx.gl.GL_TEXTURE1);
    palette.bind();

    gfx.gl.glBindVertexArray(renderer.quadVAO);
    gfx.gl.glDrawArrays(gfx.gl.GL_TRIANGLES, 0, 6);
    gfx.gl.glBindVertexArray(0);
}

pub const ANIM_IDLE: usize = asset_maps.ANIM_JAZZ_IDLE1;
