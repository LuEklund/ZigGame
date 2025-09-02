const std = @import("std");
const builtin = @import("builtin");
const header = @import("header.zig");
const rl = @import("raylib");

pub fn main() !void {
    var lib = try std.DynLib.open("zig-out/lib/libgame" ++ comptime builtin.target.os.tag.dynamicLibSuffix());
    defer lib.close();
    const update = lib.lookup(*const fn (header.State) void, "update") orelse return error.LookupFailed;

    const state: header.State = .{ .index = 90 };

    rl.SetTraceLogLevel(rl.LOG_ERROR);
    rl.InitWindow(900, 800, "ZigGame Engine");
    defer rl.CloseWindow();

    const camera: rl.Camera2D = .{ .zoom = 100 };

    while (!rl.WindowShouldClose()) {
        rl.BeginDrawing();
        defer rl.EndDrawing();
        rl.BeginMode2D(camera);
        defer rl.EndMode2D();

        rl.ClearBackground(rl.RAYWHITE);
        rl.DrawText("Lucas yay", 50, 60, 90, rl.RED);

        update(state);
    }
}
