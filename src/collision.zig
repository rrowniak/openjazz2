const std = @import("std");
const testing = std.testing;
const assets = @import("assets.zig");
const g_anim = @import("g_anim.zig");
const asset_reader = @import("assets_reader.zig");

// ── AABB ──

/// Axis-aligned bounding box in world pixel space.
pub const AABB = struct {
    /// Minimum X (left edge) in world pixel coordinates.
    min_x: f32,
    /// Minimum Y (top edge) in world pixel coordinates.
    min_y: f32,
    /// Maximum X (right edge) in world pixel coordinates.
    max_x: f32,
    /// Maximum Y (bottom edge) in world pixel coordinates.
    max_y: f32,

    /// Creates an AABB from explicit min/max edges.
    pub fn init(min_x: f32, min_y: f32, max_x: f32, max_y: f32) AABB {
        return .{ .min_x = min_x, .min_y = min_y, .max_x = max_x, .max_y = max_y };
    }

    /// Returns the box width (max_x - min_x).
    pub fn width(self: @This()) f32 {
        return self.max_x - self.min_x;
    }

    /// Returns the box height (max_y - min_y).
    pub fn height(self: @This()) f32 {
        return self.max_y - self.min_y;
    }

    /// Returns true if this box overlaps `other` (separating-axis test).
    /// Edges that merely touch do NOT count as overlap.
    pub fn overlaps(self: @This(), other: @This()) bool {
        return self.min_x < other.max_x and
            self.max_x > other.min_x and
            self.min_y < other.max_y and
            self.max_y > other.min_y;
    }

    /// Returns true if the point `(px, py)` lies inside the box
    /// (inclusive on the min edge, exclusive on the max edge).
    pub fn contains_point(self: @This(), px: f32, py: f32) bool {
        return px >= self.min_x and px < self.max_x and
            py >= self.min_y and py < self.max_y;
    }

    /// Returns a new AABB shifted by `(dx, dy)` in world space.
    pub fn translate(self: @This(), dx: f32, dy: f32) AABB {
        return .{
            .min_x = self.min_x + dx,
            .min_y = self.min_y + dy,
            .max_x = self.max_x + dx,
            .max_y = self.max_y + dy,
        };
    }
};

// ── Player hitbox ──

/// Player hitbox dimensions.
///
/// Hardcoded because per‑frame hotspot/coldspot data differs across
/// animation states (e.g. idle vs fall), causing the collision box to
/// shift relative to the entity position when the animation changes.
/// That shift makes floor detection unreliable — the probe misses the
/// ground after landing because the hitbox bottom moved up.  A fixed
/// hitbox avoids this entirely.
///
/// The hotspot is at the sprite's center‑bottom; the +8 Y offset shifts
/// the hitbox centre to the character's waist, giving a 22×30 collision box.
pub const PLAYER_WIDTH: f32 = 22;
pub const PLAYER_HEIGHT: f32 = 30;
pub const PLAYER_OFFSET_Y: f32 = 20;

/// Returns the player's world‑space AABB. Uses fixed dimensions so the
/// hitbox is stable regardless of the current animation frame.
pub fn player_aabb(pos_x: f32, pos_y: f32) AABB {
    return AABB.init(
        pos_x - PLAYER_WIDTH / 2,
        pos_y + PLAYER_OFFSET_Y - PLAYER_HEIGHT,
        pos_x + PLAYER_WIDTH / 2,
        pos_y + PLAYER_OFFSET_Y,
    );
}

// ── Frame hitbox ──

/// Returns a world‑space AABB for a sprite at `(pos_x, pos_y)` based on the
/// given animation frame's hotspot and coldspot.
/// The formula `pos - hotspot + coldspot` gives the coldspot centre in world
/// space; a fallback size of `frame.size - 2` is used on each axis.
pub fn frame_aabb(pos_x: f32, pos_y: f32, frame: assets.Frame) AABB {
    const fw: f32 = @floatFromInt(frame.width);
    const fh: f32 = @floatFromInt(frame.height);
    const hx: f32 = @floatFromInt(frame.hotspotX);
    const hy: f32 = @floatFromInt(frame.hotspotY);
    const csx: f32 = @floatFromInt(frame.coldspotX);
    const csy: f32 = @floatFromInt(frame.coldspotY);

    const hitbox_w = fw - 2;
    const hitbox_h = fh - 2;
    const center_x = pos_x - hx + csx;
    const bottom_y = pos_y - hy + csy;

    return AABB.init(
        center_x - hitbox_w / 2,
        bottom_y - hitbox_h,
        center_x + hitbox_w / 2,
        bottom_y,
    );
}

// ── Collision flags ──

/// Bit-packed flags returned after a collision resolve.
/// Each field represents a single contact direction.
pub const CollisionFlags = packed struct {
    on_ground: bool,
    touch_ceiling: bool,
    touch_wall_left: bool,
    touch_wall_right: bool,
};

// ── Tile pixel helpers ──

