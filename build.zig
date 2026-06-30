const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const gfx = b.addModule("gfx", .{
        .root_source_file = b.path("./src/gfx/root.zig"),
        .target = target,
    });

    const utils = b.addModule("utils", .{
        .root_source_file = b.path("./src/utils/root.zig"),
        .target = target,
    });

    const mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "gfx", .module = gfx },
            .{ .name = "utils", .module = utils },
        },
    });

    const exe = b.addExecutable(.{
        .name = "openjazz2",
        .root_module = mod,
    });

    mod.link_libc = true;
    mod.linkSystemLibrary("sdl3", .{});
    mod.linkSystemLibrary("SDL3_ttf", .{});
    mod.linkSystemLibrary("SDL3_mixer", .{});

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const test_step = b.step("test", "Run tests");
    const test_files = [_][]const u8{
        "src/assets.zig",
        "src/assets_reader.zig",
        "src/collision.zig",
        "src/console.zig",
        "src/diag_level.zig",
        "src/g_math.zig",
        "src/g_anim.zig",
    };

    for (test_files) |path| {
        const t_mod = b.createModule(.{
            .root_source_file = b.path(path),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "gfx", .module = gfx },
                .{ .name = "utils", .module = utils },
            },
        });
        const t = b.addTest(.{ .root_module = t_mod });
        t_mod.link_libc = true;
        t_mod.linkSystemLibrary("sdl3", .{});
        t_mod.linkSystemLibrary("SDL3_ttf", .{});
        t_mod.linkSystemLibrary("SDL3_mixer", .{});
        t_mod.linkSystemLibrary("gl", .{});
        const run_t = b.addRunArtifact(t);
        test_step.dependOn(&run_t.step);
    }

    const exe_tests = b.addTest(.{
        .root_module = mod,
    });

    mod.link_libc = true;
    mod.linkSystemLibrary("sdl3", .{});
    mod.linkSystemLibrary("gl", .{});

    const run_exe_tests = b.addRunArtifact(exe_tests);

    test_step.dependOn(&run_exe_tests.step);
}
