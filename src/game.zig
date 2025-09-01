const std = @import("std");
const GameState = @import("header.zig").GameState;

pub export fn update(dt: f32, state: *GameState) void {
    if (state.pos_x >= 300) {
        state.dir_x = -100;
    } else if (state.pos_x <= 100) state.dir_x = 100;
    std.debug.print("struct: {any}\n", .{state.*});
    state.pos_x += state.dir_x * dt;
}

pub export fn render() void {}
