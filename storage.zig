const std = @import("std");

const backend_size = 1024 * 1024 * 100;
var buf: [backend_size][]const u8 = undefined;
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const allocator = arena.allocator();

pub fn hashKey(k: []const u8) u32 {
    return djb2(k);
    //return xoramasrosas(k);
}

pub fn djb2(key: []const u8) u32 {
    var hash: u32 = 5381;

    for (key) |c| {
        hash = ((hash << 5) +% hash) +% c;
    }

    return hash;
}

pub fn xoramasrosas(k: []const u8) u32 {
    var hash: u32 = 17 * 22;
    const x = "xoramasrosas";

    for (k, 0..) |char, i| {
        hash = hash +% (char ^ x[i % 12]) << 12;
    }

    return hash;
}

pub fn write(key: []const u8, value: []const u8) bool {
    const valueCopy = allocator.dupe(u8, value) catch {
        std.debug.print("Failed to duplicate value for key: {s}\n", .{key});
        return false;
    };

    const hash = hashKey(key);
    buf[hash % buf.len] = valueCopy;
    return true;
}

pub fn read(key: []const u8) ?[]const u8 {
    const hash = hashKey(key);
    return buf[hash % buf.len];
}
