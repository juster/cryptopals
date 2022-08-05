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

fn slurpBase64File(path: []const u8, allocator: std.mem.Allocator) ![]u8 {
    var base64 = try std.fs.cwd().readFileAlloc(allocator, path, 1024*1024);
    defer allocator.free(base64);
    const dec64 = std.base64.standard.Decoder;
    var raw = try allocator.alloc(u8, try dec64.calcSizeForSlice(base64));
    base64 = joinLines(base64);
    try dec64.decode(raw, base64);
    return raw;
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var cypher_text = try slurpBase64File("10.txt", allocator);
    defer allocator.free(cypher_text);

    var plain_text = try allocator.alloc(u8, cypher_text.len);
    aesDecryptCBC(plain_text, cypher_text, "YELLOW SUBMARINE", "\x00" ** aes_block_size);

    var out = std.io.getStdOut().writer();
    try out.print("{s}\n\n", .{plain_text});
}
