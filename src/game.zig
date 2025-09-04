const std = @import("std");
pub const State = struct {
    pos_x: f32 = 0,
    pos_y: f32 = 0,
    dir_x: f32 = 0,
    dir_y: f32 = 0,
    elapsed_time: f32 = 0,
};

pub const Input = extern struct {
    a: bool = false,
    w: bool = false,
    s: bool = false,
    d: bool = false,
};

pub const Pixel = extern struct {
    r: u8 = 0,
    g: u8 = 0,
    b: u8 = 0,
    a: u8 = 0,
};

//TODO: COPY the state dont use the same!
pub export fn update(dt: f32, state: *State, input: *Input) void {
    state.dir_y = 0;
    state.dir_x = 0;
    state.dir_y += if (input.w) -1 else 0;
    state.dir_y += if (input.s) 1 else 0;
    state.dir_x += if (input.a) -1 else 0;
    state.dir_x += if (input.d) 1 else 0;

    state.elapsed_time += dt;
    state.pos_x += state.dir_x * dt * 50;
    state.pos_y += state.dir_y * dt * 50;
    // state.pos_x = @cos(state.elapsed_time * 100) * 30 + 100;
    // state.pos_y = @sin(state.elapsed_time * 100) * 30 + 100;
}

pub export fn draw(state: *State, buffer: [*]Pixel) void {
    for (@intFromFloat(state.pos_y)..@as(usize, @intFromFloat(state.pos_y)) + 10) |y| {
        for (@intFromFloat(state.pos_x)..@as(usize, @intFromFloat(state.pos_x)) + 10) |x| {
            // buffer[x + y * 600] = @bitCast(@as(u32, 0xFF0000FF));
            buffer[x + y * 600].r = @intCast(@mod(@as(u32, @intFromFloat(state.elapsed_time * 50)), 0xAA));
            buffer[x + y * 600].g = @intCast(@mod(@as(u32, @intFromFloat(state.elapsed_time * 0)), 0xFF));
            buffer[x + y * 600].b = @intCast(@mod(@as(u32, @intFromFloat(state.elapsed_time * 50)), 0xFF));
            buffer[x + y * 600].a = 0xFF;
        }
    }
}
