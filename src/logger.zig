const std = @import("std");
const os = std.os;

const errors = @import("errors.zig");

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

    pub fn logInfo(self: logger, str: []const u8) void {
        std.fmt.format(self.log_file.writer(), "{s}\r\n", .{str}) catch |werr| {
            std.debug.print("{s}: {s}\n", .{ "can't log info", @errorName(werr) });
            os.exit(1);
        };
    }
    pub fn logError(self: logger, str: []const u8, err: anyerror) void {
        std.fmt.format(self.log_file.writer(), "{s}: {s}\r\n", .{ str, @errorName(err) }) catch |werr| {
            std.debug.print("{s}: {s}\n", .{ "can't log error:", @errorName(werr) });
            os.exit(1);
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

pub fn logInfo(str: []const u8) void {
    l.logInfo(str);
}

pub fn logError(str: []const u8, err: anyerror) void {
    l.logError(str, err);
}
