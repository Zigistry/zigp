const std = @import("std");
const ansi = @import("../libs/ansi_codes.zig");
const hfs = @import("../libs/helper_functions.zig");
const types = @import("../types.zig");

pub fn remove_dependency(allocator: std.mem.Allocator, dependency_to_remove: []const u8) void {
    const file = try std.fs.cwd().openFile("./zigp.zon", .{ .mode = .read_write });
    defer file.close();

    const data_constu8 = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(data_constu8);

    const data = try allocator.dupeZ(u8, data_constu8);

    var zigp_zon_parsed = try hfs.parse_zigp_zon(allocator, data);

    defer {
        allocator.free(zigp_zon_parsed.zig_version.?);
        allocator.free(zigp_zon_parsed.zigp_version.?);
        var iterfree = zigp_zon_parsed.dependencies.iterator();
        while (iterfree.next()) |next| {
            allocator.free(next.key_ptr.*);
        }
        zigp_zon_parsed.dependencies.deinit(allocator);
    }
    var iter = zigp_zon_parsed.dependencies.iterator();

    while (iter.next()) |dependency| {
        if (std.mem.eql(u8, dependency.key_ptr.*, dependency_to_remove)) {
            if (zigp_zon_parsed.dependencies.swapRemove(dependency)) {
                const to_write_to_file = try types.zigp_zon_to_string(zigp_zon_parsed, allocator);
                try file.seekTo(0);
                try file.setEndPos(0);
                try file.writeAll(to_write_to_file);
                std.debug.print("Removed {s} dependency.", .{dependency_to_remove});
            } else {
                @panic("Unable to remove dependency.");
            }
        }
    }
}
