const std = @import("std");
const os = std.os;

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

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leak = gpa.deinit();
        switch (leak) {
            std.heap.Check.leak => {
                std.debug.print("memory leak detected {}\n", .{leak});
            },
            std.heap.Check.ok => {},
        }
    }
    const allocator = gpa.allocator();

    state.initState(allocator) catch |err| {
        return err;
    };
    defer state.deinitState();
    logger.logInfo("state inited");

    var args = std.process.argsAlloc(allocator) catch |err| {
        logger.logError("can't init args", err);
        return err;
    };
    defer std.process.argsFree(allocator, args);

    if (args.len != 2) {
        std.debug.print("path a file name\n", .{});
        return;
    }
    const filename: []const u8 = args[1];
    editor.editorOpen(filename, allocator) catch |err| {
        return err;
    };

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
        editor.processKey(allocator) catch |err| switch (err) {
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
