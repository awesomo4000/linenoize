const Build = @import("std").Build;

pub fn build(b: *Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Use vendored wcwidth - no network required!
    const wcwidth = b.addModule("wcwidth", .{
        .root_source_file = b.path("vendor/wcwidth/src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const linenoise = b.addModule("linenoise", .{
        .root_source_file = b.path("src/main.zig"),
        .imports = &.{
            .{ .name = "wcwidth", .module = wcwidth },
        },
        .target = target,
        .optimize = optimize,
    });

    // Static library
    const lib = b.addLibrary(.{
        .name = "linenoise",
        .linkage = .static,
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/c.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    lib.root_module.addImport("wcwidth", wcwidth);
    lib.linkLibC();
    b.installArtifact(lib);

    // Tests
    const main_tests = b.addTest(.{
        .root_module = linenoise,
    });

    const run_main_tests = b.addRunArtifact(main_tests);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&run_main_tests.step);

    // Zig example
    var example = b.addExecutable(.{
        .name = "example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/example.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    example.root_module.addImport("linenoise", linenoise);
    b.installArtifact(example);

    var example_run = b.addRunArtifact(example);

    const example_step = b.step("run-example", "Run example");
    example_step.dependOn(&example_run.step);

    // C example
    var c_example = b.addExecutable(.{
        .name = "c-example",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
        }),
    });
    c_example.root_module.addCSourceFile(.{ .file = b.path("examples/example.c") });
    c_example.addIncludePath(b.path("include"));
    c_example.linkLibC();
    c_example.linkLibrary(lib);
    b.installArtifact(c_example);

    var c_example_run = b.addRunArtifact(c_example);

    const c_example_step = b.step("run-c-example", "Run C example");
    c_example_step.dependOn(&c_example_run.step);
    c_example_step.dependOn(&lib.step);

    // Simple REPL example
    var simple_repl = b.addExecutable(.{
        .name = "simple-repl",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/simple-repl.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    simple_repl.root_module.addImport("linenoise", linenoise);
    b.installArtifact(simple_repl);

    var simple_repl_run = b.addRunArtifact(simple_repl);
    if (b.args) |args| {
        simple_repl_run.addArgs(args);
    }

    const run_simple_repl_step = b.step("run-simple-repl", "Run simple REPL with hints");
    run_simple_repl_step.dependOn(&simple_repl_run.step);
}
