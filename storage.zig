const std = @import("std");

const index = @import("index.zig");
const hashing = @import("hashing.zig");
const persistence = @import("persistence.zig");

const INITIAL_BUCKETS = 1_048_576;
const Entry = struct {
    key: []const u8,
    value: []const u8,
    hash: u32,
    next: ?*Entry,
};

var buckets: []?*Entry = undefined;
var buckets_initialized: bool = false;

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const allocator = arena.allocator();

var rwlock: std.Thread.RwLock = .{};
var init_mutex: std.Thread.Mutex = .{};

pub fn init() void {
    if (buckets_initialized) return;

    init_mutex.lock();
    defer init_mutex.unlock();

    if (!buckets_initialized) {
        buckets = allocator.alloc(?*Entry, INITIAL_BUCKETS) catch unreachable;
        @memset(buckets, null);
        buckets_initialized = true;
    }
}

pub fn restore(key: []const u8, value: []const u8) bool {
    rwlock.lock();
    defer rwlock.unlock();

    const entry = writeVolatile(key, value);
    if (entry != null) {
        index.insert(entry.?.key);
        return true;
    }
    return false;
}

pub fn restoreDelete(key: []const u8) bool {
    rwlock.lock();
    defer rwlock.unlock();

    const deleted = deleteVolatile(key);
    if (deleted) {
        index.delete(key);
        return true;
    }
    return false;
}

pub fn writeVolatile(key: []const u8, value: []const u8) ?*Entry {
    const hash = hashing.hashKey(key);
    const bucketIdx = hash % buckets.len;

    var current = buckets[bucketIdx];
    while (current) |entry| {
        if (entry.hash == hash and std.mem.eql(u8, entry.key, key)) {
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
        .hash = hash, // Cache hash value
        .next = buckets[bucketIdx],
    };

    buckets[bucketIdx] = newEntry;
    return newEntry;
}

pub fn write(key: []const u8, value: []const u8) bool {
    rwlock.lock();
    defer rwlock.unlock();

    const entry = writeVolatile(key, value);
    if (entry == null) {
        return false;
    }

    index.insert(entry.?.key);
    persistence.persist('W', entry.?.key, entry.?.value);
    return true;
}

pub fn read(key: []const u8) ?[]const u8 {
    rwlock.lockShared();
    defer rwlock.unlockShared();

    if (!buckets_initialized) return null;

    const hash = hashing.hashKey(key);
    var current = buckets[hash % buckets.len];
    while (current) |entry| {
        if (entry.hash == hash and std.mem.eql(u8, entry.key, key)) {
            return entry.value;
        }
        current = entry.next;
    }

    return null;
}

pub fn deleteVolatile(key: []const u8) bool {
    if (!buckets_initialized) return false;
    const hash = hashing.hashKey(key);
    const bucketIdx = hash % buckets.len;

    var current = buckets[bucketIdx];
    var prev: ?*Entry = null;

    while (current) |entry| {
        if (entry.hash == hash and std.mem.eql(u8, entry.key, key)) {
            if (prev) |p| {
                p.next = entry.next;
            } else {
                buckets[bucketIdx] = entry.next;
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

pub fn delete(key: []const u8) bool {
    rwlock.lock();
    defer rwlock.unlock();

    const deleted = deleteVolatile(key);
    if (deleted) {
        index.delete(key);
        persistence.persist('D', key, "");
    }

    return deleted;
}
