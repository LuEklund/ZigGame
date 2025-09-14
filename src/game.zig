const std = @import("std");

pub const width: usize = 400;
pub const heigth: usize = 400;

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

    pub const red: Pixel = .initOpaque(255, 0, 0);
    pub const green: Pixel = .initOpaque(0, 255, 0);

    pub fn init(r: u8, g: u8, b: u8, a: u8) Pixel {
        return .{
            .r = r,
            .g = g,
            .b = b,
            .a = a,
        };
    }

    pub fn initOpaque(r: u8, g: u8, b: u8) Pixel {
        return .init(r, g, b, 255);
    }
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
    state.pos_x += state.dir_x * dt * 100;
    state.pos_y += state.dir_y * dt * 100;
    // state.pos_x = @cos(state.elapsed_time * 100) * 30 + 100;
    // state.pos_y = @sin(state.elapsed_time * 100) * 30 + 100;
}

pub export fn draw(state: *State, buffer: [*]Pixel) void {
    @memset(buffer[0..(width * heigth)], .green);

    const box_x: i32 = @intFromFloat(state.pos_x);
    const box_y: i32 = @intFromFloat(state.pos_y);

    for (0..10) |offset_y| {
        for (0..10) |offset_x| {
            const y: i32 = box_y + @as(i32, @intCast(offset_y));

            const x: i32 = box_x + @as(i32, @intCast(offset_x));

            if (x >= 0 and y >= 0 and @as(usize, @intCast(x)) < width and @as(usize, @intCast(y)) < heigth) {
                const index = @as(usize, @intCast(x)) + @as(usize, @intCast(y)) * width;

                buffer[index] = .initOpaque(0xFF, 0xFF, 0x0F);
            }
        }
    }
}
