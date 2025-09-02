const rl = @import("raylib");
const std = @import("std");
const builtin = @import("builtin");
const GameState = @import("game.zig").State;
const FileWatcher = @import("FileWatcher.zig");

const fps = 60;
const screen_width = 600;
const screen_height = 600;

// 💩💩💩💩💩 <-- ga
const Platform = struct {};
const Game = struct {};
const Tool = struct {};

pub fn main() !void {
    const game_file_path = "zig-out/lib/libgame" ++ comptime builtin.target.dynamicLibSuffix(); //TODO: dynamicLibSuffix you also need dynamicLibPrefix, there's std.process.selfExePath() iirc
    var file_watcher: FileWatcher = try .init();
    defer file_watcher.deinit();
    try file_watcher.addFile("zig-out/lib/");

    var state: GameState = .{};
    // This is the shit I cooked up
    var lib: std.DynLib = try .open(game_file_path);
    defer lib.close();
    var update = lib.lookup(*const fn (f32, *GameState) callconv(.c) void, "update") orelse return error.LookupFailed;
    var draw = lib.lookup(*const fn (*GameState, [*]u32) callconv(.c) void, "draw") orelse return error.LookupFailed;

    rl.InitWindow(screen_width, screen_height, "ZigGame");
    rl.SetTargetFPS(fps);
    rl.SetTraceLogLevel(rl.LOG_ERROR);

    var buffer = [_]u32{0} ** (screen_width * screen_height);
    @memset(&buffer, 0);
    const image: rl.Image = .{
        .width = rl.GetRenderWidth(),
        .height = rl.GetRenderHeight(),
        .format = rl.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8,
        .mipmaps = 1,
        .data = &buffer,
    };

    while (!rl.WindowShouldClose()) {
        const dt = rl.GetFrameTime();
        update(dt, &state);

        @memset(&buffer, @bitCast(rl.GREEN));
        draw(&state, &buffer);
        const texture = rl.LoadTextureFromImage(image);
        defer rl.UnloadTexture(texture);

        rl.BeginDrawing();
        rl.ClearBackground(rl.BLACK);

        // std.debug.print("curr state: {any}\n", .{state});
        rl.DrawTexture(texture, 0, 0, rl.WHITE);

        rl.DrawText("Suscribe", 10, screen_height, 30, .{ .r = 255, .g = 0, .b = 0, .a = 255.0 });
        rl.EndDrawing();

        if (try file_watcher.listen() == true) blk: {
            std.debug.print("Updated!\n", .{});
            const new_lib = std.DynLib.open(game_file_path) catch break :blk;
            lib.close();
            lib = new_lib;
            update = lib.lookup(*const fn (f32, *GameState) callconv(.c) void, "update") orelse return error.LookupFailed;
            draw = lib.lookup(*const fn (*GameState, [*]u32) callconv(.c) void, "draw") orelse return error.LookupFailed;
            std.debug.print("Updated WORKED: {s}\n", .{game_file_path});
        } else {
            // std.debug.print("NO Update!\n", .{});
        }
    }
}
