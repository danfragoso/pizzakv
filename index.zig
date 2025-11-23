const std = @import("std");
const storage = @import("storage.zig");

var tree_arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
const tree_allocator = tree_arena.allocator();
const temp_allocator = std.heap.c_allocator;

const RadixNode = struct {
    edge: []const u8,
    children: std.StringHashMap(*RadixNode),
    is_terminal: bool,

    fn init(edge: []const u8) *RadixNode {
        const node = tree_allocator.create(RadixNode) catch unreachable;
        node.* = .{
            .edge = tree_allocator.dupe(u8, edge) catch unreachable,
            .children = std.StringHashMap(*RadixNode).init(tree_allocator),
            .is_terminal = false,
        };
        return node;
    }

    fn deinit(self: *RadixNode) void {
        var it = self.children.iterator();
        while (it.next()) |entry| {
            entry.value_ptr.*.deinit();
        }
        self.children.deinit();
        tree_allocator.free(self.edge);
        tree_allocator.destroy(self);
    }
};

var root: *RadixNode = undefined;
var root_initialized = false;

fn ensureRoot() void {
    if (!root_initialized) {
        root = RadixNode.init("");
        root_initialized = true;
    }
}

fn commonPrefixLen(a: []const u8, b: []const u8) usize {
    var i: usize = 0;
    while (i < a.len and i < b.len and a[i] == b[i]) {
        i += 1;
    }
    return i;
}

pub fn insert(key: []const u8) void {
    ensureRoot();
    if (key.len == 0) return;

    var node = root;
    var remaining = key;

    while (remaining.len > 0) {
        var found = false;

        var it = node.children.iterator();
        while (it.next()) |entry| {
            const child = entry.value_ptr.*;
            const prefix_len = commonPrefixLen(child.edge, remaining);

            if (prefix_len > 0) {
                found = true;

                if (prefix_len == child.edge.len) {
                    if (prefix_len == remaining.len) {
                        child.is_terminal = true;
                        return;
                    }
                    remaining = remaining[prefix_len..];
                    node = child;
                    break;
                } else {
                    const old_edge = child.edge;
                    const common = old_edge[0..prefix_len];
                    const child_suffix = old_edge[prefix_len..];
                    const key_suffix = remaining[prefix_len..];

                    const intermediate = RadixNode.init(common);

                    tree_allocator.free(child.edge);
                    child.edge = tree_allocator.dupe(u8, child_suffix) catch unreachable;

                    intermediate.children.put(child_suffix, child) catch unreachable;

                    _ = node.children.remove(old_edge);
                    node.children.put(common, intermediate) catch unreachable;

                    if (key_suffix.len == 0) {
                        intermediate.is_terminal = true;
                        return;
                    } else {
                        const new_child = RadixNode.init(key_suffix);
                        new_child.is_terminal = true;
                        intermediate.children.put(key_suffix, new_child) catch unreachable;
                        return;
                    }
                }
            }
        }

        if (!found) {
            const new_child = RadixNode.init(remaining);
            new_child.is_terminal = true;
            node.children.put(remaining, new_child) catch unreachable;
            return;
        }
    }

    node.is_terminal = true;
}

pub fn delete(key: []const u8) void {
    ensureRoot();
    if (key.len == 0) return;

    const node = findNode(root, key);
    if (node) |n| {
        n.is_terminal = false;
    }
}

fn findNode(node: *RadixNode, key: []const u8) ?*RadixNode {
    if (key.len == 0) return node;

    var current = node;
    var remaining = key;

    while (remaining.len > 0) {
        var found = false;

        var it = current.children.iterator();
        while (it.next()) |entry| {
            const child = entry.value_ptr.*;
            const prefix_len = commonPrefixLen(child.edge, remaining);

            if (prefix_len > 0) {
                if (prefix_len < child.edge.len) {
                    return null;
                }

                if (prefix_len == remaining.len) {
                    return child;
                }

                remaining = remaining[prefix_len..];
                current = child;
                found = true;
                break;
            }
        }

        if (!found) return null;
    }

    return current;
}

pub fn searchByPrefix(prefix: []const u8) ?*RadixNode {
    ensureRoot();
    if (prefix.len == 0) return root;
    return findNode(root, prefix);
}

fn countKeys(node: *RadixNode) usize {
    var count: usize = 0;
    if (node.is_terminal) {
        count += 1;
    }

    var it = node.children.iterator();
    while (it.next()) |entry| {
        count += countKeys(entry.value_ptr.*);
    }
    return count;
}

const MAX_KEYS_RETURN = 10000;
const MAX_KEY_LENGTH = 1024;

fn collectKeysWithBuffer(node: *RadixNode, prefix_buffer: []u8, prefix_len: usize, keys: *std.ArrayListUnmanaged([]const u8), max_keys: usize) void {
    if (keys.items.len >= max_keys) return;

    if (node.is_terminal) {
        const key = temp_allocator.dupe(u8, prefix_buffer[0..prefix_len]) catch return;
        keys.append(temp_allocator, key) catch return;
    }

    var it = node.children.iterator();
    while (it.next()) |entry| {
        if (keys.items.len >= max_keys) break;
        const child = entry.value_ptr.*;
        const edge_len = child.edge.len;

        if (prefix_len + edge_len > MAX_KEY_LENGTH) continue;

        @memcpy(prefix_buffer[prefix_len .. prefix_len + edge_len], child.edge);
        collectKeysWithBuffer(child, prefix_buffer, prefix_len + edge_len, keys, max_keys);
    }
}

fn collectKeys(node: *RadixNode, prefix: []const u8, keys: *std.ArrayListUnmanaged([]const u8), max_keys: usize) void {
    var prefix_buffer: [MAX_KEY_LENGTH]u8 = undefined;
    if (prefix.len > MAX_KEY_LENGTH) return;
    @memcpy(prefix_buffer[0..prefix.len], prefix);
    collectKeysWithBuffer(node, &prefix_buffer, prefix.len, keys, max_keys);
}

pub fn getKeysFromNode(node: *RadixNode, prefix: []const u8) [][]const u8 {
    var keys_list = std.ArrayListUnmanaged([]const u8){};
    collectKeys(node, prefix, &keys_list, MAX_KEYS_RETURN);
    return keys_list.toOwnedSlice(temp_allocator) catch &[_][]const u8{};
}

pub fn getKeysByPrefix(prefix: []const u8) []const u8 {
    ensureRoot();
    const node = searchByPrefix(prefix) orelse return "";
    const keys = getKeysFromNode(node, prefix);
    if (keys.len == 0) return "";
    return std.mem.join(temp_allocator, "\r", keys) catch "";
}

pub fn getValuesByPrefix(prefix: []const u8) []const u8 {
    ensureRoot();
    const node = searchByPrefix(prefix) orelse return "";
    const keys = getKeysFromNode(node, prefix);
    if (keys.len == 0) return "";

    const values = temp_allocator.alloc([]const u8, keys.len) catch return "";
    for (keys, 0..) |key, i| {
        const value = storage.read(key) orelse "";
        values[i] = value;
    }

    return std.mem.join(temp_allocator, "\r", values) catch "";
}

pub fn getAllKeys() []const u8 {
    ensureRoot();
    const keys = getKeysFromNode(root, &[_]u8{});
    if (keys.len == 0) return "";
    return std.mem.join(temp_allocator, "\r", keys) catch "";
}
