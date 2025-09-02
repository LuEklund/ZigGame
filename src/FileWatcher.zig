const std = @import("std");
inotify_fd: i32,

pub fn init() !@This() {
    const fd = try std.posix.inotify_init1(std.os.linux.SOCK.NONBLOCK);
    return .{
        .inotify_fd = fd,
    };
}

pub fn deinit(self: @This()) void {
    std.posix.close(self.inotify_fd);
}

pub fn addFile(self: *@This(), path: []const u8) !void {
    _ = try std.posix.inotify_add_watch(self.inotify_fd, path, std.os.linux.IN.MODIFY);
}

pub fn listen(self: *@This()) !bool {
    const max_event_size = @sizeOf(std.os.linux.inotify_event) + std.os.linux.NAME_MAX + 1;
    var buffer: [max_event_size]u8 align(@alignOf(std.os.linux.inotify_event)) = undefined;

    const read = std.posix.read(self.inotify_fd, &buffer) catch return false;
    if (read > 0) return true;
    return false;
}
