const std = @import("std");

pub const width: usize = 400;
pub const heigth: usize = 400;
pub const max_entity_count: usize = 128;
// comptime {
//     @compileLog(@sizeOf(State));
// }

pub const State = struct {
    elapsed_time: f32 = 0,
    entities: [max_entity_count]Entity = undefined,
    entity_count: usize = 0,
};

const entityType = enum(c_int) {
    player,
    food,
};

pub const Entity = extern struct {
    id: u32 = 0,
    pos_x: f32 = 0,
    pos_y: f32 = 0,
    mass: u32 = 0,
    e_type: entityType = .player,
};

const entityAction = enum(c_int) {
    spawnPlayer = 0,
    spawnFood = 1,
    update = 2,
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

pub export fn entityFunction(state: *State, enitity: Entity, action: entityAction) void {
    switch (action) {
        .spawnPlayer => spawnPlayer(state, enitity),
        .spawnFood => spawnFood(state, enitity),
        .update => updateEntity(state, enitity),
    }
}

pub fn updateEntity(state: *State, enitity: Entity) void {
    for (0..@min(state.entity_count, max_entity_count)) |i| {
        if (state.entities[i].id == enitity.id) {
            state.entities[i].pos_x = enitity.pos_x;
            state.entities[i].pos_y = enitity.pos_y;
            return;
        }
    }
}

pub fn spawnPlayer(state: *State, enitity: Entity) void {
    if (state.entity_count < max_entity_count) {
        state.entities[state.entity_count] = .{
            .id = enitity.id,
            .pos_x = enitity.pos_x,
            .pos_y = enitity.pos_y,
            .mass = enitity.mass,
            .e_type = .player,
        };
        state.entity_count += 1;
    }
}

pub fn spawnFood(state: *State, enitity: Entity) void {
    if (state.entity_count < max_entity_count) {
        state.entities[state.entity_count] = .{
            .id = enitity.id,
            .pos_x = enitity.pos_x,
            .pos_y = enitity.pos_y,
            .mass = enitity.mass,
            .e_type = .food,
        };
        state.entity_count += 1;
    }
}

pub export fn draw(state: *State, buffer: [*]Pixel) void {
    @memset(buffer[0..(width * heigth)], .green);

    // const box_x: i32 = @intFromFloat(state.pos_x);
    // const box_y: i32 = @intFromFloat(state.pos_y);
    // drawCube(buffer, box_x, box_y, Pixel.initOpaque(0xFF, 0x00, 0x0F));
    for (0..@min(state.entity_count, max_entity_count)) |i| {
        var color: Pixel = .initOpaque(0xFF, 0x00, 0x00);
        if (state.entities[i].e_type == .food)
            color = .initOpaque(0x00, 0x00, 0xFF);
        drawCube(buffer, @intFromFloat(state.entities[i].pos_x), @intFromFloat(state.entities[i].pos_y), color);
    }
}

fn drawCube(buffer: [*]Pixel, xPos: i32, yPos: i32, color: Pixel) void {
    for (0..10) |offset_y| {
        for (0..10) |offset_x| {
            const y: i32 = yPos + @as(i32, @intCast(offset_y));

            const x: i32 = xPos + @as(i32, @intCast(offset_x));

            if (x >= 0 and y >= 0 and @as(usize, @intCast(x)) < width and @as(usize, @intCast(y)) < heigth) {
                const index = @as(usize, @intCast(x)) + @as(usize, @intCast(y)) * width;

                buffer[index] = color;
            }
        }
    }
}
