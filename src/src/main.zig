const std = @import("std");
const print = @import("std").debug.print;

const gfx = @import("gfx.zig");
const assets = @import("assets.zig");
const assets_reader = @import("assets_reader.zig");

pub const log_level: std.log.Level = .debug;

fn init_text() void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var a = assets_reader.load_tileset(gpa.allocator(), "/home/rr/Games/Jazz2/Jungle1.j2t") catch {std.debug.panic("asset {s}", .{"reader"});};
    defer a.deinit();
}

pub fn main() !void {
    std.debug.print("\nStarting {s}\n", .{"OpenJazz2"});
    try gfx.init();
    gfx.init_window();
    init_text();
    defer gfx.deinit();

    while (gfx.is_running()) {
        gfx.update_frame();
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
