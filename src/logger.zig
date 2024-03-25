const std = @import("std");
const os = std.os;

const errors = @import("errors.zig");
const mem = std.mem;

pub const logger = struct {
    log_file: std.fs.File = undefined,

    pub fn init(file_name: []const u8) !logger {
        var ret: logger = undefined;
        ret.log_file = std.fs.cwd().createFile(file_name, std.fs.File.CreateFlags{ .read = false, .truncate = true }) catch |err| {
            return err;
        };
        return ret;
    }

    pub fn deinit(self: *logger) void {
        self.log_file.close();
    }

    pub fn logInfo(self: logger, comptime str: []const u8) void {
        std.fmt.format(self.log_file.writer(), str ++ "\r\n", .{}) catch |werr| {
            std.debug.print("{s}: {s}\n", .{ "can't log info", @errorName(werr) });
            os.linux.exit(1);
        };
    }

    pub fn logInfof(self: logger, comptime fmt: []const u8, args: anytype) void {
        std.fmt.format(self.log_file.writer(), fmt ++ "\r\n", .{args}) catch |werr| {
            std.debug.print("{s}: {s}\n", .{ "can't log info", @errorName(werr) });
            os.linux.exit(1);
        };
    }

    pub fn logError(self: logger, comptime str: []const u8, err: anyerror) void {
        std.fmt.format(self.log_file.writer(), "{s}: {s}" ++ "\r\n", .{ str, @errorName(err) }) catch |werr| {
            std.debug.print("{s}: {s}\n", .{ "can't log error:", @errorName(werr) });
            os.linux.exit(1);
        };
    }
};

var l: logger = undefined;

pub fn initGlobalLogger() !void {
    l = logger.init("obed.log") catch |err| {
        return err;
    };
    l.logInfo("logger inited");
    return;
}

pub fn deinitGlobalLogger() void {
    l.logInfo("logger deinited");
    l.deinit();
}

pub fn logInfo(comptime str: []const u8) void {
    l.logInfo(str);
}

pub fn logInfof(comptime fmt: []const u8, args: anytype) void {
    l.logInfof(fmt, args);
}

pub fn logError(comptime str: []const u8, err: anyerror) void {
    l.logError(str, err);
}
