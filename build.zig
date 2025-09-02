const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const raylib = b.dependency("raylib", .{
        .target = target,
        .optimize = optimize,
    });

    const raylib_c = b.addTranslateC(.{
        .root_source_file = raylib.path("src/raylib.h"),
        .target = target,
        .optimize = optimize,
        .link_libc = true,
    }).createModule();

    const game = b.addLibrary(.{
        .name = "game",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/game.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "raylib", .module = raylib_c },
            },
        }),
        .linkage = .dynamic,
    });
    game.linkLibrary(raylib.artifact("raylib"));

    b.installArtifact(game);

    const exe = b.addExecutable(.{
        .name = "ZigGameRuntime",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "raylib", .module = raylib_c },
            },
        }),
    });
    exe.linkLibrary(raylib.artifact("raylib"));

    b.installArtifact(exe);

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);

    const exe_tests = b.addTest(.{
        .root_module = exe.root_module,
    });
    const run_exe_tests = b.addRunArtifact(exe_tests);
    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_exe_tests.step);
}
