const std = @import("std");
const storage = @import("storage.zig");

const MAX_PERSISTENCE_SIZE = 10_000_000 * 100;
var storage_file: ?std.fs.File = null;
var thread_pool: std.Thread.Pool = undefined;
var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const allocator = arena.allocator();
const c_allocator = std.heap.c_allocator;

var mutex: std.Thread.Mutex = .{};

const OPCode = enum {
    W,
    D,
};

pub fn init() !void {
    try std.Thread.Pool.init(&thread_pool, .{ .allocator = allocator, .n_jobs = 4 });

    const cwd = std.fs.cwd();
    storage_file = cwd.openFile(".db", .{ .mode = .read_write }) catch |err| {
        if (err == std.fs.File.OpenError.FileNotFound) {
            std.debug.print("No persisted data found, starting fresh...\n", .{});

            storage_file = cwd.createFile(".db", .{ .read = true }) catch |ierr| {
                std.debug.print("Failed to create storage file: {any}\n", .{ierr});
                return;
            };

            std.debug.print("Created new storage file .db\n", .{});
        }
        return;
    };

    const storage_data = storage_file.?.readToEndAlloc(c_allocator, MAX_PERSISTENCE_SIZE) catch |err| {
        std.debug.print("Failed to read storage file: {any}\n", .{err});
        return;
    };
    defer c_allocator.free(storage_data);
    var records = std.mem.splitScalar(u8, storage_data, '\r');
    var record_count: usize = 0;
    while (records.next()) |record| {
        if (record.len == 0) {
            continue;
        }

        record_count += 1;
        std.debug.print("Restoring record N:{d}\r", .{record_count});

        var recordIterator = std.mem.splitScalar(u8, record, '|');

        const opcode = recordIterator.first();
        const key = recordIterator.next() orelse continue;
        const value = recordIterator.next() orelse continue;

        const opcodeEnum = std.meta.stringToEnum(OPCode, opcode) orelse continue;

        switch (opcodeEnum) {
            .W => _ = storage.writeVolatile(key, value),
            .D => _ = storage.deleteVolatile(key),
        }
    }
    std.debug.print("Restored {d} records from persistence", .{record_count});

    storage_file.?.close();
    storage_file = cwd.openFile(".db", .{ .mode = .write_only }) catch |err| {
        std.debug.print("Failed to reopen storage file in append mode: {any}\n", .{err});
        return;
    };
    try storage_file.?.seekFromEnd(0);

    return;
}

pub fn persist(opcode: u8, key: []const u8, value: []const u8) void {
    const record = std.fmt.allocPrint(c_allocator, "{c}|{s}|{s}\r", .{ opcode, key, value }) catch {
        std.debug.print("Failed to format record for persistence\n", .{});
        return;
    };

    thread_pool.spawn(persistRecord, .{record}) catch |err| {
        std.debug.print("Failed to spawn persistence job: {any}\n", .{err});
        return;
    };
}

fn persistRecord(record: []const u8) void {
    defer c_allocator.free(record);

    mutex.lock();
    defer mutex.unlock();

    _ = storage_file.?.write(record) catch |err| {
        std.debug.print("Failed to write record to storage file: {any}\n", .{err});
        return;
    };
}
