const std = @import("std");
pub const State = extern struct {
    pos_x: f32 = 0,
    pos_y: f32 = 0,
    dir_x: f32 = 100,
    dir_y: f32 = 0,
};

pub const Pixels = extern struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 0,
};

pub export fn update(dt: f32, state: *State) void {
    if (state.pos_x >= 300) {
        state.dir_x = -100;
    } else if (state.pos_x <= 100) state.dir_x = 100;
    state.pos_x += state.dir_x * dt;
}

pub export fn draw(state: *State, buffer: [*]Pixels) void {
    for (@intFromFloat(state.pos_y)..@as(usize, @intFromFloat(state.pos_y)) + 10) |y| {
        for (@intFromFloat(state.pos_x)..@as(usize, @intFromFloat(state.pos_x)) + 10) |x| {
            buffer[x + y * 600] = @bitCast(@as(u32, 0xFF0000FF));
        }
    }
}
