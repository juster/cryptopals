const std = @import("std");
const assert = std.debug.assert;
const print = std.debug.print;
const base64 = std.base64;
const math = std.math;
const mem = std.mem;
const fmt = std.fmt;
const sort = std.sort.sort;
const fs = std.fs;

const alloc_limit = 128 * 1024;
var alloc_buffer: [alloc_limit]u8 = .{0} ** alloc_limit;

const alpha_count = 'Z' - 'A' + 1;
var letter_freq: [alpha_count]f32 = undefined;
var alpha_freq: [alpha_count]f32 = .{ 8.2, 1.5, 2.8, 4.3, 13.0, 2.2, 2.0, 6.1, 7.0, 0.15, 0.77, 4.0, 2.4, 6.7, 7.5, 1.9, 0.095, 6.0, 6.3, 9.1, 2.8, 0.98, 2.4, 0.15, 2.0, 0.074 };

const printable_min = ' ';
const printable_max = '~';

const LinesBuf = struct {
    lines: [][] const u8,
    buffer: []u8
};

fn slurpLines(path: [] const u8, allocator: std.mem.Allocator, limit: usize) !LinesBuf {
    var buf = try std.fs.cwd().readFileAlloc(allocator, path, limit);
    var iter = std.mem.split(u8, buf, "\n");
    var i: u64 = 0;
    var lines: [][] const u8 = try allocator.alloc([] const u8, 0);
    while (iter.next()) |line| {
        lines = try allocator.realloc(lines, i+1);
        lines[i] = line;
        i += 1;
    }
    return LinesBuf {
        .lines = lines,
        .buffer = buf
    };
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
        if (ch == '\r' or ch == '\n' or ch == '\t') continue;
        if (ch < printable_min or ch > printable_max) return 0.0;
    }

    const n = letterFrequency(&letter_freq, text);
    var variance: f32 = 0.0;
    for (letter_freq) |p, i| {
        variance += math.pow(f32, p - (alpha_freq[i] / 100.0), 2);
    }

    const alpha_ratio = @intToFloat(f32, n);
    return (100.0 * alpha_ratio / @intToFloat(f32, text.len)) * (100.0 / math.sqrt(variance));
}

// XOR one-time-pad
fn xorOTP(dest: []u8, key: []const u8, ctext: []const u8) void {
    assert(ctext.len % key.len == 0);
    assert(dest.len == ctext.len);
    var i: u64 = 0;
    while (i < ctext.len) : (i += key.len) {
        for (key) |k, j| {
            dest[i + j] = ctext[i + j] ^ k;
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
    const text_len = cypher_hex.len / 2;
    var buf = try allocator.alloc(u8, 256 * text_len);
    defer allocator.free(buf);

    const cypher = try fmt.hexToBytes(buf[0..text_len], cypher_hex);
    var scored: [255]ScoreText = undefined;

    // XOR decrypt with all possible one-byte keys (except for 0; that would be silly).
    // Score each resulting plaintext.
    var i: u64 = 255;
    while (i > 0) : (i -= 1) {
        var iter = &scored[i-1];
        var text_dest = buf[i*text_len .. (i+1)*text_len];
        iter.key[0] = @truncate(u8, i);
        xorOTP(text_dest, &iter.key, cypher);
        iter.text = text_dest;
        iter.score = score(text_dest);
    }

    // print the top results
    sort(ScoreText, &scored, {}, byScore);
    if (scored[0].score == 0.0) return false; // all scores are awful
    for (scored) |iter, j| {
        if (j > top_results_count) break;
        if (iter.score == 0.0) break;
        print("*DBG* {d}\t{}\t{d:1.2}\t{s}\n", .{ j+1, fmt.fmtSliceHexUpper(&iter.key), iter.score, iter.text });
    }

    result.key = scored[0].key;
    result.score = scored[0].score;
    std.mem.copy(u8, result.text, scored[0].text);
    return true;
}

pub fn main() !void {
    var fba = std.heap.FixedBufferAllocator.init(&alloc_buffer);
    defer fba.reset();
    var allocator = fba.allocator();
    var lines_buf = try slurpLines("4.txt", allocator, alloc_buffer.len);
    defer allocator.free(lines_buf.buffer);
    const hex_lines = lines_buf.lines;

    print("*DBG* read {d} lines\n", .{hex_lines.len});

    var buf1: [128]u8 = .{0} ** 128;
    var buf2: [buf1.len]u8 = .{0} ** buf1.len;
    var max = ScoreText { .score = 0.0, .key = .{0}, .text = &buf1 };
    var max_i: u64 = 0;
    var result = ScoreText { .score = 0.0, .key = .{0}, .text = &buf2 };

    for (hex_lines) |hex, i| {
        if (try crack(&result, hex, allocator)) {
            if (result.score > max.score) {
                max.score = result.score;
                max.key = result.key;
                max_i = i;
                std.mem.copy(u8, max.text, result.text);
            }
        }
    }
    print("(Line {d})\t(Key 0x{})\t(Score {d:1.2})\t{s}\n", .{max_i, fmt.fmtSliceHexUpper(&max.key), max.score, max.text});
}
