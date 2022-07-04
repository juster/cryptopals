const std = @import("std");
const assert = std.debug.assert;
const print = std.debug.print;
const base64 = std.base64;
const mem = std.mem;
const fmt = std.fmt;

const cypher_hex = "1b37373331363f78151b7f2b783431333d78397828372d363c78373e783a393b3736";
const vowels = "aeiouyAEIOUY";

fn score(english: []u8) f32 {
    var result: f32 = 0.0;
    for (english) |ch| {
        if (ch < ' ' or ch > '~') return 0.0;
        for (vowels) |v| {
            if (v == ch) {
                result += 1.0;
                break;
            }
        }
    }
    return result;
}

fn otp(dest: []u8, key: []const u8, ctext: []const u8) void {
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
        otp(&buf2, &key, cypher);
        const x = score(&buf2);
        if (x == 0.0) continue;
        print("{d}\t{s}\n", .{ i, &buf2 });
        if (x > max) {
            max = x;
            found[0] = i;
            for (buf2) |ch, j| found[j + 1] = ch;
        }
    }
}
