const std = @import("std");
const os = std.os;
const system = os.system;

pub fn makeRaw() void {
    var t = os.tcgetattr(std.io.getStdIn().handle) catch |err| {
        std.debug.print("can't get termios attrs {}\n", .{err});
        os.exit(1);
    };

    // при нажатии на кнопку она не появляется в терминали
    t.lflag &= ~(system.ECHO);

    os.tcsetattr(std.io.getStdIn().handle, os.TCSA.FLUSH, t) catch |err| {
        std.debug.print("can't set termios attr {}\n", .{err});
        os.exit(1);
    };
}

pub fn main() !void {
    makeRaw();
    var c: [1]u8 = undefined;
    while (std.io.getStdIn().read(&c)) |val| {
        if (val != 1) {
            std.debug.print("read zero chars\n", .{});
        } else {
            std.debug.print("{c}\n", .{c[0]});
        }
    } else |err| {
        std.debug.print("err {}\n", .{err});
    }
    //    // Prints to stderr (it's a shortcut based on `std.io.getStdErr()`)
    //    std.debug.print("All your {s} are belong to us.\n", .{"codebase"});
    //
    //    // stdout is for the actual output of your application, for example if you
    //    // are implementing gzip, then only the compressed bytes should be sent to
    //    // stdout, not any debugging messages.
    //    const stdout_file = std.io.getStdOut().writer();
    //    var bw = std.io.bufferedWriter(stdout_file);
    //    const stdout = bw.writer();
    //
    //    try stdout.print("Run `zig build test` to run the tests.\n", .{});
    //
    //    try bw.flush(); // don't forget to flush!
}

// test "simple test" {
//     var list = std.ArrayList(i32).init(std.testing.allocator);
//     defer list.deinit(); // try commenting this out and see if zig detects the memory leak!
//     try list.append(42);
//     try std.testing.expectEqual(@as(i32, 42), list.pop());
// }
