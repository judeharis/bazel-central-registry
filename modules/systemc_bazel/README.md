# systemc_bazel

Bazel module wrapping Accellera SystemC 2.3.3. Every version downloads the same
upstream tarball (`systemc-2.3.3.tar.gz`); the only thing that differs between
versions is the `BUILD.bazel` injected by `patches/add_build_file.patch`, which
decides how SystemC is compiled. The exposed target is always
`@systemc_bazel//:systemc_lib`.

## Version summary

| Version | Build method | Compiler | C++ std | Status |
|---------|--------------|----------|---------|--------|
| 2.3.3   | `rules_foreign_cc` `cmake()` | `g++` / `gcc` | 14 | Original |
| 2.3.3b  | `rules_foreign_cc` `cmake()` | `g++` / `gcc` | 17 | Superseded |
| 2.3.3c  | `rules_foreign_cc` `cmake()` | `clang++` / `clang` via wrapper scripts | 17 | Working |
| 2.3.3d  | Plain `genrule` running cmake + make | `clang++` / `clang` | 17 | Working |
| 2.3.3e  | Native `cc_library` (no cmake) | Project's Bazel toolchain | 17 | Working |
| 2.3.3f  | 2.3.3e + optional pthread coroutines | Project's Bazel toolchain | 17 | Working, recommended |

## Differences in detail

### 2.3.3
First version. `cmake()` rule from `rules_foreign_cc`, building with `g++`/`gcc`
and `CMAKE_CXX_STANDARD=14`.

### 2.3.3b
Same as 2.3.3 but with `CMAKE_CXX_STANDARD=17`.

### 2.3.3c
Same `cmake()` rule, but switched to clang and added
`CMAKE_POLICY_VERSION_MINIMUM=3.1` (newer CMake rejects the old policy version
in the SystemC `CMakeLists.txt`).

Problem this solves: `rules_foreign_cc` always passes the registered Bazel
C++ toolchain's flags to CMake through the `CFLAGS`/`CXXFLAGS` environment
variables, even when `CC`/`CXX` point at clang. With a GCC toolchain (for
example `aspect_gcc_toolchain`) those include GCC-only flags such as
`-fno-canonical-system-headers` and `-pass-exit-codes`, which clang rejects,
so CMake's compiler check fails. Setting `generate_crosstool_file = False` or
empty `CMAKE_CXX_FLAGS` does not help because the flags come through the
environment.

Fix: `CC`/`CXX` point at `clang_wrapper.sh` / `clangxx_wrapper.sh` (shipped in
the same patch, mode 755). They drop those two flags and `exec` clang/clang++.

### 2.3.3d
Drops `rules_foreign_cc`. A `genrule` runs `cmake` and `make install` directly
with `clang`/`clang++`. Because a plain shell command does not inherit the
toolchain flags, no wrapper scripts are needed.

The catch is that a genrule can only expose files it declares as outputs, and
`glob()` runs before the genrule does, so it cannot find installed headers.
The patch therefore lists all 279 installed header files explicitly as genrule
outputs (generated from a real install of 2.3.3). This list is specific to
SystemC 2.3.3 and must be regenerated if the upstream version changes.
Sources are declared as genrule inputs (excluding `docs`, `examples`,
`msvc10`) and everything is built inside Bazel's output directory.

### 2.3.3e
No cmake at all. SystemC is compiled by Bazel as an ordinary `cc_library`:

- the 85 `.cpp` files taken from SystemC's own `src/CMakeLists.txt`
- QuickThreads coroutines: `qt.c` plus a `select()` on CPU for
  `iX86_64.s` (x86_64) or `aarch64.s` (aarch64)
- the same default defines cmake uses (`SC_BUILD`, `SC_INCLUDE_FX`,
  `SC_ENABLE_ASSERTIONS`, `SC_ENABLE_EARLY_MAXTIME_CREATION`,
  `SC_ENABLE_SIMULATION_PHASE_CALLBACKS_TRACING`), kept as `local_defines`
- headers used in place from `systemc-2.3.3/src` (so `<systemc.h>` and
  `<tlm.h>` resolve directly)
- `-lpthread` link option; depends on `rules_cc` and `platforms` only

Benefits: SystemC is built with the project's own toolchain and flags, so there
is no clang/GCC flag mismatch, no wrapper scripts, no header list, and it
rebuilds incrementally.

Notes:
- `SC_INCLUDE_FX` is private (as in the cmake build). Code that uses `sc_fixed`
  and friends must define `SC_INCLUDE_FX` itself.
- Verified by building `benchmark_model_plus_vm_delegate` and by running a
  standalone simulation (clocked `SC_CTHREAD`, `SC_THREAD` events, 50
  coroutine threads, `sc_fixed`).
- Coroutine assembly is only selected for x86_64 and aarch64; other CPUs would
  need another `select()` branch (see `QT_ARCH` in SystemC's `src/CMakeLists.txt`).

### 2.3.3f
Identical to 2.3.3e (native `cc_library`, same sources and defines) plus an
opt-in debugging mode. The default QuickThreads backend runs each `SC_THREAD`
on its own stack, so a debugger's call stack for a thread ends at `qt_blocki`.
Build with `--define=systemc_pthreads=1` (use `-c dbg`) to use one POSIX thread
per `SC_THREAD` instead: this defines `SC_USE_PTHREADS` (also exported to
consumers) and drops the QuickThreads sources. The stack then unwinds cleanly
to `start_thread` and every SystemC process appears as its own thread in
gdb/VSCode. It is slower, and the scheduler (`sc_start` -> kernel) stays on the
main thread, so it shows up as a separate thread, not as a continuation of the
process's stack. Without the define the build is the same as 2.3.3e.

## Which one to use

Use 2.3.3f (2.3.3e if you never need the pthread debug mode). Use 2.3.3c or 2.3.3d only if you need the cmake-built layout
(headers under `install/include/systemc`). 2.3.3 and 2.3.3b are the older
GCC-based cmake builds.

## Updating a version

After editing `patches/add_build_file.patch`, update the patch hash in
`source.json`:

    openssl dgst -sha256 -binary patches/add_build_file.patch | openssl base64 -A

and prefix the result with `sha256-`. Bazel caches fetched modules by version,
so after a change run `bazel shutdown` and delete the cached
`external/systemc_bazel~<version>` directory and its `.marker` file.
