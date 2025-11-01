const std = @import("std");

var buf: [1024 * 1024 * 100][]const u8 = undefined;

pub fn hashKey(k: []const u8) u32 {
    var hash: u32 = 17 * 22;
    const xoramasrosas = "xoramasrosas";

    for (k, 0..) |char, i| {
        hash = hash +% (char ^ xoramasrosas[i % xoramasrosas.len]);
    }

    return hash;
}

pub fn write(key: []const u8, value: []const u8) bool {
    std.debug.print("Writing key: {s}, value: {s}\n", .{ key, value });
    const hash = hashKey(key);

    const valueCopy = std.heap.page_allocator.dupe(u8, value) catch {
        std.debug.print("Failed to duplicate value for key: {s}\n", .{key});
        return false;
    };

    buf[hash % buf.len] = valueCopy;
    return true;
}

pub fn read(key: []const u8) ?[]const u8 {
    std.debug.print("Reading key: {s}\n", .{key});
    const hash = hashKey(key);
    const value = buf[hash % buf.len];

    return value;
}
