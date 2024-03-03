const std = @import("std");
const os = std.os;
const system = os.system;

const term = @import("term.zig");
const editor = @import("editor.zig");

var stdin = std.io.getStdIn();
var stdout = std.out.getStdOut();

var orig_termios: os.termios = undefined;

pub fn controlKey(c: u8) u8 {
    return c & 0x1f;
}

pub fn main() !void {
    term.enableRaw();
    defer (term.disableRaw());
    while (true) {
        editor.processKey();
    }
    return;
}

// test "simple test" {
//     var list = std.ArrayList(i32).init(std.testing.allocator);
//     defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
//     try list.append(42);
//     try std.testing.expectEqual(@as(i32, 42), list.pop());
// }
