const std = @import("std");
const os = std.os;
const system = os.system;

const term = @import("term.zig");
const editor = @import("editor.zig");
const state = @import("state.zig");
const logger = @import("logger.zig");
const errors = @import("errors.zig");

pub fn main() !void {
    logger.initGlobalLogger() catch |err| {
        return err;
    };
    defer {
        logger.deinitGlobalLogger();
    }

    state.initState() catch |err| {
        return err;
    };
    logger.logInfo("state inited");

    term.enableRawMode() catch |err| {
        return err;
    };
    logger.logInfo("raw mode enabled");
    defer {
        term.disableRaw();
        logger.logInfo("raw mode disabled");
    }

    while (true) {
        editor.refreshScreen() catch |err| {
            return err;
        };
        editor.processKey() catch |err| switch (err) {
            errors.EditorError.Exit => {
                return;
            },
            else => {
                return err;
            },
        };
    }
    return;
}

// test "simple test" {
//     var list = std.ArrayList(i32).init(std.testing.allocator);
//     defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
//     try list.append(42);
//     try std.testing.expectEqual(@as(i32, 42), list.pop());
// }
