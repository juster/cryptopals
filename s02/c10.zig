const std = @import("std");
// const cl = @import("cryptlib");

const testing = std.testing;
const assert = std.debug.assert;
const mem = std.mem;
const aes = std.crypto.core.aes;

fn xorBlock(a: []u8, b: []const u8) void {
    assert(a.len == b.len);
    for (a) |ch, i| {
        a[i] = ch ^ b[i];
    }
}

const aes_block_size = 16;

fn aesEncryptCBC(cypher_dest: []u8, plain_text: []const u8, key: []const u8, iv: []const u8) void {
    assert(plain_text.len % aes_block_size == 0);
    assert(key.len == aes_block_size);
    assert(iv.len == aes_block_size);

    var ctx  = aes.Aes128.initEnc(key[0..16].*);
    var prev = iv[0..16];
    var i: usize = 0;
    while (i < plain_text.len) {
        const j = i + aes_block_size;
        var p = plain_text[i .. j];
        var c = cypher_dest[i .. j];
        xorBlock(c, prev);
        ctx.encrypt(c[0..16], p[0..16]);
        prev = c[0..16];
        i = j;
    }
}

fn aesDecryptCBC(plain_dest: []u8, cypher_text: []const u8, key: []const u8, iv: []const u8) void {
    assert(cypher_text.len % aes_block_size == 0);
    assert(key.len == aes_block_size);
    assert(iv.len == aes_block_size);

    var prev = iv;
    var ctx = aes.Aes128.initDec(key[0..16].*);
    var i: usize = 0;
    while (i < cypher_text.len) {
        const j = i + aes_block_size;
        const c = cypher_text[i .. j];
        const p = plain_dest[i .. j];
        ctx.decrypt(p[0..16], c[0..16]);
        xorBlock(p, prev);
        prev = c;
        i = j;
    }
}

const expectEqualSlices = testing.expectEqualSlices;

test "encrypt/decrypt ECB" {
    const key = "YELLOWSUBMARINE0";
    const plain1 = "YELLOWSUBMARINE!";
    const iv = "\x00" ** 16;
    var cypher: [16]u8 = undefined;
    aesEncryptCBC(cypher[0..], plain1[0..], key, iv);

    var plain2: [16]u8 = undefined;
    aesDecryptCBC(plain2[0..], cypher[0..], key, iv);
    try expectEqualSlices(u8, plain1[0..], plain2[0..]);
}

const expectEqual = testing.expectEqual;

pub fn main() !void {

}
