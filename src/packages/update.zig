// Deprecated

const std = @import("std");
const ansi = @import("../libs/ansi_codes.zig");
const hfs = @import("../libs/helper_functions.zig");
const types = @import("../types.zig");

pub fn update_packages(allocator: std.mem.Allocator) !void {
    const file = try std.fs.cwd().openFile("./build.zig.zon", .{});
    defer file.close();

    // Read entire file into memory
    const data = try file.readToEndAlloc(allocator, std.math.maxInt(usize));
    defer allocator.free(data);

    const new_string = try allocator.dupeZ(u8, data);
    defer allocator.free(new_string);

    var parsed = try hfs.parse_build_zig_zon(allocator, new_string);
    defer {
        if (parsed.name) |name| allocator.free(name);
        if (parsed.version) |version| allocator.free(version);
    }

    std.debug.print("{?s}\n", .{parsed.name});
    std.debug.print("{?s}\n", .{parsed.version});

    var it = parsed.dependencies.iterator();
    defer parsed.dependencies.deinit(allocator);
    while (it.next()) |dependency| {
        std.debug.print("{s}\n", .{dependency.key_ptr.*});
        std.debug.print("{?s}\n", .{dependency.value_ptr.url});
        if (dependency.value_ptr.url) |url_| {
            if (std.mem.startsWith(u8, url_, "git+")) {
                // must be a direct github link, just wanna update
                // After testing a lot, I found out that I can
                // just remove the part after # if it is there
                // and run zig fetch on the remaining part
                // it will update it to the latest commit.
                // Suppose if this was the url:
                // git+https://github.com/capy-ui/capy?ref=master#some_commit
                // we just get this part
                // git+https://github.com/capy-ui/capy?ref=master
                // and run zig fetch on it
                // REMEMBER! to use double quotes around it "git+https://github.com/capy-ui/capy?ref=master"
                // because my terminal was giving me error like error: ref not found: main
                // After adding double quote, it worked.
                var iter = std.mem.splitScalar(u8, url_, '#');
                const url_we_need = iter.next().?;
                const process = try hfs.run_cli_command(&.{ "zig", "fetch", "--save", url_we_need }, allocator, .no_read);
                switch (process.Exited) {
                    0 => std.debug.print("{s}Successfully Updated {s}.{s}\n", .{ ansi.BRIGHT_GREEN ++ ansi.BOLD, url_we_need, ansi.RESET }),
                    1 => std.debug.print("{s}Zig fetch returned an error. The process returned 1 exit code.{s}\n", .{ ansi.RED ++ ansi.BOLD, ansi.RESET }),
                    else => std.debug.print("{s}Zig fetch returned an unknown error. It returned {} exit code.{s}\n", .{ ansi.RED ++ ansi.BOLD, process.Exited, ansi.RESET }),
                }
            } else if (std.mem.endsWith(u8, url_, ".tar.gz") and std.mem.startsWith(u8, url_, "https://")) {
                // if the url is like:
                // https://github.com/zigzap/zap/archive/refs/tags/v0.11.0.tar.gz
                // I only need https://github.com/zigzap/zap/archive/refs/tags/
                var front_url = std.mem.splitBackwardsScalar(u8, url_, '/');
                const current_tag_version = front_url.next().?;
                std.debug.print("Currently at: {s}", .{current_tag_version});
                const new_url_without_https = front_url.rest()[8..];
                const new_url = front_url.rest();
                // Now I also need https://github.com/zigzap/zap/ to fetch the versions.
                // for that I think I can do .next 2 times.
                var iter = std.mem.splitScalar(u8, new_url_without_https, '/');
                const provider = iter.next().?;
                if (!std.mem.eql(u8, provider, "github.com")) {
                    return error.unknown_provider;
                }
                const owner_name = iter.next().?;
                const repo_name = iter.next().?;
                const repo_full_name = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ owner_name, repo_name });
                const versions = try hfs.fetch_versions(.{ .full_name = repo_full_name, .name = repo_name, .owner = owner_name, .provider = .GitHub }, allocator);
                const latest_version = versions[1];
                std.debug.print("Going to: {s}", .{latest_version});
                const resulting = try std.fmt.allocPrint(allocator, "{s}/{s}.tar.gz", .{ new_url, latest_version });
                var process = std.process.Child.init(&[_][]const u8{ "zig", "fetch", "--save", resulting }, allocator);
                const term = try process.spawnAndWait();
                switch (term.Exited) {
                    0 => std.debug.print("{s}Successfully Updated {s}.{s}\n", .{ ansi.BRIGHT_GREEN ++ ansi.BOLD, repo_full_name, ansi.RESET }),
                    1 => std.debug.print("{s}Zig fetch returned an error. The process returned 1 exit code.{s}\n", .{ ansi.RED ++ ansi.BOLD, ansi.RESET }),
                    else => std.debug.print("{s}Zig fetch returned an unknown error. It returned {} exit code.{s}\n", .{ ansi.RED ++ ansi.BOLD, term.Exited, ansi.RESET }),
                }
            }
        }
        if (dependency.value_ptr.url) |url_| allocator.free(url_);

        std.debug.print("{?s}\n", .{dependency.value_ptr.hash});
        if (dependency.value_ptr.hash) |hash| allocator.free(hash);
        allocator.free(dependency.key_ptr.*);
        std.debug.print("{?s}\n", .{dependency.value_ptr.path});
        std.debug.print("{?}\n", .{dependency.value_ptr.lazy});
    }
}
