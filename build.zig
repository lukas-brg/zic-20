const std = @import("std");


pub fn build(b: *std.Build) void {
    
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

 
    const exe = b.addExecutable(.{
        .name = "sc64",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    
    });
    
    exe.root_module.addAnonymousImport("clap", .{ .root_source_file =  b.path("lib/clap/clap.zig")});
    exe.linkSystemLibrary("SDL2");
    
    
    //exe.linkLibC();

    const raylib_dep = b.dependency("raylib", .{
        .target = target,
    });
    exe.linkLibrary(raylib_dep.artifact("raylib"));

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);


    const exe_unit_tests = b.addTest(.{
        .root_source_file =  b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
