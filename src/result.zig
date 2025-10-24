const std = @import("std");

/// Result type similar to Rust's Result<T, E> and TypeScript's neverthrow
/// Represents either a success value (Ok) or an error value (Err)
pub fn Result(comptime T: type, comptime E: type) type {
    return union(enum) {
        success: T,
        failure: E,

        const Self = @This();

        /// Create a successful Result containing a value
        pub fn ok(value: T) Self {
            return .{ .success = value };
        }

        /// Create an error Result containing an error
        pub fn err(error_value: E) Self {
            return .{ .failure = error_value };
        }

        /// Returns true if the Result is Ok
        pub fn isOk(self: Self) bool {
            return switch (self) {
                .success => true,
                .failure => false,
            };
        }

        /// Returns true if the Result is Err
        pub fn isErr(self: Self) bool {
            return !self.isOk();
        }

        /// Maps a Result<T, E> to Result<U, E> by applying a function to the Ok value
        pub fn map(self: Self, comptime U: type, func: fn (T) U) Result(U, E) {
            return switch (self) {
                .success => |val| Result(U, E).ok(func(val)),
                .failure => |e| Result(U, E).err(e),
            };
        }

        /// Maps a Result<T, E> to Result<T, F> by applying a function to the Err value
        pub fn mapErr(self: Self, comptime F: type, func: fn (E) F) Result(T, F) {
            return switch (self) {
                .success => |val| Result(T, F).ok(val),
                .failure => |e| Result(T, F).err(func(e)),
            };
        }

        /// Maps both Ok and Err values, similar to Rust's map_or_else
        pub fn mapBoth(self: Self, comptime U: type, okFunc: fn (T) U, errFunc: fn (E) U) U {
            return switch (self) {
                .success => |val| okFunc(val),
                .failure => |e| errFunc(e),
            };
        }

        /// Chains Results together (flatMap/andThen)
        /// Calls func with the Ok value if Ok, otherwise returns the Err
        pub fn andThen(self: Self, comptime U: type, func: fn (T) Result(U, E)) Result(U, E) {
            return switch (self) {
                .success => |val| func(val),
                .failure => |e| Result(U, E).err(e),
            };
        }

        /// Chains error handling (orElse)
        /// Calls func with the Err value if Err, otherwise returns the Ok
        pub fn orElse(self: Self, func: fn (E) Self) Self {
            return switch (self) {
                .success => self,
                .failure => |e| func(e),
            };
        }

        /// Returns the Ok value or a default value
        pub fn unwrapOr(self: Self, default: T) T {
            return switch (self) {
                .success => |val| val,
                .failure => default,
            };
        }

        /// Returns the Ok value or computes it from the error using a function
        pub fn unwrapOrElse(self: Self, func: fn (E) T) T {
            return switch (self) {
                .success => |val| val,
                .failure => |e| func(e),
            };
        }

        /// Returns the Ok value or panics with a message
        pub fn unwrap(self: Self) T {
            return switch (self) {
                .success => |val| val,
                .failure => @panic("called unwrap on an Err value"),
            };
        }

        /// Returns the Err value or panics with a message
        pub fn unwrapErr(self: Self) E {
            return switch (self) {
                .success => @panic("called unwrapErr on an Ok value"),
                .failure => |e| e,
            };
        }

        /// Returns the Ok value or panics with a custom message
        pub fn expect(self: Self, msg: []const u8) T {
            return switch (self) {
                .success => |val| val,
                .failure => {
                    std.debug.panic("{s}", .{msg});
                },
            };
        }

        /// Returns the Err value or panics with a custom message
        pub fn expectErr(self: Self, msg: []const u8) E {
            return switch (self) {
                .success => {
                    std.debug.panic("{s}", .{msg});
                },
                .failure => |e| e,
            };
        }

        /// Pattern matching on Result - similar to Rust's match
        pub fn match(self: Self, comptime U: type, handlers: struct {
            ok: fn (T) U,
            err: fn (E) U,
        }) U {
            return switch (self) {
                .success => |val| handlers.ok(val),
                .failure => |e| handlers.err(e),
            };
        }

        /// Combines two Results - if both are Ok, returns Ok with both values as a tuple
        pub fn combine(self: Self, other: Self) Result(struct { T, T }, E) {
            return switch (self) {
                .success => |val1| switch (other) {
                    .success => |val2| Result(struct { T, T }, E).ok(.{ val1, val2 }),
                    .failure => |e| Result(struct { T, T }, E).err(e),
                },
                .failure => |e| Result(struct { T, T }, E).err(e),
            };
        }

        /// Returns the Ok value if present, otherwise returns the other Result
        pub fn orResult(self: Self, other: Self) Self {
            return switch (self) {
                .success => self,
                .failure => other,
            };
        }

        /// Returns self if it's an error, otherwise returns the other Result
        pub fn andResult(self: Self, other: Self) Self {
            return switch (self) {
                .success => other,
                .failure => self,
            };
        }

        /// Converts to an optional, discarding the error
        pub fn okOrNull(self: Self) ?T {
            return switch (self) {
                .success => |val| val,
                .failure => null,
            };
        }

        /// Converts to an optional error, discarding the ok value
        pub fn errOrNull(self: Self) ?E {
            return switch (self) {
                .success => null,
                .failure => |e| e,
            };
        }

        /// Inspect the Ok value without consuming or transforming it
        /// Useful for debugging or logging
        pub fn inspect(self: Self, func: fn (T) void) Self {
            switch (self) {
                .success => |val| func(val),
                .failure => {},
            }
            return self;
        }

        /// Inspect the Err value without consuming or transforming it
        pub fn inspectErr(self: Self, func: fn (E) void) Self {
            switch (self) {
                .success => {},
                .failure => |e| func(e),
            }
            return self;
        }

        /// Flatten a nested Result - Result(Result(T, E), E) -> Result(T, E)
        pub fn flatten(self: Result(Self, E)) Self {
            return switch (self) {
                .success => |inner| inner,
                .failure => |e| Self.err(e),
            };
        }

        /// Returns the Ok value as an error union, or the Err as an error
        /// This allows safe unwrapping that returns a Zig error union
        pub fn toErrorUnion(self: Self) E!T {
            return switch (self) {
                .success => |val| val,
                .failure => |e| e,
            };
        }
    };
}

