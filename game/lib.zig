const std = @import("std");

export fn gameInit() i32 {
    std.debug.print("Hello, from lib!\n", .{});
    return 0;
}
