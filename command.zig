const std = @import("std");
const storage = @import("storage.zig");

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
    const trimSet = [_]u8{ '\n', ' ' };
    const cleanMsg = std.mem.trim(u8, msg, &trimSet);
    var messageIterator = std.mem.splitAny(u8, cleanMsg, " ");

    const cmdString = messageIterator.first();
    const command = std.meta.stringToEnum(Command, cmdString) orelse {
        std.debug.print("Failed to parse command\n", .{});
        return null;
    };

    switch (command) {
        .read => {
            const key = messageIterator.rest();

            const value = storage.read(key) orelse {
                std.debug.print("Key not found in storage: {s}\n", .{key});
                return "false";
            };

            return value;
        },
        .write => {
            const kvPair = messageIterator.rest();

            const kv = parseKeyValue(kvPair) orelse {
                std.debug.print("Failed to parse key-value pair\n", .{});
                return "false";
            };

            if (storage.write(kv[0], kv[1])) {
                return "true";
            }

            std.debug.print("Failed to write to storage\n", .{});
            return "false";
        },
        .delete => {
            std.debug.print("Delete command received\n", .{});
            return "false";
        },
        .status => {
            std.debug.print("Status command received\n", .{});
            return "well going our operation";
        },
    }

    return null;
}
