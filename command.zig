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
    const value = kvIterator.next() orelse {
        std.debug.print("No value found for key: {s}\n", .{key});
        return null;
    };

    return [2][]const u8{ key, value };
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
            const key = messageIterator.next() orelse {
                std.debug.print("No key provided for read command\n", .{});
                return null;
            };

            const value = storage.read(key) orelse {
                std.debug.print("Key not found in storage: {s}\n", .{key});
                return "false";
            };

            return value;
        },
        .write => {
            const kvPair = messageIterator.next() orelse {
                std.debug.print("No key-value pair provided for read command\n", .{});
                return null;
            };

            const kv = parseKeyValue(kvPair) orelse {
                std.debug.print("Failed to parse key-value pair\n", .{});
                return null;
            };

            if (storage.write(kv[0], kv[1])) {
                return "true";
            }

            std.debug.print("Failed to write to storage\n", .{});
            return "false";
        },
        .delete => {
            std.debug.print("Delete command received\n", .{});
            return null;
        },
        .status => {
            std.debug.print("Status command received\n", .{});
            return "well going our operation";
        },
    }

    return null;
}
