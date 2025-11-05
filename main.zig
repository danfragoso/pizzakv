const std = @import("std");

const net = std.net;
const posix = std.posix;
const fmt = std.fmt;

const socket = @import("socket.zig");
const command = @import("command.zig");
const storage = @import("storage.zig");

pub fn main() !void {
    const listener = try socket.init(8080);
    defer posix.close(listener);

    std.debug.print("2025 pizzakv!\n<danilo.fragoso@dev>\n---------\n", .{});
    std.debug.print("Commands:\n\nread key\nwrite key|value\ndelete key\nstatus\n", .{});
    std.debug.print("---------\n", .{});

    while (true) {
        var client_address: net.Address = undefined;
        var client_address_len: posix.socklen_t = @sizeOf(net.Address);

        const conn = posix.accept(listener, &client_address.any, &client_address_len, 0) catch |err| {
            std.debug.print("error accept: {any}\n", .{err});
            continue;
        };

        const thread = try std.Thread.spawn(.{}, handleConnection, .{conn});
        thread.detach();
    }
}

pub fn handleConnection(conn: posix.socket_t) !void {
    defer posix.close(conn);

    var requestBuffer: [1024 * 1024]u8 = undefined;
    var responseBuffer: [1024 * 1024]u8 = undefined;
    while (true) {
        const n = try socket.readUntilNewLine(conn, &requestBuffer);
        if (n == 0) {
            break;
        }

        const cmdResponse = command.parse(requestBuffer[0..n]) orelse {
            std.debug.print("Failed to parse message\n", .{});
            socket.write(conn, "false\n") catch |err| {
                std.debug.print("error writing: {any}\n", .{err});
            };
            continue;
        };

        @memcpy(responseBuffer[0..cmdResponse.len], cmdResponse);
        responseBuffer[cmdResponse.len] = '\n';
        socket.write(conn, responseBuffer[0 .. cmdResponse.len + 1]) catch |err| {
            std.debug.print("error writing: {any}\n", .{err});
        };
    }
}