/// Returns true if the pixel at `(local_x, local_y)` within the tile's
/// collision mask is solid.  Applies flip transforms.
///
/// The mask is a 1‑bit‑per‑pixel bitmap stored row‑major. TILE_SIZE defines
/// the tile dimension (typically 32 px) and BIT_MASK_SIZE = TILE_SIZE² / 8.
pub fn is_tile_pixel_solid(
    mask: []const u8,
    flip_x: bool,
    flip_y: bool,
    local_x: usize,
    local_y: usize,
) bool {
    // Apply flips to map tile-local coords to mask coords.
    const px = if (flip_x) (assets.TILE_SIZE - 1) - local_x else local_x;
    const py = if (flip_y) (assets.TILE_SIZE - 1) - local_y else local_y;

    const bit_idx = py * assets.TILE_SIZE + px;
    const byte_idx = bit_idx / 8;
    const bit_off: u3 = @intCast(bit_idx % 8);
    return (mask[byte_idx] >> bit_off) & 1 == 1;
}

/// Resolves a tile ID (static or animated) into a concrete tileset index.
pub fn resolve_tileset_idx(
    tile_id: assets.TileId,
    animated_tiles: []const asset_reader.AnimatedTile,
    time_elapsed: f32,
) usize {
    return switch (tile_id) {
        .static_tile => |id| id,
        .anim_tile => |id| {
            const anim = animated_tiles[id];
            const frame_no = g_anim.calc_curr_frame(
                time_elapsed,
                anim.frame_count,
                anim.speed,
                anim.is_ping_pong,
            );
            return anim.frames[frame_no];
        },
    };
}

// ── Core tile collision query ──

/// Returns `true` if the given AABB does *not* overlap any solid tile pixels
/// on the specified layer.  Returns `false` if a collision is detected.
///
/// Iterates all tiles that the AABB touches, then scans overlapping pixel
/// regions against each tile's collision bitmask.
pub fn is_position_empty(
    aabb: AABB,
    layer: *const assets.Layer,
    tileset: *const assets.Tileset,
    animated_tiles: []const asset_reader.AnimatedTile,
    time_elapsed: f32,
) bool {
    // Layer with no cells is vacuously empty.
    const cells = layer.cells orelse return true;
    const layer_w: i32 = @intCast(layer.width);
    const layer_h: i32 = @intCast(layer.height);

    // Tile-range that the AABB covers (clamped to layer bounds).
    const t_min_x = @max(@as(i32, @intFromFloat(@floor(aabb.min_x / 32))), 0);
    const t_min_y = @max(@as(i32, @intFromFloat(@floor(aabb.min_y / 32))), 0);
    const t_max_x = @min(@as(i32, @intFromFloat(@floor((aabb.max_x - 0.001) / 32))), layer_w - 1);
    const t_max_y = @min(@as(i32, @intFromFloat(@floor((aabb.max_y - 0.001) / 32))), layer_h - 1);

    // AABB entirely outside the layer → empty.
    if (t_min_x > t_max_x or t_min_y > t_max_y) return true;

    // Walk every overlapping tile.
    var ty: i32 = t_min_y;
    while (ty <= t_max_y) : (ty += 1) {
        const row = cells[@as(usize, @intCast(ty))];
        var tx: i32 = t_min_x;
        while (tx <= t_max_x) : (tx += 1) {
            const cell = row[@as(usize, @intCast(tx))];
            // Empty cell (no tile placed).
            const maybe_lev_tile = cell.tile orelse continue;
            const lev_tile = maybe_lev_tile;

            // Resolve tile index (handles animated tiles).
            const tileset_idx = resolve_tileset_idx(lev_tile.id, animated_tiles, time_elapsed);
            if (tileset_idx >= tileset.tiles.len) continue;
            const tile = &tileset.tiles[tileset_idx];

            const tile_world_x: i32 = tx * 32;
            const tile_world_y: i32 = ty * 32;

            // Pixel-level overlap region between the AABB and this tile.
            const overlap_l = @max(@as(i32, @intFromFloat(aabb.min_x)), tile_world_x);
            const overlap_r = @min(@as(i32, @intFromFloat(aabb.max_x)), tile_world_x + 32);
            const overlap_t = @max(@as(i32, @intFromFloat(aabb.min_y)), tile_world_y);
            const overlap_b = @min(@as(i32, @intFromFloat(aabb.max_y)), tile_world_y + 32);

            if (overlap_l >= overlap_r or overlap_t >= overlap_b) continue;

            // Scan every overlapping pixel; if any is solid → colliding.
            var py: i32 = overlap_t;
            while (py < overlap_b) : (py += 1) {
                var px: i32 = overlap_l;
                while (px < overlap_r) : (px += 1) {
                    const lx: usize = @intCast(px - tile_world_x);
                    const ly: usize = @intCast(py - tile_world_y);
                    if (is_tile_pixel_solid(
                        tile.collision_bit_mask[0..],
                        lev_tile.flip_x,
                        lev_tile.flip_y,
                        lx,
                        ly,
                    )) {
                        return false;
                    }
                }
            }
        }
    }
    return true;
}

