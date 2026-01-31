
pub const TileCoord = struct {
    pub const SIZE: usize = 32;
    // usize types because `x` and `y` are indices of array
    x: usize,
    y: usize,

    // bottom left
    // floor truncation
    pub fn init_from_world_tl(world: WorldCoord) TileCoord {
        const wx = @as(usize, @intCast(world.x));
        const wy = @as(usize, @intCast(world.y)); 
        const x = @divFloor(wx, TileCoord.SIZE);
        const y = @divFloor(wy, TileCoord.SIZE);
        return .{
            .x =  x, 
            .y =  y, 
        };
    }
    // top right
    // ceil truncation
    pub fn init_from_world_br(world: WorldCoord) TileCoord {
        const wx = @as(usize, @intCast(world.x));
        const wy = @as(usize, @intCast(world.y)); 
        return .{
            .x = @divFloor(wx, TileCoord.SIZE) + 1,
            .y = @divFloor(wy, TileCoord.SIZE) + 1,
        };
    }
};

pub const ScreenCoord = struct {
    x: i32,
    y: i32,
};

pub const WorldCoord = struct {
    x: u32,
    y: u32,
};

