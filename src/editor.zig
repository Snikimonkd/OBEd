const std = @import("std");
const os = std.os;

const term = @import("term.zig");
const errors = @import("errors.zig");

var stdin = std.io.getStdIn();

pub fn controlKey(c: u8) u8 {
    return c & 0x1f;
}

const ctrlQ = controlKey('q');

pub fn readKey() u8 {
    var c: [1]u8 = undefined;
    if (stdin.read(&c)) |val| {
        if (val != 1) {
            errors.printWrapped("no chars were read", undefined);
            os.exit(1);
        }

        return c[0];
    } else |err| {
        errors.printWrapped("can't read from stdin", err);
        os.exit(1);
    }
}

pub fn processKey() void {
    var c = readKey();

    switch (c) {
        ctrlQ => {
            os.exit(0);
        },
        // 0...std.ascii.control_code.us, std.ascii.control_code.del => {
        //     std.debug.print("control num:{d}\r\n", .{c});
        //     return;
        // },
        else => {
            std.debug.print("simple num:{d}, char:{c}\r\n", .{ c, c });
            return;
        },
    }
}
