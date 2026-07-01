const assets = @import("assets.zig");
const asset_maps = @import("assets_maps.zig");
const collision = @import("collision.zig");
const gfx = @import("gfx");
const gl = gfx.gl;
const m = @import("g_math.zig");
const g_anim = @import("g_anim.zig");
const context = @import("ctx.zig");
const Shader = gfx.gl_utils.ShaderProgram;

const TileCoord = m.TileCoord;

const MaskOverlayUniforms = enum { image, pos, spriteSize, view, projection };

/// Renders level layers with parallax, auto-scrolling, animated tiles, and
/// event sprites.  Owns the renderers and scroll-offset state; callers supply
/// the assets and camera position each frame.
pub const LevelView = struct {
    renderer: gfx.gl_utils.SpriteRenderer,
    renderer_ind: gfx.gl_utils.IndexedSpriteRenderer,
    scroll_offsets: [8]gfx.math.Vec2,
    overlay_shader: Shader(MaskOverlayUniforms),
    overlay_ind_shader: Shader(MaskOverlayUniforms),
    aabb_overlay_shader: Shader(MaskOverlayUniforms),
    aabb_tex: gfx.gl_utils.Texture2D,

    const vertex_sh = @embedFile("./gfx/glsl/sprite.vert.glsl");
    const fragment_sh = @embedFile("./gfx/glsl/sprite.frag.glsl");
    const fragment_sh_ind = @embedFile("./gfx/glsl/sprite_ind.frag.glsl");
    const mask_overlay_frag = @embedFile("./gfx/glsl/mask_overlay.frag.glsl");
    const mask_overlay_ind_frag = @embedFile("./gfx/glsl/mask_overlay_ind.frag.glsl");
    const aabb_overlay_frag = @embedFile("./gfx/glsl/aabb_overlay.frag.glsl");

    /// Initialises both RGBA and indexed-sprite renderers, plus the overlay
    /// shaders used for collision-mask display.  All share the same projection.
    pub fn init(scr_w: i32, scr_h: i32) !LevelView {
        const zero = gfx.math.Vec2.init(0, 0);
        const scr_w_f: f32 = @floatFromInt(scr_w);
        const scr_h_f: f32 = @floatFromInt(scr_h);
        var self = LevelView{
            .renderer = try .init(vertex_sh, fragment_sh, scr_w_f, scr_h_f),
            .renderer_ind = try .init(vertex_sh, fragment_sh_ind, scr_w_f, scr_h_f),
            .scroll_offsets = [_]gfx.math.Vec2{zero} ** 8,
            .overlay_shader = try .init(vertex_sh, mask_overlay_frag, null),
            .overlay_ind_shader = try .init(vertex_sh, mask_overlay_ind_frag, null),
            .aabb_overlay_shader = try .init(vertex_sh, aabb_overlay_frag, null),
            .aabb_tex = undefined,
        };

        // Share the main view/projection matrices with the overlay shaders.
        self.overlay_shader.use_prog();
        self.overlay_shader.set_int(.image, 0);
        self.overlay_shader.set_mat4(.projection, self.renderer.projection.m);
        self.overlay_shader.set_mat4(.view, self.renderer.view.m);

        self.overlay_ind_shader.use_prog();
        self.overlay_ind_shader.set_int(.image, 0);
        self.overlay_ind_shader.set_mat4(.projection, self.renderer.projection.m);
        self.overlay_ind_shader.set_mat4(.view, self.renderer.view.m);

        self.aabb_overlay_shader.use_prog();
        self.aabb_overlay_shader.set_int(.image, 0);
        self.aabb_overlay_shader.set_mat4(.projection, self.renderer.projection.m);
        self.aabb_overlay_shader.set_mat4(.view, self.renderer.view.m);

        // 1×1 white RGBA texture for solid-colour overlay quads.
        {
            const white_pixel = [_]u8{ 255, 255, 255, 255 };
            self.aabb_tex = try gfx.gl_utils.Texture2D.init_from_rgba(&white_pixel, 1, 1);
        }

        return self;
    }

    pub fn deinit(self: *@This()) void {
        self.aabb_tex.deinit();
        self.aabb_overlay_shader.deinit();
        self.overlay_ind_shader.deinit();
        self.overlay_shader.deinit();
        self.renderer_ind.deinit();
        self.renderer.deinit();
    }

    /// Draws one layer's tile grid.  Iterates over the visible tile rectangle,
    /// resolves static vs. animated tiles, and renders each visible tile.
    /// Optionally draws collision-mask overlays on top.
    fn draw_layer_tiles(
        self: *LevelView,
        level: *const assets.Level,
        gctx: *const context.GameContext,
        layer: *const assets.Layer,
        off_x_int: i32,
        off_y_int: i32,
        tile_start_x: i32,
        tile_start_y: i32,
        tile_end_x: i32,
        tile_end_y: i32,
        time_elapsed: f32,
    ) void {
        const tileset = gctx.draw_ctx.tileset;
        const palettes = gctx.draw_ctx.palettes;
        const scr_w = gctx.draw_ctx.scr_w;
        const scr_h = gctx.draw_ctx.scr_h;
        const show_collision_mask = gctx.show_collision_mask;
        const cells = layer.cells.?;
        const layer_w: i32 = @intCast(layer.width);
        const layer_h: i32 = @intCast(layer.height);
        const tile_size_i32: i32 = @intCast(TileCoord.SIZE);
        var ty: i32 = tile_start_y;
        while (ty < tile_end_y) : (ty += 1) {
            var tx: i32 = tile_start_x;
            while (tx < tile_end_x) : (tx += 1) {
                // Wrap tile coordinates when the layer has repeat_x/repeat_y set.
                const tile_x = if (layer.flags.repeat_x) @mod(tx, layer_w) else tx;
                const tile_y = if (layer.flags.repeat_y) @mod(ty, layer_h) else ty;

                if (tile_x < 0 or tile_x >= layer_w or tile_y < 0 or tile_y >= layer_h) continue;

                const maybe_lev_tile = cells[@as(usize, @intCast(tile_y))][@as(usize, @intCast(tile_x))].tile;
                if (maybe_lev_tile) |lev_tile| {
                    const sx = tx * tile_size_i32 - off_x_int;
                    const sy = ty * tile_size_i32 - off_y_int;

                    if (sx + tile_size_i32 < 0 or sx > scr_w) continue;
                    if (sy + tile_size_i32 < 0 or sy > scr_h) continue;

                    const idd = lev_tile.id;
                    // Resolve tile index: static tiles use the index directly,
                    // animated tiles compute the current frame from the level's animation table.
                    const tileset_idx, const asset_tile = switch (idd) {
                        assets.TileId.static_tile => |id| .{ id, tileset.tiles[id] },
                        assets.TileId.anim_tile => |id| blk: {
                            const anim = level.animated_tiles[id];
                            const frame_no = g_anim.calc_curr_frame(time_elapsed, anim.frame_count, anim.speed, anim.is_ping_pong);
                            const frame_id = anim.frames[frame_no];
                            break :blk .{ frame_id, tileset.tiles[frame_id] };
                        },
                    };
                    render_tex(self, asset_tile.texture, palettes[0], sx, sy);

                    if (show_collision_mask) {
                        if (tileset.mask_overlays) |overlays| {
                            self.draw_mask_overlay(overlays[tileset_idx], sx, sy);
                        }
                    }
                }
            }
        }
    }

    /// Draws event sprites (gems, springs, enemies, etc.) on layer 3.
    /// Uses the animset to look up the sprite for each event, selects the
    /// gem-colour palette variant, and renders at the tile's hotspot offset.
    fn draw_layer_events(
        self: *LevelView,
        gctx: *const context.GameContext,
        layer: *const assets.Layer,
        off_x_int: i32,
        off_y_int: i32,
        tile_start_x: i32,
        tile_start_y: i32,
        tile_end_x: i32,
        tile_end_y: i32,
        time_elapsed: f32,
    ) void {
        const animset = gctx.draw_ctx.animset;
        const palettes = gctx.draw_ctx.palettes;
        const show_collision_mask = gctx.show_collision_mask;
        const cells = layer.cells.?;
        const layer_w: i32 = @intCast(layer.width);
        const layer_h: i32 = @intCast(layer.height);
        const tile_size_i32: i32 = @intCast(TileCoord.SIZE);
        const half_tile: i32 = tile_size_i32 / 2;
        var ty: i32 = tile_start_y;
        while (ty < tile_end_y) : (ty += 1) {
            if (ty < 0 or ty >= layer_h) continue;
            var tx: i32 = tile_start_x;
            while (tx < tile_end_x) : (tx += 1) {
                if (tx < 0 or tx >= layer_w) continue;
                if (cells[@as(usize, @intCast(ty))][@as(usize, @intCast(tx))].event) |ev| {
                    if (asset_maps.is_enemy_event(ev.id)) continue;
                    const sx = tx * tile_size_i32 - off_x_int;
                    const sy = ty * tile_size_i32 - off_y_int;

                    // Gems use palette slots 1-4 (red, green, blue, purple).
                    var palette_id: usize = 0;
                    if (@intFromEnum(ev.id) >= @intFromEnum(asset_maps.EventId.RedGemPlus1) and @intFromEnum(ev.id) <= @intFromEnum(asset_maps.EventId.PurpleGemPlus1)) {
                        palette_id = @intFromEnum(ev.id) - @intFromEnum(asset_maps.EventId.RedGemPlus1) + 1;
                    }
                    if (asset_maps.event2animsetinxd(ev.id)) |anim| {
                        const a = &animset.blocks[anim.animblock].anims[anim.anim];
                        const always = asset_maps.event_always_animates(ev.id);
                        const elapsed = if (always) time_elapsed else 0;
                        const frame = g_anim.calc_curr_frame_for_anim(elapsed, a);
                        const obj = a.frames[frame];
                        // Horizontal: hotspotX offsets from tile centre (half_tile).
                        // Vertical (always-animating): hotspotY offsets from tile centre.
                        // Vertical (trigger-only): sprite bottom aligns with tile bottom.
                        const dy = if (always) sy + obj.hotspotY + half_tile else sy + tile_size_i32 - obj.height;
                        render_tex(self, obj.texture, palettes[palette_id], sx + obj.hotspotX + half_tile, dy);

                        if (show_collision_mask) {
                            self.render_mask_overlay(obj.texture, sx + obj.hotspotX + half_tile, dy);
                        }
                    }
                }
            }
        }
    }

    /// Renders all visible layers (background to foreground), including
    /// parallax, auto-scrolling, animated tiles, and event sprites on layer 3.
    /// If `gctx.show_collision_mask` is true, collision mask overlays are drawn
    /// on tiles and sprites.
    pub fn draw(
        self: *@This(),
        level: *const assets.Level,
        gctx: *const context.GameContext,
        time_elapsed: f32,
        from: usize,
        to: usize,
    ) void {
        const zoom = gctx.zoom;
        const scr_w_f: f32 = @floatFromInt(gctx.draw_ctx.scr_w);
        const scr_h_f: f32 = @floatFromInt(gctx.draw_ctx.scr_h);

        // Update projection for all renderers so the same screen coordinates
        // map to a larger/smaller visible area when zoomed.
        const proj = gfx.math.Mat4x4.init_ortho(0.0, scr_w_f / zoom, scr_h_f / zoom, 0.0, -1.0, 1.0);
        self.renderer.projection = proj;
        self.renderer.shader.set_mat4(.projection, proj.m);
        self.renderer_ind.projection = proj;
        self.renderer_ind.shader.set_mat4(.projection, proj.m);
        self.overlay_shader.set_mat4(.projection, proj.m);
        self.overlay_ind_shader.set_mat4(.projection, proj.m);
        self.aabb_overlay_shader.set_mat4(.projection, proj.m);

        const w_2: f32 = scr_w_f / 2;
        const h_2: f32 = scr_h_f / 2;
        const cx: f32 = @floatFromInt(gctx.cam_pos.x);
        const cy: f32 = @floatFromInt(gctx.cam_pos.y);
        const show_collision_mask = gctx.show_collision_mask;

        // Camera centre → top-left corner of the visible area (zoom-aware).
        const base_off_x = @max(0, cx - w_2 / zoom);
        const base_off_y = @max(0, cy - h_2 / zoom);

        // Enable blending when showing collision overlays.
        const blend_was_enabled = if (show_collision_mask)
            gl.glIsEnabled(gl.GL_BLEND) == gl.GL_TRUE
        else
            true;

        if (show_collision_mask) {
            if (!blend_was_enabled) gl.glEnable(gl.GL_BLEND);
            gl.glBlendFunc(gl.GL_SRC_ALPHA, gl.GL_ONE_MINUS_SRC_ALPHA);
        }

        // Draw layers back-to-front so background layers render first.
        var numi: i32 = @intCast(from);
        while (numi >= @as(i32, @intCast(to))) : (numi -= 1) {
            const num: usize = @intCast(numi);
            const layer = &level.layers[num];
            if (layer.cells == null) continue;

            // Accumulate auto-scroll offsets for this layer.
            self.scroll_offsets[num].v[0] += layer.auto_speed_x * time_elapsed;
            self.scroll_offsets[num].v[1] += layer.auto_speed_y * time_elapsed;

            // Parallax: scale the base offset by the layer's speed factor, then add auto-scroll.
            const layer_off_x = base_off_x * layer.speed_x + self.scroll_offsets[num].v[0];
            const layer_off_y = base_off_y * layer.speed_y + self.scroll_offsets[num].v[1];

            const tile_size_f: f32 = @floatFromInt(TileCoord.SIZE);

            // Visible tile range (zoom shrinks/grows the visible area).
            const tile_start_x: i32 = @intFromFloat(@floor(layer_off_x / tile_size_f));
            const tile_start_y: i32 = @intFromFloat(@floor(layer_off_y / tile_size_f));
            const tile_end_x: i32 = @intFromFloat(@ceil((layer_off_x + scr_w_f / zoom) / tile_size_f));
            const tile_end_y: i32 = @intFromFloat(@ceil((layer_off_y + scr_h_f / zoom) / tile_size_f));

            // Pixel-precise sub-tile offset for smooth scrolling.
            const off_x_int: i32 = @intFromFloat(@floor(layer_off_x));
            const off_y_int: i32 = @intFromFloat(@floor(layer_off_y));

            self.draw_layer_tiles(level, gctx, layer, off_x_int, off_y_int, tile_start_x, tile_start_y, tile_end_x, tile_end_y, time_elapsed);

            // Event sprites (enemies, items) only live on layer 3.
            if (num == 3) {
                self.draw_layer_events(gctx, layer, off_x_int, off_y_int, tile_start_x, tile_start_y, tile_end_x, tile_end_y, time_elapsed);
            }
        }

        // Restore blending state if we changed it.
        if (show_collision_mask and !blend_was_enabled) {
            gl.glDisable(gl.GL_BLEND);
        }
    }

    fn draw_mask_overlay(self: *@This(), texture: gfx.gl_utils.Texture2D, x: i32, y: i32) void {
        self.overlay_shader.use_prog();
        self.overlay_shader.set_vec2(.pos, [2]f32{ @floatFromInt(x), @floatFromInt(y) });
        self.overlay_shader.set_vec2(.spriteSize, [2]f32{ @floatFromInt(texture.w), @floatFromInt(texture.h) });

        gl.glActiveTexture(gl.GL_TEXTURE0);
        texture.bind();

        gl.glBindVertexArray(self.renderer.quadVAO);
        gl.glDrawArrays(gl.GL_TRIANGLES, 0, 6);
        gl.glBindVertexArray(0);
    }

    fn draw_mask_overlay_ind(self: *@This(), texture: gfx.gl_utils.Texture2DInd, x: i32, y: i32) void {
        self.overlay_ind_shader.use_prog();
        self.overlay_ind_shader.set_vec2(.pos, [2]f32{ @floatFromInt(x), @floatFromInt(y) });
        self.overlay_ind_shader.set_vec2(.spriteSize, [2]f32{ @floatFromInt(texture.w), @floatFromInt(texture.h) });

        gl.glActiveTexture(gl.GL_TEXTURE0);
        texture.bind();

        gl.glBindVertexArray(self.renderer.quadVAO);
        gl.glDrawArrays(gl.GL_TRIANGLES, 0, 6);
        gl.glBindVertexArray(0);
    }

    /// Draws a green semi-transparent filled rectangle for a world-space AABB.
    /// The rectangle is drawn at screen coordinates derived from the camera offset.
    pub fn draw_aabb(
        self: *@This(),
        aabb: collision.AABB,
        gctx: *const context.GameContext,
    ) void {
        const zoom = gctx.zoom;
        const w_2: f32 = @floatFromInt(@divTrunc(gctx.draw_ctx.scr_w, 2));
        const h_2: f32 = @floatFromInt(@divTrunc(gctx.draw_ctx.scr_h, 2));
        const cx: f32 = @floatFromInt(gctx.cam_pos.x);
        const cy: f32 = @floatFromInt(gctx.cam_pos.y);

        const base_off_x = @max(0, cx - w_2 / zoom);
        const base_off_y = @max(0, cy - h_2 / zoom);

        const sx: i32 = @intFromFloat(aabb.min_x - base_off_x);
        const sy: i32 = @intFromFloat(aabb.min_y - base_off_y);

        self.aabb_overlay_shader.use_prog();
        self.aabb_overlay_shader.set_vec2(.pos, [2]f32{ @floatFromInt(sx), @floatFromInt(sy) });
        self.aabb_overlay_shader.set_vec2(.spriteSize, [2]f32{ aabb.width(), aabb.height() });

        gl.glActiveTexture(gl.GL_TEXTURE0);
        self.aabb_tex.bind();

        gl.glBindVertexArray(self.renderer.quadVAO);
        gl.glDrawArrays(gl.GL_TRIANGLES, 0, 6);
        gl.glBindVertexArray(0);
    }

    /// Dispatches to the correct overlay shader based on texture variant.
    fn render_mask_overlay(self: *@This(), tex: assets.Texture, x: i32, y: i32) void {
        switch (tex) {
            .texture2d => |t| self.draw_mask_overlay(t, x, y),
            .texture2dind => |t| self.draw_mask_overlay_ind(t, x, y),
        }
    }
};

/// Helper: draws a single tile/event texture at screen (x, y).
/// Dispatches to the RGBA or indexed-sprite renderer depending on texture type.
fn render_tex(self: *LevelView, tex: assets.Texture, palette: gfx.gl_utils.Texture1D, x: i32, y: i32) void {
    const position = gfx.math.Vec2.init(@floatFromInt(x), @floatFromInt(y));
    const color = gfx.math.Vec3.init(1.0, 1.0, 1.0);
    switch (tex) {
        .texture2d => |t| self.renderer.draw(t, position, color),
        .texture2dind => |t| self.renderer_ind.draw(t, palette, position, color),
    }
}
