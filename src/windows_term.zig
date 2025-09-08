const std = @import("std");
const File = std.fs.File;

const w = std.os.windows;

// Windows console constants
pub const ENABLE_VIRTUAL_TERMINAL_INPUT = @as(c_int, 0x200);
pub const CP_UTF8 = @as(c_int, 65001);

// Windows-specific termios equivalent
pub const WindowsTermios = struct {
    inMode: w.DWORD,
    outMode: w.DWORD,
};

// Input record structure for console input
pub const INPUT_RECORD = extern struct {
    EventType: w.WORD,
    _ignored: [16]u8,
};

// Kernel32 function imports
pub const k32 = struct {
    const kernel32 = std.os.windows.kernel32;
    pub const GetConsoleMode =
        kernel32.GetConsoleMode;
    pub const SetConsoleMode =
        kernel32.SetConsoleMode;
    pub const SetConsoleOutputCP =
        kernel32.SetConsoleOutputCP;
    pub const GetConsoleScreenBufferInfo =
        kernel32.GetConsoleScreenBufferInfo;
    pub extern "kernel32" fn SetConsoleCP(
        wCodePageID: w.UINT,
    ) callconv(.winapi) w.BOOL;
    pub extern "kernel32" fn PeekConsoleInputW(
        hConsoleInput: w.HANDLE,
        lpBuffer: [*]INPUT_RECORD,
        nLength: w.DWORD,
        lpNumberOfEventsRead: ?*w.DWORD,
    ) callconv(.winapi) w.BOOL;
    pub extern "kernel32" fn ReadConsoleW(
        hConsoleInput: w.HANDLE,
        lpBuffer: [*]u16,
        nNumberOfCharsToRead: w.DWORD,
        lpNumberOfCharsRead: ?*w.DWORD,
        lpReserved: ?*anyopaque,
    ) callconv(.winapi) w.BOOL;
};

// UTF-8 console read buffer for handling multi-byte characters
var utf8ConsoleBuffer = [_]u8{0} ** 10;
var utf8ConsoleReadBytes: usize = 0;

// Get standard input handle
pub fn getStdIn() File {
    const handle = std.os.windows.GetStdHandle(
        std.os.windows.STD_INPUT_HANDLE,
    ) catch unreachable;
    return File{ .handle = handle };
}

// Get standard output handle
pub fn getStdOut() File {
    const handle = std.os.windows.GetStdHandle(
        std.os.windows.STD_OUTPUT_HANDLE,
    ) catch unreachable;
    return File{ .handle = handle };
}

// Get standard error handle
pub fn getStdErr() File {
    const handle = std.os.windows.GetStdHandle(
        std.os.windows.STD_ERROR_HANDLE,
    ) catch unreachable;
    return File{ .handle = handle };
}

// Enable raw mode for Windows console
pub fn enableRawMode(in: File, out: File) !WindowsTermios {
    var result: WindowsTermios = .{
        .inMode = 0,
        .outMode = 0,
    };
    var irec: [1]INPUT_RECORD = undefined;
    var n: w.DWORD = 0;
    if (k32.PeekConsoleInputW(
        in.handle,
        &irec,
        1,
        &n,
    ) == 0 or
        k32.GetConsoleMode(
            in.handle,
            &result.inMode,
        ) == 0 or
        k32.GetConsoleMode(
            out.handle,
            &result.outMode,
        ) == 0)
        return error.InitFailed;
    _ = k32.SetConsoleMode(
        in.handle,
        ENABLE_VIRTUAL_TERMINAL_INPUT,
    );
    _ = k32.SetConsoleMode(
        out.handle,
        result.outMode | w.ENABLE_VIRTUAL_TERMINAL_PROCESSING,
    );
    _ = k32.SetConsoleCP(CP_UTF8);
    _ = k32.SetConsoleOutputCP(CP_UTF8);
    return result;
}

// Disable raw mode for Windows console
pub fn disableRawMode(in: File, out: File, orig: WindowsTermios) void {
    _ = k32.SetConsoleMode(in.handle, orig.inMode);
    _ = k32.SetConsoleMode(out.handle, orig.outMode);
}

// Get number of columns in Windows console
pub fn getColumns(in: File, out: File) !usize {
    _ = in;
    var csbi: w.CONSOLE_SCREEN_BUFFER_INFO = undefined;
    _ = k32.GetConsoleScreenBufferInfo(
        out.handle,
        &csbi,
    );
    return @intCast(csbi.dwSize.X);
}

// Windows-specific console read function
// This is needed due to a bug in win32 console:
// https://github.com/microsoft/terminal/issues/4551
pub fn readConsole(self: File, buffer: []u8) !usize {
    var toRead = buffer.len;
    while (toRead > 0) {
        if (utf8ConsoleReadBytes > 0) {
            const existing = @min(toRead, utf8ConsoleReadBytes);
            @memcpy(
                buffer[(buffer.len - toRead)..],
                utf8ConsoleBuffer[0..existing],
            );
            utf8ConsoleReadBytes -= existing;
            if (utf8ConsoleReadBytes > 0)
                std.mem.copyForwards(
                    u8,
                    &utf8ConsoleBuffer,
                    utf8ConsoleBuffer[existing..],
                );
            toRead -= existing;
            continue;
        }
        var charsRead: w.DWORD = 0;
        var wideBuf: [2]w.WCHAR = undefined;
        if (k32.ReadConsoleW(
            self.handle,
            &wideBuf,
            1,
            &charsRead,
            null,
        ) == 0)
            return 0;
        if (charsRead == 0)
            break;
        const wideBufLen: u8 =
            if (wideBuf[0] >= 0xD800 and wideBuf[0] <= 0xDBFF) _: {
                // read surrogate
                if (k32.ReadConsoleW(
                    self.handle,
                    wideBuf[1..],
                    1,
                    &charsRead,
                    null,
                ) == 0)
                    return 0;
                if (charsRead == 0)
                    break;
                break :_ 2;
            } else 1;
        //WideCharToMultiByte(GetConsoleCP(), 0, buf, bufLen, converted,
        //sizeof(converted), NULL, NULL);
        utf8ConsoleReadBytes += try std.unicode.utf16LeToUtf8(
            &utf8ConsoleBuffer,
            wideBuf[0..wideBufLen],
        );
    }
    return buffer.len - toRead;
}
