const std = @import("std");
const assets = @import("assets.zig");
const asset_maps = @import("assets_maps.zig");
const gfx = @import("gfx");
const m = @import("g_math.zig");
const g_anim = @import("g_anim.zig");

const WorldCoord = m.WorldCoord;
const TileCoord = m.TileCoord;

/// Renders level layers with parallax, auto-scrolling, animated tiles, and
/// event sprites.  Owns the renderers and scroll-offset state; callers supply
/// the assets and camera position each frame.
pub const LevelView = struct {
    renderer: gfx.gl_utils.SpriteRenderer,
    renderer_ind: gfx.gl_utils.IndexedSpriteRenderer,
    scroll_offsets: [8]gfx.math.Vec2,

    const vertex_sh = @embedFile("./gfx/glsl/sprite.vert.glsl");
    const fragment_sh = @embedFile("./gfx/glsl/sprite.frag.glsl");
    const fragment_sh_ind = @embedFile("./gfx/glsl/sprite_ind.frag.glsl");

    pub fn init(scr_w: i32, scr_h: i32) !LevelView {
        const zero = gfx.math.Vec2.init(0, 0);
        return .{
            .renderer = try .init(vertex_sh, fragment_sh, @floatFromInt(scr_w), @floatFromInt(scr_h)),
            .renderer_ind = try .init(vertex_sh, fragment_sh_ind, @floatFromInt(scr_w), @floatFromInt(scr_h)),
            .scroll_offsets = [_]gfx.math.Vec2{zero} ** 8,
        };
    }

    pub fn deinit(self: *@This()) void {
        self.renderer_ind.deinit();
        self.renderer.deinit();
    }

    /// Renders all visible layers (background to foreground), including
    /// parallax, auto-scrolling, animated tiles, and event sprites on layer 3.
    pub fn draw(
        self: *@This(),
        level: *const assets.Level,
        tileset: *const assets.Tileset,
        animset: *const assets.Animset,
        palettes: []const gfx.gl_utils.Texture1D,
        cam_pos: WorldCoord,
        scr_w: i32,
        scr_h: i32,
        time_elapsed: f32,
    ) void {
        const w_2: f32 = @floatFromInt(@divTrunc(scr_w, 2));
        const h_2: f32 = @floatFromInt(@divTrunc(scr_h, 2));
        const cx: f32 = @floatFromInt(cam_pos.x);
        const cy: f32 = @floatFromInt(cam_pos.y);

        const base_off_x = @max(0, cx - w_2);
        const base_off_y = @max(0, cy - h_2);

        var numi: i32 = @as(i32, @intCast(level.layers.len)) - 1;
        while (numi >= 0) : (numi -= 1) {
            const num: usize = @intCast(numi);
            const layer = &level.layers[num];
            if (layer.cells == null) continue;
            const cells = layer.cells.?;

            self.scroll_offsets[num].v[0] += layer.auto_speed_x * time_elapsed;
            self.scroll_offsets[num].v[1] += layer.auto_speed_y * time_elapsed;

            const layer_off_x = base_off_x * layer.speed_x + self.scroll_offsets[num].v[0];
            const layer_off_y = base_off_y * layer.speed_y + self.scroll_offsets[num].v[1];

            const tile_size_f: f32 = @floatFromInt(TileCoord.SIZE);
            const scr_w_f: f32 = @floatFromInt(scr_w);
            const scr_h_f: f32 = @floatFromInt(scr_h);

            const tile_start_x: i32 = @intFromFloat(@floor(layer_off_x / tile_size_f));
            const tile_start_y: i32 = @intFromFloat(@floor(layer_off_y / tile_size_f));
            const tile_end_x: i32 = @intFromFloat(@ceil((layer_off_x + scr_w_f) / tile_size_f));
            const tile_end_y: i32 = @intFromFloat(@ceil((layer_off_y + scr_h_f) / tile_size_f));

            const layer_w: i32 = @intCast(layer.width);
            const layer_h: i32 = @intCast(layer.height);
            const off_x_int: i32 = @intFromFloat(@floor(layer_off_x));
            const off_y_int: i32 = @intFromFloat(@floor(layer_off_y));

            {
                const tile_size_i32: i32 = @intCast(TileCoord.SIZE);
                var ty: i32 = tile_start_y;
                while (ty < tile_end_y) : (ty += 1) {
                    var tx: i32 = tile_start_x;
                    while (tx < tile_end_x) : (tx += 1) {
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
                            const asset_tile = switch (idd) {
                                assets.TileId.static_tile => |id| tileset.tiles[id],
                                assets.TileId.anim_tile => |id| blk: {
                                    const anim = level.animated_tiles[id];
                                    const frame_no = g_anim.calc_curr_frame(time_elapsed, anim.frame_count, anim.speed, anim.is_ping_pong);
                                    const frame_id = anim.frames[frame_no];
                                    break :blk tileset.tiles[frame_id];
                                },
                            };
                            render_tex(self, asset_tile.texture, palettes[0], sx, sy);
                        }
                    }
                }
            }

            if (num == 3) {
                const tile_size_i32: i32 = @intCast(TileCoord.SIZE);
                var ty: i32 = tile_start_y;
                while (ty < tile_end_y) : (ty += 1) {
                    if (ty < 0 or ty >= layer_h) continue;
                    var tx: i32 = tile_start_x;
                    while (tx < tile_end_x) : (tx += 1) {
                        if (tx < 0 or tx >= layer_w) continue;
                        if (cells[@as(usize, @intCast(ty))][@as(usize, @intCast(tx))].event) |ev| {
                            const sx = tx * tile_size_i32 - off_x_int;
                            const sy = ty * tile_size_i32 - off_y_int;

                            var palette_id: usize = 0;
                            if (@intFromEnum(ev.id) >= @intFromEnum(asset_maps.EventId.RedGemPlus1) and @intFromEnum(ev.id) <= @intFromEnum(asset_maps.EventId.PurpleGemPlus1)) {
                                palette_id = @intFromEnum(ev.id) - @intFromEnum(asset_maps.EventId.RedGemPlus1) + 1;
                            }
                            if (asset_maps.event2animsetinxd(ev.id)) |anim| {
                                const a = &animset.blocks[anim.animblock].anims[anim.anim];
                                const frame = g_anim.calc_curr_frame_for_anim(time_elapsed * 10.0, a);
                                const obj = a.frames[frame];
                                render_tex(self, obj.texture, palettes[palette_id], sx + obj.hotspotX + 16, sy + obj.hotspotY + 16);
                            }
                        }
                    }
                }
            }
        }
    }

    fn render_tex(self: *@This(), tex: assets.Texture, palette: gfx.gl_utils.Texture1D, x: i32, y: i32) void {
        const position = gfx.math.Vec2.init(@floatFromInt(x), @floatFromInt(y));
        const color = gfx.math.Vec3.init(1.0, 1.0, 1.0);
        switch (tex) {
            .texture2d => |t| self.renderer.draw(t, position, color),
            .texture2dind => |t| self.renderer_ind.draw(t, palette, position, color),
        }
    }
};
