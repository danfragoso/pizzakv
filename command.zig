const std = @import("std");
const storage = @import("storage.zig");

const FAILURE_RESPONSE = "error";
const SUCCESS_RESPONSE = "success";

const Command = enum {
    read,
    write,
    delete,
    status,
};

fn parseKeyValue(buf: []const u8) ?[2][]const u8 {
    var kvIterator = std.mem.splitAny(u8, buf, "|");
    const key = kvIterator.first();
    return [2][]const u8{ key, kvIterator.rest() };
}

pub fn parse(msg: []const u8) ?[]const u8 {
    const trimSet = [_]u8{ '\n', ' ', '\r' };
    const cleanMsg = std.mem.trim(u8, msg, &trimSet);
    var messageIterator = std.mem.splitAny(u8, cleanMsg, " ");

    const cmdString = messageIterator.first();
    const command = std.meta.stringToEnum(Command, cmdString) orelse {
        std.debug.print("Failed to parse command: {s}\n", .{cmdString});
        return null;
    };

    switch (command) {
        .read => {
            const key = messageIterator.rest();

            const value = storage.read(key) orelse {
                std.debug.print("Key not found in storage: {s}\n", .{key});
                return FAILURE_RESPONSE;
            };

            return value;
        },
        .write => {
            const kvPair = messageIterator.rest();

            const kv = parseKeyValue(kvPair) orelse {
                std.debug.print("Failed to parse key-value pair", .{});
                return FAILURE_RESPONSE;
            };

            if (storage.write(kv[0], kv[1])) {
                return SUCCESS_RESPONSE;
            }

            std.debug.print("Failed to write to storage", .{});
            return FAILURE_RESPONSE;
        },
        .delete => {
            const key = messageIterator.rest();
            if (!storage.delete(key)) {
                std.debug.print("Failed to delete key from storage: {s}\n", .{key});
                return FAILURE_RESPONSE;
            }

            return SUCCESS_RESPONSE;
        },
        .status => {
            return "well going our operation";
        },
    }

    return null;
}
