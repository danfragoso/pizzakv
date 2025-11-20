const std = @import("std");

const net = std.net;
const posix = std.posix;
const fmt = std.fmt;

const socket = @import("socket.zig");
const command = @import("command.zig");
const storage = @import("storage.zig");
const persistence = @import("persistence.zig");

const PORT = 8085;
var should_exit = std.atomic.Value(bool).init(false);
fn handleSignal(sig: c_int) callconv(.c) void {
    _ = sig;
    should_exit.store(true, .seq_cst);
}

pub fn main() !void {
    const empty_mask = std.mem.zeroes(posix.sigset_t);
    const act = posix.Sigaction{
        .handler = .{ .handler = handleSignal },
        .mask = empty_mask,
        .flags = 0,
    };

    _ = posix.sigaction(posix.SIG.TERM, &act, null);
    _ = posix.sigaction(posix.SIG.INT, &act, null);

    const listener = try socket.init(PORT);
    defer posix.close(listener);

    std.debug.print("2025 pizzakv! TCP Listening on port {any}\n<danilo@fragoso.dev>\n---------\n", .{PORT});
    std.debug.print("Commands:\n\nread key\nwrite key|value\ndelete key\nkeys\nreads prefix\nstatus\n", .{});
    std.debug.print("---------\n", .{});

    storage.init();
    try persistence.init();

    while (!should_exit.load(.seq_cst)) {
        var poll_fds = [_]posix.pollfd{
            .{
                .fd = listener,
                .events = posix.POLL.IN,
                .revents = 0,
            },
        };

        const ready = posix.poll(&poll_fds, 1000) catch |err| {
            if (should_exit.load(.seq_cst)) break;
            std.debug.print("poll error: {any}\n", .{err});
            continue;
        };

        if (ready == 0) {
            continue;
        }

        if (should_exit.load(.seq_cst)) break;

        var client_address: net.Address = undefined;
        var client_address_len: posix.socklen_t = @sizeOf(net.Address);

        const conn = posix.accept(listener, &client_address.any, &client_address_len, 0) catch |err| {
            if (should_exit.load(.seq_cst)) break;
            std.debug.print("error accept: {any}\n", .{err});
            continue;
        };

        if (should_exit.load(.seq_cst)) {
            posix.close(conn);
            break;
        }

        posix.setsockopt(conn, posix.IPPROTO.TCP, posix.TCP.NODELAY, &std.mem.toBytes(@as(c_int, 1))) catch {};

        const thread = try std.Thread.spawn(.{}, handleConnection, .{conn});
        thread.detach();
    }

    std.debug.print("\nShutdown signal received...\n", .{});
    persistence.flush() catch |err| {
        std.debug.print("Failed to flush persistence: {any}\n", .{err});
    };
}

pub fn handleConnection(conn: posix.socket_t) !void {
    defer posix.close(conn);

    var requestBuffer: [1024 * 1024]u8 = undefined;

    while (true) {
        const n = socket.readUntilCR(conn, &requestBuffer) catch |err| {
            if (err == error.ConnectionClosed) break;
            return err;
        };
        if (n == 0) {
            break;
        }

        const cmdResponse = command.parse(requestBuffer[0..n]) orelse {
            socket.write(conn, "error\r") catch |err| {
                std.debug.print("error writing: {any}", .{err});
            };
            continue;
        };

        const terminator = "\r";
        const iovecs = [_]posix.iovec_const{
            .{ .base = cmdResponse.ptr, .len = cmdResponse.len },
            .{ .base = terminator.ptr, .len = 1 },
        };
        socket.writev(conn, &iovecs) catch |err| {
            std.debug.print("error writing: {any}", .{err});
        };
    }
}
