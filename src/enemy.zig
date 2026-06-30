const std = @import("std");
const assets = @import("assets.zig");
const asset_maps = @import("assets_maps.zig");
const collision = @import("collision.zig");
const g_anim = @import("g_anim.zig");
const gfx = @import("gfx");
const context = @import("ctx.zig");

const MovementMode = enum {
    Ground,
    Flying,
    Idle,
};

const EnemyInfo = struct {
    anim_block: usize,
    anim_id: usize,
    movement_mode: MovementMode,
    move_speed: f32,
    width: f32,
    height: f32,
};

fn enemy_info(event_id: asset_maps.EventId) ?EnemyInfo {
    return switch (event_id) {
        // ── Flying ──
        .Bat => .{ .anim_block = asset_maps.ANIM_SET_BAT,       .anim_id = asset_maps.ANIM_BAT_IDLE,
            .movement_mode = .Flying, .move_speed = 50, .width = 24, .height = 24 },
        .Bee, .Bees, .BeeBoy => .{ .anim_block = asset_maps.ANIM_SET_BEE, .anim_id = asset_maps.ANIM_BEE_FLY,
            .movement_mode = .Flying, .move_speed = 40, .width = 24, .height = 24 },
        .Caterpillar => .{ .anim_block = asset_maps.ANIM_SET_CATERPILLAR, .anim_id = asset_maps.ANIM_CATERPILLAR_IDLE,
            .movement_mode = .Flying, .move_speed = 30, .width = 24, .height = 24 },
        .Demon => .{ .anim_block = asset_maps.ANIM_SET_DEMON,   .anim_id = asset_maps.ANIM_DEMON_IDLE,
            .movement_mode = .Flying, .move_speed = 30, .width = 28, .height = 26 },
        .Dragon => .{ .anim_block = asset_maps.ANIM_SET_DRAGON, .anim_id = asset_maps.ANIM_DRAGON_IDLE,
            .movement_mode = .Flying, .move_speed = 60, .width = 40, .height = 30 },
        .DragonFly => .{ .anim_block = asset_maps.ANIM_SET_DRAGONFLY, .anim_id = asset_maps.ANIM_DRAGONFLY_IDLE,
            .movement_mode = .Flying, .move_speed = 40, .width = 24, .height = 24 },
        .Fish => .{ .anim_block = asset_maps.ANIM_SET_FISH,     .anim_id = asset_maps.ANIM_FISH_IDLE,
            .movement_mode = .Flying, .move_speed = 30, .width = 24, .height = 24 },
        .FloatLizard => .{ .anim_block = asset_maps.ANIM_SET_LIZARD, .anim_id = asset_maps.ANIM_LIZARD_COPTER_IDLE,
            .movement_mode = .Flying, .move_speed = 50, .width = 30, .height = 30 },
        .Moth => .{ .anim_block = asset_maps.ANIM_SET_MOTH,     .anim_id = asset_maps.ANIM_MOTH_GREEN,
            .movement_mode = .Flying, .move_speed = 30, .width = 24, .height = 24 },
        .Raven => .{ .anim_block = asset_maps.ANIM_SET_RAVEN,   .anim_id = asset_maps.ANIM_RAVEN_IDLE,
            .movement_mode = .Flying, .move_speed = 70, .width = 24, .height = 24 },
        .Sparks => .{ .anim_block = asset_maps.ANIM_SET_SPARKS, .anim_id = asset_maps.ANIM_SPARKS_IDLE,
            .movement_mode = .Flying, .move_speed = 20, .width = 24, .height = 24 },
        .Witch => .{ .anim_block = asset_maps.ANIM_SET_WITCH,   .anim_id = asset_maps.ANIM_WITCH_FLY,
            .movement_mode = .Flying, .move_speed = 60, .width = 30, .height = 30 },

        // ── Ground ──
        .Crab => .{ .anim_block = asset_maps.ANIM_SET_CRAB,     .anim_id = asset_maps.ANIM_CRAB_WALK,
            .movement_mode = .Ground, .move_speed = 50, .width = 26, .height = 20 },
        .Helmut => .{ .anim_block = asset_maps.ANIM_SET_HELMUT, .anim_id = asset_maps.ANIM_HELMUT_WALK,
            .movement_mode = .Ground, .move_speed = 60, .width = 28, .height = 26 },
        .LabRat => .{ .anim_block = asset_maps.ANIM_SET_LAB_RAT, .anim_id = asset_maps.ANIM_LAB_RAT_WALK,
            .movement_mode = .Ground, .move_speed = 70, .width = 30, .height = 30 },
        .Lizard => .{ .anim_block = asset_maps.ANIM_SET_LIZARD, .anim_id = asset_maps.ANIM_LIZARD_WALK,
            .movement_mode = .Ground, .move_speed = 60, .width = 30, .height = 30 },
        .Monkey, .StandMonkey => .{ .anim_block = asset_maps.ANIM_SET_MONKEY, .anim_id = asset_maps.ANIM_MONKEY_WALK,
            .movement_mode = .Ground, .move_speed = 70, .width = 30, .height = 30 },
        .NormTurtle => .{ .anim_block = asset_maps.ANIM_SET_NORM_TURTLE, .anim_id = asset_maps.ANIM_NORM_TURT_WALK,
            .movement_mode = .Ground, .move_speed = 60, .width = 24, .height = 24 },
        .TufTurt => .{ .anim_block = asset_maps.ANIM_SET_TUFF_TURT, .anim_id = asset_maps.ANIM_TUFF_TURT_WALK,
            .movement_mode = .Ground, .move_speed = 50, .width = 30, .height = 40 },
        .Skeleton => .{ .anim_block = asset_maps.ANIM_SET_SKELETON, .anim_id = asset_maps.ANIM_SKELETON_WALK,
            .movement_mode = .Ground, .move_speed = 55, .width = 30, .height = 30 },
        .Sucker, .FloatingSucker => .{ .anim_block = asset_maps.ANIM_SET_SUCKER, .anim_id = asset_maps.ANIM_SUCKER_WALK,
            .movement_mode = .Ground, .move_speed = 40, .width = 24, .height = 24 },
        .TufBoss => .{ .anim_block = asset_maps.ANIM_SET_TURTLE_BOSS, .anim_id = asset_maps.ANIM_TURTLE_BOSS_WALK,
            .movement_mode = .Ground, .move_speed = 50, .width = 30, .height = 40 },

        // ── Idle ──
        .Rapier => .{ .anim_block = asset_maps.ANIM_SET_RAPIER, .anim_id = asset_maps.ANIM_RAPIER_IDLE,
            .movement_mode = .Idle, .move_speed = 0, .width = 24, .height = 24 },
        .RocketTurtle => .{ .anim_block = asset_maps.ANIM_SET_ROCKET_TURTLE, .anim_id = asset_maps.ANIM_ROCKET_TURT_DOWNRIGHT,
            .movement_mode = .Idle, .move_speed = 0, .width = 24, .height = 24 },
        .TubeTurtle => .{ .anim_block = asset_maps.ANIM_SET_TUBE_TURTLE, .anim_id = asset_maps.ANIM_TUBE_TURT_IDLE,
            .movement_mode = .Idle, .move_speed = 0, .width = 24, .height = 24 },

        else => null,
    };
}

