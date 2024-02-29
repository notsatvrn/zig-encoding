const std = @import("std");

const Allocator = std.mem.Allocator;

pub const Codepoint = packed struct {
    inner: u21 = 0,

    const Self = @This();

    // UTF-8

    // based on std.unicode.{utf8ByteSequenceLength, utf8Decode}
    pub fn fromUtf8(in: []const u8) !struct { Self, usize } {
        var codepoint = Self{};
        var length: usize = 1;

        switch (in[0]) {
            0b0000_0000...0b0111_1111 => {
                codepoint.inner = @as(u21, in[0]);
            },
            0b1100_0000...0b1101_1111 => {
                if (in.len < 2) return error.InvalidCodepoint;
                codepoint.inner = try std.unicode.utf8Decode2(in[0..2]);
                length = 2;
            },
            0b1110_0000...0b1110_1111 => {
                if (in.len < 3) return error.InvalidCodepoint;
                codepoint.inner = try std.unicode.utf8Decode3(in[0..3]);
                length = 3;
            },
            0b1111_0000...0b1111_0111 => {
                if (in.len < 4) return error.InvalidCodepoint;
                codepoint.inner = try std.unicode.utf8Decode4(in[0..4]);
                length = 4;
            },
            else => return error.InvalidStartByte,
        }

        return .{ codepoint, length };
    }

    // based on std.unicode.{utf8CodepointSequenceLength, utf8Encode}
    pub fn appendToUtf8(self: *const Self, out: *std.ArrayList(u8)) !void {
        if (self.inner < 0x80) {
            try out.append(@intCast(self.inner));
        } else if (self.inner < 0x800) {
            try out.ensureUnusedCapacity(2);
            out.appendAssumeCapacity(@intCast(0b11000000 | (self.inner >> 6)));
            out.appendAssumeCapacity(@intCast(0b10000000 | (self.inner & 0b111111)));
        } else if (self.inner < 0x10000) {
            if (0xd800 <= self.inner and self.inner <= 0xdfff) return error.CannotEncodeSurrogateHalf;
            try out.ensureUnusedCapacity(3);
            out.appendAssumeCapacity(@intCast(0b11100000 | (self.inner >> 12)));
            out.appendAssumeCapacity(@intCast(0b10000000 | ((self.inner >> 6) & 0b111111)));
            out.appendAssumeCapacity(@intCast(0b10000000 | (self.inner & 0b111111)));
        } else if (self.inner < 0x110000) {
            try out.ensureUnusedCapacity(4);
            out.appendAssumeCapacity(@intCast(0b11110000 | (self.inner >> 18)));
            out.appendAssumeCapacity(@intCast(0b10000000 | ((self.inner >> 12) & 0b111111)));
            out.appendAssumeCapacity(@intCast(0b10000000 | ((self.inner >> 6) & 0b111111)));
            out.appendAssumeCapacity(@intCast(0b10000000 | (self.inner & 0b111111)));
        } else {
            return error.CodepointTooLarge;
        }
    }

    // Java Modified UTF-8

    // based on JNI Type Docs
    pub fn fromMutf8(in: []const u8) !struct { Self, usize } {
        var codepoint = Self{};
        var length: usize = 1;

        if (in[0] == 0) {
            return error.NullByte;
        } else if (in[0] < 0x80) {
            codepoint.inner = @as(u21, in[0]);
        } else if (in.len >= 2 and (in[1] & 0xC0) == 0x80) {
            if ((in[0] & 0xE0) == 0xC0) {
                codepoint.inner = (@as(u21, in[0] & 0b11111) << 6) | @as(u21, in[1] & 0b111111);
                length = 2;
            } else if (in.len >= 3 and (in[0] & 0xF0) == 0xE0 and (in[2] & 0xC0) == 0x80) {
                if (in.len >= 6 and
                    in[0] == 0b11101101 and
                    (in[1] & 0xF0) == 0xA0 and
                    in[3] == 0b11101101 and
                    (in[4] & 0xF0) == 0xB0 and
                    (in[5] & 0xC0) == 0x80)
                {
                    codepoint.inner = (@as(u21, in[1] & 0b1111) << 16) |
                        (@as(u21, in[2] & 0b111111) << 10) |
                        (@as(u21, in[4] & 0b1111) << 6) |
                        @as(u21, in[5] & 0b111111);
                    length = 6;
                } else {
                    codepoint.inner = (@as(u21, in[0] & 0b1111) << 12) | (@as(u21, in[1] & 0b111111) << 6) | @as(u21, in[2] & 0b111111);
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
    pub fn appendToMutf8(self: *const Self, out: *std.ArrayList(u8)) !void {
        if (self.inner == 0) {
            try out.ensureUnusedCapacity(2);
            out.appendAssumeCapacity(0xC0);
            out.appendAssumeCapacity(0x80);
        } else if (self.inner < 0x80) {
            try out.append(@intCast(self.inner));
        } else if (self.inner < 0x800) {
            try out.ensureUnusedCapacity(2);
            out.appendAssumeCapacity(@intCast(0b11000000 | (self.inner >> 6)));
            out.appendAssumeCapacity(@intCast(0b10000000 | (self.inner & 0b111111)));
        } else if (self.inner < 0x10000) {
            if (0xd800 <= self.inner and self.inner <= 0xdfff) return error.CannotEncodeSurrogateHalf;
            try out.ensureUnusedCapacity(3);
            out.appendAssumeCapacity(@intCast(0b11100000 | (self.inner >> 12)));
            out.appendAssumeCapacity(@intCast(0b10000000 | ((self.inner >> 6) & 0b111111)));
            out.appendAssumeCapacity(@intCast(0b10000000 | (self.inner & 0b111111)));
        } else if (self.inner < 0x110000) {
            try out.ensureUnusedCapacity(6);
            out.appendAssumeCapacity(0b11101101);
            out.appendAssumeCapacity(@intCast(0b10100000 | (self.inner >> 16)));
            out.appendAssumeCapacity(@intCast(0b10000000 | ((self.inner >> 10) & 0b111111)));
            out.appendAssumeCapacity(0b11101101);
            out.appendAssumeCapacity(@intCast(0b10110000 | ((self.inner >> 6) & 0b1111)));
            out.appendAssumeCapacity(@intCast(0b10000000 | (self.inner & 0b111111)));
        } else {
            return error.CodepointTooLarge;
        }
    }

    // UTF-16-LE

    // based on std.unicode.utf16DecodeSurrogatePair + wikipedia
    pub fn fromUtf16le(in: []const u16) !struct { Self, usize } {
        var codepoint = Self{};
        var length: usize = 1;

        switch (in[0]) {
            0x0000...0xD7FF, 0xE000...0xFFFF => {
                codepoint.inner = @as(u21, in[0]);
            },
            else => if (in[0] & ~@as(u16, 0x03ff) == 0xd800) {
                if (in.len < 2) return error.InvalidCodepoint;
                if (in[1] & ~@as(u16, 0x03ff) != 0xdc00) return error.ExpectedSecondSurrogateHalf;
                codepoint.inner = 0x10000 + ((@as(u21, in[0]) & 0x03ff) << 10) | (in[1] & 0x03ff);
                length = 2;
            } else {
                return error.InvalidStartByte;
            },
        }

        return .{ codepoint, length };
    }

    // based on std.unicode.utf16CodepointSequenceLength + wikipedia
    pub fn appendToUtf16le(self: *const Self, out: *std.ArrayList(u16)) !void {
        if (self.inner < 0xFFFF) {
            try out.append(@intCast(self.inner));
        } else if (self.inner < 0x10FFFF) {
            try out.ensureUnusedCapacity(2);
            const codepoint = self.inner - 0x10000;
            out.appendAssumeCapacity(@intCast(0xd800 + (codepoint >> 10)));
            out.appendAssumeCapacity(@intCast(0xdc00 + (codepoint & 0b1111111111)));
        } else {
            return error.CodepointTooLarge;
        }
    }
};

// IMPLEMENTATIONS

inline fn codepointsFromUtf8Alloc(allocator: Allocator, in: []const u8) !std.ArrayList(Codepoint) {
    var codepoints = try std.ArrayList(Codepoint).initCapacity(allocator, in.len);
    errdefer codepoints.deinit();

    var i: usize = 0;
    var len: usize = 0;
    while (i < in.len) : (len += 1) {
        const codepoint = try Codepoint.fromUtf8(in[i..]);
        codepoints.appendAssumeCapacity(codepoint[0]);
        i += codepoint[1];
    }

    codepoints.shrinkAndFree(len);
    return codepoints;
}

inline fn codepointsToUtf8Alloc(allocator: Allocator, codepoints: []const Codepoint) ![]u8 {
    var out = try std.ArrayList(u8).initCapacity(allocator, codepoints.len);
    defer out.deinit();

    for (codepoints) |codepoint| {
        try codepoint.appendToUtf8(&out);
    }

    return try out.toOwnedSlice();
}

inline fn codepointsFromMutf8Alloc(allocator: Allocator, in: []const u8) !std.ArrayList(Codepoint) {
    var codepoints = try std.ArrayList(Codepoint).initCapacity(allocator, in.len);
    errdefer codepoints.deinit();

    var i: usize = 0;
    var len: usize = 0;
    while (i < in.len) : (len += 1) {
        const codepoint = try Codepoint.fromMutf8(in[i..]);
        codepoints.appendAssumeCapacity(codepoint[0]);
        i += codepoint[1];
    }

    codepoints.shrinkAndFree(len);
    return codepoints;
}

inline fn codepointsToMutf8Alloc(allocator: Allocator, codepoints: []const Codepoint) ![]u8 {
    var out = try std.ArrayList(u8).initCapacity(allocator, codepoints.len);
    defer out.deinit();

    for (codepoints) |codepoint| {
        try codepoint.appendToMutf8(&out);
    }

    return try out.toOwnedSlice();
}

inline fn codepointsFromUtf16leAlloc(allocator: Allocator, in: []const u16) !std.ArrayList(Codepoint) {
    var codepoints = try std.ArrayList(Codepoint).initCapacity(allocator, in.len);
    errdefer codepoints.deinit();

    var i: usize = 0;
    var len: usize = 0;
    while (i < in.len) : (len += 1) {
        const codepoint = try Codepoint.fromUtf16le(in[i..]);
        codepoints.appendAssumeCapacity(codepoint[0]);
        i += codepoint[1];
    }

    codepoints.shrinkAndFree(len);
    return codepoints;
}

inline fn codepointsToUtf16leAlloc(allocator: Allocator, codepoints: []const Codepoint) ![]u16 {
    var out = try std.ArrayList(u16).initCapacity(allocator, codepoints.len);
    defer out.deinit();

    for (codepoints) |codepoint| {
        try codepoint.appendToUtf16le(&out);
    }

    return try out.toOwnedSlice();
}

// STRING TYPES

pub const MutableString = struct {
    codepoints: std.ArrayList(Codepoint),

    const Self = @This();

    pub inline fn toOwnedStatic(self: Self) !StaticString {
        return .{
            .codepoints = try self.codepoints.toOwnedSlice(),
        };
    }

    pub inline fn asStatic(self: *const Self) StaticString {
        return .{
            .codepoints = self.codepoints.items,
        };
    }

    // UTF-8

    pub fn fromUtf8(allocator: Allocator, in: []const u8) !Self {
        return .{
            .codepoints = try codepointsFromUtf8Alloc(allocator, in),
        };
    }

    pub fn toUtf8(self: *const Self) ![]u8 {
        return codepointsToUtf8Alloc(self.codepoints.allocator, self.codepoints.items);
    }

    // Java Modified UTF-8

    pub fn fromMutf8(allocator: Allocator, in: []const u8) !Self {
        return .{
            .codepoints = try codepointsFromMutf8Alloc(allocator, in),
        };
    }

    pub fn toMutf8(self: *const Self) ![]u8 {
        return codepointsToMutf8Alloc(self.codepoints.allocator, self.codepoints.items);
    }

    // UTF-16-LE

    pub fn fromUtf16le(allocator: Allocator, in: []const u16) !Self {
        return .{
            .codepoints = try codepointsFromUtf16leAlloc(allocator, in),
        };
    }

    pub fn toUtf16le(self: *const Self) ![]u16 {
        return codepointsToUtf16leAlloc(self.codepoints.allocator, self.codepoints.items);
    }
};

pub const StaticString = struct {
    codepoints: []const Codepoint,

    const Self = @This();

    pub inline fn toMutable(self: Self, allocator: Allocator) MutableString {
        return .{
            .codepoints = std.ArrayList(Codepoint).fromOwnedSlice(allocator, self.codepoints),
        };
    }

    // UTF-8

    pub inline fn fromUtf8Comptime(comptime in: []const u8) Self {
        comptime var codepoints: [in.len]Codepoint = undefined;

        comptime var i: usize = 0;
        comptime var len: usize = 0;
        inline while (i < in.len) : (len += 1) {
            const codepoint = comptime Codepoint.fromUtf8(in[i..]) catch @compileError("invalid UTF-8 in string");
            codepoints[len] = codepoint[0];
            i += codepoint[1];
        }

        return .{ .codepoints = codepoints[0..len] };
    }

    pub fn fromUtf8Alloc(allocator: Allocator, in: []const u8) !Self {
        var codepoints = try codepointsFromUtf8Alloc(allocator, in);
        return .{
            .codepoints = try codepoints.toOwnedSlice(),
        };
    }

    pub fn toUtf8Alloc(self: *const Self, allocator: Allocator) ![]u8 {
        return codepointsToUtf8Alloc(allocator, self.codepoints);
    }

    // Java Modified UTF-8

    pub fn fromMutf8Alloc(allocator: Allocator, in: []const u8) !Self {
        var codepoints = try codepointsFromMutf8Alloc(allocator, in);
        return .{
            .codepoints = try codepoints.toOwnedSlice(),
        };
    }

    pub fn toMutf8Alloc(self: *const Self, allocator: Allocator) ![]u8 {
        return codepointsToMutf8Alloc(allocator, self.codepoints);
    }

    // UTF-16-LE

    pub fn fromUtf16leAlloc(allocator: Allocator, in: []const u16) !Self {
        var codepoints = try codepointsFromUtf16leAlloc(allocator, in);
        return .{
            .codepoints = try codepoints.toOwnedSlice(),
        };
    }

    pub fn toUtf16leAlloc(self: *const Self, allocator: Allocator) ![]u16 {
        return codepointsToUtf16leAlloc(allocator, self.codepoints);
    }

    // OPERATIONS

    pub inline fn eq(self: *const Self, other: *const Self) bool {
        if (self.codepoints.len != other.codepoints.len) {
            return false;
        }

        var i: usize = 0;
        while (i < self.codepoints.len) : (i += 1) {
            if (self.codepoints[i].inner != other.codepoints[i].inner) {
                return false;
            }
        }

        return true;
    }
};

test "StaticString from comptime string literal + eq" {
    const static = StaticString.fromUtf8Comptime("test");
    const other = try StaticString.fromUtf8Alloc(std.testing.allocator, "test");
    std.debug.assert(static.eq(&other));
    std.testing.allocator.free(other.codepoints);
}

// TODO: Unicode Categories

// Pattern_White_Space
pub inline fn pattern_white_space(codepoint: Codepoint) bool {
    return switch (codepoint.inner) {
        0x0009...0x000D => true,
        0x0020 => true,
        0x0085 => true,
        0x200E...0x200F => true,
        0x2028 => true,
        0x2029 => true,
        else => false,
    };
}

// Pattern_Syntax
pub inline fn pattern_syntax(codepoint: Codepoint) bool {
    return switch (codepoint.inner) {};
}
