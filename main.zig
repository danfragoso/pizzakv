const std = @import("std");
const net = std.net;
const posix = std.posix;

pub fn main() !void {
    const address = try std.net.Address.parseIp("127.0.0.1", 6000);

    const tpe: u32 = posix.SOCK.STREAM;
    const protocol = posix.IPPROTO.TCP;
    const listener = try posix.socket(address.any.family, tpe, protocol);
    defer posix.close(listener);

    try posix.setsockopt(listener, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
    try posix.bind(listener, &address.any, address.getOsSockLen());
    try posix.listen(listener, 128);

    while (true) {
        var client_address: net.Address = undefined;
        var client_address_len: posix.socklen_t = @sizeOf(net.Address);

        const socket = posix.accept(listener, &client_address.any, &client_address_len, 0) catch |err| {
            std.debug.print("error accept: {any}\n", .{err});
            continue;
        };
        defer posix.close(socket);

        std.debug.print("Connection received\n", .{});
        var buf: [128]u8 = undefined;
        const n = try read(socket, &buf);
        std.debug.print("Read {d} bytes: {s}\n", .{ n, buf[0..n] });

        try parseMessage(buf[0..n]);

        write(socket, "congratulations") catch |err| {
            // This can easily happen, say if the client disconnects.
            std.debug.print("error writing: {any}\n", .{err});
        };
    }
}

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

    std.debug.print("Parsed key: {s}, value: {s}\n", .{ key, value });
    return [2][]const u8{ key, value };
}

fn parseMessage(buf: []const u8) !void {
    var messageIterator = std.mem.splitAny(u8, buf, " ");

    const command = std.meta.stringToEnum(Command, messageIterator.first()) orelse {
        std.debug.print("Failed to parse command\n", .{});
        return;
    };

    switch (command) {
        .read => {
            std.debug.print("Read command received\n", .{});
        },
        .write => {
            std.debug.print("Write command received\n", .{});

            const kvPair = messageIterator.next() orelse {
                std.debug.print("No key-value pair provided for read command\n", .{});
                return;
            };

            const kv = parseKeyValue(kvPair) orelse {
                std.debug.print("Failed to parse key-value pair\n", .{});
                return;
            };

            std.debug.print("Key: {s}, Value: {s}\n", .{ kv[0], kv[1] });
        },
        .delete => std.debug.print("Delete command received\n", .{}),
        .status => std.debug.print("Status command received\n", .{}),
    }
}

fn read(socket: posix.socket_t, buf: []u8) !usize {
    var pos: usize = 0;
    while (pos < buf.len) {
        const n = try posix.read(socket, buf[pos..]);
        if (n == 0) {
            return pos; // connection closed
        }
        pos += n;
    }
    return pos;
}

fn write(socket: posix.socket_t, msg: []const u8) !void {
    var pos: usize = 0;
    while (pos < msg.len) {
        const written = try posix.write(socket, msg[pos..]);
        if (written == 0) {
            return error.Closed;
        }
        pos += written;
    }
}
