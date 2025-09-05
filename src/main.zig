const rl = @import("raylib");
const std = @import("std");
const builtin = @import("builtin");
const GameState = @import("game.zig").State;
const Input = @import("game.zig").Input;
const lib = @import("lib.zig");

const fps = 60;
const screen_width = 600;
const screen_height = 600;

// 💩💩💩💩💩 <-- ga
const Platform = struct {};
const Game = struct {};
const Tool = struct {};

const PlaybackMode = enum {
    playing,
    recording,
    replaying,
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
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

    rl.SetTraceLogLevel(rl.LOG_ERROR);
    rl.InitWindow(screen_width, screen_height, "ZigGame");
    rl.SetTargetFPS(fps);

    var buffer: [screen_width * screen_height]u32 = @splat(0);
    const image: rl.Image = .{
        .width = rl.GetRenderWidth(),
        .height = rl.GetRenderHeight(),
        .format = rl.PIXELFORMAT_UNCOMPRESSED_R8G8B8A8,
        .mipmaps = 1,
        .data = &buffer,
    };

    var timer = try std.time.Timer.start();
    var accumulated_time: f32 = 0;
    const seconds_per_update = 0.016;

    var playing_state_text: []const u8 = "Playing";

    while (!rl.WindowShouldClose()) {
        std.debug.print("current: {d}\n", .{current_state.elapsed_time});
        std.debug.print("start: {d}\n", .{start_state.elapsed_time});
        std.debug.print("end: {d}\n", .{end_state.elapsed_time});

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

            if (rl.IsKeyPressed(rl.KEY_R)) {
                switch (playback_mode) {
                    .playing => {
                        start_state = current_state;
                        playing_state_text = "Recording";
                        playback_mode = .recording;
                        game_states.clearAndFree(allocator);
                        replay_index = 0;
                    },
                    .recording => {
                        end_state = current_state;
                        current_state = start_state;
                        playing_state_text = "Replaying";
                        playback_mode = .replaying;
                    },
                    .replaying => {
                        playing_state_text = "Playing";
                        playback_mode = .playing;
                    },
                }
            }

            update(seconds_per_update, &current_state, &input);

            if (playback_mode == .recording) {
                try game_states.append(allocator, input);
            }
        }

        @memset(&buffer, @bitCast(rl.GREEN));
        draw(&current_state, &buffer);
        const texture = rl.LoadTextureFromImage(image);
        defer rl.UnloadTexture(texture);

        rl.BeginDrawing();
        rl.ClearBackground(rl.BLACK);

        rl.DrawTexture(texture, 0, 0, rl.WHITE);

        rl.DrawText(playing_state_text.ptr, 10, screen_height, 30, .{ .r = 255, .g = 0, .b = 0, .a = 255.0 });
        rl.EndDrawing();

        if (try game.listen()) {
            update = try game.lookup(@TypeOf(update), "update");
            draw = try game.lookup(@TypeOf(draw), "draw");
        }
    }
}
