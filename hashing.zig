const std = @import("std");

pub fn hashKey(k: []const u8) u32 {
    return xxhash32(k);
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

pub fn murmur3(key: []const u8) u32 {
    const seed: u32 = 0;
    var hash: u32 = seed;

    const c1: u32 = 0xcc9e2d51;
    const c2: u32 = 0x1b873593;

    var i: usize = 0;
    while (i + 4 <= key.len) : (i += 4) {
        var k: u32 = @as(u32, key[i]) |
            (@as(u32, key[i + 1]) << 8) |
            (@as(u32, key[i + 2]) << 16) |
            (@as(u32, key[i + 3]) << 24);

        k *%= c1;
        k = (k << 15) | (k >> 17);
        k *%= c2;

        hash ^= k;
        hash = (hash << 13) | (hash >> 19);
        hash = hash *% 5 +% 0xe6546b64;
    }

    var k: u32 = 0;
    const remaining = key.len - i;
    if (remaining >= 3) k ^= @as(u32, key[i + 2]) << 16;
    if (remaining >= 2) k ^= @as(u32, key[i + 1]) << 8;
    if (remaining >= 1) {
        k ^= @as(u32, key[i]);
        k *%= c1;
        k = (k << 15) | (k >> 17);
        k *%= c2;
        hash ^= k;
    }

    hash ^= @as(u32, @intCast(key.len));
    hash ^= hash >> 16;
    hash *%= 0x85ebca6b;
    hash ^= hash >> 13;
    hash *%= 0xc2b2ae35;
    hash ^= hash >> 16;

    return hash;
}

pub fn xxhash32(key: []const u8) u32 {
    const PRIME1: u32 = 2654435761;
    const PRIME2: u32 = 2246822519;
    const PRIME3: u32 = 3266489917;
    const PRIME4: u32 = 668265263;
    const PRIME5: u32 = 374761393;

    var hash: u32 = PRIME5 +% @as(u32, @intCast(key.len));

    var i: usize = 0;
    while (i + 4 <= key.len) : (i += 4) {
        const k: u32 = @as(u32, key[i]) |
            (@as(u32, key[i + 1]) << 8) |
            (@as(u32, key[i + 2]) << 16) |
            (@as(u32, key[i + 3]) << 24);
        hash +%= k *% PRIME3;
        hash = ((hash << 17) | (hash >> 15)) *% PRIME4;
    }

    while (i < key.len) : (i += 1) {
        hash +%= @as(u32, key[i]) *% PRIME5;
        hash = ((hash << 11) | (hash >> 21)) *% PRIME1;
    }

    hash ^= hash >> 15;
    hash *%= PRIME2;
    hash ^= hash >> 13;
    hash *%= PRIME3;
    hash ^= hash >> 16;

    return hash;
}

pub fn wyhash(key: []const u8) u32 {
    return @as(u32, @truncate(std.hash.Wyhash.hash(0, key)));
}
