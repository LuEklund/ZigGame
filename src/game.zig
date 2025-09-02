const std = @import("std");
const header = @import("header.zig");

export fn update(state: header.State) void {
    std.debug.print("State index: {d}\n", .{state.index});
}
