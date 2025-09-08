const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseFast });

    const exe = switch (target.result.os.tag) {
        .freestanding => switch (target.result.cpu.arch) {
            .wasm32, .wasm64 => wasm: {
                const mod = b.createModule(.{
                    .root_source_file = b.path("src/game.zig"),
                    .target = target,
                    .optimize = optimize,
                });
                mod.export_symbol_names = &.{ "update", "draw" };
                const exe = b.addExecutable(.{
                    .name = "ZigGameRuntime",
                    .root_module = mod,
                });
                exe.entry = .disabled;
                exe.initial_memory = 30 * 65536; // ~1.92MB (covers pixel buffer + stack)
                exe.max_memory = 35 * 65536; // ~2.24MB (room for safety)
                exe.shared_memory = false;
                break :wasm exe;
            },
            else => unreachable,
        },
        else => blk: {
            const game = b.addLibrary(.{
                .name = "game",
                .root_module = b.createModule(.{
                    .root_source_file = b.path("src/game.zig"),
                    .target = target,
                    .optimize = optimize,
                }),
                .linkage = .dynamic,
                .use_llvm = true,
            });

            b.installArtifact(game);

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
                .use_llvm = true,
            });
            exe.linkLibrary(raylib.artifact("raylib"));
            break :blk exe;
        },
    };

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
