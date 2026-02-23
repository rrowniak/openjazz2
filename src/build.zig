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
    
    const exe = b.addExecutable(.{
        .name = "openjazz2",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "gfx", .module = gfx },
                .{ .name = "utils", .module = utils },
            },
        }),
    });
    
    // SDL3 integration
    const pkg_config = b.addSystemCommand(&.{"pkg-config"});

    pkg_config.addArgs(&.{
        "pkg-config",
        "--cflags",
        "--libs",
        "sdl3",
    }); 
    const sdl_out = pkg_config.captureStdOut(.{});
    // Apply the flags found by pkg-config
    exe.addIncludePath(sdl_out);
    // needed by SDL3 - otherwise segfault
    exe.linkLibC();
    exe.linkSystemLibrary("sdl3");
    exe.linkSystemLibrary("SDL3_ttf");
    exe.linkSystemLibrary("SDL3_mixer");

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const test_step = b.step("test", "Run tests");
    // const mod_tests = b.addTest(.{
    //      .root_module = mod,
    // });
    //
    // const run_mod_tests = b.addRunArtifact(mod_tests);
    const test_files = [_][]const u8{
        "src/assets.zig",
        "src/assets_reader.zig",
        "src/console.zig",
        "src/diag_level.zig",
        "src/g_math.zig",
        "src/g_anim.zig",
    };


    // Loop through all test files and add them as test artifacts
    for (test_files) |path| {
        const t = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(path),
                .target = target,
                .optimize = optimize,
            }),
        });
        t.addIncludePath(sdl_out);
        // needed by SDL3 - otherwise segfault
        t.linkLibC();
        t.linkSystemLibrary("sdl3");
        const run_t = b.addRunArtifact(t);
        test_step.dependOn(&run_t.step);
    }

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    exe_tests.addIncludePath(sdl_out);
    // needed by SDL3 - otherwise segfault
    exe_tests.linkLibC();
    exe_tests.linkSystemLibrary("sdl3");

    const run_exe_tests = b.addRunArtifact(exe_tests);

    // test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
