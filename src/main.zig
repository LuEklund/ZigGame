const std = @import("std");
const builtin = @import("builtin");

pub fn main() !void {
    var lib = try std.DynLib.open("zig-out/lib/libgame" ++ comptime builtin.target.os.tag.dynamicLibSuffix());
    defer lib.close();

    std.debug.print("{any}\n", .{@TypeOf(lib.inner)});

    const gameInit = lib.lookup(*const fn () i32, "gameInit") orelse return error.LookupFailed;

    _ = gameInit();
}
