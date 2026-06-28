const assets = @import("assets.zig");
const gfx = @import("gfx");
const m = @import("g_math.zig");

/// Bundles the stable rendering parameters shared across draw calls:
/// the loaded assets (tileset, animset, GPU palettes) and the screen dimensions.
/// Populated once and passed through the draw chain.
pub const DrawContext = struct {
    tileset: *const assets.Tileset,
    animset: *const assets.Animset,
    palettes: []const gfx.gl_utils.Texture1D,
    scr_w: i32,
    scr_h: i32,
};

/// Per-frame context for rendering a game level.  Wraps the stable
/// DrawContext together with the frame-varying camera position and
/// rendering flags that are shared across draw calls.
pub const GameContext = struct {
    draw_ctx: DrawContext,
    cam_pos: m.WorldCoord,
    show_collision_mask: bool,
};
