const std = @import("std");
const os = std.os;
const system = os.system;
const errors = @import("errors.zig");

var orig_termios: os.termios = undefined;

var stdin = std.io.getStdIn();
var stdout = std.out.getStdOut();

pub fn disableRaw() void {
    os.tcsetattr(stdin.handle, os.TCSA.FLUSH, orig_termios) catch |err| {
        errors.printWrapped("can't disable raw mode", err);
        os.exit(1);
    };
}

pub fn enableRaw() void {
    orig_termios = os.tcgetattr(stdin.handle) catch |err| {
        errors.printWrapped("can't get termios attr", err);
        os.exit(1);
    };

    var raw_termios: os.termios = orig_termios;

    // ECHO - при нажатии на кнопку она не появляется в терминали
    // ICANON - читаем посимвольно а не после нажатия на энтер
    // ISIG - отключает обработку сигналов SIGINT и SIGSTP
    // IEXTEN - включаем обработку Ctrl-V (по дефолту - не читается терминалом и он продолжает ждать следующих символов
    // (типо ты вставляешь что-то и Ctrl-V не несет в себе никакой инфы для терминала))
    raw_termios.lflag &= ~(system.ECHO | system.ICANON | system.IEXTEN | system.ISIG);

    // IXON - при помощи Ctrl-S и Ctrl-Q можно сказать терминалу
    // "перестань обрабатывать поступающие данные" и "продолжи обрабатывать поступающие данные" - нам это не нужно
    // ICRNL - по дефолту терминал автоматом переводит \r в \n (13 в 10) - выключаем
    // BRKINT, INPCK, ISTRIP - когда-то давным давно их тоже использовали чтобы включить сырой режим,
    // в современных терминалах они вроде выключены по дефолтну, но как дань традиции (на всякий случай) тоже отключаем
    raw_termios.iflag &= ~(system.BRKINT | system.ICRNL | system.INPCK | system.ISTRIP | system.IXON);

    // OPOST - при выводу \n терминал добавляет к ней еще \r (в итоге получается \r\n) - выключаем
    raw_termios.oflag &= ~(system.OPOST);

    // CS8 - тоже что-то от древних динозавров, выключаем на всякий случай
    raw_termios.cflag &= ~(system.CS8);

    os.tcsetattr(stdin.handle, os.TCSA.FLUSH, raw_termios) catch |err| {
        errors.printWrapped("can't set termios attr", err);
        os.exit(1);
    };
}
