const std = @import("std");
const net = std.net;
const posix = std.posix;

pub fn init(port: u16) !posix.socket_t {
    const address = try std.net.Address.parseIp("0.0.0.0", port);

    const tpe: u32 = posix.SOCK.STREAM;
    const protocol = posix.IPPROTO.TCP;

    const listener = try posix.socket(address.any.family, tpe, protocol);

    try posix.setsockopt(listener, posix.SOL.SOCKET, posix.SO.REUSEADDR, &std.mem.toBytes(@as(c_int, 1)));
    try posix.bind(listener, &address.any, address.getOsSockLen());
    try posix.listen(listener, 128);

    return listener;
}

pub fn readUntilCR(conn: posix.socket_t, buf: []u8) !usize {
    var pos: usize = 0;
    while (pos < buf.len) {
        const n = try posix.read(conn, buf[pos .. pos + 1]);
        if (n == 0) {
            return pos;
        }
        if (buf[pos] == '\r') {
            return pos + 1;
        }
        pos += n;
    }
    return pos;
}

pub fn readUntilNewLine(conn: posix.socket_t, buf: []u8) !usize {
    var pos: usize = 0;
    while (pos < buf.len) {
        const n = try posix.read(conn, buf[pos .. pos + 1]);
        if (n == 0) {
            return pos;
        }
        if (buf[pos] == '\n') {
            return pos + 1;
        }
        pos += n;
    }
    return pos;
}

pub fn read(conn: posix.socket_t, buf: []u8) !usize {
    var pos: usize = 0;
    while (pos < buf.len) {
        const n = try posix.read(conn, buf[pos..]);
        if (n == 0) {
            return pos;
        }
        pos += n;
    }
    return pos;
}

pub fn write(conn: posix.socket_t, msg: []const u8) !void {
    const written = try posix.write(conn, msg);
    if (written != msg.len) {
        return error.PartialWrite;
    }
}
