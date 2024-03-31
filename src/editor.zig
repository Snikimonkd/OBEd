const std = @import("std");
const os = std.os;

const term = @import("term.zig");
const state = @import("state.zig");

const logger = @import("logger.zig");
const errors = @import("errors.zig");

const stdin = std.io.getStdIn();
const stdout = std.io.getStdOut();
var bufferedStdout = std.io.bufferedWriter(stdout.writer());

const Key = enum(u8) {
    backspace = 127,

    up = 201,
    down = 202,
    left = 203,
    right = 204,

    delete = 205,
};

fn controlKey(c: u8) u8 {
    return c & 0x1f;
}

const ctrlQ = controlKey('q');
const ctrlH = controlKey('h');
const ctrlS = controlKey('s');
const ctrlL = controlKey('l');

fn moveCursor(key: Key) void {
    var row: ?std.ArrayList(u8) = if (state.S.y >= state.S.num_lines) null else state.S.lines.items[state.S.y];
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
            if (row != null and state.S.x < row.?.items.len) {
                state.S.x = state.S.x + 1;
            }
        },
        else => {
            unreachable;
        },
    }

    row = if (state.S.y >= state.S.num_lines) null else state.S.lines.items[state.S.y];
    const rowlen: u16 = if (row != null) @intCast(row.?.items.len) else 0;
    if (state.S.x > rowlen) {
        state.S.x = rowlen;
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
        const filerow = y + state.S.row_offset;
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
            var len: i64 = @as(i64, @intCast(state.S.lines.items[filerow].items.len)) - state.S.col_offset;
            if (len < 0) {
                len = 0;
            }
            if (len > state.S.cols) {
                len = state.S.cols;
            }
            if (len != 0) {
                bufferedStdout.writer().writeAll(state.S.lines.items[filerow].items[state.S.col_offset..(state.S.col_offset + @as(u16, @intCast(len)))]) catch |err| {
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
    if (state.S.y < state.S.row_offset) {
        state.S.row_offset = state.S.y;
    }
    if (state.S.y >= state.S.row_offset + state.S.rows) {
        state.S.row_offset = state.S.y - state.S.rows + 1;
    }
    if (state.S.x < state.S.col_offset) {
        state.S.col_offset = state.S.x;
    }
    if (state.S.x >= state.S.col_offset + state.S.cols) {
        state.S.col_offset = state.S.x - state.S.cols + 1;
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

    std.fmt.format(bufferedStdout.writer(), "\x1b[{d};{d}H", .{ state.S.y + 1 - state.S.row_offset, state.S.x + 1 - state.S.col_offset }) catch |err| {
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

fn readKey() !u8 {
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
                            '3' => {
                                return @intFromEnum(Key.delete);
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
            },
            else => {
                return '\x1b';
            },
        }
    }
    switch (c[0]) {
        else => {
            return c[0];
        },
    }
}

pub fn lineInsertChar(line: *std.ArrayList(u8), at: u16, c: u8) !void {
    var pos = at;
    if (pos < 0 or pos > line.items.len) {
        pos = @intCast(line.items.len);
    }
    line.insert(pos, c) catch |err| {
        logger.logError("can't insert char", err);
        return err;
    };
}

pub fn lineDeleteChar(line: *std.ArrayList(u8), at: u16) !void {
    if (at < 0 or at >= line.items.len) {
        return;
    }
    _ = line.orderedRemove(at);
    // line.resize(line.items.len - 1) catch |err| {
    //     logger.logError("can't resize", err);
    //     return err;
    // };
    logger.logInfof("line after remove: len: {d}", line.items.len);
}

pub fn delChar() !void {
    if (state.S.y == state.S.num_lines) {
        return;
    }
    if (state.S.x == 0 and state.S.y == 0) {
        return;
    }

    var line = &state.S.lines.items[state.S.y];
    if (state.S.x > 0) {
        lineDeleteChar(line, state.S.x - 1) catch |err| {
            return err;
        };
        state.S.x -= 1;
    } else {
        state.S.x = @intCast(state.S.lines.items[state.S.y - 1].items.len);
        rowAppendString(&state.S.lines.items[state.S.y - 1], line.items) catch |err| {
            return err;
        };
        delRow(state.S.y);
        state.S.y -= 1;
    }
}

pub fn insertChar(c: u8, allocator: std.mem.Allocator) !void {
    if (state.S.y == state.S.num_lines) {
        state.S.lines.append(std.ArrayList(u8).init(allocator)) catch |err| {
            logger.logError("can't add line", err);
            return err;
        };
    }
    lineInsertChar(&state.S.lines.items[state.S.y], state.S.x, c) catch |err| {
        return err;
    };
    state.S.x += 1;
}

pub fn delRow(at: u16) void {
    if (at < 0 or at >= state.S.num_lines) {
        return;
    }
    state.S.lines.items[at].deinit();
    _ = state.S.lines.orderedRemove(at);
    state.S.num_lines -= 1;
}

pub fn rowAppendString(line: *std.ArrayList(u8), chrs: []u8) !void {
    line.appendSlice(chrs) catch |err| {
        logger.logError("can't appen two rows", err);
        return err;
    };
}

pub fn save() !void {
    const file = std.fs.cwd().createFile(state.S.file_name, std.fs.File.CreateFlags{ .read = false, .truncate = true }) catch |err| {
        logger.logError("can't open file to save", err);
        return err;
    };
    defer file.close();

    for (state.S.lines.items) |line| {
        file.writer().writeAll(line.items) catch |err| {
            logger.logError("can't save file", err);
            return err;
        };
        file.writer().writeAll("\n") catch |err| {
            logger.logError("can't save file", err);
            return err;
        };
    }
}

pub fn processKey(allocator: std.mem.Allocator) !void {
    const c = readKey() catch |err| {
        return err;
    };

    switch (c) {
        '\r' => {
            // todo
            return;
        },

        ctrlS => {
            save() catch |err| {
                return err;
            };
        },

        @intFromEnum(Key.delete),
        @intFromEnum(Key.backspace),
        ctrlH,
        => {
            delChar() catch |err| {
                return err;
            };
            return;
        },

        ctrlQ => {
            return errors.EditorError.Exit;
        },
        @intFromEnum(Key.up),
        @intFromEnum(Key.down),
        @intFromEnum(Key.left),
        @intFromEnum(Key.right),
        => {
            moveCursor(@enumFromInt(c));
            return;
        },

        ctrlL => {
            return;
        },
        20...126 => {
            insertChar(c, allocator) catch |err| {
                return err;
            };
            return;
        },
        else => {
            return;
        },
    }
}

pub fn editorOpen(file_name: []const u8, allocator: std.mem.Allocator) !void {
    state.S.file_name = file_name;
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
            //            line.append('\x00') catch |err| {
            //                logger.logError("can't append null byte", err);
            //                return err;
            //            };
            state.S.lines.append(line) catch |err| {
                logger.logError("can't append line", err);
                return err;
            };
        }
    }
}
