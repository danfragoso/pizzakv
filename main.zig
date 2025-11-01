const std = @import("std");
const net = std.net;
const posix = std.posix;

const socket = @import("socket.zig");
const command = @import("command.zig");
const storage = @import("storage.zig");

pub fn main() !void {
    const listener = try socket.init(8080);
    defer posix.close(listener);
    std.debug.print("pizzakv!\n", .{});

    while (true) {
        var client_address: net.Address = undefined;
        var client_address_len: posix.socklen_t = @sizeOf(net.Address);

        const conn = posix.accept(listener, &client_address.any, &client_address_len, 0) catch |err| {
            std.debug.print("error accept: {any}\n", .{err});
            continue;
        };
        defer posix.close(conn);

        std.debug.print("Connection received\n", .{});
        var buf: [128]u8 = undefined;
        const n = try socket.read(conn, &buf);

        const response = command.parse(buf[0..n]) orelse {
            std.debug.print("Failed to parse message\n", .{});
            continue;
        };

        socket.write(conn, response) catch |err| {
            // This can easily happen, say if the client disconnects.
            std.debug.print("error writing: {any}\n", .{err});
        };
    }
}
