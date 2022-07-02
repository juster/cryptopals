const std = @import("std");
const assert = std.debug.assert;
const print = std.debug.print;
const base64 = std.base64;
const mem = std.mem;
const fmt = std.fmt;

fn xorBuffer(dest: []u8, a: []u8, b: []u8) ![]u8 {
    assert(dest.len == a.len and a.len == b.len);
    var i: usize = 0;
    while (i < dest.len) : (i += 1) dest[i] = a[i] ^ b[i];
    return dest[0..i];
}

pub fn main() !void {
    const a = "1c0111001f010100061a024b53535009181c";
    const b = "686974207468652062756c6c277320657965";
    const c = "746865206b696420646f6e277420706c6179";

    var buf1: [a.len / 2]u8 = undefined;
    var buf2: [b.len / 2]u8 = undefined;
    var buf3: [a.len / 2]u8 = undefined;
    var buf4: [c.len]u8 = undefined;

    _ = try fmt.hexToBytes(&buf1, a);
    _ = try fmt.hexToBytes(&buf2, b);
    _ = try xorBuffer(&buf3, &buf1, &buf2);
    const out = try fmt.bufPrint(&buf4, "{}", .{fmt.fmtSliceHexLower(&buf3)});
    print("got\t{s}\nwant\t{s}\n", .{ out, c });

    if (mem.eql(u8, out, c)) {
        print("ok\n", .{});
    } else {
        print("FAIL\n", .{});
    }
}
