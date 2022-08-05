const std = @import("std");
const testing = std.testing;

fn pkcs7CalcSize(block_size: usize, plain_text: [] const u8) usize {
    const n = plain_text.len % block_size;
    return if (n == 0) plain_text.len else plain_text.len + block_size - n;
}

fn pkcs7(block_size: usize, dest: []u8, plain_text: [] const u8) []u8 {
    std.mem.copy(u8, dest, plain_text);
    const n = plain_text.len % block_size;
    if (n == 0) return dest[0 .. plain_text.len];

    const m = @truncate(u8, block_size - n);
    const len = plain_text.len + m;

    var i: usize = plain_text.len;
    while (i < len) : (i += 1) dest[i] = m;
    return dest[0 .. len];
}

const expectEqualSlices = testing.expectEqualSlices;

test "pkcs7" {
    const allocator = testing.allocator;
    const block_size = 20;
    const plain_text = "YELLOW SUBMARINE";
    // std.debug.print("*DBG* pkcs7 size: {}\n", .{ pkcs7CalcSize(block_size, plain_text) });
    var buf = try allocator.alloc(u8, pkcs7CalcSize(block_size, plain_text));
    defer allocator.free(buf);
    try expectEqualSlices(u8,
                          "YELLOW SUBMARINE\x04\x04\x04\x04",
                          pkcs7(block_size, buf[0..], plain_text[0..]));
}

pub fn main() !void {
    return;
}
