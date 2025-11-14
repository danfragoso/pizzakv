const std = @import("std");
const storage = @import("storage");

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const allocator = arena.allocator();

const MAX_CHILDREN = 1024;

const RadixNode = struct {
    children: [MAX_CHILDREN]?*RadixNode,
    eof: bool,
    prefix: []const u8,
};

var root: RadixNode = .{
    .children = [_]?*RadixNode{null} ** MAX_CHILDREN,
    .eof = false,
    .prefix = &[_]u8{},
};

fn commonPrefixLen(a: []const u8, b: []const u8) usize {
    var len: usize = 0;
    const min_len = if (a.len < b.len) a.len else b.len;

    while (len < min_len) : (len += 1) {
        if (a[len] != b[len]) {
            break;
        }
    }

    return len;
}