/// Resolves collision along one axis for an already-displaced AABB.
/// Returns the push-out distance needed to clear all solid tile pixels,
/// or `null` if no collision occurred.
///
/// The AABB is already at the *new* (displaced) position.  This function
/// finds the minimum push-out that eliminates all overlaps with solid pixels
/// along the given axis.
///
/// `axis`:    `0` = X, `1` = Y
/// `vel_sign`: `-1` (moving left/up), `0` (stationary), `1` (moving right/down).
///   Determines the push direction — we push back against the movement.
pub fn resolve_axis(
    moved_aabb: AABB,
    layer: *const assets.Layer,
    tileset: *const assets.Tileset,
    animated_tiles: []const asset_reader.AnimatedTile,
    time_elapsed: f32,
    axis: u1,
    vel_sign: i2,
) ?f32 {
    if (vel_sign == 0) return null;

    // No cells → nothing to collide with.
    const cells = layer.cells orelse return null;
    const layer_w: i32 = @intCast(layer.width);
    const layer_h: i32 = @intCast(layer.height);

    // Tile-range that the displaced AABB covers.
    const t_min_x = @max(@as(i32, @intFromFloat(@floor(moved_aabb.min_x / 32))), 0);
    const t_min_y = @max(@as(i32, @intFromFloat(@floor(moved_aabb.min_y / 32))), 0);
    const t_max_x = @min(@as(i32, @intFromFloat(@floor((moved_aabb.max_x - 0.001) / 32))), layer_w - 1);
    const t_max_y = @min(@as(i32, @intFromFloat(@floor((moved_aabb.max_y - 0.001) / 32))), layer_h - 1);

    if (t_min_x > t_max_x or t_min_y > t_max_y) return null;

    var result_push: f32 = undefined;
    var found = false;

    // Walk every overlapping tile.
    var ty: i32 = t_min_y;
    while (ty <= t_max_y) : (ty += 1) {
        const row = cells[@as(usize, @intCast(ty))];
        var tx: i32 = t_min_x;
        while (tx <= t_max_x) : (tx += 1) {
            const cell = row[@as(usize, @intCast(tx))];
            // Empty cell → no collision.
            const maybe_lev_tile = cell.tile orelse continue;
            const lev_tile = maybe_lev_tile;

            const tileset_idx = resolve_tileset_idx(lev_tile.id, animated_tiles, time_elapsed);
            if (tileset_idx >= tileset.tiles.len) continue;
            const tile = &tileset.tiles[tileset_idx];

            const tile_world_x: i32 = tx * 32;
            const tile_world_y: i32 = ty * 32;

            // Overlap rect in world pixel coords.
            const overlap_l = @max(@as(i32, @intFromFloat(moved_aabb.min_x)), tile_world_x);
            const overlap_r = @min(@as(i32, @intFromFloat(moved_aabb.max_x)), tile_world_x + 32);
            const overlap_t = @max(@as(i32, @intFromFloat(moved_aabb.min_y)), tile_world_y);
            const overlap_b = @min(@as(i32, @intFromFloat(moved_aabb.max_y)), tile_world_y + 32);

            if (overlap_l >= overlap_r or overlap_t >= overlap_b) continue;

            // Scan overlapping pixels.
            var py: i32 = overlap_t;
            while (py < overlap_b) : (py += 1) {
                var px: i32 = overlap_l;
                while (px < overlap_r) : (px += 1) {
                    const lx: usize = @intCast(px - tile_world_x);
                    const ly: usize = @intCast(py - tile_world_y);
                    if (is_tile_pixel_solid(
                        tile.collision_bit_mask[0..],
                        lev_tile.flip_x,
                        lev_tile.flip_y,
                        lx,
                        ly,
                    )) {
                        // Found a solid pixel — compute push distance.
                        if (axis == 0) {
                            if (vel_sign > 0) {
                                // Moving right: push left (negative).
                                const d = @as(f32, @floatFromInt(px)) - moved_aabb.max_x;
                                if (!found or d < result_push) {
                                    result_push = d;
                                    found = true;
                                }
                            } else {
                                // Moving left: push right (positive).
                                const d = (@as(f32, @floatFromInt(px)) + 1) - moved_aabb.min_x;
                                if (!found or d > result_push) {
                                    result_push = d;
                                    found = true;
                                }
                            }
                        } else {
                            if (vel_sign > 0) {
                                // Moving down: push up (negative).
                                const d = @as(f32, @floatFromInt(py)) - moved_aabb.max_y;
                                if (!found or d < result_push) {
                                    result_push = d;
                                    found = true;
                                }
                            } else {
                                // Moving up: push down (positive).
                                const d = (@as(f32, @floatFromInt(py)) + 1) - moved_aabb.min_y;
                                if (!found or d > result_push) {
                                    result_push = d;
                                    found = true;
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    return if (found) result_push else null;
}

// ── Spatial Grid ──

/// Simple spatial hash grid with fixed 32px cells.
/// Stores entity IDs in cells they overlap.  Used for broad-phase entity-entity
/// collision queries.
///
/// Register → Move → Query → Remove is the typical lifecycle for each entity.
pub const SpatialGrid = struct {
    const Cell = std.ArrayListUnmanaged(usize);

    /// Flat array of cells (row-major, num_cols × num_rows).
    cells: []Cell,
    num_cols: usize,
    num_rows: usize,
    alloc: std.mem.Allocator,

    /// Allocates a grid with `num_cols × num_rows` cells, all initially empty.
    pub fn init(alloc: std.mem.Allocator, num_cols: usize, num_rows: usize) !SpatialGrid {
        const total = num_cols * num_rows;
        const cells = try alloc.alloc(Cell, total);
        for (cells) |*c| c.* = .empty;
        return .{
            .cells = cells,
            .num_cols = num_cols,
            .num_rows = num_rows,
            .alloc = alloc,
        };
    }

    pub fn deinit(self: *@This()) void {
        for (self.cells) |*c| c.deinit(self.alloc);
        self.alloc.free(self.cells);
    }

    /// Inserts `id` into all cells that the given AABB overlaps.
    /// Idempotent — calling register twice for the same id will duplicate it.
    pub fn register(self: *@This(), id: usize, aabb: AABB) void {
        const r = self.cell_range(aabb);
        var row = r.row_min;
        while (row <= r.row_max) : (row += 1) {
            var col = r.col_min;
            while (col <= r.col_max) : (col += 1) {
                self.cells[self.cell_idx(col, row)].append(self.alloc, id) catch {};
            }
        }
    }

    /// Removes `id` from all cells that the given AABB overlaps.
    /// Uses swap-remove (O(1) but does not preserve order).
    pub fn remove(self: *@This(), id: usize, aabb: AABB) void {
        const r = self.cell_range(aabb);
        var row = r.row_min;
        while (row <= r.row_max) : (row += 1) {
            var col = r.col_min;
            while (col <= r.col_max) : (col += 1) {
                const cell = &self.cells[self.cell_idx(col, row)];
                for (cell.items, 0..) |eid, i| {
                    if (eid == id) {
                        _ = cell.swapRemove(i);
                        break;
                    }
                }
            }
        }
    }

    /// Moves `id` from `old_aabb` cells to `new_aabb` cells efficiently by
    /// only touching cells that changed.
    ///
    /// Cells present in both old and new ranges are left untouched.
    pub fn move(self: *@This(), id: usize, old_aabb: AABB, new_aabb: AABB) void {
        const old_r = self.cell_range(old_aabb);
        const new_r = self.cell_range(new_aabb);

        // Remove from stale cells (cells in old range but not in new).
        var row = old_r.row_min;
        while (row <= old_r.row_max) : (row += 1) {
            var col = old_r.col_min;
            while (col <= old_r.col_max) : (col += 1) {
                // Skip cells that are still in the new range.
                if (row >= new_r.row_min and row <= new_r.row_max and
                    col >= new_r.col_min and col <= new_r.col_max) continue;
                const cell = &self.cells[self.cell_idx(col, row)];
                for (cell.items, 0..) |eid, i| {
                    if (eid == id) {
                        _ = cell.swapRemove(i);
                        break;
                    }
                }
            }
        }

        // Insert into fresh cells (cells in new range but not in old).
        row = new_r.row_min;
        while (row <= new_r.row_max) : (row += 1) {
            var col = new_r.col_min;
            while (col <= new_r.col_max) : (col += 1) {
                // Skip cells that were already in the old range.
                if (row >= old_r.row_min and row <= old_r.row_max and
                    col >= old_r.col_min and col <= old_r.col_max) continue;
                self.cells[self.cell_idx(col, row)].append(self.alloc, id) catch {};
            }
        }
    }

    /// Calls `callback(context, id)` for every entity whose cell overlaps
    /// the given query AABB.  May return the same id multiple times if an
    /// entity spans multiple cells (caller should deduplicate).
    pub fn query(self: *@This(), aabb: AABB, context: anytype, callback: fn (@TypeOf(context), usize) void) void {
        const r = self.cell_range(aabb);
        var row = r.row_min;
        while (row <= r.row_max) : (row += 1) {
            var col = r.col_min;
            while (col <= r.col_max) : (col += 1) {
                for (self.cells[self.cell_idx(col, row)].items) |eid| {
                    callback(context, eid);
                }
            }
        }
    }

    /// Returns the flat index into the `cells` array for grid (col, row).
    fn cell_idx(self: *@This(), col: usize, row: usize) usize {
        return row * self.num_cols + col;
    }

    /// Returns the inclusive cell range that the given AABB covers,
    /// clamped to grid bounds.
    ///
    /// Grid cells are 32×32 px, so dividing world coords by 32 gives the
    /// cell index.  The -0.001 epsilon ensures aabb.max sits exactly on a
    /// cell boundary maps to the correct cell (max is exclusive).
    fn cell_range(self: *@This(), aabb: AABB) struct { col_min: usize, col_max: usize, row_min: usize, row_max: usize } {
        const col_min: usize = @intCast(@max(@as(i32, @intFromFloat(@floor(aabb.min_x / 32))), 0));
        const col_max: usize = @min(
            @as(usize, @intCast(@max(@as(i32, @intFromFloat(@floor((aabb.max_x - 0.001) / 32))), 0))),
            self.num_cols - 1,
        );
        const row_min: usize = @intCast(@max(@as(i32, @intFromFloat(@floor(aabb.min_y / 32))), 0));
        const row_max: usize = @min(
            @as(usize, @intCast(@max(@as(i32, @intFromFloat(@floor((aabb.max_y - 0.001) / 32))), 0))),
            self.num_rows - 1,
        );
        return .{
            .col_min = col_min,
            .col_max = col_max,
            .row_min = row_min,
            .row_max = row_max,
        };
    }
};

// ── CollisionSystem ──

/// Holds references needed for tile collision queries so callers only pass
/// the CollisionSystem pointer instead of individual layer/tileset/etc args.
/// Owns a SpatialGrid for entity-entity broad-phase.
///
/// All pointer/reference fields must be refreshed each frame in the game
/// update loop — they may become stale if the backing data is moved.
pub const CollisionSystem = struct {
    /// The action layer to run tile collision against.
    action_layer: *const assets.Layer,
    /// The current tileset (for tile collision bitmasks).
    tileset: *const assets.Tileset,
    /// The current animset (for per-frame sprite hitboxes).
    animset: *const assets.Animset,
    /// Animated tile definitions (for resolving anim_tile IDs).
    animated_tiles: []const asset_reader.AnimatedTile,
    /// Spatial grid for entity-entity broad-phase.
    grid: SpatialGrid,
    /// Game time elapsed in seconds (for animated tile frame calc).
    time_elapsed: f32,

    /// Creates a CollisionSystem with an empty SpatialGrid sized to the
    /// action layer dimensions.
    ///
    /// All pointer fields (`action_layer`, `tileset`, `animset`, `animated_tiles`)
    /// default to whatever is passed in but **must be refreshed each frame**
    /// in the game update loop.
    pub fn init(
        alloc: std.mem.Allocator,
        action_layer: *const assets.Layer,
        tileset: *const assets.Tileset,
        animset: *const assets.Animset,
        animated_tiles: []const asset_reader.AnimatedTile,
        grid_cols: usize,
        grid_rows: usize,
    ) !CollisionSystem {
        return .{
            .action_layer = action_layer,
            .tileset = tileset,
            .animset = animset,
            .animated_tiles = animated_tiles,
            .grid = try SpatialGrid.init(alloc, grid_cols, grid_rows),
            .time_elapsed = 0,
        };
    }

    /// Convenience: checks `is_position_empty` using the system's stored
    /// layer, tileset, animated tiles and time.
    pub fn is_empty(self: *const @This(), aabb: AABB) bool {
        return is_position_empty(aabb, self.action_layer, self.tileset, self.animated_tiles, self.time_elapsed);
    }

    /// Convenience: resolves along the X axis.
    pub fn resolve_x(self: *const @This(), moved_aabb: AABB, vel_sign: i2) ?f32 {
        return resolve_axis(moved_aabb, self.action_layer, self.tileset, self.animated_tiles, self.time_elapsed, 0, vel_sign);
    }

    /// Convenience: resolves along the Y axis.
    pub fn resolve_y(self: *const @This(), moved_aabb: AABB, vel_sign: i2) ?f32 {
        return resolve_axis(moved_aabb, self.action_layer, self.tileset, self.animated_tiles, self.time_elapsed, 1, vel_sign);
    }

    /// Frees the spatial grid.  Does NOT free the pointer references.
    pub fn deinit(self: *@This()) void {
        self.grid.deinit();
    }
};

// ── Tests ──

test "AABB.init" {
    const b = AABB.init(10, 20, 50, 60);
    try testing.expectEqual(@as(f32, 10), b.min_x);
    try testing.expectEqual(@as(f32, 20), b.min_y);
    try testing.expectEqual(@as(f32, 50), b.max_x);
    try testing.expectEqual(@as(f32, 60), b.max_y);
}

test "AABB.width_height" {
    const b = AABB.init(10, 20, 50, 60);
    try testing.expectEqual(@as(f32, 40), b.width());
    try testing.expectEqual(@as(f32, 40), b.height());
}

test "AABB.overlaps" {
    const a = AABB.init(0, 0, 32, 32);
    // Fully overlapping
    try testing.expect(a.overlaps(AABB.init(8, 8, 24, 24)));
    // Partial overlap
    try testing.expect(a.overlaps(AABB.init(24, 24, 48, 48)));
    // Edge touching is not an overlap
    try testing.expect(!a.overlaps(AABB.init(32, 0, 64, 32)));
    // No overlap
    try testing.expect(!a.overlaps(AABB.init(40, 0, 72, 32)));
    // Completely separate
    try testing.expect(!a.overlaps(AABB.init(100, 100, 200, 200)));
}

test "AABB.contains_point" {
    const b = AABB.init(0, 0, 32, 32);
    try testing.expect(b.contains_point(16, 16));
    try testing.expect(b.contains_point(0, 0));
    try testing.expect(b.contains_point(31, 31));
    try testing.expect(!b.contains_point(32, 16));
    try testing.expect(!b.contains_point(16, -1));
    try testing.expect(!b.contains_point(16, 32));
}

test "AABB.translate" {
    const b = AABB.init(10, 20, 50, 60);
    const t = b.translate(5, -3);
    try testing.expectEqual(@as(f32, 15), t.min_x);
    try testing.expectEqual(@as(f32, 17), t.min_y);
    try testing.expectEqual(@as(f32, 55), t.max_x);
    try testing.expectEqual(@as(f32, 57), t.max_y);
}

test "frame_aabb" {
    const frame = assets.Frame{
        .texture = undefined,
        .width = 24,
        .height = 32,
        .coldspotX = 0,
        .coldspotY = 8,
        .hotspotX = 12,
        .hotspotY = 32,
        .gunspotX = 0,
        .gunspotY = 0,
    };
    const pos_x: f32 = 100;
    const pos_y: f32 = 200;
    const hb = frame_aabb(pos_x, pos_y, frame);
    // hitbox_w = 24 - 2 = 22, hitbox_h = 32 - 2 = 30
    // center_x = 100 - 12 + 0 = 88, bottom_y = 200 - 32 + 8 = 176
    try testing.expectApproxEqAbs(@as(f32, 88 - 11), hb.min_x, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 88 + 11), hb.max_x, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 176 - 30), hb.min_y, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 176), hb.max_y, 0.001);
    try testing.expectApproxEqAbs(@as(f32, 22), hb.width(), 0.001);
    try testing.expectApproxEqAbs(@as(f32, 30), hb.height(), 0.001);
}

test "is_tile_pixel_solid" {
    // Build a mask with only pixel (5, 5) set.
    var mask: [assets.BIT_MASK_SIZE]u8 = [_]u8{0} ** assets.BIT_MASK_SIZE;
    {
        const bit_idx = 5 * assets.TILE_SIZE + 5;
        mask[bit_idx / 8] |= @as(u8, 1) << @as(u3, @intCast(bit_idx % 8));
    }

    // Unflipped: pixel (5,5) is solid.
    try testing.expect(is_tile_pixel_solid(&mask, false, false, 5, 5));
    // Other pixels are empty.
    try testing.expect(!is_tile_pixel_solid(&mask, false, false, 0, 0));
    try testing.expect(!is_tile_pixel_solid(&mask, false, false, 31, 31));

    // Flip-X: (5,5) maps to (26,5).  Original (5,5) should not be solid.
    try testing.expect(!is_tile_pixel_solid(&mask, true, false, 5, 5));
    // But (26,5) should now be solid.
    try testing.expect(is_tile_pixel_solid(&mask, true, false, 26, 5));

    // Flip-Y: (5,5) maps to (5,26).
    try testing.expect(!is_tile_pixel_solid(&mask, false, true, 5, 5));
    try testing.expect(is_tile_pixel_solid(&mask, false, true, 5, 26));

    // Both flips: (5,5) maps to (26,26).
    try testing.expect(is_tile_pixel_solid(&mask, true, true, 26, 26));
}

test "resolve_tileset_idx static" {
    const id = assets.TileId{ .static_tile = 42 };
    const result = resolve_tileset_idx(id, &.{}, 0);
    try testing.expectEqual(@as(usize, 42), result);
}

test "resolve_tileset_idx animated" {
    var anim_frames: [64]u16 = undefined;
    anim_frames[0] = 5;
    anim_frames[1] = 9;
    anim_frames[2] = 13;
    const anim = asset_reader.AnimatedTile{
        .delay = 0,
        .delay_jitter = 0,
        .reverse_delay = 0,
        .is_ping_pong = false,
        .speed = 100,
        .frame_count = 3,
        .frames = anim_frames,
    };
    const animated_tiles = [_]asset_reader.AnimatedTile{anim};
    const id = assets.TileId{ .anim_tile = 0 };
    // At t=0, frame_no = 0, so frames[0] = 5.
    const result = resolve_tileset_idx(id, &animated_tiles, 0);
    try testing.expectEqual(@as(usize, 5), result);
}

test "is_position_empty — no tiles" {
    // A layer with no cells (null) is always empty.
    const empty_layer = assets.Layer{
        .cells = null,
        .width = 0,
        .height = 0,
        .flags = undefined,
        .type_id = 0,
        .z_axis = 0,
        .offset_x = 0,
        .offset_y = 0,
        .speed_x = 0,
        .speed_y = 0,
        .auto_speed_x = 0,
        .auto_speed_y = 0,
        .texture_bg_type = 0,
        .texture_params_rgb = undefined,
    };
    const aabb = AABB.init(0, 0, 16, 16);
    try testing.expect(is_position_empty(aabb, &empty_layer, undefined, &.{}, 0));
}

test "is_position_empty — solid tile" {
    const mask: [assets.BIT_MASK_SIZE]u8 = [_]u8{0xFF} ** assets.BIT_MASK_SIZE;
    const tile = assets.Tile{ .texture = undefined, .collision_bit_mask = mask, .flipped_collision_bit_mask = mask };
    var tiles = [_]assets.Tile{tile};
    _ = &tiles;
    const tileset = assets.Tileset{ .tiles = tiles[0..], .version = 0, .palette = undefined, .alloc = undefined, .mask_overlays = null };
    const cell = assets.Cell{ .tile = assets.LayerTile{ .id = .{ .static_tile = 0 }, .flip_x = false, .flip_y = false }, .event = null };
    var cells_row: [1]assets.Cell = [_]assets.Cell{cell};
    _ = &cells_row;
    var cells: [1][]assets.Cell = [_][]assets.Cell{cells_row[0..]};
    _ = &cells;
    const layer = assets.Layer{ .cells = cells[0..], .width = 1, .height = 1, .flags = undefined, .type_id = 0, .z_axis = 0, .offset_x = 0, .offset_y = 0, .speed_x = 0, .speed_y = 0, .auto_speed_x = 0, .auto_speed_y = 0, .texture_bg_type = 0, .texture_params_rgb = undefined };

    const inside = AABB.init(4, 4, 28, 28);
    try testing.expect(!is_position_empty(inside, &layer, &tileset, &.{}, 0));

    const outside = AABB.init(40, 40, 60, 60);
    try testing.expect(is_position_empty(outside, &layer, &tileset, &.{}, 0));
}

test "is_position_empty — empty tile pixel" {
    const mask: [assets.BIT_MASK_SIZE]u8 = [_]u8{0} ** assets.BIT_MASK_SIZE;
    const tile = assets.Tile{ .texture = undefined, .collision_bit_mask = mask, .flipped_collision_bit_mask = mask };
    var tiles = [_]assets.Tile{tile};
    _ = &tiles;
    const tileset = assets.Tileset{ .tiles = tiles[0..], .version = 0, .palette = undefined, .alloc = undefined, .mask_overlays = null };
    const cell = assets.Cell{ .tile = assets.LayerTile{ .id = .{ .static_tile = 0 }, .flip_x = false, .flip_y = false }, .event = null };
    var cells_row: [1]assets.Cell = [_]assets.Cell{cell};
    _ = &cells_row;
    var cells: [1][]assets.Cell = [_][]assets.Cell{cells_row[0..]};
    _ = &cells;
    const layer = assets.Layer{ .cells = cells[0..], .width = 1, .height = 1, .flags = undefined, .type_id = 0, .z_axis = 0, .offset_x = 0, .offset_y = 0, .speed_x = 0, .speed_y = 0, .auto_speed_x = 0, .auto_speed_y = 0, .texture_bg_type = 0, .texture_params_rgb = undefined };

    const inside = AABB.init(4, 4, 28, 28);
    try testing.expect(is_position_empty(inside, &layer, &tileset, &.{}, 0));
}

test "resolve_axis — wall collision" {
    const mask: [assets.BIT_MASK_SIZE]u8 = [_]u8{0xFF} ** assets.BIT_MASK_SIZE;
    const tile = assets.Tile{ .texture = undefined, .collision_bit_mask = mask, .flipped_collision_bit_mask = mask };
    var tiles = [_]assets.Tile{tile};
    _ = &tiles;
    const tileset = assets.Tileset{ .tiles = tiles[0..], .version = 0, .palette = undefined, .alloc = undefined, .mask_overlays = null };
    const cell = assets.Cell{ .tile = assets.LayerTile{ .id = .{ .static_tile = 0 }, .flip_x = false, .flip_y = false }, .event = null };
    var cells_row: [1]assets.Cell = [_]assets.Cell{cell};
    _ = &cells_row;
    var cells: [1][]assets.Cell = [_][]assets.Cell{cells_row[0..]};
    _ = &cells;
    const layer = assets.Layer{ .cells = cells[0..], .width = 1, .height = 1, .flags = undefined, .type_id = 0, .z_axis = 0, .offset_x = 0, .offset_y = 0, .speed_x = 0, .speed_y = 0, .auto_speed_x = 0, .auto_speed_y = 0, .texture_bg_type = 0, .texture_params_rgb = undefined };

    const aabb = AABB.init(24, 0, 56, 32);
    const push = resolve_axis(aabb, &layer, &tileset, &.{}, 0, 0, 1);
    try testing.expect(push != null);
    try testing.expectApproxEqAbs(@as(f32, -32), push.?, 0.001);

    const push2 = resolve_axis(aabb, &layer, &tileset, &.{}, 0, 0, -1);
    try testing.expect(push2 != null);
    try testing.expectApproxEqAbs(@as(f32, 8), push2.?, 0.001);
}

test "resolve_axis — floor collision" {
    const mask: [assets.BIT_MASK_SIZE]u8 = [_]u8{0xFF} ** assets.BIT_MASK_SIZE;
    const tile = assets.Tile{ .texture = undefined, .collision_bit_mask = mask, .flipped_collision_bit_mask = mask };
    var tiles = [_]assets.Tile{tile};
    _ = &tiles;
    const tileset = assets.Tileset{ .tiles = tiles[0..], .version = 0, .palette = undefined, .alloc = undefined, .mask_overlays = null };
    const cell = assets.Cell{ .tile = assets.LayerTile{ .id = .{ .static_tile = 0 }, .flip_x = false, .flip_y = false }, .event = null };
    var cells_row: [1]assets.Cell = [_]assets.Cell{cell};
    _ = &cells_row;
    var cells: [1][]assets.Cell = [_][]assets.Cell{cells_row[0..]};
    _ = &cells;
    const layer = assets.Layer{ .cells = cells[0..], .width = 1, .height = 1, .flags = undefined, .type_id = 0, .z_axis = 0, .offset_x = 0, .offset_y = 0, .speed_x = 0, .speed_y = 0, .auto_speed_x = 0, .auto_speed_y = 0, .texture_bg_type = 0, .texture_params_rgb = undefined };

    const aabb = AABB.init(0, 24, 32, 56);
    const push = resolve_axis(aabb, &layer, &tileset, &.{}, 0, 1, 1);
    try testing.expect(push != null);
    try testing.expectApproxEqAbs(@as(f32, -32), push.?, 0.001);

    const aabb2 = AABB.init(0, -24, 32, 8);
    const push2 = resolve_axis(aabb2, &layer, &tileset, &.{}, 0, 1, -1);
    try testing.expect(push2 != null);
    try testing.expectApproxEqAbs(@as(f32, 32), push2.?, 0.001);
}

test "resolve_axis — no collision" {
    const mask: [assets.BIT_MASK_SIZE]u8 = [_]u8{0xFF} ** assets.BIT_MASK_SIZE;
    const tile = assets.Tile{ .texture = undefined, .collision_bit_mask = mask, .flipped_collision_bit_mask = mask };
    var tiles = [_]assets.Tile{tile};
    _ = &tiles;
    const tileset = assets.Tileset{ .tiles = tiles[0..], .version = 0, .palette = undefined, .alloc = undefined, .mask_overlays = null };
    const cell = assets.Cell{ .tile = assets.LayerTile{ .id = .{ .static_tile = 0 }, .flip_x = false, .flip_y = false }, .event = null };
    var cells_row: [1]assets.Cell = [_]assets.Cell{cell};
    _ = &cells_row;
    var cells: [1][]assets.Cell = [_][]assets.Cell{cells_row[0..]};
    _ = &cells;
    const layer = assets.Layer{ .cells = cells[0..], .width = 1, .height = 1, .flags = undefined, .type_id = 0, .z_axis = 0, .offset_x = 0, .offset_y = 0, .speed_x = 0, .speed_y = 0, .auto_speed_x = 0, .auto_speed_y = 0, .texture_bg_type = 0, .texture_params_rgb = undefined };

    const aabb = AABB.init(100, 100, 132, 132);
    try testing.expect(resolve_axis(aabb, &layer, &tileset, &.{}, 0, 0, 1) == null);
    try testing.expect(resolve_axis(aabb, &layer, &tileset, &.{}, 0, 0, -1) == null);
    try testing.expect(resolve_axis(aabb, &layer, &tileset, &.{}, 0, 1, 1) == null);
    try testing.expect(resolve_axis(aabb, &layer, &tileset, &.{}, 0, 1, -1) == null);
}

test "SpatialGrid init and deinit" {
    var grid = try SpatialGrid.init(testing.allocator, 4, 3);
    defer grid.deinit();
    try testing.expectEqual(@as(usize, 4), grid.num_cols);
    try testing.expectEqual(@as(usize, 3), grid.num_rows);
    try testing.expectEqual(@as(usize, 12), grid.cells.len);
}

const QueryFound = struct {
    target: usize,
    found: *bool,
    fn cb(ctx: @This(), id: usize) void {
        if (id == ctx.target) ctx.found.* = true;
    }
};

const QueryAny = struct {
    found: *bool,
    fn cb(ctx: @This(), _: usize) void {
        ctx.found.* = true;
    }
};

const QueryCount = struct {
    count: *usize,
    fn cb(ctx: @This(), _: usize) void {
        ctx.count.* += 1;
    }
};

test "SpatialGrid register and query" {
    var grid = try SpatialGrid.init(testing.allocator, 4, 3);
    defer grid.deinit();

    const aabb = AABB.init(32, 32, 64, 64); // spans cells (1,1)-(1,1)
    grid.register(1, aabb);

    // Query an overlapping cell.
    var found = false;
    grid.query(AABB.init(32, 32, 48, 48), QueryFound{ .target = 1, .found = &found }, QueryFound.cb);
    try testing.expect(found);
}

test "SpatialGrid move and remove" {
    var grid = try SpatialGrid.init(testing.allocator, 10, 10);
    defer grid.deinit();

    const old_aabb = AABB.init(0, 0, 32, 32);
    grid.register(5, old_aabb);

    // Move to a new position.
    const new_aabb = AABB.init(128, 128, 160, 160);
    grid.move(5, old_aabb, new_aabb);

    // Should NOT find entity at old location.
    var found_old = false;
    grid.query(AABB.init(0, 0, 32, 32), QueryAny{ .found = &found_old }, QueryAny.cb);
    try testing.expect(!found_old);

    // Should find entity at new location.
    var found_new = false;
    grid.query(AABB.init(128, 128, 160, 160), QueryAny{ .found = &found_new }, QueryAny.cb);
    try testing.expect(found_new);

    // Remove entity.
    grid.remove(5, new_aabb);
    var found_after_remove = false;
    grid.query(AABB.init(128, 128, 160, 160), QueryAny{ .found = &found_after_remove }, QueryAny.cb);
    try testing.expect(!found_after_remove);
}

test "SpatialGrid — AABB spans multiple cells" {
    var grid = try SpatialGrid.init(testing.allocator, 10, 10);
    defer grid.deinit();

    // AABB that spans 2×2 cells: (0,0)-(64,64) covers cells (0,0), (0,1), (1,0), (1,1)
    const aabb = AABB.init(0, 0, 64, 64);
    grid.register(7, aabb);

    // Query from different cells that should all find it.
    var count: usize = 0;
    grid.query(AABB.init(0, 0, 16, 16), QueryCount{ .count = &count }, QueryCount.cb);
    try testing.expect(count >= 1);

    count = 0;
    grid.query(AABB.init(48, 48, 64, 64), QueryCount{ .count = &count }, QueryCount.cb);
    try testing.expect(count >= 1);
}

test "CollisionFlags packed" {
    const flags = CollisionFlags{
        .on_ground = true,
        .touch_ceiling = false,
        .touch_wall_left = true,
        .touch_wall_right = false,
    };
    try testing.expect(flags.on_ground);
    try testing.expect(!flags.touch_ceiling);
    try testing.expect(flags.touch_wall_left);
    try testing.expect(!flags.touch_wall_right);
}
