const std = @import("std");
const hashing = @import("hashing.zig");

const MAX_RECORDS = 10_000_000;
const Entry = struct {
    key: []const u8,
    value: []const u8,
    next: ?*Entry,
};
var buf: [MAX_RECORDS]?*Entry = undefined;

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const allocator = arena.allocator();

const EMPTY = "";
var mutex: std.Thread.Mutex = .{};

pub fn write(key: []const u8, value: []const u8) bool {
    mutex.lock();
    defer mutex.unlock();

    const hash = hashing.hashKey(key);
    const index = hash % buf.len;

    var current = buf[index];
    while (current) |entry| {
        if (std.mem.eql(u8, entry.key, key)) {
            allocator.free(entry.value);
            entry.value = allocator.dupe(u8, value) catch return false;
            return true;
        }

        current = entry.next;
    }

    const newEntry = allocator.create(Entry) catch return false;
    errdefer allocator.destroy(newEntry);
    newEntry.* = Entry{
        .key = allocator.dupe(u8, key) catch return false,
        .value = allocator.dupe(u8, value) catch return false,
        .next = buf[index],
    };

    buf[index] = newEntry;
    return true;
}

pub fn read(key: []const u8) ?[]const u8 {
    mutex.lock();
    defer mutex.unlock();

    const hash = hashing.hashKey(key);
    var current = buf[hash % buf.len];
    while (current) |entry| {
        if (std.mem.eql(u8, entry.key, key)) {
            return entry.value;
        }
        current = entry.next;
    }

    return null;
}

pub fn delete(key: []const u8) bool {
    mutex.lock();
    defer mutex.unlock();

    const hash = hashing.hashKey(key);
    const index = hash % buf.len;

    var current = buf[index];
    var prev: ?*Entry = null;

    while (current) |entry| {
        if (std.mem.eql(u8, entry.key, key)) {
            if (prev) |p| {
                p.next = entry.next;
            } else {
                buf[index] = entry.next;
            }

            allocator.free(entry.key);
            allocator.free(entry.value);
            allocator.destroy(entry);
            return true;
        }

        prev = entry;
        current = entry.next;
    }

    return false;
}