pub const Enemy = struct {
    pos_x: f32,
    pos_y: f32,
    start_x: f32,
    start_y: f32,
    vel_x: f32,
    vel_y: f32,
    movement_mode: MovementMode,
    facing_left: bool,
    anim_block: usize,
    anim_id: usize,
    anim_elapsed: f32,
    alive: bool,
    move_speed: f32,
    on_ground: bool,
    placed: bool,
    width: f32,
    height: f32,
    fly_phase: f32,

    pub fn init(event_id: asset_maps.EventId, x: f32, y: f32) ?Enemy {
        const info = enemy_info(event_id) orelse return null;
        return .{
            .pos_x = x,
            .pos_y = y,
            .start_x = x,
            .start_y = y,
            .vel_x = if (info.movement_mode == .Ground) -info.move_speed else 0,
            .vel_y = 0,
            .movement_mode = info.movement_mode,
            .facing_left = true,
            .anim_block = info.anim_block,
            .anim_id = info.anim_id,
            .anim_elapsed = 0,
            .alive = true,
            .move_speed = info.move_speed,
            .on_ground = false,
            .placed = info.movement_mode != .Ground,
            .width = info.width,
            .height = info.height,
            .fly_phase = @mod(x + y, 100.0),
        };
    }

    pub fn update(self: *Enemy, dt: f32, cs: *const collision.CollisionSystem) void {
        if (!self.alive) return;

        if (!self.placed) {
            self.place_on_ground(cs);
            self.placed = true;
        }

        switch (self.movement_mode) {
            .Ground => self.update_ground(dt, cs),
            .Flying => self.update_flying(dt),
            .Idle => {},
        }

        self.anim_elapsed += dt;
    }

    fn place_on_ground(self: *Enemy, cs: *const collision.CollisionSystem) void {
        // Check if already inside ground → push up until feet touch surface
        if (cs.resolve_y(self.aabb(), 1)) |push| {
            self.pos_y += push;
            self.on_ground = true;
            return;
        }
        // Above ground — drop pixel by pixel until we touch
        var i: i32 = 0;
        while (i < 500) : (i += 1) {
            self.pos_y += 1.0;
            if (cs.resolve_y(self.aabb(), 1)) |push| {
                self.pos_y += push;
                self.on_ground = true;
                return;
            }
        }
    }

    pub fn aabb(self: *const Enemy) collision.AABB {
        return collision.AABB.init(
            self.pos_x - self.width / 2,
            self.pos_y - self.height,
            self.pos_x + self.width / 2,
            self.pos_y,
        );
    }

    fn update_ground(self: *Enemy, dt: f32, cs: *const collision.CollisionSystem) void {
        const gravity: f32 = 1200.0;

        if (!self.on_ground) {
            self.vel_y += gravity * dt;
            if (self.vel_y > 900.0) self.vel_y = 900.0;
        }

        self.vel_x = if (self.facing_left) -self.move_speed else self.move_speed;

        const dx = self.vel_x * dt;
        const dy = self.vel_y * dt;

        const try_x = self.pos_x + dx;
        const try_y = self.pos_y + dy;
        const try_full = collision.AABB.init(
            try_x - self.width / 2,
            try_y - self.height,
            try_x + self.width / 2,
            try_y,
        );

        if (cs.is_empty(try_full)) {
            self.pos_x = try_x;
            self.pos_y = try_y;
        } else {
            if (dx != 0) {
                const x_aabb = collision.AABB.init(
                    try_x - self.width / 2,
                    self.pos_y - self.height,
                    try_x + self.width / 2,
                    self.pos_y,
                );
                const x_sign: i2 = if (dx > 0) 1 else -1;
                if (cs.resolve_x(x_aabb, x_sign)) |_| {
                    self.facing_left = !self.facing_left;
                } else {
                    self.pos_x = try_x;
                }
            }

            if (dy != 0) {
                const y_aabb = collision.AABB.init(
                    self.pos_x - self.width / 2,
                    try_y - self.height,
                    self.pos_x + self.width / 2,
                    try_y,
                );
                const y_sign: i2 = if (dy > 0) 1 else -1;
                if (cs.resolve_y(y_aabb, y_sign)) |p| {
                    self.pos_y = try_y + p;
                    self.vel_y = 0;
                    if (dy > 0) self.on_ground = true;
                } else {
                    self.pos_y = try_y;
                    if (dy > 0) self.on_ground = false;
                }
            }
        }

        {
            var probe = collision.AABB.init(
                self.pos_x - self.width / 2,
                self.pos_y - self.height,
                self.pos_x + self.width / 2,
                self.pos_y,
            );
            probe.max_y += 1.0;
            if (!cs.is_empty(probe)) {
                if (!self.on_ground) {
                    const push = cs.resolve_y(probe, 1);
                    if (push) |p| self.pos_y += p;
                    self.vel_y = 0;
                }
                self.on_ground = true;
            } else if (self.on_ground) {
                self.on_ground = false;
            }
        }
    }

    fn update_flying(self: *Enemy, dt: f32) void {
        self.fly_phase += dt * 2.0;
        const target_x = self.start_x + @sin(self.fly_phase * 0.5) * 80.0;
        const target_y = self.start_y + @sin(self.fly_phase) * 30.0;

        const lerp_speed: f32 = 2.0;
        self.pos_x += (target_x - self.pos_x) * lerp_speed * dt;
        self.pos_y += (target_y - self.pos_y) * lerp_speed * dt;

        if (target_x - self.pos_x < -1.0) {
            self.facing_left = true;
        } else if (target_x - self.pos_x > 1.0) {
            self.facing_left = false;
        }
    }

    pub fn draw(
        self: *Enemy,
        renderer: *gfx.gl_utils.SpriteRenderer,
        renderer_ind: *gfx.gl_utils.IndexedSpriteRenderer,
        gctx: *const context.GameContext,
    ) void {
        if (!self.alive) return;

        const animset = gctx.draw_ctx.animset;
        const palettes = gctx.draw_ctx.palettes;
        const cam_pos = gctx.cam_pos;
        const scr_w = gctx.draw_ctx.scr_w;
        const scr_h = gctx.draw_ctx.scr_h;
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

        const dy = screen_y - frame.height;
        if (self.facing_left) {
            const dx = screen_x + frame.width + frame.hotspotX;
            render_tex_mirrored(renderer, renderer_ind, frame.texture, palettes[palette_id], dx, dy, frame.width, frame.height);
        } else {
            const dx = screen_x + frame.hotspotX;
            render_tex(renderer, renderer_ind, frame.texture, palettes[palette_id], dx, dy, frame.width, frame.height);
        }
    }
};

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
