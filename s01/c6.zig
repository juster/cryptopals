const std = @import("std");

const testing = std.testing;
const assert = std.debug.assert;
const base64 = std.base64;
const math = std.math;
const fmt = std.fmt;
const sort = std.sort.sort;

const alpha_count = 'Z' - 'A' + 1;
var letter_freq: [alpha_count]f32 = undefined;
var alpha_freq: [alpha_count]f32 = .{ 8.2, 1.5, 2.8, 4.3, 13.0, 2.2, 2.0, 6.1, 7.0, 0.15, 0.77, 4.0, 2.4, 6.7, 7.5, 1.9, 0.095, 6.0, 6.3, 9.1, 2.8, 0.98, 2.4, 0.15, 2.0, 0.074 };

const printable_min = ' ';
const printable_max = '~';

var input_lines: [128][]const u8 = undefined;
var line_count: u8 = 0;

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

fn joinLines(a: []u8) []u8 {
    var i: u64 = 0;
    var j = i;
    while (i < a.len) : (i += 1) {
        if (a[i] == '\n') continue;
        if (i > j) a[j] = a[i];
        j += 1;
    }
    return a[0..j];
}

fn slurpLines(path: []const u8, allocator: std.mem.Allocator, limit: usize) ![]u8 {
    var lines = try std.fs.cwd().readFileAlloc(allocator, path, limit);
    var buf = joinLines(lines);
    return allocator.shrink(lines, buf.len);
}

const min_block_size = 2;
const max_block_size = 40;
const block_size_count = max_block_size - min_block_size + 1;

const BlockDistance = struct { block_size: u8, distance: f32 };

fn byDistance(_: void, a: BlockDistance, b: BlockDistance) bool {
    return a.distance < b.distance;
}

fn guessBlockSizes(dest: []BlockDistance, cypher: []u8) void {
    var i: u8 = 0;
    while (i < block_size_count) : (i += 1) {
        const sz = i + min_block_size;

        const n = (cypher.len / sz) - 1;
        var j: usize = 0;
        var sum: u64 = 0;
        while (j < n) : (j += 1) {
            const block1 = cypher[sz * (j + 0) .. sz * (j + 1)];
            const block2 = cypher[sz * (j + 1) .. sz * (j + 2)];
            sum += hamming(block1, block2);
        }

        const distance = @intToFloat(f32, sum) / @intToFloat(f32, n) / @intToFloat(f32, sz);
        dest[i].block_size = sz;
        dest[i].distance = distance;
        // std.debug.print("*DBG* (block_size:{}) (dist:{})\n", .{sz, distance});
    }

    sort(BlockDistance, dest, {}, byDistance);
}

fn blocksByteAt(byte_index: u8, block_size: u8, blocks: []u8, allocator: std.mem.Allocator) ![]u8 {
    var i: usize = byte_index;
    var j: usize = 0;
    var len = blocks.len / block_size;
    if (byte_index < (blocks.len % block_size) + 1) len += 1;
    var result = try allocator.alloc(u8, len);
    while (i < blocks.len) {
        result[j] = blocks[i];
        i += block_size;
        j += 1;
    }
    return result;
}

fn letterFrequency(dest: []f32, text: []const u8) u64 {
    var count: [alpha_count]u8 = undefined;
    var n_printable: u64 = 0;
    assert(dest.len == alpha_count);

    for (count) |_, i| {
        count[i] = 0;
        dest[i] = 0.0;
    }
    for (text) |ch| {
        if (ch < printable_min or ch > printable_max) continue;
        n_printable += 1;
        if (!std.ascii.isAlpha(ch)) continue;
        var uch = ch & ~@as(u8, 0x20); // make ASCII uppercase
        count[uch - 'A'] += 1;
    }
    for (count) |n, i| {
        dest[i] = @intToFloat(f32, n) / @intToFloat(f32, text.len); //@intToFloat(f32, n_alpha);
    }

    return n_printable;
}

fn score(text: []u8) f32 {
    const n = letterFrequency(&letter_freq, text);
    var variance: f32 = 0.0;
    for (letter_freq) |p, i| {
        variance += math.pow(f32, p - (alpha_freq[i] / 100.0), 2);
    }

    const print_ratio = @intToFloat(f32, n) / @intToFloat(f32, text.len);
    // std.debug.print("*DBG* alpha_ratio = {} :: text = {s}\n", .{alpha_ratio, text});
    return print_ratio * (100.0 / math.sqrt(variance));
}