/// Helper to create Ok results
pub fn ok(value: anytype) Result(@TypeOf(value), anyerror) {
    return Result(@TypeOf(value), anyerror).ok(value);
}

/// Helper to create Err results with type inference
pub fn err(comptime T: type, error_value: anytype) Result(T, @TypeOf(error_value)) {
    return Result(T, @TypeOf(error_value)).err(error_value);
}

/// Convert a Zig error union to a Result
pub fn fromErrorUnion(value: anytype) Result(
    @typeInfo(@TypeOf(value)).error_union.payload,
    @typeInfo(@TypeOf(value)).error_union.error_set,
) {
    const T = @typeInfo(@TypeOf(value)).error_union.payload;
    const E = @typeInfo(@TypeOf(value)).error_union.error_set;
    const ResultType = Result(T, E);

    if (value) |val| {
        return ResultType.ok(val);
    } else |e| {
        return ResultType.err(e);
    }
}

/// Transpose Result<?T, E> to ?Result(T, E)
/// If Ok(null), returns null. If Ok(some), returns Some(Ok(some)). If Err, returns Some(Err)
pub fn transpose(comptime T: type, comptime E: type, result: Result(?T, E)) ?Result(T, E) {
    return switch (result) {
        .success => |maybe_val| if (maybe_val) |val| Result(T, E).ok(val) else null,
        .failure => |e| Result(T, E).err(e),
    };
}

