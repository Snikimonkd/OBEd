const std = @import("std");
const os = std.os;

const term = @import("term.zig");
const errors = @import("errors.zig");
const state = @import("state.zig");

const stdin = std.io.getStdIn();
const stdout = std.io.getStdOut();
var bufferedStdout = std.io.bufferedWriter(stdout.writer());

fn controlKey(c: u8) u8 {
    return c & 0x1f;
}

const ctrlQ = controlKey('q');

fn moveCursor(key: u8) void {
    switch (key) {
        'h' => {
            if (state.S.x >= 1) {
                state.S.x = state.S.x - 1;
            }
        },
        'j' => {
            if (state.S.y < state.S.rows - 1) {
                state.S.y = state.S.y + 1;
            }
        },
        'k' => {
            if (state.S.y >= 1) {
                state.S.y = state.S.y - 1;
            }
        },
        'l' => {
            if (state.S.x < state.S.cols - 1) {
                state.S.x = state.S.x + 1;
            }
        },
        else => {},
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
    defer bufferedStdout.flush() catch |err| {
        errors.printWrapped("can't flush stdout", err);
        os.exit(1);
    };

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
    bufferedStdout.writer().writeAll("\x1b[H") catch |err| {
        errors.printWrapped("can't move cursor to the beggining", err);
        os.exit(1);
    };

    drawRows();

    std.fmt.format(stdout.writer(), "\x1b[{d};{d}H", .{ state.S.y + 1, state.S.x + 1 }) catch |err| {
        errors.printWrapped("can't move cursor to the beggining", err);
        os.exit(1);
    };

    // TODO: insert mode cursor ahspe here
    //    stdout.writer().writeAll("\x1b[5 q") catch |err| {
    //        errors.printWrapped("can't make blinking cursor screen", err);
    //        os.exit(1);
    //    };
}

fn readKey() u8 {
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
        'h', 'j', 'k', 'l' => {
            moveCursor(c);
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
