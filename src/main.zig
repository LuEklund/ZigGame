const rl = @import("raylib");
const std = @import("std");
const builtin = @import("builtin");
const Game = @import("game.zig");
const GameState = Game.State;
const width = Game.width;
const heigth = Game.heigth;
const Input = @import("game.zig").Input;
const lib = @import("lib.zig");

const PlaybackMode = enum {
    playing,
    recording,
    replaying,
};

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    const smp_allocator = std.heap.smp_allocator;
    const allocator = switch (builtin.mode) {
        .Debug => debug_allocator.allocator(),
        // release modes
        else => smp_allocator,
    };
    std.log.info("current mode: {[mode]s}", .{ .mode = @tagName(builtin.mode) });
    var game_states: std.ArrayList(Input) = .empty;
    var replay_index: u32 = 0;

    var current_state: GameState = .{};
    var start_state: GameState = .{};
    var end_state: GameState = .{};
    var playback_mode: PlaybackMode = .playing;

    var game: lib.Game = try .init();
    defer game.deinit();

    // This is the shit I cooked up;
    var update = try game.lookup(*const fn (f32, *GameState, *Input) callconv(.c) void, "update");
    var draw = try game.lookup(*const fn (*GameState, [*]u32) callconv(.c) void, "draw");
    var spawnFood = try game.lookup(*const fn (*GameState, i32, i32) callconv(.c) void, "spawnFood");

    // rl.SetConfigFlags(rl.FLAG_WINDOW_RESIZABLE);
    rl.SetTraceLogLevel(rl.LOG_ERROR);
    rl.InitWindow(width, heigth, "ZigGame");
    rl.SetTargetFPS(60);

    const buffer: []u32 = try allocator.alloc(u32, @intCast(rl.GetRenderWidth() * rl.GetRenderHeight()));
    defer allocator.free(buffer);
    @memset(buffer, 0);

    const image: rl.Image = .{
        .width = rl.GetRenderWidth(),
        .height = rl.GetRenderHeight(),
        .format = rl.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8,
        .mipmaps = 1,
        .data = @ptrCast(buffer.ptr),
    };

    var timer = try std.time.Timer.start();
    var accumulated_time: f32 = 0;
    const seconds_per_update = 0.016;

    while (!rl.WindowShouldClose()) {
        // if (rl.IsWindowResized()) {
        //     const size: usize = @intCast(rl.GetRenderWidth() * rl.GetRenderHeight());
        //     if (!allocator.resize(buffer, size)) {
        //         // allocator.free(buffer);
        //         // buffer = try allocator.alloc(u32, size);
        //         buffer = try allocator.realloc(buffer, size);
        //         image.data = @ptrCast(buffer.ptr);
        //     }

        //     rl.ImageResize(&image, rl.GetRenderWidth(), rl.GetRenderHeight());
        // }

        //std.debug.print("current: {d}\n", .{current_state.elapsed_time});
        //std.debug.print("start: {d}\n", .{start_state.elapsed_time});
        //std.debug.print("end: {d}\n", .{end_state.elapsed_time});

        if (playback_mode == .replaying and current_state.elapsed_time == end_state.elapsed_time) {
            current_state = start_state;
            replay_index = 0;
        }

        accumulated_time += @as(f32, @floatFromInt(timer.lap())) / (1000 * 1000 * 1000);

        if (accumulated_time >= seconds_per_update) {
            var input: Input = .{};
            if (playback_mode == .replaying) {
                input = game_states.items[replay_index];
                replay_index += 1;
            }
            input.a = if (rl.IsKeyDown(rl.KEY_A)) true else input.a;
            input.d = if (rl.IsKeyDown(rl.KEY_D)) true else input.d;
            input.w = if (rl.IsKeyDown(rl.KEY_W)) true else input.w;
            input.s = if (rl.IsKeyDown(rl.KEY_S)) true else input.s;
            if (rl.IsKeyPressed(rl.KEY_P)) spawnFood(
                &current_state,
                @mod(@as(i32, @intFromFloat(accumulated_time)), 400),
                @mod(@as(i32, @intFromFloat(accumulated_time * 11)), 400),
            );

            if (rl.IsKeyPressed(rl.KEY_R)) {
                switch (playback_mode) {
                    .playing => {
                        start_state = current_state;
                        playback_mode = .recording;
                        game_states.clearAndFree(allocator);
                        replay_index = 0;
                    },
                    .recording => {
                        end_state = current_state;
                        current_state = start_state;
                        playback_mode = .replaying;
                    },
                    .replaying => {
                        playback_mode = .playing;
                    },
                }
            }

            update(seconds_per_update, &current_state, &input);

            if (playback_mode == .recording) {
                try game_states.append(allocator, input);
            }
        }

        @memset(buffer, @bitCast(rl.GREEN));
        draw(&current_state, buffer.ptr);
        const texture = rl.LoadTextureFromImage(image);
        defer rl.UnloadTexture(texture);

        rl.BeginDrawing();
        rl.ClearBackground(rl.BLACK);

        rl.DrawTexture(texture, 0, 0, rl.WHITE);

        rl.DrawText(switch (playback_mode) {
            .playing => "Playing",
            .recording => "Recording",
            .replaying => "Replaying",
        }, 10, rl.GetRenderHeight() - 40, 30, .{ .r = 255, .g = 0, .b = 0, .a = 255.0 });
        rl.EndDrawing();

        if (try game.listen()) {
            update = try game.lookup(@TypeOf(update), "update");
            draw = try game.lookup(@TypeOf(draw), "draw");
            spawnFood = try game.lookup(*const fn (*GameState, i32, i32) callconv(.c) void, "spawnFood");
        }
    }
}
