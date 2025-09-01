const rl = @import("raylib");
const std = @import("std");
const builtin = @import("builtin");
const GameState = @import("header.zig").GameState;

const fps = 60;
const screen_width = 640;
const screen_height = 480;

// 💩💩💩💩💩 <-- ga
const Platform = struct {};
const Game = struct {};
const Tool = struct {};

pub fn main() !void {
    var state: GameState = .{};
    // This is the shit I cooked up
    var lib = try std.DynLib.open("zig-out/lib/libgame" ++ comptime builtin.target.dynamicLibSuffix());
    defer lib.close();
    const update = lib.lookup(*const fn (f32, *GameState) callconv(.c) void, "update") orelse return error.LookupFailed;

    rl.InitWindow(screen_width, screen_height, "ZigGame");
    rl.SetTargetFPS(fps);
    // var framebuffer: rl.Image = .{
    //     .width = rl.GetRenderWidth(),
    //     .height = rl.GetRenderHeight(),
    //     .format = rl.PixelFormat,
    //     .mipmaps = 1,
    //     // .data = // idk the shit from the rasterizer
    // };

    while (!rl.WindowShouldClose()) {
        const dt = rl.GetFrameTime();

        rl.BeginDrawing();
        rl.ClearBackground(rl.RAYWHITE);

        std.debug.print("curr state: {any}\n", .{state});
        update(dt, &state);

        rl.DrawRectangleRec(.{ .x = state.pos_x, .y = state.pos_y, .width = 10, .height = 10 }, @bitCast(@as(u32, 0xFF0000FF)));

        rl.DrawText("Why are you a c enjoyer?", 90, 90, 50, .{ .r = 255, .g = 0, .b = 0, .a = 255.0 });
        rl.EndDrawing();
    }
}
