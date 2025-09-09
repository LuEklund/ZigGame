const std = @import("std");
const builtin = @import("builtin");

pub const FileWatcher = struct {
    inotify_fd: i32,

    pub fn init() !@This() {
        const fd = try std.posix.inotify_init1(std.os.linux.SOCK.NONBLOCK);
        return .{ .inotify_fd = fd };
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
};

pub const Game = struct {
    lib_path_buffer: [std.fs.max_path_bytes]u8,
    lib_path_len: usize,
    dynlib: std.DynLib,
    file_watcher: FileWatcher,

    pub fn init() !@This() {
        const lib_name: []const u8 = std.fmt.comptimePrint("libgame{s}", .{comptime builtin.target.dynamicLibSuffix()});

        const search_paths: []const []const u8 = &.{
            "../lib/",
            "zig-out/lib/",
            "./",
        };

        const lib_path: ?[]const u8 =
            for (search_paths) |path_prefix| {
                var buffer: [std.fs.max_path_bytes]u8 = undefined;
                const path = try std.fmt.bufPrint(&buffer, "{s}{s}", .{ path_prefix, lib_name });

                if ((std.fs.cwd().access(path, .{}) catch null) != null) {
                    break @constCast(path);
                }
            } else null;

        //if (lib_path == null or (std.fs.cwd().access(lib_path.?, .{}) catch null) != null) {
        //    std.log.warn("{s} not found", .{lib_path orelse "null"});
        //    std.process.cleanExit();
        //}

        var file_watcher: FileWatcher = try .init();
        try file_watcher.addFile("zig-out/lib/");

        const dynlib: std.DynLib = try .open(lib_path.?);
        std.log.debug("PATH {s}\n", .{lib_path.?});

        var self: @This() = .{
            .lib_path_len = lib_path.?.len,
            .lib_path_buffer = undefined,
            .dynlib = dynlib,
            .file_watcher = file_watcher,
        };
        @memcpy(self.lib_path_buffer[0..lib_path.?.len], lib_path.?[0..]);
        return self;
    }

    pub fn deinit(self: *@This()) void {
        self.file_watcher.deinit();
        self.dynlib.close();
    }

    pub fn listen(self: *@This()) !bool {
        if (try self.file_watcher.listen()) blk: {
            std.log.debug("Reloaded dynamic lib:\nLEN: {}, PATH {s}\n", .{ self.lib_path_len, self.lib_path_buffer[0..self.lib_path_len] });
            self.dynlib.close();
            self.dynlib = std.DynLib.open(self.lib_path_buffer[0..self.lib_path_len]) catch break :blk;
            try self.file_watcher.addFile("zig-out/lib/");
            return true;
        }
        return false;
    }

    pub inline fn lookup(self: *@This(), comptime T: type, name: [:0]const u8) !T {
        return self.dynlib.lookup(T, name) orelse error.DynlibLookup;
    }
};
