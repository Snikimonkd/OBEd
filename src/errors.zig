const std = @import("std");
const os = std.os;

pub fn printWrapped(str: []const u8, err: anyerror) void {
    std.debug.print("{s}: {s}\n", .{ str, @errorName(err) });
}
