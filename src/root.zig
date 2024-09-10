const std = @import("std");

const Allocator = std.mem.Allocator;

// SINGLE CODEPOINT CONVERSION

// based on std.unicode.{utf8ByteSequenceLength, utf8Decode}
pub fn codepointFromUtf8(in: []const u8) !struct { u21, usize } {
    var codepoint: u21 = 0;
    var length: usize = 1;

    switch (in[0]) {
        0b0000_0000...0b0111_1111 => {
            codepoint = @as(u21, in[0]);
        },
        0b1100_0000...0b1101_1111 => {
            if (in.len < 2) return error.InvalidCodepoint;
            codepoint = try std.unicode.utf8Decode2(in[0..2]);
            length = 2;
        },
        0b1110_0000...0b1110_1111 => {
            if (in.len < 3) return error.InvalidCodepoint;
            codepoint = try std.unicode.utf8Decode3(in[0..3]);
            length = 3;
        },
        0b1111_0000...0b1111_0111 => {
            if (in.len < 4) return error.InvalidCodepoint;
            codepoint = try std.unicode.utf8Decode4(in[0..4]);
            length = 4;
        },
        else => return error.InvalidStartByte,
    }

    return .{ codepoint, length };
}

// based on std.unicode.{utf8CodepointSequenceLength, utf8Encode}
pub fn appendCodepointToUtf8(cp: u21, out: *std.ArrayList(u8)) !void {
    if (cp < 0x80) {
        try out.append(@intCast(cp));
    } else if (cp < 0x800) {
        try out.ensureUnusedCapacity(2);
        out.appendAssumeCapacity(@intCast(0b11000000 | (cp >> 6)));
        out.appendAssumeCapacity(@intCast(0b10000000 | (cp & 0b111111)));
    } else if (cp < 0x10000) {
        if (0xd800 <= cp and cp <= 0xdfff) return error.CannotEncodeSurrogateHalf;
        try out.ensureUnusedCapacity(3);
        out.appendAssumeCapacity(@intCast(0b11100000 | (cp >> 12)));
        out.appendAssumeCapacity(@intCast(0b10000000 | ((cp >> 6) & 0b111111)));
        out.appendAssumeCapacity(@intCast(0b10000000 | (cp & 0b111111)));
    } else if (cp < 0x110000) {
        try out.ensureUnusedCapacity(4);
        out.appendAssumeCapacity(@intCast(0b11110000 | (cp >> 18)));
        out.appendAssumeCapacity(@intCast(0b10000000 | ((cp >> 12) & 0b111111)));
        out.appendAssumeCapacity(@intCast(0b10000000 | ((cp >> 6) & 0b111111)));
        out.appendAssumeCapacity(@intCast(0b10000000 | (cp & 0b111111)));
    } else {
        return error.CodepointTooLarge;
    }
}

// based on JNI Type Docs
pub fn codepointFromMutf8(in: []const u8) !struct { u21, usize } {
    var codepoint: u21 = 0;
    var length: usize = 1;

    if (in[0] == 0) {
        return error.NullByte;
    } else if (in[0] < 0x80) {
        codepoint = @as(u21, in[0]);
    } else if (in.len >= 2 and (in[1] & 0xC0) == 0x80) {
        if ((in[0] & 0xE0) == 0xC0) {
            codepoint = (@as(u21, in[0] & 0b11111) << 6) | @as(u21, in[1] & 0b111111);
            length = 2;
        } else if (in.len >= 3 and (in[0] & 0xF0) == 0xE0 and (in[2] & 0xC0) == 0x80) {
            if (in.len >= 6 and
                in[0] == 0b11101101 and
                (in[1] & 0xF0) == 0xA0 and
                in[3] == 0b11101101 and
                (in[4] & 0xF0) == 0xB0 and
                (in[5] & 0xC0) == 0x80)
            {
                codepoint = (@as(u21, in[1] & 0b1111) << 16) |
                    (@as(u21, in[2] & 0b111111) << 10) |
                    (@as(u21, in[4] & 0b1111) << 6) |
                    @as(u21, in[5] & 0b111111);
                length = 6;
            } else {
                codepoint = (@as(u21, in[0] & 0b1111) << 12) | (@as(u21, in[1] & 0b111111) << 6) | @as(u21, in[2] & 0b111111);
                length = 3;
            }
        } else {
            return error.InvalidCodepoint;
        }
    } else {
        return error.InvalidCodepoint;
    }

    return .{ codepoint, length };
}