/// Collect a slice of Results into a Result of a slice
/// If any Result is Err, returns the first Err. Otherwise returns Ok with all values.
/// The caller owns the returned slice and must free it with the allocator.
/// Note: For error types that aren't error sets, OOM cannot be represented
pub fn collect(
    comptime T: type,
    comptime E: type,
    allocator: std.mem.Allocator,
    results: []const Result(T, E),
) Result([]T, E) {
    var values = std.ArrayList(T).initCapacity(allocator, results.len) catch {
        // Can't represent OOM for non-error-set E types
        // This is a known limitation
        @panic("Out of memory in collect");
    };
    errdefer values.deinit(allocator);

    for (results) |result| {
        switch (result) {
            .success => |val| values.append(allocator, val) catch {
                values.deinit(allocator);
                @panic("Out of memory in collect");
            },
            .failure => |e| {
                values.deinit(allocator);
                return Result([]T, E).err(e);
            },
        }
    }

    return Result([]T, E).ok(values.toOwnedSlice(allocator) catch {
        values.deinit(allocator);
        @panic("Out of memory in collect");
    });
}

/// Partition a slice of Results into separate Ok and Err slices
/// Returns a tuple of (ok_values, err_values)
/// Caller owns both slices and must free them.
pub fn partition(
    comptime T: type,
    comptime E: type,
    allocator: std.mem.Allocator,
    results: []const Result(T, E),
) !struct { oks: []T, errs: []E } {
    var oks = std.ArrayList(T).initCapacity(allocator, results.len) catch |e| return e;
    errdefer oks.deinit(allocator);

    var errs = std.ArrayList(E).initCapacity(allocator, results.len) catch |e| return e;
    errdefer errs.deinit(allocator);

    for (results) |result| {
        switch (result) {
            .success => |val| try oks.append(allocator, val),
            .failure => |err_val| try errs.append(allocator, err_val),
        }
    }

    return .{
        .oks = try oks.toOwnedSlice(allocator),
        .errs = try errs.toOwnedSlice(allocator),
    };
}

/// Sequence a slice of Results, succeeding only if all succeed
/// Similar to collect but more efficient as it stops at first error
pub fn sequence(
    comptime T: type,
    comptime E: type,
    allocator: std.mem.Allocator,
    results: []const Result(T, E),
) Result([]T, E) {
    // Quick check for any errors first
    for (results) |result| {
        if (result.isErr()) {
            return Result([]T, E).err(result.unwrapErr());
        }
    }

    // All are Ok, collect them
    var values = allocator.alloc(T, results.len) catch {
        @panic("Out of memory in sequence");
    };

    for (results, 0..) |result, i| {
        values[i] = result.unwrap();
    }

    return Result([]T, E).ok(values);
}

// Tests
test "Result.ok creates Ok variant" {
    const r = Result(i32, []const u8).ok(42);
    try std.testing.expect(r.isOk());
    try std.testing.expectEqual(42, r.unwrap());
}

test "Result.err creates Err variant" {
    const r = Result(i32, []const u8).err("error");
    try std.testing.expect(r.isErr());
    try std.testing.expectEqualStrings("error", r.unwrapErr());
}

test "Result.map transforms Ok values" {
    const r = Result(i32, []const u8).ok(21);
    const doubled = r.map(i32, struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double);

    try std.testing.expect(doubled.isOk());
    try std.testing.expectEqual(42, doubled.unwrap());
}

test "Result.map preserves Err" {
    const r = Result(i32, []const u8).err("failed");
    const doubled = r.map(i32, struct {
        fn double(x: i32) i32 {
            return x * 2;
        }
    }.double);

    try std.testing.expect(doubled.isErr());
    try std.testing.expectEqualStrings("failed", doubled.unwrapErr());
}

test "Result.mapErr transforms error values" {
    const r = Result(i32, []const u8).err("error");
    const mapped = r.mapErr([]const u8, struct {
        fn upper(_: []const u8) []const u8 {
            return "ERROR";
        }
    }.upper);

    try std.testing.expect(mapped.isErr());
    try std.testing.expectEqualStrings("ERROR", mapped.unwrapErr());
}

test "Result.andThen chains operations" {
    const r = Result(i32, []const u8).ok(10);
    const result = r.andThen(i32, struct {
        fn halveIfEven(x: i32) Result(i32, []const u8) {
            if (@mod(x, 2) == 0) {
                return Result(i32, []const u8).ok(@divTrunc(x, 2));
            }
            return Result(i32, []const u8).err("not even");
        }
    }.halveIfEven);

    try std.testing.expect(result.isOk());
    try std.testing.expectEqual(5, result.unwrap());
}

