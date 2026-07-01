const std = @import("std");

// const gfx = @import("gfx").gfx;
// const assets = @import("assets.zig");
// const assets_reader = @import("assets_reader.zig");
const diag_tileset = @import("diag_tileset.zig");
const diag_animset = @import("diag_animset.zig");
const diag_level = @import("diag_level.zig");
const diag_sound = @import("diag_sound.zig");
const diag_gfx = @import("diag_gfx.zig");
const game = @import("game.zig");

const DEFAULT_COMMAND = "game";
const DEFAULT_TILESET = "/home/rr/Games/Jazz2/Jungle1.j2t";
const DEFAULT_ANIMSET = "/home/rr/Games/Jazz2/Anims.j2a";
const DEFAULT_LEVEL = "/home/rr/Games/Jazz2/Castle1.j2l";
const DEFAULT_SONG = "/home/rr/Games/Jazz2/Castle.j2b";

/// Entry point: parses CLI args and runs the selected diagnostic mode.
pub fn main(init: std.process.Init) !void {
    const fs = @import("utils").fs;
    fs.init(init.io);
    std.debug.print("\nStarting {s}\n", .{"OpenJazz2"});
    const alloc = init.gpa;

    var args_iter = try init.minimal.args.iterateAllocator(alloc);
    defer args_iter.deinit();
    const prog_name = args_iter.next() orelse "program";
    const command = args_iter.next() orelse DEFAULT_COMMAND;
    // if (!std.mem.eql(u8, command, "gfx")) {
    //     // init gfx, sound, window
    //     try gfx.init();
    //     gfx.init_window();
    //     defer gfx.deinit();
    // }

    var app: @import("app.zig").IApp = undefined;
    var tilesets: diag_tileset.DiagTileset = undefined;
    var animsets: diag_animset.DiagAnimset = undefined;
    var level: diag_level.DiagLevel = undefined;
    var sound: diag_sound.DiagSound = undefined;
    var gfx_sys: diag_gfx.DiagGfx = undefined;
    var game_mod: game.Game = undefined;

    if (std.mem.eql(u8, command, "game")) {
        game_mod = try .init(alloc, DEFAULT_LEVEL);
        app = game_mod.app_cast();
    } else if (std.mem.eql(u8, command, "tileset")) {
        // filename
        const arg = args_iter.next() orelse DEFAULT_TILESET;
        tilesets = try .init(alloc, arg);
        app = tilesets.app_cast();
    } else if (std.mem.eql(u8, command, "animset")) {
        // filename
        const arg = args_iter.next() orelse DEFAULT_ANIMSET;
        animsets = try .init(alloc, arg);
        app = animsets.app_cast();
    } else if (std.mem.eql(u8, command, "level")) {
        const arg = args_iter.next() orelse DEFAULT_LEVEL;
        level = try .init(alloc, arg);
        app = level.app_cast();
    } else if (std.mem.eql(u8, command, "sound")) {
        const arg = args_iter.next() orelse DEFAULT_SONG;
        sound = try .init(alloc, arg);
        app = sound.app_cast();
    } else if (std.mem.eql(u8, command, "gfx")) {
        gfx_sys = try .init(alloc);
        app = gfx_sys.app_cast();
        // defer app.deinit();
        // app.update();
        // return;
    } else {
        std.debug.print("No command valid selected ({s})!\n", .{command});
        printHelp(prog_name);
        return;
    }

    defer app.deinit();

    // while (gfx.is_running()) {
    //     gfx.update_frame();
    //     app.update();
    //     gfx.render();
    // }
    app.run();
}

/// Prints usage information and available commands to stdout.
fn printHelp(prog_name: []const u8) void {
    std.debug.print(
        \\Usage:
        \\  {s} [command] [options]
        \\
        \\Commands:
        \\  game                        Run the main game (default)
        \\  tileset TILESET_FILE.j2t    Load and display a tileset file 
        \\  animset ANIMSET_FILE.j2a    Load and display a animset file 
        \\  level LEVAL_FILE.j2l        Load and display a level file 
        \\  sound SOUND_FILE.j2b        Load and play a music/sound file
        \\  gfx                         Test graphics system
        \\  help                        Show this help
        \\
        \\If no arguments are passed, the game is started.
        \\
    , .{prog_name});
}
