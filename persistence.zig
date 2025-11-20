const std = @import("std");
const storage = @import("storage.zig");

const MAX_PERSISTENCE_SIZE = 10_000_000 * 100;
const BUFFER_SIZE = 1024 * 1024 * 8;
const FLUSH_THRESHOLD = (BUFFER_SIZE * 3) / 4;

var storage_file: ?std.fs.File = null;
const c_allocator = std.heap.c_allocator;

var mutex: std.Thread.Mutex = .{};

var write_buffer: [BUFFER_SIZE]u8 = undefined;
var buffer_position: usize = 0;

const OPCode = enum {
    W,
    D,
};

pub fn init() !void {
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
            .W => _ = storage.restore(key, value),
            .D => _ = storage.restoreDelete(key),
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
    defer c_allocator.free(record);

    mutex.lock();
    defer mutex.unlock();

    if (buffer_position + record.len > FLUSH_THRESHOLD) {
        flushBuffer() catch |err| {
            std.debug.print("Failed to flush buffer: {any}\n", .{err});
            return;
        };
    }

    if (record.len > BUFFER_SIZE) {
        _ = storage_file.?.write(record) catch |err| {
            std.debug.print("Failed to write large record to storage file: {any}\n", .{err});
            return;
        };
        return;
    }

    if (buffer_position + record.len > BUFFER_SIZE) {
        flushBuffer() catch |err| {
            std.debug.print("Failed to flush buffer: {any}\n", .{err});
            return;
        };
    }

    @memcpy(write_buffer[buffer_position .. buffer_position + record.len], record);
    buffer_position += record.len;
}

pub fn flush() !void {
    mutex.lock();
    defer mutex.unlock();
    try flushBuffer();
}

fn flushBuffer() !void {
    if (buffer_position == 0) {
        return;
    }

    _ = try storage_file.?.write(write_buffer[0..buffer_position]);
    buffer_position = 0;
}
