const std = @import("std");
pub const GameState = extern struct {
    pos_x: f32 = 0,
    pos_y: f32 = 0,
    dir_x: f32 = 100,
    dir_y: f32 = 0,
};

pub export fn update(dt: f32, state: *GameState) void {
    if (state.pos_x >= 300) {
        state.dir_x = -100;
    } else if (state.pos_x <= 100) state.dir_x = 100;
    std.debug.print("struct: {any}\n", .{state.*});
    state.pos_x += state.dir_x * dt;
}

pub export fn render() void {}
