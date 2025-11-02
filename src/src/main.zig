const std = @import("std");
const print = @import("std").debug.print;

const gfx = @import("gfx.zig");
const assets = @import("assets.zig");
const assets_reader = @import("assets_reader.zig");

pub const log_level: std.log.Level = .debug;

pub fn main() !void {
    std.debug.print("\nStarting {s}\n", .{"OpenJazz2"});
    try gfx.init();
    gfx.init_window();
    defer gfx.deinit();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var a = assets_reader.load_tileset(gpa.allocator(), "/home/rr/Games/Jazz2/Jungle1.j2t") catch {std.debug.panic("asset {s}", .{"reader"});};
    defer a.deinit();

    const SPR_IN_ROW: usize = 10;
    const scr = gfx.screen_res();
    while (gfx.is_running()) {
        gfx.update_frame();
        var x: usize = 0;
        var y: usize = 0;
        var block_cnt: usize = 0;
        for (a.tiles, 0..) |t, i| {
            if (i != 0 and i % SPR_IN_ROW == 0) {
                y += t.sprite.h;
                x = block_cnt * SPR_IN_ROW * t.sprite.w; 
                if (y + t.sprite.h > scr.h) {
                    block_cnt += 1;
                    y = 0;
                }
            }
            t.sprite.draw(x, y);
            x += t.sprite.w;
        }
        gfx.render();
    }
}

test "simple test" {
    const gpa = std.testing.allocator;
    var list: std.ArrayList(i32) = .empty;
    defer list.deinit(gpa); // Try commenting this out and see if zig detects the memory leak!
    try list.append(gpa, 42);
    try std.testing.expectEqual(@as(i32, 42), list.pop());
}

test "fuzz example" {
    const Context = struct {
        fn testOne(context: @This(), input: []const u8) anyerror!void {
            _ = context;
            // Try passing `--fuzz` to `zig build test` and see if it manages to fail this test case!
            try std.testing.expect(!std.mem.eql(u8, "canyoufindme", input));
        }
    };
    try std.testing.fuzz(Context{}, Context.testOne, .{});
}
