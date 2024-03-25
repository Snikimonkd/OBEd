const std = @import("std");
const os = std.os;
const system = os.system;

const errors = @import("errors.zig");
const logger = @import("logger.zig");

var stdout = std.io.getStdOut();

pub const State = struct {
    termios: os.termios = undefined,
    rows: u16 = 0,
    cols: u16 = 0,
    x: u16 = 0,
    y: u16 = 0,

    num_lines: u32 = 0,
    lines: std.ArrayList(std.ArrayList(u8)) = undefined,
};

pub var S = State{};

fn getWindowSize(rows: *u16, cols: *u16) errors.EditorError!void {
    var ws = system.winsize{
        .ws_row = undefined,
        .ws_col = undefined,
        .ws_xpixel = undefined,
        .ws_ypixel = undefined,
    };

    const res = system.ioctl(stdout.handle, system.T.IOCGWINSZ, &ws);
    if ((res == -1) or (ws.ws_col == 0)) {
        logger.logError("can't get winsize", error.CantGetWinSize);
        return error.CantGetWinSize;
    }

    cols.* = ws.ws_col;
    rows.* = ws.ws_row;
    return;
}

pub fn initState(allocator: std.mem.Allocator) errors.EditorError!void {
    S.lines = std.ArrayList(std.ArrayList(u8)).init(allocator);
    getWindowSize(&S.rows, &S.cols) catch |err| {
        return err;
    };
}

pub fn deinitState() void {
    for (S.lines.items) |line| line.deinit();
    S.lines.deinit();
}
