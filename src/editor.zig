const std = @import("std");
const os = std.os;

const term = @import("term.zig");
const state = @import("state.zig");

const logger = @import("logger.zig");
const errors = @import("errors.zig");

const stdin = std.io.getStdIn();
const stdout = std.io.getStdOut();
var bufferedStdout = std.io.bufferedWriter(stdout.writer());

const Key = enum(u16) {
    up = 1001,
    down = 1002,
    left = 1003,
    right = 1004,
    pg_up = 1005,
    pg_down = 1006,
    home = 1007,
    end = 1008,

    delete = 2001,
};

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
            if (state.S.y < state.S.num_lines) {
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
            const delta = state.S.rows / 2;
            if (state.S.y >= delta) {
                state.S.y = state.S.y - delta;
            } else {
                state.S.y = 0;
            }
        },
        Key.pg_down => {
            const delta = state.S.rows / 2;
            if (state.S.y < state.S.rows - delta) {
                state.S.y = state.S.y + delta;
            } else {
                state.S.y = state.S.rows - 1;
            }
        },
        Key.home => {
            state.S.x = 0;
        },
        Key.end => {
            state.S.x = state.S.cols - 1;
        },
        else => {
            unreachable;
        },
    }
}

fn welcomeMsg() !void {
    const msg = "OBEd -- version 0.0.1";
    var offset: i32 = @divTrunc((@as(i32, state.S.cols) - @as(i32, msg.len)), 2);
    offset = if (offset < 0) 0 else offset;

    for (0..@intCast(offset)) |_| {
        bufferedStdout.writer().writeAll(" ") catch |err| {
            logger.logError("can't add whitespaces to welcome msg", err);
            return err;
        };
    }
    bufferedStdout.writer().writeAll(msg) catch |err| {
        logger.logError("can't print welcome msg", err);
        return err;
    };
}

fn drawRows() !void {
    for (0..state.S.rows) |y| {
        const filerow = y + state.S.offset;
        if (filerow >= state.S.num_lines) {
            bufferedStdout.writer().writeAll("~") catch |err| {
                logger.logError("can't draw tild on screen", err);
                return err;
            };

            if (state.S.num_lines == 0 and y == state.S.rows / 2) {
                welcomeMsg() catch |err| {
                    return err;
                };
            }
        } else {
            var len: usize = state.S.lines.items[filerow].items.len;
            if (len > state.S.cols) {
                len = state.S.cols;
            }
            if (len != 0) {
                bufferedStdout.writer().writeAll(state.S.lines.items[filerow].items[0..len]) catch |err| {
                    logger.logError("can't write row on the screen", err);
                    return err;
                };
            }
        }

        bufferedStdout.writer().writeAll("\x1b[K") catch |err| {
            logger.logError("can't clear line", err);
            return err;
        };
        if (y < state.S.rows - 1) {
            bufferedStdout.writer().writeAll("\r\n") catch |err| {
                logger.logError("can't draw \\r\\n on screen", err);
                return err;
            };
        }
    }
}

fn scroll() void {
    if (state.S.y < state.S.offset) {
        state.S.offset = state.S.y;
    }
    if (state.S.y >= state.S.offset + state.S.rows) {
        state.S.offset = state.S.y - state.S.rows + 1;
    }
}

pub fn refreshScreen() !void {
    scroll();

    bufferedStdout.writer().writeAll("\x1b[H") catch |err| {
        logger.logError("can't move cursor to the beggining", err);
        return err;
    };

    drawRows() catch |err| {
        return err;
    };

    std.fmt.format(bufferedStdout.writer(), "\x1b[{d};{d}H", .{ state.S.y + 1 - state.S.offset, state.S.x + 1 }) catch |err| {
        logger.logError("can't move cursor to its position", err);
        return err;
    };

    bufferedStdout.flush() catch |err| {
        logger.logError("can't flush stdout", err);
        return err;
    };

    // TODO: insert mode cursor ahspe here
    //    stdout.writer().writeAll("\x1b[5 q") catch |err| {
    //        errors.printWrapped("can't make blinking cursor screen", err);
    //        os.exit(1);
    //    };
}

fn readKey() !u16 {
    var c: [1]u8 = undefined;
    _ = stdin.read(&c) catch |err| {
        logger.logError("can't read from stdin", err);
        return err;
    };

    if (c[0] == '\x1b') {
        var seq: [3]u8 = undefined;
        const val = (stdin.read(&seq)) catch |err| {
            logger.logError("can't read special symbols", err);
            return err;
        };
        if (val < 2) {
            return '\x1b';
        }
        switch (seq[0]) {
            '[' => {
                if (seq[1] >= '0' and seq[1] <= '9') {
                    if (seq[2] == '~') {
                        switch (seq[1]) {
                            '1' => {
                                return @intFromEnum(Key.home);
                            },
                            '3' => {
                                return @intFromEnum(Key.delete);
                            },
                            '4' => {
                                return @intFromEnum(Key.end);
                            },
                            '5' => {
                                return @intFromEnum(Key.pg_up);
                            },
                            '6' => {
                                return @intFromEnum(Key.pg_down);
                            },
                            '7' => {
                                return @intFromEnum(Key.home);
                            },
                            '8' => {
                                return @intFromEnum(Key.end);
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
                    'H' => {
                        return @intFromEnum(Key.home);
                    },
                    'F' => {
                        return @intFromEnum(Key.end);
                    },
                    else => {
                        return '\x1b';
                    },
                }
            },
            'O' => {
                switch (seq[1]) {
                    'H' => {
                        return @intFromEnum(Key.home);
                    },
                    'F' => {
                        return @intFromEnum(Key.end);
                    },
                    else => {
                        return '\x1b';
                    },
                }
            },
            else => {
                return '\x1b';
            },
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

pub fn processKey() !void {
    const c = readKey() catch |err| {
        return err;
    };

    switch (c) {
        ctrlQ => {
            return errors.EditorError.Exit;
        },
        @intFromEnum(Key.up),
        @intFromEnum(Key.down),
        @intFromEnum(Key.left),
        @intFromEnum(Key.right),
        @intFromEnum(Key.pg_up),
        @intFromEnum(Key.pg_down),
        @intFromEnum(Key.home),
        @intFromEnum(Key.end),
        => {
            moveCursor(@enumFromInt(c));
        },
        @intFromEnum(Key.delete) => {},
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

pub fn editorOpen(file_name: []const u8, allocator: std.mem.Allocator) !void {
    const file = std.fs.cwd().openFile(file_name, .{}) catch |err| {
        return err;
    };
    defer file.close();

    var buf_reader = std.io.bufferedReader(file.reader());
    const reader = buf_reader.reader();

    var flag: bool = true;
    while (flag) {
        var line = std.ArrayList(u8).init(allocator);
        reader.streamUntilDelimiter(line.writer(), '\n', null) catch |err| {
            switch (err) {
                error.EndOfStream => {
                    flag = false;
                },
                else => {
                    logger.logError("can't read line from file", err);
                    return err;
                },
            }
        };
        if (flag) {
            state.S.num_lines += 1;
            //        line.appendSlice("\r\n") catch |err| {
            //            logger.logError("can't append \\r\\n to line end", err);
            //            return err;
            //        };
            state.S.lines.append(line) catch |err| {
                logger.logError("can't append line", err);
                return err;
            };
        }
    }
}
