const std = @import("std");
const os = std.os;
const system = os.system;

const term = @import("term.zig");
const editor = @import("editor.zig");
const state = @import("state.zig");

pub fn main() !void {
    state.initState();
    term.enableRaw();
    defer (term.disableRaw());
    while (true) {
        editor.refreshScreen();
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
