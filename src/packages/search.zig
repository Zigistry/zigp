const std = @import("std");
const http = std.http;
const json = std.json;

// package response from zigistry
const Package = struct {
    name: []const u8,
    full_name: []const u8,
    description: []const u8,
    stargazers_count: u32,
    forks_count: u32,
    license: ?[]const u8,
    topics: []const []const u8,
    repo_from: []const u8,
    zig_minimum_version: []const u8,
    has_build_zig: bool,
    has_build_zig_zon: bool,
    updated_at: []const u8,
};

pub fn search_packages(allocator: std.mem.Allocator, query: ?[]const u8, filter: ?[]const u8) !void {
    const actual_query = if (query != null and query.?.len > 0 and !std.mem.eql(u8, query.?, "*")) query else null;
    const actual_filter = if (filter != null and filter.?.len > 0) filter else null;

    if (actual_query == null and actual_filter == null) {
        std.debug.print("Error: No valid search parameters provided.\n", .{});
        return error.InvalidSearchParameters;
    }

    var url_buffer: [512]u8 = undefined;
    const url = try build_search_url(&url_buffer, actual_query, actual_filter);

    std.debug.print("Searching: {s}\n\n", .{url});

    // Create HTTP client
    var client = http.Client{ .allocator = allocator };
    defer client.deinit();

    var body = std.Io.Writer.Allocating.init(allocator);
    const bodywriter: *std.Io.Writer = &body.writer;
    defer body.deinit();
    const response = try client.fetch(.{
        .location = .{ .url = url },
        .method = .GET,
        .response_writer = bodywriter,
    });

    if (response.status != .ok) {
        std.debug.print("API request failed with status: {s}\n", .{@tagName(response.status)});
        return;
    }

    const packages = try parse_packages(allocator, body.written());
    defer free_packages(allocator, packages);

    print_packages(packages);
}

fn free_packages(allocator: std.mem.Allocator, packages: []Package) void {
    for (packages) |pkg| {
        allocator.free(pkg.name);
        allocator.free(pkg.full_name);
        allocator.free(pkg.description);
        if (pkg.license) |license| allocator.free(license);
        for (pkg.topics) |topic| allocator.free(topic);
        allocator.free(pkg.topics);
        allocator.free(pkg.repo_from);
        allocator.free(pkg.zig_minimum_version);
        allocator.free(pkg.updated_at);
    }
    allocator.free(packages);
}

fn build_search_url(buffer: []u8, query: ?[]const u8, filter: ?[]const u8) ![]const u8 {
    const base_url = "https://zigistry-api.hf.space/api/searchPackages";

    if (query != null and filter != null) {
        // Both provided: ?q=query&filter=filter
        return std.fmt.bufPrint(buffer, "{s}?q={s}&filter={s}", .{ base_url, query.?, filter.? });
    } else if (query != null) {
        // Only query provided: ?q=query
        return std.fmt.bufPrint(buffer, "{s}?q={s}", .{ base_url, query.? });
    } else if (filter != null) {
        // Only filter provided: ?filter=filter
        return std.fmt.bufPrint(buffer, "{s}?filter={s}", .{ base_url, filter.? });
    } else {
        // Neither
        return error.NoSearchParameters;
    }
}

// Parse JSON response into Package array
fn parse_packages(allocator: std.mem.Allocator, body: []const u8) ![]Package {
    var parsed = try json.parseFromSlice(json.Value, allocator, body, .{});
    defer parsed.deinit();

    if (parsed.value != .array) {
        return error.InvalidJSON;
    }

    const packages_array = parsed.value.array;
    var packages = try allocator.alloc(Package, packages_array.items.len);

    for (packages_array.items, 0..) |item, i| {
        if (item != .object) continue;

        const obj = item.object;
        packages[i] = Package{
            .name = try allocator.dupe(u8, get_string(obj, "name") orelse "unknown"),
            .full_name = try allocator.dupe(u8, get_string(obj, "full_name") orelse "unknown"),
            .description = try allocator.dupe(u8, get_string(obj, "description") orelse ""),
            .stargazers_count = get_u32(obj, "stargazers_count") orelse 0,
            .forks_count = get_u32(obj, "forks_count") orelse 0,
            .license = if (get_string(obj, "license")) |license|
                try allocator.dupe(u8, license)
            else
                null,
            .topics = try parse_topics(allocator, obj),
            .repo_from = try allocator.dupe(u8, get_string(obj, "repo_from") orelse "unknown"),
            .zig_minimum_version = try allocator.dupe(u8, get_string(obj, "zig_minimum_version") orelse "unknown"),
            .has_build_zig = get_bool(obj, "has_build_zig") orelse false,
            .has_build_zig_zon = get_bool(obj, "has_build_zig_zon") orelse false,
            .updated_at = try allocator.dupe(u8, get_string(obj, "updated_at") orelse "unknown"),
        };
    }

    return packages;
}

// JSON object to sting
fn get_string(obj: json.ObjectMap, key: []const u8) ?[]const u8 {
    if (obj.get(key)) |value| {
        if (value == .string) {
            return value.string;
        }
    }
    return null;
}

// JSON object to u32
fn get_u32(obj: json.ObjectMap, key: []const u8) ?u32 {
    if (obj.get(key)) |value| {
        if (value == .integer) {
            return @intCast(value.integer);
        }
    }
    return null;
}

// JSON object to bool
fn get_bool(obj: json.ObjectMap, key: []const u8) ?bool {
    if (obj.get(key)) |value| {
        if (value == .bool) {
            return value.bool;
        }
    }
    return null;
}

// Parse topics array
fn parse_topics(allocator: std.mem.Allocator, obj: json.ObjectMap) ![]const []const u8 {
    if (obj.get("topics")) |value| {
        if (value == .array) {
            const topics_array = value.array;
            var topics = try allocator.alloc([]const u8, topics_array.items.len);

            for (topics_array.items, 0..) |topic, i| {
                if (topic == .string) {
                    topics[i] = try allocator.dupe(u8, topic.string);
                } else {
                    topics[i] = try allocator.dupe(u8, "");
                }
            }
            return topics;
        }
    }
    return &[0][]const u8{};
}

// Print packages in a nice format
fn print_packages(packages: []const Package) void {
    if (packages.len == 0) {
        std.debug.print("No packages found.\n", .{});
        return;
    }

    std.debug.print("Found {d} package(s):\n\n", .{packages.len});

    for (packages, 0..) |pkg, i| {
        std.debug.print("--- Package {d} ---\n", .{i + 1});
        std.debug.print("Name: {s}\n", .{pkg.name});
        std.debug.print("Full Name: {s}\n", .{pkg.full_name});
        std.debug.print("Description: {s}\n", .{pkg.description});
        std.debug.print("Stars: {d}, Forks: {d}\n", .{ pkg.stargazers_count, pkg.forks_count });
        std.debug.print("License: {s}\n", .{pkg.license orelse "None"});
        std.debug.print("Source: {s}\n", .{pkg.repo_from});
        std.debug.print("Zig Version: {s}\n", .{pkg.zig_minimum_version});
        std.debug.print("Build.zig: {}, Build.zig.zon: {}\n", .{ pkg.has_build_zig, pkg.has_build_zig_zon });

        if (pkg.topics.len > 0) {
            std.debug.print("Topics: ", .{});
            for (pkg.topics, 0..) |topic, j| {
                if (j > 0) std.debug.print(", ", .{});
                std.debug.print("{s}", .{topic});
            }
            std.debug.print("\n", .{});
        }

        std.debug.print("Updated: {s}\n", .{pkg.updated_at});
        std.debug.print("\n", .{});
    }
}
