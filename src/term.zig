const std = @import("std");
const builtin = @import("builtin");
const File = std.fs.File;

const unsupported_term =
    [_][]const u8{ "dumb", "cons25", "emacs" };

const is_windows = builtin.os.tag == .windows;

// Import Windows-specific module when on Windows
const windows_term = if (is_windows) @import(
    "windows_term.zig",
) else struct {};

// Platform-specific termios type
pub const termios = if (!is_windows)
blk: {
    break :blk std.posix.termios;
} else windows_term.WindowsTermios;

pub fn isUnsupportedTerm(allocator: std.mem.Allocator) bool {
    const env_var = std.process.getEnvVarOwned(
        allocator,
        "TERM",
    ) catch return false;
    defer allocator.free(env_var);
    return for (unsupported_term) |t| {
        if (std.ascii.eqlIgnoreCase(env_var, t))
            break true;
    } else false;
}

pub fn enableRawMode(in: File, out: File) !termios {
    if (is_windows) {
        return windows_term.enableRawMode(in, out);
    } else {
        const orig = try std.posix.tcgetattr(in.handle);
        var raw = orig;

        raw.iflag.BRKINT = false;
        raw.iflag.ICRNL = false;
        raw.iflag.INPCK = false;
        raw.iflag.ISTRIP = false;
        raw.iflag.IXON = false;

        raw.oflag.OPOST = false;

        raw.cflag.CSIZE = .CS8;

        raw.lflag.ECHO = false;
        raw.lflag.ICANON = false;
        raw.lflag.IEXTEN = false;
        raw.lflag.ISIG = false;

        // FIXME
        // raw.cc[std.os.VMIN] = 1;
        // raw.cc[std.os.VTIME] = 0;

        try std.posix.tcsetattr(
            in.handle,
            std.posix.TCSA.FLUSH,
            raw,
        );

        return orig;
    }
}

pub fn disableRawMode(in: File, out: File, orig: termios) void {
    if (is_windows) {
        windows_term.disableRawMode(in, out, orig);
    } else {
        std.posix.tcsetattr(
            in.handle,
            std.posix.TCSA.FLUSH,
            orig,
        ) catch {};
    }
}

fn getCursorPosition(in: File, out: File) !usize {
    var buf: [32]u8 = undefined;

    // Tell terminal to report cursor to in
    try out.writeAll("\x1B[6n");

    // Read answer
    var bytes_read: usize = 0;
    while (bytes_read < buf.len) {
        var one_byte: [1]u8 = undefined;
        if (in.read(&one_byte) catch break != 1) break;
        buf[bytes_read] = one_byte[0];
        bytes_read += 1;
        if (one_byte[0] == 'R') break;
    }
    if (bytes_read == 0 or buf[bytes_read - 1] != 'R')
        return error.CursorPos;
    const answer = buf[0 .. bytes_read - 1];

    // Parse answer
    if (!std.mem.startsWith(u8, "\x1B[", answer))
        return error.CursorPos;

    var iter = std.mem.splitScalar(
        u8,
        answer[2..],
        ';',
    );
    _ = iter.next() orelse return error.CursorPos;
    const x = iter.next() orelse return error.CursorPos;

    return try std.fmt.parseInt(usize, x, 10);
}

fn getColumnsFallback(in: File, out: File) !usize {
    const orig_cursor_pos = try getCursorPosition(in, out);

    try out.writeAll("\x1B[999C");
    const cols = try getCursorPosition(in, out);

    var buf: [32]u8 = undefined;
    const bytes = try std.fmt.bufPrint(
        &buf,
        "\x1B[{}D",
        .{orig_cursor_pos},
    );
    try out.writeAll(bytes);

    return cols;
}

pub fn getColumns(in: File, out: File) !usize {
    if (is_windows) {
        return windows_term.getColumns(in, out);
    } else {
        var winsize: std.posix.winsize = .{
            .row = 0,
            .col = 0,
            .xpixel = 0,
            .ypixel = 0,
        };

        const err = std.posix.system.ioctl(
            in.handle,
            std.posix.T.IOCGWINSZ,
            @intFromPtr(&winsize),
        );
        if (std.posix.errno(err) == .SUCCESS and winsize.col > 0) {
            return winsize.col;
        } else {
            return try getColumnsFallback(in, out);
        }
    }
}

pub fn clearScreen() !void {
    const stderr =
        if (is_windows) blk: {
            break :blk windows_term.getStdErr();
        } else std.fs.File{ .handle = 2 };
    try stderr.writeAll("\x1b[H\x1b[2J");
}

pub fn beep() !void {
    const stderr =
        if (is_windows) windows_term.getStdErr() else std.fs.File{ .handle = 2 };
    try stderr.writeAll("\x07");
}

// Platform-specific read function
pub const read = if (is_windows) windows_term.readConsole else File.read;

test "isUnsupportedTerm - unsupported terminals" {
    const allocator = std.testing.allocator;
    
    // Test with known unsupported terminals
    // Note: We can't easily mock environment variables in tests,
    // so we'll test the function logic by calling it directly
    // In a real environment where TERM is not set, it should return false
    const result = isUnsupportedTerm(allocator);
    // This will depend on the test environment
    _ = result;
}

test "termios type selection" {
    // Just verify the type exists and can be instantiated
    if (is_windows) {
        const t: termios = .{ .inMode = 0, .outMode = 0 };
        try std.testing.expectEqual(@as(u32, 0), t.inMode);
    } else {
        // On non-Windows, termios is std.posix.termios
        // We can't easily test this without a real terminal
    }
}
