const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    
    const exe = b.addExecutable(.{
        .name = "openjazz2",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
            },
        }),
    });
    
    // SDL3 integration
    exe.linkSystemLibrary("sdl3");
    
    const pkg_config = b.addSystemCommand(&.{"pkg-config"});

    pkg_config.addArgs(&.{
        "pkg-config",
        "--cflags",
        "--libs",
        "sdl3",
    }); 
    const out = pkg_config.captureStdOut(.{});
    // Apply the flags found by pkg-config
    exe.addIncludePath(out);
    // needed by SDL3 - otherwise segfault
    exe.linkLibC();

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // const mod_tests = b.addTest(.{
    //      .root_module = mod,
    // });
    //
    // const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });

    const run_exe_tests = b.addRunArtifact(exe_tests);

    const test_step = b.step("test", "Run tests");
    // test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
