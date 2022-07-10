const std = @import("std");

const testing = std.testing;
const assert = std.debug.assert;
const base64 = std.base64;
const math = std.math;
const fmt = std.fmt;

const alloc_limit = 128 * 1024;
var alloc_buffer: [alloc_limit]u8 = .{0} ** alloc_limit;

var input_lines: [128][] const u8 = undefined;
var line_count: u8 = 0;

fn hamming(a: [] const u8, b: [] const u8) u64 {
    assert(a.len == b.len);
    var result: u64 = 0;
    for (a) |x, i| result += @popCount(u8, x ^ b[i]);
    return result;
}

const expectEqual = testing.expectEqual;
test "hamming distance" {
    try expectEqual(@as(u64, 37), hamming("this is a test", "wokka wokka!!!"));
}

fn joinLines(a: []u8) []u8 {
    var i: u64 = 0;
    var j = i;
    while (i < a.len) : (i += 1) {
        if (a[i] == '\n') continue;
        if (i > j) a[j] = a[i];
        j += 1;
    }
    return a[0 .. j];
}

fn slurpLines(path: [] const u8, allocator: std.mem.Allocator, limit: usize) ![]u8 {
    var lines = try std.fs.cwd().readFileAlloc(allocator, path, limit);
    var buf = joinLines(lines);
    return allocator.shrink(lines, buf.len);
}

const min_block_size = 2;
const max_block_size = 40;
const block_size_count = max_block_size - min_block_size + 1;

const BlockDistance = struct {
    block_size: u8,
    distance: f32
};

fn byDistance(_: void, a: BlockDistance, b: BlockDistance) bool {
    return a.distance < b.distance;
}

fn blockSize(cypher: []u8) ?u8 {
    var block_dists: [block_size_count]BlockDistance = undefined;

    var i: u8 = 0;
    while (i < block_size_count) : (i += 1) {
        const sz = i + min_block_size;

        const n = (cypher.len / sz) - 1;
        var j: usize = 0;
        var sum: u64 = 0;
        while (j < n) : (j += 1) {
            const block1 = cypher[sz*(j+0) .. sz*(j+1)];
            const block2 = cypher[sz*(j+1) .. sz*(j+2)];
            sum += hamming(block1, block2);
        }

        const distance = @intToFloat(f32, sum) / @intToFloat(f32, n) / @intToFloat(f32, sz);
        block_dists[i].block_size = sz;
        block_dists[i].distance = distance;
        std.debug.print("*DBG* (block_size:{}) (dist:{})\n", .{sz, distance});
    }

    if (std.sort.min(BlockDistance, block_dists[0..], {}, byDistance)) |min_dist| {
        return min_dist.block_size;
    } else {
        return null;
    }
}

// XOR one-time-pad
fn xorEncrypt(dest: []u8, src: []const u8, key: []const u8) void {
    assert(dest.len == src.len);
    for (src) |ch, i| {
        dest[i] = ch ^ key[i % key.len];
    }
}

pub fn main() !void {
    // var out = std.io.getStdOut().writer();
    var fba = std.heap.FixedBufferAllocator.init(&alloc_buffer);
    var allocator = fba.allocator();

    var b64 = try slurpLines("6.txt", allocator, alloc_limit);
    std.debug.print("*DBG* read {} bytes\n", .{b64.len});

    const dec64 = base64.standard.Decoder;
    const dest_len = try dec64.calcSizeForSlice(b64);
    var cypher = try allocator.alloc(u8, dest_len);
    try dec64.decode(cypher, b64);

    std.debug.print("*DBG* (block size:{})\n", .{blockSize(cypher).?});
}