// based on std.unicode.{utf8CodepointSequenceLength, utf8Encode} + JNI Type Docs
pub fn appendCodepointToMutf8(cp: u21, out: *std.ArrayList(u8)) !void {
    if (cp == 0) {
        try out.ensureUnusedCapacity(2);
        out.appendAssumeCapacity(0xC0);
        out.appendAssumeCapacity(0x80);
    } else if (cp < 0x80) {
        try out.append(@intCast(cp));
    } else if (cp < 0x800) {
        try out.ensureUnusedCapacity(2);
        out.appendAssumeCapacity(@intCast(0b11000000 | (cp >> 6)));
        out.appendAssumeCapacity(@intCast(0b10000000 | (cp & 0b111111)));
    } else if (cp < 0x10000) {
        if (0xd800 <= cp and cp <= 0xdfff) return error.CannotEncodeSurrogateHalf;
        try out.ensureUnusedCapacity(3);
        out.appendAssumeCapacity(@intCast(0b11100000 | (cp >> 12)));
        out.appendAssumeCapacity(@intCast(0b10000000 | ((cp >> 6) & 0b111111)));
        out.appendAssumeCapacity(@intCast(0b10000000 | (cp & 0b111111)));
    } else if (cp < 0x110000) {
        try out.ensureUnusedCapacity(6);
        out.appendAssumeCapacity(0b11101101);
        out.appendAssumeCapacity(@intCast(0b10100000 | (cp >> 16)));
        out.appendAssumeCapacity(@intCast(0b10000000 | ((cp >> 10) & 0b111111)));
        out.appendAssumeCapacity(0b11101101);
        out.appendAssumeCapacity(@intCast(0b10110000 | ((cp >> 6) & 0b1111)));
        out.appendAssumeCapacity(@intCast(0b10000000 | (cp & 0b111111)));
    } else {
        return error.CodepointTooLarge;
    }
}

// based on std.unicode.utf16DecodeSurrogatePair + wikipedia
pub fn codepointFromUtf16le(in: []const u16) !struct { u21, usize } {
    var codepoint: u21 = 0;
    var length: usize = 1;

    switch (in[0]) {
        0x0000...0xD7FF, 0xE000...0xFFFF => {
            codepoint = @as(u21, in[0]);
        },
        else => if (in[0] & ~@as(u16, 0x03ff) == 0xd800) {
            if (in.len < 2) return error.InvalidCodepoint;
            if (in[1] & ~@as(u16, 0x03ff) != 0xdc00) return error.ExpectedSecondSurrogateHalf;
            codepoint = 0x10000 + ((@as(u21, in[0]) & 0x03ff) << 10) | (in[1] & 0x03ff);
            length = 2;
        } else {
            return error.InvalidStartByte;
        },
    }

    return .{ codepoint, length };
}

// based on std.unicode.utf16CodepointSequenceLength + wikipedia
pub fn appendCodepointToUtf16le(cp: u21, out: *std.ArrayList(u16)) !void {
    if (cp < 0xFFFF) {
        try out.append(@intCast(cp));
    } else if (cp < 0x10FFFF) {
        try out.ensureUnusedCapacity(2);
        const codepoint = cp - 0x10000;
        out.appendAssumeCapacity(@intCast(0xd800 + (codepoint >> 10)));
        out.appendAssumeCapacity(@intCast(0xdc00 + (codepoint & 0b1111111111)));
    } else {
        return error.CodepointTooLarge;
    }
}

// IMPLEMENTATIONS

pub fn codepointsFromUtf8Alloc(allocator: Allocator, in: []const u8) ![]u21 {
    var codepoints = try std.ArrayList(u21).initCapacity(allocator, in.len);
    errdefer codepoints.deinit();

    var i: usize = 0;
    var len: usize = 0;
    while (i < in.len) : (len += 1) {
        const codepoint = try codepointFromUtf8(in[i..]);
        codepoints.appendAssumeCapacity(codepoint[0]);
        i += codepoint[1];
    }

    return try codepoints.toOwnedSlice();
}

