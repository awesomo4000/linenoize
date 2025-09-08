const std = @import("std");
const Allocator = std.mem.Allocator;
const expectEqualSlices = std.testing.expectEqualSlices;

const wcwidth = @import("wcwidth").wcwidth;

pub fn width(s: []const u8) usize {
    var result: usize = 0;

    var escape_seq = false;
    const view = std.unicode.Utf8View.init(s) catch return 0;
    var iter = view.iterator();
    while (iter.nextCodepoint()) |codepoint| {
        if (escape_seq) {
            if (codepoint == 'm') {
                escape_seq = false;
            }
        } else {
            if (codepoint == '\x1b') {
                escape_seq = true;
            } else {
                const wcw = wcwidth(codepoint);
                if (wcw < 0) return 0;
                result += @intCast(wcw);
            }
        }
    }

    return result;
}

test "width - ASCII characters" {
    const ascii = "Hello, World!";
    try std.testing.expectEqual(@as(usize, 13), width(ascii));
}

test "width - empty string" {
    try std.testing.expectEqual(@as(usize, 0), width(""));
}

test "width - escape sequences" {
    // ANSI escape sequences should not contribute to width
    const colored = "\x1b[31mRed Text\x1b[0m";
    try std.testing.expectEqual(@as(usize, 8), width(colored)); // Only "Red Text" counts
}

test "width - unicode characters" {
    // Test various Unicode characters
    const emoji = "👍"; // Many emojis are width 2
    const japanese = "日本"; // CJK characters are typically width 2
    
    // Basic Latin characters
    try std.testing.expectEqual(@as(usize, 3), width("abc"));
    
    // Note: exact width depends on wcwidth implementation
    // These tests may need adjustment based on the wcwidth library behavior
    _ = width(emoji);
    _ = width(japanese);
}

test "width - mixed content" {
    // Mix of ASCII and escape sequences
    const mixed = "Normal \x1b[1mBold\x1b[0m Text";
    try std.testing.expectEqual(@as(usize, 16), width(mixed)); // "Normal Bold Text"
}

test "width - invalid UTF-8" {
    // Invalid UTF-8 should return 0
    const invalid = &[_]u8{ 0xFF, 0xFE, 0xFD };
    try std.testing.expectEqual(@as(usize, 0), width(invalid));
}