const ScoreText = struct {
    offset: u8,
    key: [1]u8,
    score: f32,
    text: []u8,
};

fn byScore(context: void, a: ScoreText, b: ScoreText) bool {
    _ = context;
    return a.score >= b.score;
}

const top_results_count = 2;

// XOR with key in place
fn xorBytes(buf: []u8, key: []const u8) void {
    for (buf) |ch, i| {
        buf[i] = ch ^ key[i % key.len];
    }
}

fn crack(result: *ScoreText, cypher: []u8, allocator: std.mem.Allocator) !bool {
    var buf = try allocator.alloc(u8, 255 * cypher.len);
    defer allocator.free(buf);

    var scored: [255]ScoreText = undefined;

    // XOR decrypt with all possible one-byte keys (except for 0; that would be silly).
    // Score each resulting plaintext.
    var i: usize = 0;
    while (i < 255) : (i += 1) {
        const iter = &scored[i];
        var plain = buf[i * cypher.len .. (i + 1) * cypher.len];
        std.mem.copy(u8, plain, cypher);
        iter.key[0] = @truncate(u8, i + 1);
        xorBytes(plain, &iter.key);
        iter.text = plain;
        iter.score = score(plain);
    }

    // Print the top results
    sort(ScoreText, &scored, {}, byScore);
    if (scored[0].score == 0.0) return false; // all scores are awful
    for (scored) |iter, j| {
        if (j >= top_results_count) break;
        if (iter.score == 0.0) break;
        // std.debug.print("*DBG* score offset:{}\t{d}\t{}\t{d:1.2}\t{s}\n", .{
        //     result.offset, j+1, fmt.fmtSliceHexUpper(&iter.key), iter.score, iter.text
        // });
    }

    result.key = scored[0].key;
    result.score = scored[0].score;
    std.mem.copy(u8, result.text, scored[0].text);
    return true;
}

fn crackBlockSize(key_dest: []u8, cypher: []u8, allocator: std.mem.Allocator) !bool {
    const block_size = @truncate(u8, key_dest.len);
    std.debug.print("*DBG* (block size:{})\n", .{block_size});

    var i: u8 = 0;
    while (i < block_size) : (i += 1) {
        var nth = try blocksByteAt(i, block_size, cypher, allocator);
        defer allocator.free(nth);
        var text_buf = try allocator.alloc(u8, nth.len);
        defer allocator.free(text_buf);

        var score_text: ScoreText = .{ .offset = i, .key = .{0}, .text = text_buf[0..], .score = 0.0 };
        if (try crack(&score_text, nth, allocator)) {
            // std.debug.print("*DBG* key byte {d}: {X:2>0}\n", .{i, score_text.key[0]});
            key_dest[i] = score_text.key[0];
        } else {
            std.debug.print("error: failed to crack byte {d}\n", .{i});
            return false;
        }
    }

    return true;
}

pub fn main() !void {
    var out = std.io.getStdOut().writer();
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();

    var b64 = try slurpLines("6.txt", allocator, 1 * 1024 * 1024);
    defer allocator.free(b64);
    std.debug.print("*DBG* read {} bytes\n", .{b64.len});

    const dec64 = base64.standard.Decoder;
    const dest_len = try dec64.calcSizeForSlice(b64);
    var cypher = try allocator.alloc(u8, dest_len);
    defer allocator.free(cypher);
    try dec64.decode(cypher, b64);

    var plain = try allocator.alloc(u8, cypher.len);
    defer allocator.free(plain);

    var block_sizes: [block_size_count]BlockDistance = undefined;
    guessBlockSizes(block_sizes[0..], cypher);

    for (block_sizes) |block_dist| {
        const block_size = block_dist.block_size;
        var key = try allocator.alloc(u8, block_size);
        defer allocator.free(key);
        if (try crackBlockSize(key[0..], cypher, allocator)) {
            std.debug.print("*DBG* block size {} found key {s}\n", .{ block_size, key[0..] });
            std.mem.copy(u8, plain, cypher);
            xorBytes(plain, key[0..]);
            try out.print("-----\n{s}-----\n\n", .{plain});

            // var offset: usize = 0;
            // while (offset < block_size) : (offset += 1) {
            //     try out.print("*DBG* byte {} key char: {c}\n", .{offset, key[offset]});
            //     var i: usize = offset;
            //     while (i < plain.len) : (i += block_size) {
            //         try out.print("{c}", .{plain[i]});
            //     }
            //     try out.print("\n", .{});
            // }
            return;
        }
    }
}
