const std = @import("std");
const testing = std.testing;
const assert = std.debug.assert;
const base64 = std.base64;
const fmt = std.fmt;
const sort = std.sort.sort;
const fs = std.fs;

const block_size = 16;

fn hamming(a: []const u8, b: []const u8) u64 {
    assert(a.len == b.len);
    var result: u64 = 0;
    for (a) |x, i| result += @popCount(u8, x ^ b[i]);
    return result;
}

const expectEqual = testing.expectEqual;
test "hamming distance" {
    try expectEqual(@as(u64, 37), hamming("this is a test", "wokka wokka!!!"));
}

/// Counts the number of duplicate blocks in the cypher text.
fn findDupBlocks(blocks: [][]const u8) u8 {
    var n: u8 = 0;
    var i: usize = 0;
    while (i < blocks.len) : (i += 1) {
        var j: usize = i+1;
        while (j < blocks.len) : (j += 1) {
            if (std.mem.eql(u8, blocks[i], blocks[j])) {
                n += 1;
            }
        }
    }
    return n;
}

/// Calculate the sum of the Hamming distance between all 2-block combinations
/// in the cypher text.
fn blocksDistance(blocks: [][]const u8) u64 {
    var dist: u64 = 0;
    var i: usize = 0;
    while (i < blocks.len) : (i += 1) {
        var j: usize = i+1;
        while (j < blocks.len) : (j += 1) {
            dist += hamming(blocks[i], blocks[j]);
        }
    }
    return dist;
}

const Cypher = struct {
    line: u8,
    distance: u64,
};

fn byDistance(_: void, a: Cypher, b: Cypher) bool {
    return a.distance < b.distance;
}

fn findFileECB(path: []const u8, allocator: std.mem.Allocator) !void {
    var cypher_dists = std.ArrayList(Cypher).init(allocator);
    defer cypher_dists.deinit();

    const text = try std.fs.cwd().readFileAlloc(allocator, path, 1024*1024);
    var iter = std.mem.tokenize(u8, text, "\n");

    var line: u8 = 1;
    while (iter.next()) |cypher_hex| : (line += 1) {
        var cypher = try allocator.alloc(u8, cypher_hex.len / 2);
        _ = try std.fmt.hexToBytes(cypher, cypher_hex);

        var blocks = std.ArrayList([]u8).init(allocator);
        var i: usize = 0;
        defer blocks.deinit();

        while (i < cypher.len) : (i += block_size) {
            try blocks.append(cypher[i .. i+block_size]);
        }

        var dups = findDupBlocks(blocks.items);
        if (dups > 0) {
            std.debug.print("*DBG* line: {} found {} dup blocks\n", .{ line, dups });
        }
        var dist = blocksDistance(blocks.items);
        try cypher_dists.append(.{ .line = line, .distance = dist });
    }

    sort(Cypher, cypher_dists.items, {}, byDistance);
    // for (cypher_dists.items) |cd| {
    //     std.debug.print("*DBG* line: {} distance: {}\n", .{cd.line, cd.distance});
    // }
    const top = cypher_dists.items[0];
    std.debug.print("*DBG* line: {} hamming: {}\n", .{top.line, top.distance});
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();
    try findFileECB("8.txt", allocator);
}
