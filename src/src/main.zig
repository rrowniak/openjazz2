const std = @import("std");
const print = @import("std").debug.print;

const gfx = @import("gfx").gfx;
const assets = @import("assets.zig");
const assets_reader = @import("assets_reader.zig");
const diag_tileset = @import("diag_tileset.zig");
const diag_animset = @import("diag_animset.zig");
const diag_level = @import("diag_level.zig");
const diag_sound = @import("diag_sound.zig");
const diag_gfx = @import("diag_gfx.zig");

pub const log_level: std.log.Level = .debug;

const DEFAULT_COMMAND = "tileset";
const DEFAULT_TILESET = "/home/rr/Games/Jazz2/Jungle1.j2t";
const DEFAULT_ANIMSET = "/home/rr/Games/Jazz2/Anims.j2a";
const DEFAULT_LEVEL = "/home/rr/Games/Jazz2/Castle1.j2l";
const DEFAULT_SONG = "/home/rr/Games/Jazz2/Castle.j2b";

pub fn main() !void {
    std.debug.print("\nStarting {s}\n", .{"OpenJazz2"});
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    var args = try std.process.argsWithAllocator(alloc);
    defer args.deinit();
    const prog_name = args.next() orelse "program";
    const command = args.next() orelse DEFAULT_COMMAND;
    if (!std.mem.eql(u8, command, "gfx")) {
        // init gfx, sound, window
        try gfx.init();
        gfx.init_window();
        defer gfx.deinit();
    }

    var app: @import("app.zig").IApp = undefined;
    var tilesets: diag_tileset.DiagTileset = undefined;
    var animsets: diag_animset.DiagAnimset = undefined;
    var level: diag_level.DiagLevel = undefined;
    var sound: diag_sound.DiagSound = undefined;
    var gfx_sys: diag_gfx.DiagGfx = undefined;
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
    } else if (std.mem.eql(u8, command, "level")) {
        const arg = args.next() orelse DEFAULT_LEVEL;
        level = try .init(alloc, arg);
        app = level.app_cast();
    } else if (std.mem.eql(u8, command, "sound")) {
        const arg = args.next() orelse DEFAULT_SONG;
        sound = try .init(alloc, arg);
        app = sound.app_cast();
    } else if (std.mem.eql(u8, command, "gfx")) {
        gfx_sys = try .init(alloc);
        app = gfx_sys.app_cast();
        defer app.deinit();
        app.update();
        return;
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
        \\  level LEVAL_FILE.j2l        Load and display a level file 
        \\  sound SOUND_FILE.j2b        Load and play a music/sound file
        \\  gfx                         Test graphics system
        \\  help                        Show this help
        \\
        \\If no arguments are passed, defaults are used.
        \\
    , .{prog_name});
}
