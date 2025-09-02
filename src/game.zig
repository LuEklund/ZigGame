const std = @import("std");
const header = @import("header.zig");

export fn update(state: header.State) header.State {
    var new_state: header.State = state;
    new_state.index += 1;
    return new_state;
}
