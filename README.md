# Zig Result Type

A type-safe error handling library for Zig inspired by Rust's `Result<T, E>` and TypeScript's [neverthrow](https://github.com/supermacro/neverthrow).

## Features

- **Type-safe error handling** - No more guessing what errors a function might return
- **Chainable operations** - Compose multiple fallible operations with `andThen`, `map`, and more
- **Pattern matching** - Use `match` for elegant error handling
- **Zero runtime overhead** - Compiles down to efficient Zig code
- **Familiar API** - If you know Rust's Result or neverthrow, you'll feel right at home
- **Comprehensive utilities** - `unwrap`, `unwrapOr`, `combine`, and many more helpers
- **Collection operations** - `collect`, `partition`, and `sequence` for working with arrays of Results
- **Advanced transformations** - `flatten`, `transpose`, `inspect` for complex workflows
- **Safe unwrapping** - Convert to Zig error unions with `toErrorUnion()`

## Installation

Add this library to your `build.zig.zon`:

```zig
.{
    .name = "my-project",
    .version = "0.1.0",
    .dependencies = .{
        .result = .{
            .url = "https://github.com/yourusername/zig-result/archive/refs/tags/v0.1.0.tar.gz",
            // Add hash after first fetch
        },
    },
}
```

Then in your `build.zig`:

```zig
const result = b.dependency("result", .{
    .target = target,
    .optimize = optimize,
});

exe.root_module.addImport("result", result.module("result"));
```

Or simply copy `src/result.zig` into your project.

## Quick Start

```zig
const std = @import("std");
const Result = @import("result").Result;

fn divide(a: i32, b: i32) Result(i32, []const u8) {
    if (b == 0) {
        return Result(i32, []const u8).err("Division by zero");
    }
    return Result(i32, []const u8).ok(@divTrunc(a, b));
}

pub fn main() !void {
    const result = divide(10, 2);

    if (result.isOk()) {
        std.debug.print("Result: {d}\n", .{result.unwrap()});
    } else {
        std.debug.print("Error: {s}\n", .{result.unwrapErr()});
    }
}
```

## Core Concepts

### Creating Results

```zig
// Create an Ok result
const success = Result(i32, []const u8).ok(42);

// Create an Err result
const failure = Result(i32, []const u8).err("Something went wrong");

// Check result status
if (success.isOk()) { /* ... */ }
if (failure.isErr()) { /* ... */ }
```

### Transforming Values

#### `map` - Transform success values

```zig
const result = Result(i32, []const u8).ok(21);

const doubled = result.map(i32, struct {
    fn double(x: i32) i32 {
        return x * 2;
    }
}.double);

// doubled is Result(i32, []const u8).ok(42)
```

#### `mapErr` - Transform error values

```zig
const result = Result(i32, []const u8).err("failed");

const mapped = result.mapErr([]const u8, struct {
    fn toUpper(s: []const u8) []const u8 {
        return "FAILED";
    }
}.toUpper);

// mapped is Result(i32, []const u8).err("FAILED")
```

### Chaining Operations

#### `andThen` - Chain multiple fallible operations

```zig
fn parseNumber(str: []const u8) Result(i32, []const u8) {
    const num = std.fmt.parseInt(i32, str, 10) catch {
        return Result(i32, []const u8).err("Invalid number");
    };
    return Result(i32, []const u8).ok(num);
}

fn validatePositive(n: i32) Result(i32, []const u8) {
    if (n <= 0) {
        return Result(i32, []const u8).err("Number must be positive");
    }
    return Result(i32, []const u8).ok(n);
}

const result = parseNumber("42").andThen(i32, validatePositive);
// If parsing succeeds, validates the number
// If either fails, returns the error
```

#### `orElse` - Provide fallback on error

```zig
const result = Result(i32, []const u8).err("failed");

const recovered = result.orElse(struct {
    fn fallback(e: []const u8) Result(i32, []const u8) {
        _ = e;
        return Result(i32, []const u8).ok(0); // Default value
    }
}.fallback);

// recovered is Result(i32, []const u8).ok(0)
```

### Pattern Matching

```zig
const result = Result(i32, []const u8).ok(42);

const message = result.match([]const u8, .{
    .ok = struct {
        fn handleOk(x: i32) []const u8 {
            return "Success!";
        }
    }.handleOk,
    .err = struct {
        fn handleErr(e: []const u8) []const u8 {
            return e;
        }
    }.handleErr,
});
```

### Extracting Values

```zig
// Get value or panic
const value = result.unwrap();

// Get value or use default
const value = result.unwrapOr(0);

// Get value or compute from error
const value = result.unwrapOrElse(struct {
    fn compute(e: []const u8) i32 {
        return 0;
    }
}.compute);

// Get value or panic with custom message
const value = result.expect("Expected a valid number");
```

### Combining Results

```zig
const r1 = Result(i32, []const u8).ok(10);
const r2 = Result(i32, []const u8).ok(20);

const combined = r1.combine(r2);
// combined is Result(struct { i32, i32 }, []const u8).ok(.{ 10, 20 })

const values = combined.unwrap();
const sum = values[0] + values[1]; // 30
```

### Working with Error Unions

Convert between Zig's native error unions and Results:

```zig
const fromErrorUnion = @import("result").fromErrorUnion;

// Convert error union to Result
const errorUnion: anyerror!i32 = 42;
const result = fromErrorUnion(errorUnion);
// result is Result(i32, anyerror).ok(42)

// Convert Result to error union for safe unwrapping
const result = Result(i32, anyerror).ok(42);
const error_union = result.toErrorUnion(); // Returns anyerror!i32
```

### Working with Collections of Results

#### Collect - Transform slice of Results to Result of slice

```zig
const results = [_]Result(i32, []const u8){
    Result(i32, []const u8).ok(1),
    Result(i32, []const u8).ok(2),
    Result(i32, []const u8).ok(3),
};

const collected = collect(i32, []const u8, allocator, &results);
// If all Ok: Result([]i32, []const u8).ok([1, 2, 3])
// If any Err: Returns first error
defer if (collected.isOk()) allocator.free(collected.unwrap());
```

#### Partition - Split into separate Ok and Err arrays

```zig
const results = [_]Result(i32, []const u8){
    Result(i32, []const u8).ok(1),
    Result(i32, []const u8).err("error1"),
    Result(i32, []const u8).ok(2),
};

const partitioned = try partition(i32, []const u8, allocator, &results);
defer allocator.free(partitioned.oks);
defer allocator.free(partitioned.errs);
// partitioned.oks = [1, 2]
// partitioned.errs = ["error1"]
```

#### Sequence - Short-circuit on first error

```zig
const results = [_]Result(i32, []const u8){
    Result(i32, []const u8).ok(10),
    Result(i32, []const u8).ok(20),
};

const sequenced = sequence(i32, []const u8, allocator, &results);
// Stops at first error, otherwise returns all Ok values
defer if (sequenced.isOk()) allocator.free(sequenced.unwrap());
```

### Advanced Operations

#### Inspect - Side effects without transformation

```zig
const result = Result(i32, []const u8).ok(42)
    .inspect(struct {
        fn log(val: i32) void {
            std.debug.print("Value: {d}\n", .{val});
        }
    }.log)
    .inspectErr(struct {
        fn logErr(e: []const u8) void {
            std.debug.print("Error: {s}\n", .{e});
        }
    }.logErr);
```

#### Transpose - Convert Result of Optional to Optional of Result

```zig
const transpose = @import("result").transpose;

const result_opt = Result(?i32, []const u8).ok(42);
const opt_result = transpose(i32, []const u8, result_opt);
// Some(Result(i32).ok(42))

const result_none = Result(?i32, []const u8).ok(null);
const none = transpose(i32, []const u8, result_none);
// null
```

#### Flatten - Unwrap nested Results

```zig
const nested = Result(Result(i32, []const u8), []const u8).ok(
    Result(i32, []const u8).ok(42)
);
const flattened = nested.flatten();
// Result(i32, []const u8).ok(42)
```

## API Reference

### Construction

- `Result(T, E).ok(value: T)` - Create a success result
- `Result(T, E).err(error: E)` - Create an error result

### Checking Status

- `isOk() bool` - Returns true if Ok
- `isErr() bool` - Returns true if Err

### Transformations

- `map(U, func: fn(T) U) Result(U, E)` - Transform Ok value
- `mapErr(F, func: fn(E) F) Result(T, F)` - Transform Err value
- `mapBoth(U, okFunc, errFunc) U` - Transform both variants

### Chaining

- `andThen(U, func: fn(T) Result(U, E)) Result(U, E)` - Chain operations (flatMap)
- `orElse(func: fn(E) Self) Self` - Provide fallback on error
- `andResult(other: Self) Self` - Return other if Ok, self if Err
- `orResult(other: Self) Self` - Return self if Ok, other if Err

### Extraction

- `unwrap() T` - Get Ok value or panic
- `unwrapErr() E` - Get Err value or panic
- `unwrapOr(default: T) T` - Get Ok value or default
- `unwrapOrElse(func: fn(E) T) T` - Get Ok value or compute from error
- `expect(msg: []const u8) T` - Get Ok value or panic with message
- `expectErr(msg: []const u8) E` - Get Err value or panic with message

### Pattern Matching

- `match(U, handlers: struct { ok: fn(T) U, err: fn(E) U }) U` - Pattern match on result

### Combining

- `combine(other: Self) Result(struct { T, T }, E)` - Combine two results

### Conversion

- `okOrNull() ?T` - Convert to optional, discarding error
- `errOrNull() ?E` - Convert to optional error, discarding value
- `fromErrorUnion(value: anytype) Result(...)` - Convert error union to Result
- `toErrorUnion() E!T` - Convert Result to Zig error union for safe unwrapping

### Inspection & Side Effects

- `inspect(func: fn(T) void) Self` - Inspect Ok value without transformation (for logging/debugging)
- `inspectErr(func: fn(E) void) Self` - Inspect Err value without transformation

### Advanced Transformations

- `flatten() Self` - Flatten nested Result (Result(Result(T, E), E) -> Result(T, E))
- `transpose(T, E, Result(?T, E)) ?Result(T, E)` - Convert Result of Optional to Optional of Result

### Collection Operations

- `collect(T, E, allocator, []Result(T, E)) Result([]T, E)` - Transform slice of Results to Result of slice
- `partition(T, E, allocator, []Result(T, E)) {oks: []T, errs: []E}` - Split Results into separate Ok and Err arrays
- `sequence(T, E, allocator, []Result(T, E)) Result([]T, E)` - Short-circuit on first error, collect all Ok values

## Examples

See the [`examples/`](examples/) directory for comprehensive examples.

Run the example:

```bash
zig build run-example
```

## Testing

Run the test suite:

```bash
zig build test
```

## Comparison with Zig's Error Unions

Zig has built-in error unions (`!T`), which are great for simple cases. This library provides additional benefits:

| Feature | Error Union (`!T`) | Result Type |
|---------|-------------------|-------------|
| Type safety | Error set only | Any error type |
| Explicit errors | No | Yes |
| Chainable | Limited | Yes |
| Pattern matching | Via `catch` | Via `match` |
| Transform errors | Via `catch` | Via `mapErr` |
| Combine results | Manual | `combine` |

Use error unions when:
- You want the simplest solution
- Errors are exceptional cases
- You're okay with `try`/`catch` syntax

Use Result when:
- Errors are expected and need explicit handling
- You want functional composition
- You need fine-grained control over error flow
- You prefer explicit over implicit error propagation

## Comparison with Rust and neverthrow

If you're coming from Rust or TypeScript:

| Rust | neverthrow | Zig Result |
|------|-----------|------------|
| `Result::Ok(v)` | `ok(v)` | `Result(T, E).ok(v)` |
| `Result::Err(e)` | `err(e)` | `Result(T, E).err(e)` |
| `.map(f)` | `.map(f)` | `.map(U, f)` |
| `.map_err(f)` | `.mapErr(f)` | `.mapErr(F, f)` |
| `.and_then(f)` | `.andThen(f)` | `.andThen(U, f)` |
| `.or_else(f)` | `.orElse(f)` | `.orElse(f)` |
| `.unwrap()` | `.unwrap()` | `.unwrap()` |
| `.unwrap_or(d)` | `.unwrapOr(d)` | `.unwrapOr(d)` |
| `.match` (via `match`) | `.match` | `.match(U, handlers)` |

## License

MIT

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## Acknowledgments

Inspired by:
- Rust's `Result<T, E>` type
- TypeScript's [neverthrow](https://github.com/supermacro/neverthrow) library
- Functional programming error handling patterns
