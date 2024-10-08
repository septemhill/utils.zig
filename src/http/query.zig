const std = @import("std");
// const expect = std.testing.expect(ok: bool)

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
