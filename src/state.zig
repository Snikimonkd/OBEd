const std = @import("std");
const os = std.os;
const system = os.system;

const errors = @import("errors.zig");

var stdout = std.io.getStdOut();

pub const State = struct {
    termios: os.termios = undefined,
    rows: u16 = 0,
    cols: u16 = 0,
    x: u16 = 0,
    y: u16 = 0,

    bufr_rows: u32 = 0,
    row: []u8 = undefined,
};

pub var S = State{};

fn getWindowSize(rows: *u16, cols: *u16) void {
    var ws = system.winsize{
        .ws_row = undefined,
        .ws_col = undefined,
        .ws_xpixel = undefined,
        .ws_ypixel = undefined,
    };

    var res = system.ioctl(stdout.handle, system.T.IOCGWINSZ, &ws);
    if ((res == -1) or (ws.ws_col == 0)) {
        errors.printWrapped("can't get winsize", undefined);
        os.exit(1);
    }

    cols.* = ws.ws_col;
    rows.* = ws.ws_row;
}

pub fn initState() void {
    getWindowSize(&S.rows, &S.cols);
}
