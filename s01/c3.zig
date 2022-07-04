const std = @import("std");
const assert = std.debug.assert;
const print = std.debug.print;
const base64 = std.base64;
const math = std.math;
const mem = std.mem;
const fmt = std.fmt;

const cypher_hex = "1b37373331363f78151b7f2b783431333d78397828372d363c78373e783a393b3736";
const vowels = "aeiouyAEIOUY";

// const letter_range_count = '~' - ' ' + 1;
const alpha_count = 'Z'-'A' + 1;
var letter_freq: [alpha_count]f32 = undefined;
var alpha_freq: [alpha_count]f32 = .{8.2, 1.5, 2.8, 4.3, 13.0, 2.2, 2.0, 6.1,
                                     7.0, 0.15, 0.77, 4.0, 2.4, 6.7, 7.5, 1.9,
                                     0.095, 6.0, 6.3, 9.1, 2.8, 0.98, 2.4,
                                     0.15, 2.0, 0.074};

fn letterFrequency(dest: []f32, text: []const u8) u64 {
    var count: [alpha_count]u8 = undefined;
    var n_alpha: u64 = 0;
    assert(dest.len == alpha_count);

    for (count) |_,i| {
        count[i] = 0;
        dest[i] = 0.0;
    }
    for (text) |ch| {
        var uch = ch & ~@as(u8, 0x20);
        if (uch < 'A' or uch > 'Z') continue;
        count[uch - 'A'] += 1;
        n_alpha += 1;
    }
    for (count) |n,i| {
        dest[i] = @intToFloat(f32, n) / @intToFloat(f32, n_alpha);
    }

    return n_alpha;
}

fn score(text: []u8) f32 {
    for (text) |ch| {
        if (ch < ' ' or ch > '~') return 0.0;
    }
    const n = letterFrequency(&letter_freq, text);
    var sd: f32 = 0.0;
    for (letter_freq) |p,i| {
        sd += math.pow(f32, p - (alpha_freq[i] / 100.0), 2);
    }
    return (@intToFloat(f32, n) / @intToFloat(f32, text.len)) * (1.0 / sd);
}

// XOR one-time-pad
fn xorOTP(dest: []u8, key: []const u8, ctext: []const u8) void {
    assert(ctext.len % key.len == 0);
    assert(dest.len == ctext.len);
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
        print("DBG: {c} {}\n", .{@truncate(u8, 'A' + i), p});
    }
    print("\n", .{});
}

pub fn main() !void {
    var buf1: [cypher_hex.len / 2]u8 = undefined;
    var buf2: [buf1.len]u8 = undefined;
    const cypher = try fmt.hexToBytes(&buf1, cypher_hex);

    var key: [1]u8 = undefined;
    var i: u8 = 255;
    var max: f32 = 0.0;
    var found: [1 + buf2.len]u8 = undefined;
    while (i > 0) : (i -= 1) {
        key[0] = i;
        xorOTP(&buf2, &key, cypher);
        const x = score(&buf2);
        if (x == 0.0) continue;
        if (x > max) {
            print("{d}\t{}\t{s}\n", .{ i, x, &buf2 });
            max = x;
            found[0] = i;
            for (buf2) |ch, j| found[j + 1] = ch;
        }
    }
}
