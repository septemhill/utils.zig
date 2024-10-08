const std = @import("std");
// const expect = std.testing.expect(ok: bool)

fn ArenaAlloc(comptime T: type) type {
    return struct {
        arena: std.heap.ArenaAllocator,
        data: T,

        fn deinit(self: @This()) void {
            self.arena.deinit();
        }
    };
}

const EncodedQueryString = struct {
    arena: std.heap.ArenaAllocator,
    data: []const u8,

    fn deinit(self: EncodedQueryString) void {
        self.arena.deinit();
    }
};

pub fn Pair(comptime FIRST: type, comptime SECOND: type) type {
    return struct { FIRST, SECOND };
}

pub const Values = Pair([]const u8, []const u8);

pub fn encode(alloc: std.mem.Allocator, values: []const Values) !EncodedQueryString {
    var arena = std.heap.ArenaAllocator.init(alloc);
    var builder = std.ArrayList(u8).init(arena.allocator());
    defer builder.deinit();

    var i: usize = 0;
    while (i < values.len) : (i += 1) {
        // TODO: escape
        try builder.appendSlice(values[i].@"0");

        try builder.appendSlice("=");

        // TODO: escape
        try builder.appendSlice(values[i].@"1");

        if (i + 1 < values.len) {
            try builder.appendSlice("&");
        }
    }

    return EncodedQueryString{
        .arena = arena,
        .data = try builder.toOwnedSlice(),
    };
}

test "encode testing" {
    const tests = [_]struct {
        args: []const Values,
        expected: []const u8,
    }{
        .{
            .args = &.{
                .{ "Jerry", "Connor" },
                .{ "Septem", "Hazel" },
                .{ "Rennis", "Nicole" },
            },
            .expected = "Jerry=Connor&Septem=Hazel&Rennis=Nicole",
        },
        .{
            .args = &.{
                .{ "111", "Connor" },
                .{ "222", "Hazel" },
                .{ "333", "Nicole" },
            },
            .expected = "111=Connor&222=Hazel&333=Nicole",
        },
    };

    for (tests) |tt| {
        const encoded = try encode(std.testing.allocator, tt.args);
        defer encoded.deinit();
        try std.testing.expectEqualSlices(u8, encoded.data, tt.expected);
    }
}

fn decode(alloc: std.mem.Allocator, url: []const u8) !?ArenaAlloc([]Values) {
    const start_index = std.mem.indexOf(u8, url, "?") orelse return null;
    var pairs = std.mem.splitBackwardsScalar(u8, url[start_index + 1 ..], '&');

    var arena = std.heap.ArenaAllocator.init(alloc);
    var builder = std.ArrayList(Values).init(arena.allocator());
    defer builder.deinit();

    while (pairs.next()) |pair| {
        const index = std.mem.indexOf(u8, pair, "=");

        try builder.append(if (index) |i| .{
            try arena.allocator().dupe(u8, pair[0..i]),
            try arena.allocator().dupe(u8, pair[i + 1 ..]),
        } else .{
            try arena.allocator().dupe(u8, pair),
            try arena.allocator().dupe(u8, ""),
        });
    }

    return .{
        .arena = arena,
        .data = try builder.toOwnedSlice(),
    };
}

test "decode query string" {
    const tests = [_]struct {
        url: []const u8,
        expected: ?[]const Values,
    }{
        .{
            .url = "https://ziglang.org/?a=1&b=2",
            .expected = &.{
                .{ "b", "2" },
                .{ "a", "1" },
            },
        },
        .{
            .url = "https://ziglang.org/?a=1",
            .expected = &.{
                .{ "a", "1" },
            },
        },
        .{
            .url = "https://ziglang.org/?a=1&b=2&c&d=3",
            .expected = &.{
                .{ "d", "3" },
                .{ "c", "" },
                .{ "b", "2" },
                .{ "a", "1" },
            },
        },
        .{
            .url = "https://ziglang.org/",
            .expected = null,
        },
    };

    for (tests) |tt| {
        const decoded = try decode(std.testing.allocator, tt.url);

        defer if (decoded) |data| {
            data.arena.deinit();
        };

        if (decoded) |data| {
            try std.testing.expectEqualDeep(tt.expected.?, data.data);
        } else {
            try std.testing.expect(tt.expected == null);
        }
    }
}
