const std = @import("std");

pub fn build(b: *std.Build) void {
    const upstream = b.dependency("oneTBB", .{});
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const linkage = b.option(std.builtin.LinkMode, "linkage", "Link mode") orelse .dynamic;

    const tbb = createLibrary(
        b,
        upstream,
        target,
        optimize,
        linkage,
        "tbb",
        tbb_files,
        tbb_win32_resource_file,
    );
    tbb.root_module.addCMacro("__TBB_BUILD", "1");
    tbb.installHeadersDirectory(upstream.path("include"), "include", .{});

    const tbb_malloc = createLibrary(
        b,
        upstream,
        target,
        optimize,
        linkage,
        "tbbmalloc",
        tbb_malloc_files,
        tbb_malloc_win32_resource_file,
    );
    tbb_malloc.root_module.addCMacro("__TBBMALLOC_BUILD", "1");

    const tbb_malloc_proxy = createLibrary(
        b,
        upstream,
        target,
        optimize,
        linkage,
        "tbbmalloc_proxy",
        tbb_malloc_proxy_files,
        tbb_malloc_proxy_win32_resource_file,
    );
    tbb_malloc_proxy.root_module.addCMacro("__TBBMALLOCPROXY_BUILD", "1");
}

fn createLibrary(b: *std.Build, upstream: *std.Build.Dependency, target: std.Build.ResolvedTarget, optimize: std.builtin.OptimizeMode, linkage: std.builtin.LinkMode, name: []const u8, cpp_files: []const []const u8, win32_resource_file: []const u8) *std.Build.Step.Compile {
    const lib = b.addLibrary(.{
        .linkage = linkage,
        .name = name,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
            .link_libcpp = true,
        }),
    });

    if (optimize == std.builtin.OptimizeMode.Debug) {
        lib.root_module.addCMacro("TBB_USE_DEBUG", "1");
    }
    if (linkage == std.builtin.LinkMode.static) {
        lib.root_module.addCMacro("__TBB_DYNAMIC_LOAD_ENABLED", "0");
        lib.root_module.addCMacro("__TBB_SOURCE_DIRECTLY_INCLUDED", "1");
    }
    switch (target.result.cpu.arch) {
        std.Target.Cpu.Arch.arm, std.Target.Cpu.Arch.aarch64, std.Target.Cpu.Arch.mips, std.Target.Cpu.Arch.riscv32, std.Target.Cpu.Arch.riscv64 => {
            // NOP
        },
        else => {
            lib.root_module.addCMacro("__TBB_USE_ITT_NOTIFY", "1");
        },
    }

    // TBB defines various XXX.cmake files (one for each compiler type) which
    // defines a series of preprocessor defines and compiler flags
    // Zig is clang-based, so we can "hardcode" those configs here, rather than
    // needing to copy all the different configs for each different compiler

    var compile_flags = std.ArrayList([]const u8).empty;
    // Make sure we're in C++ mode
    compile_flags.append(b.allocator, "-std=c++17") catch @panic("OOM");

    // Enable Intel(R) Transactional Synchronization Extensions (-mrtm) on relevant processors
    switch (target.result.cpu.arch) {
        std.Target.Cpu.Arch.x86, std.Target.Cpu.Arch.x86_64 => {
            compile_flags.append(b.allocator, "-mrtm") catch @panic("OOM");
        },
        else => {
            // NOP
        },
    }
    // Clang is very unhappy about -mwaitpkg coordination with function inlining, so we
    // just disable it completely.
    // However, __TBB_WAITPKG_INTRINSICS_PRESENT is defined unconditionally, so we have to
    // do a bit of hacking to undefine and redefine it
    lib.root_module.addIncludePath(b.path(".")); // directory containing the shim
    compile_flags.append(b.allocator, "-include") catch @panic("OOM");
    compile_flags.append(b.allocator, "config_shim.h") catch @panic("OOM");

    lib.root_module.addIncludePath(upstream.path("src"));
    lib.root_module.addIncludePath(upstream.path("include"));

    lib.root_module.addCSourceFiles(.{
        .root = upstream.path("src"),
        .files = cpp_files,
        .flags = compile_flags.items,
    });

    if (target.result.os.tag != std.Target.Os.Tag.windows) {
        // Expose POSIX features (sem_t) to C/C++ headers
        lib.root_module.addCMacro("_XOPEN_SOURCE", "700");
        lib.linkSystemLibrary("pthread");
    }

    if (target.result.os.tag == std.Target.Os.Tag.windows) {
        lib.addWin32ResourceFile(.{ .file = upstream.path(win32_resource_file) });
    }

    b.installArtifact(lib);

    return lib;
}

const tbb_files: []const []const u8 = &.{
    "tbb/address_waiter.cpp",
    "tbb/allocator.cpp",
    "tbb/arena.cpp",
    "tbb/arena_slot.cpp",
    "tbb/concurrent_bounded_queue.cpp",
    "tbb/dynamic_link.cpp",
    "tbb/exception.cpp",
    "tbb/governor.cpp",
    "tbb/global_control.cpp",
    "tbb/itt_notify.cpp",
    "tbb/main.cpp",
    "tbb/market.cpp",
    "tbb/tcm_adaptor.cpp",
    "tbb/misc.cpp",
    "tbb/misc_ex.cpp",
    "tbb/observer_proxy.cpp",
    "tbb/parallel_pipeline.cpp",
    "tbb/private_server.cpp",
    "tbb/profiling.cpp",
    "tbb/rml_tbb.cpp",
    "tbb/rtm_mutex.cpp",
    "tbb/rtm_rw_mutex.cpp",
    "tbb/semaphore.cpp",
    "tbb/small_object_pool.cpp",
    "tbb/task.cpp",
    "tbb/task_dispatcher.cpp",
    "tbb/task_group_context.cpp",
    "tbb/thread_dispatcher.cpp",
    "tbb/thread_request_serializer.cpp",
    "tbb/threading_control.cpp",
    "tbb/version.cpp",
    "tbb/queuing_rw_mutex.cpp",
};
const tbb_win32_resource_file: []const u8 = "tbb/tbb.rc";

const tbb_malloc_files: []const []const u8 = &.{
    "tbbmalloc/backend.cpp",
    "tbbmalloc/backref.cpp",
    "tbbmalloc/frontend.cpp",
    "tbbmalloc/large_objects.cpp",
    "tbbmalloc/tbbmalloc.cpp",
    //"tbb/itt_notify.cpp",
};
const tbb_malloc_win32_resource_file: []const u8 = "tbbmalloc/tbbmalloc.rc";

const tbb_malloc_proxy_files: []const []const u8 = &.{
    "tbbmalloc_proxy/function_replacement.cpp",
    "tbbmalloc_proxy/proxy.cpp",
};
const tbb_malloc_proxy_win32_resource_file: []const u8 = "tbbmalloc_proxy/tbbmalloc_proxy.rc";
