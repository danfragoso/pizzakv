const std = @import("std");

pub fn hashKey(k: []const u8) u32 {
    return fnv1a(k);
}

pub fn fnv1a(key: []const u8) u32 {
    var hash: u32 = 2166136261;

    for (key) |c| {
        hash ^= c;
        hash *%= 16777619;
    }

    return hash;
}

pub fn xoramasrosas(k: []const u8) u32 {
    var hash: u32 = 17 * 22;
    const x = "xoramasrosas";

    for (k, 0..) |char, i| {
        hash = hash +% (char ^ x[i % 12]) << 12;
    }

    return hash;
}

pub fn djb2(key: []const u8) u32 {
    var hash: u32 = 5381;

    for (key) |c| {
        hash = ((hash << 5) +% hash) +% c;
    }

    return hash;
}
