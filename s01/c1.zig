const std = @import("std");
const print = std.debug.print;
const base64 = std.base64;
const mem = std.mem;
const fmt = std.fmt;

const input = "49276d206b696c6c696e6720796f757220627261696e206c696b65206120706f69736f6e6f7573206d757368726f6f6d";
const want = "SSdtIGtpbGxpbmcgeW91ciBicmFpbiBsaWtlIGEgcG9pc29ub3VzIG11c2hyb29t";

pub fn main() !void {
    var buf1: [input.len / 2]u8 = undefined;
    var buf2: [want.len]u8 = undefined;

    const raw = try fmt.hexToBytes(&buf1, input);
    const b64 = base64.standard_no_pad.Encoder.encode(&buf2, raw);
    print("{s}\n{s}\n", .{ raw, b64 });

    if (mem.eql(u8, b64, want)) {
        print("ok\n", .{});
    } else {
        print("FAIL\n", .{});
    }
}
