const std = @import("std");

const index = @import("index.zig");
const hashing = @import("hashing.zig");
const persistence = @import("persistence.zig");

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

pub fn writeVolatile(key: []const u8, value: []const u8) ?*Entry {
    const hash = hashing.hashKey(key);
    const bufIdx = hash % buf.len;

    var current = buf[bufIdx];
    while (current) |entry| {
        if (std.mem.eql(u8, entry.key, key)) {
            allocator.free(entry.value);
            entry.value = allocator.dupe(u8, value) catch return null;
            return entry;
        }

        current = entry.next;
    }

    const newEntry = allocator.create(Entry) catch return null;
    errdefer allocator.destroy(newEntry);
    newEntry.* = Entry{
        .key = allocator.dupe(u8, key) catch return null,
        .value = allocator.dupe(u8, value) catch return null,
        .next = buf[bufIdx],
    };

    buf[bufIdx] = newEntry;
    index.insert(key);
    return newEntry;
}

pub fn write(key: []const u8, value: []const u8) bool {
    mutex.lock();
    defer mutex.unlock();

    const entry = writeVolatile(key, value);
    if (entry == null) {
        return false;
    }

    persistence.persist('W', entry.?.key, entry.?.value);
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

pub fn deleteVolatile(key: []const u8) bool {
    const hash = hashing.hashKey(key);
    const bufIdx = hash % buf.len;

    var current = buf[bufIdx];
    var prev: ?*Entry = null;

    while (current) |entry| {
        if (std.mem.eql(u8, entry.key, key)) {
            if (prev) |p| {
                p.next = entry.next;
            } else {
                buf[bufIdx] = entry.next;
            }

            index.delete(key);
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

pub fn delete(key: []const u8) bool {
    mutex.lock();
    defer mutex.unlock();

    const deleted = deleteVolatile(key);
    if (deleted) {
        persistence.persist('D', key, "");
    }

    return deleted;
}
