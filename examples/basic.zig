const std = @import("std");
const Result = @import("result").Result;
const fromErrorUnion = @import("result").fromErrorUnion;

// Custom error type
const ValidationError = enum {
    TooShort,
    TooLong,
    InvalidCharacters,
};

// Example: Parsing an integer from a string
fn parseNumber(str: []const u8) Result(i32, []const u8) {
    const num = std.fmt.parseInt(i32, str, 10) catch {
        return Result(i32, []const u8).err("Invalid number format");
    };
    return Result(i32, []const u8).ok(num);
}

// Example: Validating user input
fn validateUsername(username: []const u8) Result([]const u8, ValidationError) {
    if (username.len < 3) {
        return Result([]const u8, ValidationError).err(ValidationError.TooShort);
    }
    if (username.len > 20) {
        return Result([]const u8, ValidationError).err(ValidationError.TooLong);
    }

    // Check for valid characters (alphanumeric only)
    for (username) |c| {
        if (!std.ascii.isAlphanumeric(c) and c != '_') {
            return Result([]const u8, ValidationError).err(ValidationError.InvalidCharacters);
        }
    }

    return Result([]const u8, ValidationError).ok(username);
}

// Example: Chaining operations with andThen
fn divide(a: i32, b: i32) Result(i32, []const u8) {
    if (b == 0) {
        return Result(i32, []const u8).err("Division by zero");
    }
    return Result(i32, []const u8).ok(@divTrunc(a, b));
}

fn calculateRatio(numerator: []const u8, denominator: []const u8) Result(i32, []const u8) {
    const num_result = parseNumber(numerator);
    if (num_result.isErr()) {
        return num_result;
    }
    const num = num_result.unwrap();

    const denom_result = parseNumber(denominator);
    if (denom_result.isErr()) {
        return denom_result;
    }
    const denom = denom_result.unwrap();

    return divide(num, denom);
}

// Example: Using map to transform values
fn processAge(age_str: []const u8) Result([]const u8, []const u8) {
    return parseNumber(age_str).map([]const u8, struct {
        fn ageCategory(age: i32) []const u8 {
            if (age < 18) return "Minor";
            if (age < 65) return "Adult";
            return "Senior";
        }
    }.ageCategory);
}

// Example: Error recovery with orElse
fn getConfigValue(key: []const u8) Result([]const u8, []const u8) {
    _ = key;
    // Simulate config lookup failure
    return Result([]const u8, []const u8).err("Key not found");
}

fn getConfigValueWithDefault(key: []const u8) Result([]const u8, []const u8) {
    return getConfigValue(key).orElse(struct {
        fn useDefault(e: []const u8) Result([]const u8, []const u8) {
            _ = e;
            return Result([]const u8, []const u8).ok("default_value");
        }
    }.useDefault);
}

pub fn main() !void {
    const stdout_file = std.fs.File.stdout();
    var buffer: [4096]u8 = undefined;
    var stdout_writer = stdout_file.writer(&buffer);
    const stdout: *std.Io.Writer = &stdout_writer.interface;

    try stdout.writeAll("=== Zig Result Type Examples ===\n\n");

    // Example 1: Basic Result usage
    try stdout.print("1. Basic Result Usage:\n", .{});
    const num_result = parseNumber("42");
    if (num_result.isOk()) {
        try stdout.print("   Parsed number: {d}\n", .{num_result.unwrap()});
    }

    const bad_result = parseNumber("not a number");
    if (bad_result.isErr()) {
        try stdout.print("   Error: {s}\n", .{bad_result.unwrapErr()});
    }

    // Example 2: Using match for pattern matching
    try stdout.print("\n2. Pattern Matching:\n", .{});
    const username_result = validateUsername("john_doe");
    const message = username_result.match([]const u8, .{
        .ok = struct {
            fn handleOk(name: []const u8) []const u8 {
                _ = name;
                return "Valid username!";
            }
        }.handleOk,
        .err = struct {
            fn handleErr(e: ValidationError) []const u8 {
                return switch (e) {
                    .TooShort => "Username too short",
                    .TooLong => "Username too long",
                    .InvalidCharacters => "Invalid characters in username",
                };
            }
        }.handleErr,
    });
    try stdout.print("   {s}\n", .{message});

    // Example 3: Chaining operations with andThen
    try stdout.print("\n3. Chaining Operations:\n", .{});
    const ratio = calculateRatio("100", "5");
    try stdout.print("   Ratio result: {d}\n", .{ratio.unwrapOr(0)});

    const bad_ratio = calculateRatio("100", "0");
    try stdout.print("   Division by zero: {s}\n", .{bad_ratio.unwrapErr()});

    // Example 4: Using map to transform values
    try stdout.print("\n4. Transforming Values with map:\n", .{});
    const category = processAge("25");
    try stdout.print("   Age 25 category: {s}\n", .{category.unwrap()});

    const senior = processAge("70");
    try stdout.print("   Age 70 category: {s}\n", .{senior.unwrap()});

    // Example 5: Error recovery with orElse
    try stdout.print("\n5. Error Recovery:\n", .{});
    const config = getConfigValueWithDefault("missing_key");
    try stdout.print("   Config value: {s}\n", .{config.unwrap()});

    // Example 6: Combining multiple Results
    try stdout.print("\n6. Combining Results:\n", .{});
    const r1 = Result(i32, []const u8).ok(10);
    const r2 = Result(i32, []const u8).ok(20);
    const combined = r1.combine(r2);
    if (combined.isOk()) {
        const values = combined.unwrap();
        try stdout.print("   Combined: {d} + {d} = {d}\n", .{ values[0], values[1], values[0] + values[1] });
    }

    // Example 7: Converting from error unions
    try stdout.print("\n7. Converting from Error Unions:\n", .{});
    const success: anyerror!i32 = 42;
    const result_from_union = fromErrorUnion(success);
    try stdout.print("   Converted value: {d}\n", .{result_from_union.unwrap()});

    // Example 8: Using unwrapOr for defaults
    try stdout.print("\n8. Using unwrapOr:\n", .{});
    const ok_val = Result(i32, []const u8).ok(100);
    const err_val = Result(i32, []const u8).err("failed");
    try stdout.print("   Ok value with default: {d}\n", .{ok_val.unwrapOr(0)});
    try stdout.print("   Err value with default: {d}\n", .{err_val.unwrapOr(999)});

    // Example 9: Validation with multiple steps
    try stdout.print("\n9. Multi-step Validation:\n", .{});
    const usernames = [_][]const u8{ "ab", "valid_user", "this_username_is_way_too_long", "bad@user" };
    for (usernames) |name| {
        const validation = validateUsername(name);
        const status = validation.match([]const u8, .{
            .ok = struct {
                fn ok(_: []const u8) []const u8 {
                    return "✓";
                }
            }.ok,
            .err = struct {
                fn err(e: ValidationError) []const u8 {
                    return switch (e) {
                        .TooShort => "✗ (too short)",
                        .TooLong => "✗ (too long)",
                        .InvalidCharacters => "✗ (invalid chars)",
                    };
                }
            }.err,
        });
        try stdout.print("   {s:20} {s}\n", .{ name, status });
    }

    try stdout.writeAll("\n=== Examples Complete ===\n");
    try stdout.flush();
}
