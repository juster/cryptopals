const std = @import("std");
const assert = std.debug.assert;
const math = std.math;
const fmt = std.fmt;

const crypto_key = "ICE";
const plain_text =
    \\Burning 'em, if you ain't quick and nimble
    \\I go crazy when I hear a cymbal
;
var buffer: [128]u8 = undefined;

// XOR one-time-pad
fn xorEncrypt(dest: []u8, src: []const u8, key: []const u8) void {
    assert(dest.len == src.len);
    for (src) |ch, i| {
        dest[i] = ch ^ key[i % key.len];
    }
}

pub fn main() !void {
    var out = std.io.getStdOut().writer();
    const len = plain_text.len;
    xorEncrypt(buffer[0 .. len], plain_text, crypto_key);
    var i: u64 = 0;
    while (i < len) : (i += 37) {
        var end = math.min(len, i + 37);
        try out.print("{}\n", .{fmt.fmtSliceHexLower(buffer[i .. end])});
    }
}