test "Result.andThen short circuits on error" {
    const r = Result(i32, []const u8).err("initial error");
    const result = r.andThen(i32, struct {
        fn halveIfEven(x: i32) Result(i32, []const u8) {
            return Result(i32, []const u8).ok(@divTrunc(x, 2));
        }
    }.halveIfEven);

    try std.testing.expect(result.isErr());
    try std.testing.expectEqualStrings("initial error", result.unwrapErr());
}

test "Result.unwrapOr returns value or default" {
    const ok_result = Result(i32, []const u8).ok(42);
    const err_result = Result(i32, []const u8).err("failed");

    try std.testing.expectEqual(42, ok_result.unwrapOr(0));
    try std.testing.expectEqual(0, err_result.unwrapOr(0));
}

test "Result.match provides pattern matching" {
    const r = Result(i32, []const u8).ok(42);
    const result = r.match([]const u8, .{
        .ok = struct {
            fn handleOk(x: i32) []const u8 {
                _ = x;
                return "success";
            }
        }.handleOk,
        .err = struct {
            fn handleErr(e: []const u8) []const u8 {
                return e;
            }
        }.handleErr,
    });

    try std.testing.expectEqualStrings("success", result);
}

test "Result.combine merges two Ok values" {
    const r1 = Result(i32, []const u8).ok(10);
    const r2 = Result(i32, []const u8).ok(20);
    const combined = r1.combine(r2);

    try std.testing.expect(combined.isOk());
    const values = combined.unwrap();
    try std.testing.expectEqual(10, values[0]);
    try std.testing.expectEqual(20, values[1]);
}

test "Result.combine returns first error" {
    const r1 = Result(i32, []const u8).err("error1");
    const r2 = Result(i32, []const u8).ok(20);
    const combined = r1.combine(r2);

    try std.testing.expect(combined.isErr());
    try std.testing.expectEqualStrings("error1", combined.unwrapErr());
}

test "fromErrorUnion converts error union to Result" {
    const success: anyerror!i32 = 42;
    const failure: anyerror!i32 = error.Failed;

    const ok_result = fromErrorUnion(success);
    const err_result = fromErrorUnion(failure);

    try std.testing.expect(ok_result.isOk());
    try std.testing.expectEqual(42, ok_result.unwrap());

    try std.testing.expect(err_result.isErr());
    try std.testing.expectEqual(error.Failed, err_result.unwrapErr());
}

test "Result.orElse provides fallback on error" {
    const r = Result(i32, []const u8).err("error");
    const fallback = r.orElse(struct {
        fn recover(e: []const u8) Result(i32, []const u8) {
            _ = e;
            return Result(i32, []const u8).ok(99);
        }
    }.recover);

    try std.testing.expect(fallback.isOk());
    try std.testing.expectEqual(99, fallback.unwrap());
}

test "Result.okOrNull converts to optional" {
    const ok_result = Result(i32, []const u8).ok(42);
    const err_result = Result(i32, []const u8).err("failed");

    try std.testing.expectEqual(@as(?i32, 42), ok_result.okOrNull());
    try std.testing.expectEqual(@as(?i32, null), err_result.okOrNull());
}

test "Result.inspect allows side effects on Ok" {
    const r = Result(i32, []const u8).ok(42);

    // Inspect is useful for logging/debugging - we just verify it returns the same result
    const result = r.inspect(struct {
        fn log(val: i32) void {
            _ = val; // In real code, would log here
        }
    }.log);

    // Should still be Ok with same value
    try std.testing.expect(result.isOk());
    try std.testing.expectEqual(42, result.unwrap());
}

test "Result.inspectErr allows side effects on Err" {
    const r = Result(i32, []const u8).err("failed");

    const result = r.inspectErr(struct {
        fn log(e: []const u8) void {
            _ = e; // In real code, would log here
        }
    }.log);

    try std.testing.expect(result.isErr());
    try std.testing.expectEqualStrings("failed", result.unwrapErr());
}

