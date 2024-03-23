const std = @import("std");

pub const EditorError = error{
    CantGetWinSize,
    ReadCharFromInputError,
    Exit,
};
