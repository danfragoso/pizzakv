const std = @import("std");
const storage = @import("storage.zig");

var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const allocator = arena.allocator();

const MAX_CHILDREN = 256;

const TrieNode = struct {
    children: [MAX_CHILDREN]?*TrieNode,
    eof: bool,
    char: u8,
};

var root: TrieNode = .{
    .children = [_]?*TrieNode{null} ** MAX_CHILDREN,
    .eof = false,
    .char = 0,
};

fn getChild(node: *TrieNode, c: u8) ?*TrieNode {
    return node.children[c];
}

fn addChild(node: *TrieNode, c: u8) *TrieNode {
    const newNode = allocator.create(TrieNode) catch unreachable;
    newNode.* = .{
        .children = [_]?*TrieNode{null} ** MAX_CHILDREN,
        .eof = false,
        .char = c,
    };
    node.children[c] = newNode;
    return newNode;
}

pub fn insert(key: []const u8) void {
    var current = &root;
    for (key) |c| {
        var child = getChild(current, c);
        if (child == null) {
            child = addChild(current, c);
        }
        current = child.?;
    }
    current.eof = true;
}

pub fn delete(key: []const u8) void {
    var current = &root;
    for (key) |c| {
        const child = getChild(current, c);
        if (child == null) {
            return;
        }
        current = child.?;
    }
    current.eof = false;
}

pub fn searchByPrefix(prefix: []const u8) ?*TrieNode {
    var current = &root;
    for (prefix) |c| {
        const child = getChild(current, c);
        if (child == null) {
            return null;
        }
        current = child.?;
    }

    return current;
}

fn countKeys(node: *TrieNode) usize {
    var count: usize = 0;
    if (node.eof) {
        count += 1;
    }

    for (0..MAX_CHILDREN) |i| {
        const child = node.children[i];
        if (child != null) {
            count += countKeys(child.?);
        }
    }
    return count;
}

fn collectKeys(node: *TrieNode, prefix: []const u8, keys: [][]const u8, index: *usize) void {
    if (node.eof) {
        const key = allocator.alloc(u8, prefix.len) catch unreachable;
        @memcpy(key, prefix);
        keys[index.*] = key;
        index.* += 1;
    }

    for (0..MAX_CHILDREN) |i| {
        const child = node.children[i];
        if (child != null) {
            const childChar = child.?.char;
            var newPrefix = allocator.alloc(u8, prefix.len + 1) catch unreachable;
            @memcpy(newPrefix[0..prefix.len], prefix);
            newPrefix[prefix.len] = childChar;
            collectKeys(child.?, newPrefix, keys, index);
            allocator.free(newPrefix);
        }
    }
}

pub fn getKeysFromNode(node: *TrieNode, prefix: []const u8) [][]const u8 {
    const keyCount = countKeys(node);
    if (keyCount == 0) {
        return &[_][]const u8{};
    }

    const keys = allocator.alloc([]const u8, keyCount) catch unreachable;
    var index: usize = 0;
    collectKeys(node, prefix, keys, &index);
    return keys;
}

pub fn getKeysByPrefix(prefix: []const u8) []const u8 {
    const node = searchByPrefix(prefix) orelse return "";
    const keys = getKeysFromNode(node, prefix);
    if (keys.len == 0) return "";
    return std.mem.join(allocator, "\r", keys) catch unreachable;
}

pub fn getValuesByPrefix(prefix: []const u8) []const u8 {
    const node = searchByPrefix(prefix) orelse return "";
    const keys = getKeysFromNode(node, prefix);
    if (keys.len == 0) return "";

    const values = allocator.alloc([]const u8, keys.len) catch unreachable;
    for (keys, 0..) |key, i| {
        const value = storage.read(key) orelse "";
        values[i] = value;
    }

    return std.mem.join(allocator, "\r", values) catch unreachable;
}

pub fn getAllKeys() []const u8 {
    const keys = getKeysFromNode(&root, &[_]u8{});
    if (keys.len == 0) return "";
    return std.mem.join(allocator, "\r", keys) catch unreachable;
}