test "transpose converts Result of Option to Option of Result" {
    const ResultOptI32 = Result(?i32, []const u8);

    const some = ResultOptI32.ok(42);
    const none = ResultOptI32.ok(null);
    const err_result = ResultOptI32.err("failed");

    const transposed_some = transpose(i32, []const u8, some);
    const transposed_none = transpose(i32, []const u8, none);
    const transposed_err = transpose(i32, []const u8, err_result);

    try std.testing.expect(transposed_some != null);
    try std.testing.expect(transposed_some.?.isOk());
    try std.testing.expectEqual(42, transposed_some.?.unwrap());

    try std.testing.expect(transposed_none == null);

    try std.testing.expect(transposed_err != null);
    try std.testing.expect(transposed_err.?.isErr());
}

test "collect succeeds with all Ok values" {
    const allocator = std.testing.allocator;

    const results = [_]Result(i32, []const u8){
        Result(i32, []const u8).ok(1),
        Result(i32, []const u8).ok(2),
        Result(i32, []const u8).ok(3),
    };

    const collected = collect(i32, []const u8, allocator, &results);
    try std.testing.expect(collected.isOk());

    const values = collected.unwrap();
    defer allocator.free(values);

    try std.testing.expectEqual(3, values.len);
    try std.testing.expectEqual(1, values[0]);
    try std.testing.expectEqual(2, values[1]);
    try std.testing.expectEqual(3, values[2]);
}

test "collect fails with first error" {
    const allocator = std.testing.allocator;

    const results = [_]Result(i32, []const u8){
        Result(i32, []const u8).ok(1),
        Result(i32, []const u8).err("error"),
        Result(i32, []const u8).ok(3),
    };

    const collected = collect(i32, []const u8, allocator, &results);
    try std.testing.expect(collected.isErr());
    try std.testing.expectEqualStrings("error", collected.unwrapErr());
}

test "partition splits oks and errs" {
    const allocator = std.testing.allocator;

    const results = [_]Result(i32, []const u8){
        Result(i32, []const u8).ok(1),
        Result(i32, []const u8).err("error1"),
        Result(i32, []const u8).ok(2),
        Result(i32, []const u8).err("error2"),
        Result(i32, []const u8).ok(3),
    };

    const partitioned = try partition(i32, []const u8, allocator, &results);
    defer allocator.free(partitioned.oks);
    defer allocator.free(partitioned.errs);

    try std.testing.expectEqual(3, partitioned.oks.len);
    try std.testing.expectEqual(1, partitioned.oks[0]);
    try std.testing.expectEqual(2, partitioned.oks[1]);
    try std.testing.expectEqual(3, partitioned.oks[2]);

    try std.testing.expectEqual(2, partitioned.errs.len);
    try std.testing.expectEqualStrings("error1", partitioned.errs[0]);
    try std.testing.expectEqualStrings("error2", partitioned.errs[1]);
}

test "sequence returns all values if all Ok" {
    const allocator = std.testing.allocator;

    const results = [_]Result(i32, []const u8){
        Result(i32, []const u8).ok(10),
        Result(i32, []const u8).ok(20),
        Result(i32, []const u8).ok(30),
    };

    const sequenced = sequence(i32, []const u8, allocator, &results);
    try std.testing.expect(sequenced.isOk());

    const values = sequenced.unwrap();
    defer allocator.free(values);

    try std.testing.expectEqual(3, values.len);
    try std.testing.expectEqual(10, values[0]);
    try std.testing.expectEqual(20, values[1]);
    try std.testing.expectEqual(30, values[2]);
}

test "Result.toErrorUnion converts to Zig error union" {
    const ok_result = Result(i32, anyerror).ok(42);
    const err_result = Result(i32, anyerror).err(error.Failed);

    const ok_union = ok_result.toErrorUnion();
    const err_union = err_result.toErrorUnion();

    // Test ok case
    if (ok_union) |val| {
        try std.testing.expectEqual(42, val);
    } else |_| {
        try std.testing.expect(false); // Should not reach here
    }

    // Test err case
    if (err_union) |_| {
        try std.testing.expect(false); // Should not reach here
    } else |e| {
        try std.testing.expectEqual(error.Failed, e);
    }
}
