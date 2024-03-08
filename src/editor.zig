const std = @import("std");
const os = std.os;

const term = @import("term.zig");
const errors = @import("errors.zig");
const state = @import("state.zig");

const stdin = std.io.getStdIn();
const stdout = std.io.getStdOut();
var bufferedStdout = std.io.bufferedWriter(stdout.writer());

const Key = enum(u16) { up = 1000, down = 1001, left = 1002, right = 1003, pg_up = 1004, pg_down = 1005 };

fn controlKey(c: u8) u8 {
    return c & 0x1f;
}

const ctrlQ = controlKey('q');

fn moveCursor(key: Key) void {
    switch (key) {
        Key.left => {
            if (state.S.x >= 1) {
                state.S.x = state.S.x - 1;
            }
        },
        Key.down => {
            if (state.S.y < state.S.rows - 1) {
                state.S.y = state.S.y + 1;
            }
        },
        Key.up => {
            if (state.S.y >= 1) {
                state.S.y = state.S.y - 1;
            }
        },
        Key.right => {
            if (state.S.x < state.S.cols - 1) {
                state.S.x = state.S.x + 1;
            }
        },
        Key.pg_up => {
            var delta = state.S.rows / 2;
            if (state.S.y >= delta) {
                state.S.y = state.S.y - delta;
            } else {
                state.S.y = 0;
            }
        },
        Key.pg_down => {
            var delta = state.S.rows / 2;
            if (state.S.y < state.S.rows - delta) {
                state.S.y = state.S.y + delta;
            } else {
                state.S.y = state.S.rows - 1;
            }
        },
    }
}

fn welcomeMsg() void {
    var msg = "OBEd -- version 0.0.1";
    var offset: i32 = @divTrunc((@as(i32, state.S.cols) - @as(i32, msg.len)), 2);
    offset = if (offset < 0) 0 else offset;

    for (0..@intCast(offset)) |_| {
        bufferedStdout.writer().writeAll(" ") catch |err| {
            errors.printWrapped("can't add whitespaces to welcome msg", err);
            os.exit(1);
        };
    }
    bufferedStdout.writer().writeAll(msg) catch |err| {
        errors.printWrapped("can't print welcome msg", err);
        os.exit(1);
    };
}

fn drawRows() void {
    for (0..state.S.rows) |y| {
        bufferedStdout.writer().writeAll("~") catch |err| {
            errors.printWrapped("can't draw tild on screen", err);
            os.exit(1);
        };

        if (y == state.S.rows / 2) {
            welcomeMsg();
        }

        bufferedStdout.writer().writeAll("\x1b[K") catch |err| {
            errors.printWrapped("can't clear line", err);
            os.exit(1);
        };

        if (y < state.S.rows - 1) {
            bufferedStdout.writer().writeAll("\r\n") catch |err| {
                errors.printWrapped("can't draw \r\n on screen", err);
                os.exit(1);
            };
        }
    }
}

pub fn refreshScreen() void {
    defer bufferedStdout.flush() catch |err| {
        errors.printWrapped("can't flush stdout", err);
        os.exit(1);
    };

    bufferedStdout.writer().writeAll("\x1b[H") catch |err| {
        errors.printWrapped("can't move cursor to the beggining", err);
        os.exit(1);
    };

    drawRows();

    std.fmt.format(bufferedStdout.writer(), "\x1b[{d};{d}H", .{ state.S.y + 1, state.S.x + 1 }) catch |err| {
        errors.printWrapped("can't move cursor to the beggining", err);
        os.exit(1);
    };

    // TODO: insert mode cursor ahspe here
    //    stdout.writer().writeAll("\x1b[5 q") catch |err| {
    //        errors.printWrapped("can't make blinking cursor screen", err);
    //        os.exit(1);
    //    };
}

fn readKey() u16 {
    var c: [1]u8 = undefined;
    _ = stdin.read(&c) catch |err| {
        errors.printWrapped("can't read from stdin", err);
        os.exit(1);
    };

    if (c[0] == '\x1b') {
        var seq: [3]u8 = undefined;
        var val = (stdin.read(&seq)) catch |err| {
            errors.printWrapped("can't read special symbols", err);
            os.exit(1);
        };
        if (val < 2) {
            return '\x1b';
        }

        if (seq[0] == '[') {
            if (seq[1] >= '0' and seq[1] <= '9') {
                if (seq[2] == '~') {
                    switch (seq[1]) {
                        '5' => {
                            return @intFromEnum(Key.pg_up);
                        },
                        '6' => {
                            return @intFromEnum(Key.pg_down);
                        },
                        else => {
                            return '\x1b';
                        },
                    }
                }
            }
            switch (seq[1]) {
                'A' => {
                    return @intFromEnum(Key.up);
                },
                'B' => {
                    return @intFromEnum(Key.down);
                },
                'C' => {
                    return @intFromEnum(Key.right);
                },
                'D' => {
                    return @intFromEnum(Key.left);
                },
                else => {
                    return '\x1b';
                },
            }
        }
    }
    switch (c[0]) {
        'k' => {
            return @intFromEnum(Key.up);
        },
        'j' => {
            return @intFromEnum(Key.down);
        },
        'l' => {
            return @intFromEnum(Key.right);
        },
        'h' => {
            return @intFromEnum(Key.left);
        },
        else => {
            return c[0];
        },
    }
}

pub fn processKey() void {
    var c = readKey();

    switch (c) {
        ctrlQ => {
            os.exit(0);
        },
        @intFromEnum(Key.up), @intFromEnum(Key.down), @intFromEnum(Key.right), @intFromEnum(Key.left), @intFromEnum(Key.pg_up), @intFromEnum(Key.pg_down) => {
            moveCursor(@enumFromInt(c));
        },
        // 0...std.ascii.control_code.us, std.ascii.control_code.del => {
        //     std.debug.print("control num:{d}\r\n", .{c});
        //     return;
        // },
        else => {
            // std.debug.print("simple num:{d}, char:{c}\r\n", .{ c, c });
            return;
        },
    }
}
