const std = @import("std");
const print = @import("std").debug.print;

const gfx = @import("gfx.zig");
const assets = @import("assets.zig");
const assets_reader = @import("assets_reader.zig");
const diag_tileset = @import("diag_tileset.zig");
const diag_animset = @import("diag_animset.zig");

pub const log_level: std.log.Level = .debug;

const DEFAULT_COMMAND = "tileset";
const DEFAULT_TILESET =  "/home/rr/Games/Jazz2/Jungle1.j2t";
const DEFAULT_ANIMSET =  "/home/rr/Games/Jazz2/Anims.j2a";

pub fn main() !void {
    std.debug.print("\nStarting {s}\n", .{"OpenJazz2"});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();
    // init gfx, sound, window
    try gfx.init();
    gfx.init_window();
    defer gfx.deinit();

    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();
    const prog_name = args.next() orelse "program";
    const command = args.next() orelse DEFAULT_COMMAND;

    var app: @import("app.zig").IApp = undefined;
    var tilesets: diag_tileset.DiagTileset = undefined;
    var animsets: diag_animset.DiagAnimset = undefined;
    if (std.mem.eql(u8, command, "tileset")) {
        // filename
        const arg = args.next() orelse DEFAULT_TILESET;
        tilesets = try .init(alloc, arg);
        app = tilesets.app_cast();
    } else if (std.mem.eql(u8, command, "animset")) {
        // filename
        const arg = args.next() orelse DEFAULT_ANIMSET;
        animsets = try .init(alloc, arg);
        app = animsets.app_cast();
    } else {
        std.debug.print("No command valid selected ({s})!\n", .{command});
        printHelp(prog_name);
        return;
    }
    
    defer app.deinit();

    while (gfx.is_running()) {
        gfx.update_frame();
        app.update();
        gfx.render();
    }
}

fn printHelp(prog_name: []const u8) void {
    std.debug.print(
        \\Usage:
        \\  {s} [command] [options]
        \\
        \\Commands:
        \\  tileset TILESET_FILE.j2t    Load and display a tileset file 
        \\  animset ANIMSET_FILE.j2a    Load and display a animset file 
        \\  help                        Show this help
        \\
        \\If no arguments are passed, defaults are used.
        \\
    , .{prog_name});
}
