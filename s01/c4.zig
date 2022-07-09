const std = @import("std");
const assert = std.debug.assert;
const print = std.debug.print;
const base64 = std.base64;
const math = std.math;
const mem = std.mem;
const fmt = std.fmt;
const sort = std.sort.sort;
const fs = std.fs;

const alloc_limit = 5 * 1024 * 1024;
var alloc_buffer: [alloc_limit]u8 = .{0} ** alloc_limit;

const alpha_count = 'Z' - 'A' + 1;
var letter_freq: [alpha_count]f32 = undefined;
var alpha_freq: [alpha_count]f32 = .{ 8.2, 1.5, 2.8, 4.3, 13.0, 2.2, 2.0, 6.1, 7.0, 0.15, 0.77, 4.0, 2.4, 6.7, 7.5, 1.9, 0.095, 6.0, 6.3, 9.1, 2.8, 0.98, 2.4, 0.15, 2.0, 0.074 };

const printable_min = ' ';
const printable_max = '~';

fn slurpLines(path: [] const u8, allocator: std.mem.Allocator, limit: usize) ![][] const u8 {
    var buf = try std.fs.cwd().readFileAlloc(allocator, path, limit);
    var iter = std.mem.split(u8, buf, "\n");
    var i: u64 = 0;
    var lines: [][] const u8 = try allocator.alloc([] const u8, 0);
    while (iter.next()) |line| {
        lines = try allocator.realloc(lines, i+1);
        lines[i] = line;
        i += 1;
    }
    return lines;
}

fn letterFrequency(dest: []f32, text: []const u8) u64 {
    var count: [alpha_count]u8 = undefined;
    var n_alpha: u64 = 0;
    assert(dest.len == alpha_count);

    for (count) |_, i| {
        count[i] = 0;
        dest[i] = 0.0;
    }
    for (text) |ch| {
        var uch = ch & ~@as(u8, 0x20);
        if (uch < 'A' or uch > 'Z') continue;
        count[uch - 'A'] += 1;
        n_alpha += 1;
    }
    for (count) |n, i| {
        dest[i] = @intToFloat(f32, n) / @intToFloat(f32, n_alpha);
    }

    return n_alpha;
}

fn score(text: []u8) f32 {
    for (text) |ch| {
        if (ch < printable_min or ch > printable_max) return 0.0;
    }

    const n = letterFrequency(&letter_freq, text);
    var variance: f32 = 0.0;
    for (letter_freq) |p, i| {
        variance += math.pow(f32, p - (alpha_freq[i] / 100.0), 2);
    }

    const alpha_ratio = @intToFloat(f32, n);
    return (100.0 * alpha_ratio / @intToFloat(f32, text.len)) * (1.0 / math.sqrt(variance));
}

// XOR one-time-pad
fn xorOTP(dest: []u8, key: []const u8, ctext: []const u8) void {
    assert(ctext.len % key.len == 0);
    assert(dest.len >= ctext.len);
    var i: u64 = 0;
    while (i < ctext.len) : (i += key.len) {
        var j: u64 = 0;
        while (j < key.len) : (j += 1) {
            dest[i + j] = ctext[i + j] ^ key[j];
        }
    }
}

test "trace" {
    const msg = "Hello, world!".*;
    const n = letterFrequency(&letter_freq, &msg);
    print("DBG: {} total letters\n", .{n});
    for (letter_freq) |p, i| {
        print("DBG: {c} {}\n", .{ @truncate(u8, 'A' + i), p });
    }
    print("\n", .{});
}

const ScoreText = struct {
    key: [1]u8,
    score: f32,
    text: []u8,
};

fn byScore(context: void, a: ScoreText, b: ScoreText) bool {
    _ = context;
    return a.score >= b.score;
}

const top_results_count = 5;

fn crack(result: *ScoreText, cypher_hex: [] const u8, allocator: std.mem.Allocator) !bool {
    var buf = try allocator.alloc(u8, cypher_hex.len / 2);
    defer allocator.free(buf);
    const cypher = try fmt.hexToBytes(buf, cypher_hex);
    var scored: [255]ScoreText = undefined;

    for (scored) |*score_text| {
        score_text.text = try allocator.alloc(u8, cypher.len);
    }
    defer {
        for (scored) |score_text| {
            allocator.free(score_text.text);
        }
    }
    var i: u8 = 255;
    while (i > 0) : (i -= 1) {
        var iter = &scored[i-1];
        iter.key[0] = i;
        xorOTP(iter.text, &iter.key, cypher);
        iter.score = score(iter.text[0..]);
    }

    // print the top results
    sort(ScoreText, &scored, {}, byScore);
    if (scored[0].score == 0.0) return false;
    for (scored) |iter, j| {
        if (j > top_results_count) break;
        if (iter.score == 0.0) break;
        print("{d}\t{}\t{d:1.2}\t{s}\n", .{ j+1, fmt.fmtSliceHexUpper(&iter.key), iter.score, iter.text });
    }

    result.key = scored[0].key;
    result.score = scored[0].score;
    std.mem.copy(u8, result.text, scored[0].text);
    return true;
}

pub fn main() !void {
    var fba = std.heap.FixedBufferAllocator.init(&alloc_buffer);
    var allocator = fba.allocator();
    var hex_lines = try slurpLines("4.txt", allocator, alloc_buffer.len);
    print("*DBG* read {d} lines\n", .{hex_lines.len});

    var buf: [128]u8 = .{0} ** 128;
    var result: ScoreText = undefined;
    result.text = &buf;
    for (hex_lines) |hex, i| {
        print("*DBG* (i, {})\n", .{i});
        if (try crack(&result, hex, allocator)) {
            print("{}\t{d:1.2}\t{s}\n", .{fmt.fmtSliceHexUpper(&result.key), result.score, result.text});
        }
    }
}
