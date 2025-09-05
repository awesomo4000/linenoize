const std = @import("std");
const Linenoise = @import("linenoise").Linenoise;

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    
    var ln = Linenoise.init(allocator);
    defer ln.deinit();
    
    std.debug.print("=== Simple REPL Example ===\n", .{});
    std.debug.print("This example shows basic line editing with hints.\n", .{});
    std.debug.print("Type 'quit' to exit\n", .{});
    std.debug.print("Try typing 'hello' or 'test' to see hints!\n\n", .{});
    
    // Set up a simple hints callback
    // Hints appear as gray text after your cursor
    ln.hints_callback = struct {
        fn hints(alloc: std.mem.Allocator, buf: []const u8) !?[]const u8 {
            _ = alloc;
            if (std.mem.eql(u8, "hello", buf)) {
                return " world (hint)";
            } else if (std.mem.eql(u8, "test", buf)) {
                return " command (hint)";
            } else if (std.mem.eql(u8, "help", buf)) {
                return " - shows available commands (hint)";
            }
            return null;
        }
    }.hints;
    
    while (try ln.linenoise("simple> ")) |input| {
        defer allocator.free(input);
        
        if (std.mem.eql(u8, input, "quit")) {
            std.debug.print("Goodbye!\n", .{});
            break;
        }
        
        if (std.mem.eql(u8, input, "help")) {
            std.debug.print("Available commands:\n", .{});
            std.debug.print("  help  - Show this help\n", .{});
            std.debug.print("  hello - Greet the world\n", .{});
            std.debug.print("  test  - Run a test command\n", .{});
            std.debug.print("  quit  - Exit the REPL\n", .{});
            std.debug.print("\nFeatures:\n", .{});
            std.debug.print("  - Use arrow keys to navigate\n", .{});
            std.debug.print("  - Use up/down for history\n", .{});
            std.debug.print("  - Hints appear in gray as you type\n", .{});
        } else {
            std.debug.print("You typed: '{s}'\n", .{input});
        }
        
        try ln.history.add(input);
    }
}