pub fn codepointsToUtf8Alloc(allocator: Allocator, codepoints: []const u21) ![]u8 {
    var out = try std.ArrayList(u8).initCapacity(allocator, codepoints.len);
    defer out.deinit();

    for (codepoints) |codepoint| {
        try appendCodepointToUtf8(codepoint, &out);
    }

    return try out.toOwnedSlice();
}

pub fn codepointsFromMutf8Alloc(allocator: Allocator, in: []const u8) ![]u21 {
    var codepoints = try std.ArrayList(u21).initCapacity(allocator, in.len);
    errdefer codepoints.deinit();

    var i: usize = 0;
    var len: usize = 0;
    while (i < in.len) : (len += 1) {
        const codepoint = try codepointFromMutf8(in[i..]);
        codepoints.appendAssumeCapacity(codepoint[0]);
        i += codepoint[1];
    }

    return try codepoints.toOwnedSlice();
}

pub fn codepointsToMutf8Alloc(allocator: Allocator, codepoints: []const u21) ![]u8 {
    var out = try std.ArrayList(u8).initCapacity(allocator, codepoints.len);
    defer out.deinit();

    for (codepoints) |codepoint| {
        try appendCodepointToMutf8(codepoint, &out);
    }

    return try out.toOwnedSlice();
}

pub fn codepointsFromUtf16leAlloc(allocator: Allocator, in: []const u16) ![]u21 {
    var codepoints = try std.ArrayList(u21).initCapacity(allocator, in.len);
    errdefer codepoints.deinit();

    var i: usize = 0;
    var len: usize = 0;
    while (i < in.len) : (len += 1) {
        const codepoint = try codepointFromUtf16le(in[i..]);
        codepoints.appendAssumeCapacity(codepoint[0]);
        i += codepoint[1];
    }

    return try codepoints.toOwnedSlice();
}

pub fn codepointsToUtf16leAlloc(allocator: Allocator, codepoints: []const u21) ![]u16 {
    var out = try std.ArrayList(u16).initCapacity(allocator, codepoints.len);
    defer out.deinit();

    for (codepoints) |codepoint| {
        try appendCodepointToUtf16le(codepoint, &out);
    }

    return try out.toOwnedSlice();
}

// STRING CONVERSION

test "from utf-8 and back + eql" {
    const codepoints = try codepointsFromUtf8Alloc(std.testing.allocator, "test");
    const string = try codepointsToUtf8Alloc(std.testing.allocator, codepoints);
    std.debug.assert(std.mem.eql(u8, string, "test"));
    std.testing.allocator.free(codepoints);
    std.testing.allocator.free(string);
}

test "from mutf-8 to utf-8 + eql" {
    const codepoints = try codepointsFromUtf8Alloc(std.testing.allocator, "test");
    const first = try codepointsToMutf8Alloc(std.testing.allocator, codepoints);
    const codepointsMutf = try codepointsFromMutf8Alloc(std.testing.allocator, first);
    const string = try codepointsToUtf8Alloc(std.testing.allocator, codepointsMutf);
    std.debug.assert(std.mem.eql(u8, string, "test"));
    std.testing.allocator.free(codepoints);
    std.testing.allocator.free(first);
    std.testing.allocator.free(codepointsMutf);
    std.testing.allocator.free(string);
}

test "from utf-16le and back + eql" {
    const codepoints = try codepointsFromUtf8Alloc(std.testing.allocator, "test");
    const first = try codepointsToUtf16leAlloc(std.testing.allocator, codepoints);
    const codepoints16 = try codepointsFromUtf16leAlloc(std.testing.allocator, first);
    const string = try codepointsToUtf8Alloc(std.testing.allocator, codepoints16);
    std.debug.assert(std.mem.eql(u8, string, "test"));
    std.testing.allocator.free(codepoints);
    std.testing.allocator.free(first);
    std.testing.allocator.free(codepoints16);
    std.testing.allocator.free(string);
}
