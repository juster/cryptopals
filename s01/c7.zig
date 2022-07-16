const std = @import("std");
const cl = @import("cryptlib");

const testing = std.testing;
const assert = std.debug.assert;
const base64 = std.base64;
const fmt = std.fmt;
const sort = std.sort.sort;
const fs = std.fs;

const ok = cl.ok;

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

fn decrypt(cypher: []u8, key: []const u8) !void {
    var ctx: cl.CRYPT_CONTEXT = undefined;
    const user = cl.CRYPT_UNUSED;

    try ok(cl.cryptCreateContext(&ctx, user, cl.CRYPT_ALGO_AES));
    defer _ = cl.cryptDestroyContext(ctx);
    try ok(cl.cryptSetAttribute(ctx, cl.CRYPT_CTXINFO_MODE, cl.CRYPT_MODE_ECB));
    try ok(cl.cryptSetAttributeString(ctx, cl.CRYPT_CTXINFO_KEY,
                                      @ptrCast([*]const u8, key),
                                      @intCast(c_int, key.len)));

    try ok(cl.cryptDecrypt(ctx, @ptrCast([*]u8, cypher), @intCast(c_int, cypher.len)));
    std.debug.print("{s}\n", .{cypher[0..]});
}

fn decryptFile(path: []const u8, key: []const u8, allocator: std.mem.Allocator) !void {
    var cypher_b64 = try std.fs.cwd().readFileAlloc(allocator, path, 1024*1024);
    defer allocator.free(cypher_b64);
    cypher_b64 = joinLines(cypher_b64);
    const decoder = base64.standard.Decoder;
    var cypher = try allocator.alloc(u8, try decoder.calcSizeForSlice(cypher_b64));
    defer allocator.free(cypher);
    try decoder.decode(cypher, cypher_b64);
    try decrypt(cypher, key);
}

pub fn main() !void {
    try ok(cl.cryptInit());
    defer _ = cl.cryptEnd();
    try ok(cl.cryptAddRandom(null, cl.CRYPT_RANDOM_SLOWPOLL));

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    try decryptFile("7.txt", "YELLOW SUBMARINE", allocator);
}
