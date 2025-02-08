const mem = std.mem;
const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "-- [app-name] [--arg...]");
    defer if (run_step.dependencies.items.len == 0)
        run_step.dependOn(&b.addFail("[app-name] isn't specified").step);

    // Similar to creating the run step above, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");

    const sdl3_lib = b.dependency("sdl", .{
        .target = target,
        .optimize = optimize,
        .preferred_link_mode = .static, // or .dynamic
    }).artifact("SDL3");

    const zigimg_mod = b.dependency("zigimg", .{
        .target = target,
        .optimize = optimize,
    }).module("zigimg");

    // -------------------------[ Library ]-------------------------

    // This creates a "module", which represents a collection of source files alongside
    // some compilation options, such as optimization mode and linked system libraries.
    // Every executable or library we compile will be based on one or more modules.
    const lib_mod = b.createModule(.{
        // `root_source_file` is the Zig "entry point" of the module. If a module
        // only contains e.g. external object files, you can make this `null`.
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = b.path("src/lib.zig"),
        .target = target,
        .optimize = optimize,
    });
    lib_mod.addImport("zigimg", zigimg_mod);

    {
        // Creates a step for unit testing. This only builds the test executable
        // but does not run it.
        const lib_unit_tests = b.addTest(.{ .root_module = lib_mod });
        lib_unit_tests.linkLibrary(sdl3_lib);

        test_step.dependOn(&b.addRunArtifact(lib_unit_tests).step);

        b.step("docs", "Emit documentation").dependOn(&b.addInstallDirectory(.{
            .source_dir = lib_unit_tests.getEmittedDocs(),
            .install_dir = .prefix,
            .install_subdir = "docs",
        }).step);
    }

    // -------------------------[ Executables ]-------------------------

    inline for (.{"3.pool-end-game"}) |app_name| {
        // We will also create a module for our other entry point, 'main.zig'.
        const exe_mod = b.createModule(.{
            // `root_source_file` is the Zig "entry point" of the module. If a module
            // only contains e.g. external object files, you can make this `null`.
            // In this case the main source file is merely a path, however, in more
            // complicated build scripts, this could be a generated file.
            .root_source_file = b.path("src/" ++ app_name ++ "/sdl_app.zig"),
            .target = target,
            .optimize = optimize,

            // Modules can depend on one another using the `std.Build.Module.addImport` function.
            // This is what allows Zig source code to use `@import("foo")` where 'foo' is not a
            // file path. In this case, we set up `exe_mod` to import `lib_mod`.
            .imports = &.{.{ .name = "lib", .module = lib_mod }},
        });

        // This creates another `std.Build.Step.Compile`, but this one builds an executable
        // rather than a static library.
        const exe = b.addExecutable(.{
            .name = app_name,
            .root_module = exe_mod,
        });
        exe.linkLibrary(sdl3_lib);

        // This declares intent for the executable to be installed into the
        // standard location when the user invokes the "install" step (the default
        // step when running `zig build`).
        const install_artifact = b.addInstallArtifact(exe, .{ .dest_dir = .{ .override = .prefix } });
        b.getInstallStep().dependOn(&install_artifact.step);

        // This *creates* a Run step in the build graph, to be executed when another
        // step is evaluated that depends on it. The next line below will establish
        // such a dependency.
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(&install_artifact.step);

        test_step.dependOn(&b.addRunArtifact(b.addTest(.{ .root_module = exe_mod })).step);

        // This allows the user to pass arguments to the application in the build command itself
        if (b.args) |args|
            if (mem.eql(u8, args[0], app_name)) {
                run_cmd.addArgs(args[1..]);
                run_step.dependOn(&run_cmd.step);
            };
        b.step(app_name, "Build the app").dependOn(&install_artifact.step);
    }
}
