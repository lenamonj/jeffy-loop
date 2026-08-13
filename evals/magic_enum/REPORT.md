# Jeffy eval: Neargye/magic_enum

**Target**: [Neargye/magic_enum](https://github.com/Neargye/magic_enum) (6,165 stars, verified via `gh api repos/Neargye/magic_enum --jq '.stargazers_count'` on 2026-08-12) at tag `v0.9.8`, commit `1384769c66bd16ec9bb1353f45fe8ec8ccc12dbd`, MIT. C++, in a local clone; the loop's work was never pushed anywhere. magic_enum is a header-only static reflection library for enums, used to get an enum's name from its value and its value from its name at compile time.

**Convergence standard**: evaluator countersigned. The adversarial evaluator's verdict for this run is in the narrative below; the standard each target met is recorded in [evals/ATTEMPTS.md](../ATTEMPTS.md).

**This is a full `/jeffy` loop run that reached machine-checked convergence, in two runs of 19 iterations against a pre-registered budget of three.** **Fifteen findings closed - 7 High, 6 Medium, 2 Low** - with **five Lows carried** at the declaration. The shipped change is **14 files, +809/-58**, of which the runtime surface is two headers. Converged at `3edf055dd488b3ae610d77b5e1e0f744952392c1` on 2026-08-12, with the adversarial evaluator's PASS at **invocation 1 of run 2**, the only invocation the target ever spent.

## Six of the seven Highs have one cause, and it is not a coding mistake

`magic_enum_containers.hpp` ships `array`, `bitset` and `set`, drop-in containers keyed by an enum. **No translation unit in the project ever instantiated their non-template members**, so nothing ever compiled them. C++ does not diagnose the body of an uninstantiated class template member, and a test suite that never names a member grades nothing about it. Six public members were broken:

- **C1** `bitset::all()` returned wrong answers and, at some enum sizes, did not return at all. Two defects sat in one eleven-line function. It falls off the end of a non-void function whenever the enumerator count exactly fills the base word, so a 32-enumerator enum executing `set(); all();` dies on the `ud2` the compiler plants there; the probe exited 132 on SIGILL. Separately `auto check = ~a[i]` promotes a narrow `base_type` to `int`, so a saturated `uint8` word compares as `-256` rather than `0` and every full word reports incomplete. This is the one that is silent: an 8-enumerator enum with every bit set answered `all() == false` and nothing crashed.
- **C2** `array`'s six reverse-iterator accessors declare a return type nothing can convert to, so every call is a hard compile error on documented API.
- **C3** the raw `const char_type*` constructor of `bitset` delegates to a constructor overload that does not exist.
- **C4** `set::operator=` over an initializer list has no return statement.
- **C6** the name-parsing `bitset` constructor never initializes its storage.
- **C5**, the independent one: `magic_enum_format.hpp` guards its `std::formatter` specialization on `__cpp_lib_format` without including anything that defines it, so in the natural include order the specialization is silently omitted. The project's own module file includes `<version>` first, which is why the module path worked; the suite's own format test includes `<format>` before the magic_enum header, which is why the suite never saw it.

The seventh, **A1**, is a build that has never run: configuring with `-DMAGIC_ENUM_OPT_ENABLE_NONASCII=TRUE` fails outright, because two of the project's own sources declare an enumerator whose identifier is an **emoji**. That is not a valid C++ identifier; g++ 15.2 rejects it under the `-pedantic-errors` those targets already carry and clang 17 rejects it with no flags at all. It reproduced down to a two-line file. The fix substitutes Greek identifiers, which are valid extended identifiers, in paired identifier-and-literal renames so no assertion changes meaning, and the option's suite then passes 21 of 21.

## The structural closer, which is the actual deliverable

After the fourth instance in the same class the run stopped patching members and closed the class instead. **T1** added `test/test_containers_instantiation.cpp`, which explicitly instantiates `array<Color,int>`, `bitset<Color>` and `set<Color>` and so forces every non-template member to be compiled by the suite itself. The class is settled by that file, not by the six fixes: a seventh defect of the same shape now fails the build the moment it is written.

Two of the Mediums are the same move applied to the C++20 module. **T2**: `module/magic_enum.cppm` was referenced by no build file and no CI job, so the module interface could rot unobserved. **M1**: once it was built, the export list turned out to omit 35 public names that the headers declare, so an `import magic_enum;` consumer could not call them. The enumeration is a script, `.jeffy/probes/module-exports`, diffing namespace-scope declarations in the headers against using-declarations in the module file; all 35 are exported now and the diff re-runs on every change to either side.

## What the gate did

The evaluator re-ran the verify command cold, re-executed every closed task's acceptance check, and re-derived the instruments rather than trusting them. Its most useful act was **breaking a check on purpose**: it dropped one using-declaration from a copy of the module file to confirm that the battery certifying 62 exported names can actually fail, and it does, naming that identifier. It found no in-envelope High or Medium and returned PASS.

It also recorded five Low observations, filed as **E1 to E5** and deliberately left unfixed, because a fix after a PASS invalidates that PASS:

- **E1** `doc/limitations.md` states the module's include requirement more narrowly than the consumer it was measured on.
- **E2** the `MAGIC_ENUM_NO_EXCEPTION` bullet omits `array::at` and `bitset::to_` from the throwing paths it lists.
- **E3** the module test's `enum_for_each` check is satisfied by a lambda that never runs, because the test enum's values sum to zero.
- **E4** the plan's count of user-settable macros is one short of what the headers test.
- **E5** a Python bytecode file under the loop's own probe directory is tracked in git, swept in by a checkpoint's `git add -A`.

Under the v1.9.0 severity floor these are published rather than blocking. They are open findings in the tree as it stands.

## Verify command

```
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release && cmake --build build -j"$(nproc)" && ctest --test-dir build --output-on-failure -j"$(nproc)"
```

**Oracle class**: unit tests plus a compile gate, and after T1 an instantiation gate. The build half is the stronger oracle here - the tests compile with `-Wall -Wextra -Wshadow -pedantic-errors -Werror`, so a header change that only warns still fails, and much of the library is checked by `static_assert` at compile time. The ctest half runs 18 Catch2 binaries, six sources across C++17/20/23.

**Environment fingerprint**: Linux 6.18 WSL2 x86_64, g++ (Ubuntu) 15.2.0, cmake 4.2.3, Release. Exclusions were derived by command, not asserted: the derivation returns exactly `test_nonascii`, excluded because `MAGIC_ENUM_OPT_ENABLE_NONASCII` defaults off. **No entry in this run claims the suite covers it** - A1's fix is proved green from its own separate configure and says so. Also unreached by the verify command: the MSVC-only targets, the Bazel and Meson builds, the module interface (built by its own CMake job behind a default-off option), and the `MAGIC_ENUM_ENABLE_HASH` path.

**Surface inventory**: 23 rows, **21 swept, 2 marked unreachable on this host** rather than swept or ignored - `bazel` and `meson` are not installed, and the rows say so with the command that establishes it.

## A process disclosure

**The pre-registered budget was three runs and the target converged in two**, so the stopping rule never bound. The opening audit swept 20 of the 21 reachable rows in a single iteration, which is why run 1 could spend its remaining nine iterations on fixes; the last row was swept by run 2's audit, and it is the row that produced A1. That row was also the one this project's verify command cannot reach, which is the general lesson: **a configure option no verify command exercises is a build nobody has run.**

One limit was known before the run and deliberately not told to the loop: that the non-ASCII configure fails on a modern compiler. It was recorded in the target brief as a declared limit, withheld from the loop under the standing rule that findings are never seeded, and the loop found it independently at the last unswept row.

## Disclosure

The loop ran against a local clone on a branch. Nothing here was pushed to Neargye/magic_enum, and no issue or pull request was opened. `journal.md` is the run's unedited journal, both runs, and `fixes.patch` is the complete diff from `v0.9.8` to the converged commit, excluding the loop's own plan, backlog, journal and probe files.
