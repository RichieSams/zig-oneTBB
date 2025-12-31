# oneTBB

This is [oneTBB](https://github.com/uxlfoundation/oneTBB), packaged for [Zig](https://ziglang.org/).

## Installation

First, update your `build.zig.zon`:

```bash
# Initialize a `zig build` project if you haven't already
zig init
zig fetch --save git+https://github.com/RichieSams/zig-oneTBB.git#2022.3.0
```

You can then import `oneTBB` in your `build.zig` with:

```zig
const oneTBB_dependency = b.dependency("oneTBB", .{
    .target = target,
    .optimize = optimize,
    .linkage = linkage,
});
your_exe.linkLibrary(oneTBB_dependency.artifact("tbb"));
your_exe.linkLibrary(oneTBB_dependency.artifact("tbbmalloc"));
```
