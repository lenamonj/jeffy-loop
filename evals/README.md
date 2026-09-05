# Real-World Validation on Open-Source Repositories

Empirical evidence of how an autonomous coding agent performs on real software: Jeffy was run against widely-used open-source projects with no connection to this repository, with each project's own test suite as the oracle. The engine ships no language-specific analyzer, ruleset or plugin, so the same method carried across <!-- count:languages -->13<!-- /count --> languages. Every run used a local clone, and nothing went upstream without a filed issue or PR.

| Projects tested | Fixed | Failed | PRs merged | PRs open | Issues filed |
|:---:|:---:|:---:|:---:|:---:|:---:|
| **<!-- count:tested -->129<!-- /count -->** | **<!-- count:fixed -->101<!-- /count -->** | **<!-- count:failed -->28<!-- /count -->** | **<!-- count:merged -->20<!-- /count -->** | **<!-- count:prs-open -->36<!-- /count -->** | **<!-- count:issues -->4<!-- /count -->** |

**Fixed** means the loop's closing audit came back clean and an independent evaluator countersigned it: <!-- count:converged -->100<!-- /count --> loop runs converged, plus one audit (PapaParse) held to the same method. That is a standard this repository set and checked itself. A merged pull request is the one outcome it cannot award itself, which is why those rows come first. **Failed** means the project's pre-registered run budget ran out without convergence, or, for one project (libuv), the run was abandoned before it had a budget or a receipt; every one is published. Counted per attempt rather than per project, [ATTEMPTS.md](./ATTEMPTS.md) holds more non-converged rows than this table holds Failed rows, because a project that failed more than once, or converged only on a retry, contributes each attempt.

## Merged upstream

<!-- count:merged -->20<!-- /count --> patches this loop wrote are merged across <!-- count:merged-projects -->17<!-- /count --> projects, because a maintainer with no stake in this project reviewed each one and said yes, and one more finding was fixed upstream by the maintainer himself:

- **[bat](https://github.com/sharkdp/bat/pull/3862) - merged.** A just-merged security flag did nothing when piped; caught before it ever shipped.
- **[fasthttp](https://github.com/valyala/fasthttp/pull/2343) - merged.** A `Content-Length` no parser should accept became a wrong number.
- **[jsoncpp](https://github.com/open-source-parsers/jsoncpp/pull/1709) - merged.** The build the project documents for handling secrets had never compiled on MSVC, and the memory it promises to wipe was only partly wiped. Merged 2026-08-20.
- **[PapaParse](https://github.com/mholt/PapaParse/pull/1135) - merged.** Header de-duplication re-ran on every row after a resume, rewriting data in place: `"foo, bar"` came back as `"foo, bar_1"`. Merged 2026-08-24, shipped in PapaParse 5.7.0.
- **Microsoft, [mimalloc](https://github.com/microsoft/mimalloc/pull/1385) - merged.** `mi_theap_zalloc_csize` delegated its large-size branch to the plain malloc path, so a documented zeroing allocator returned uninitialized heap memory for every size above the small-size threshold. Merged 2026-08-31 by the library's author.
- **Node.js, [ada](https://github.com/ada-url/ada/pull/1244) - merged.** `ada::url` reported `host_end` one byte short of the position its own documentation describes, so slicing `href` by `[host_start, host_end)` truncated the host; `ada::url_aggregator` disagreed with it on every URL with a host. Merged 2026-09-01, twelve minutes after it was opened. ada is the URL parser inside Node.js.
- **[nanoid](https://github.com/ai/nanoid/pull/609) - merged.** `customAlphabet` accepted alphabets it cannot sample from and hung forever in `while (true)`; the maintainer judged the runtime guard too expensive for the reachability and asked for a docs notice instead, which was reworked and merged the same day. Merged 2026-09-01.
- **[unicode-segmentation](https://github.com/unicode-rs/unicode-segmentation/pull/181) - merged.** `size_hint()` on the three public sentence iterators panicked on the empty string in debug builds, and in release returned a lower bound of `usize::MAX` against an upper bound of 0 - a violation of the `Iterator` contract that a caller sizing a buffer from the hint acts on. Merged 2026-09-01. unicode-segmentation is the UAX #29 implementation under much of the Rust ecosystem.
- **[go-runewidth](https://github.com/mattn/go-runewidth/pull/106) - merged.** `Wrap(s, 0)` panicked with an integer divide by zero in a capacity hint, and the package-level `CreateLUT` never rebuilt its table after a flag change, so every width stayed stale. Two PRs, both merged 2026-09-01 within an hour of filing.
- **[console](https://github.com/console-rs/console/pull/296) - merged.** `truncate_str` without `ansi-parsing` sliced the string at a column count used as a byte offset and panicked mid-character on any multi-byte input. Merged 2026-09-02 after one review round. console is the terminal layer under indicatif and dialoguer.
- **[nanostores](https://github.com/nanostores/nanostores/pull/425) - merged.** `batch()` called from inside a store listener re-ran listeners that had already fired in the same flush, and the unbind returned by lifecycle `on()` detached a different listener on its second call. Two PRs, both merged 2026-09-02 by the maintainer for the next minor release. nanostores is the store Astro's documentation recommends for sharing state between islands.
- **[indicatif](https://github.com/console-rs/indicatif/pull/836) - merged.** `draw_to_term` underflowed its width arithmetic when the last drawn line was wider than the terminal and panicked on the next redraw. Merged 2026-09-03 after one review round; indicatif is the progress-bar layer above console.
- **JetBrains, [kotlinx-datetime](https://github.com/Kotlin/kotlinx-datetime/pull/650) - merged.** The `ReplaceWith` metadata on the deprecated `Instant` pointed `toEpochMilliseconds()` at `nanosecondsOfSecond` and `isDistantFuture` at `isDistantPast`, so an IDE quick-fix silently changed the program's result. Merged 2026-09-03 by the maintainer, about six hours after filing.
- **Apple, [swift-log](https://github.com/apple/swift-log/pull/504) - merged.** `Logger.MetadataValue.attributes` documented its setter as a no-op on `.dictionary` and `.array` values and called `assertionFailure` there instead, so debug builds trapped where release builds silently dropped the write. The maintainer wanted the assertion kept as a programmer error; the merged change is the documentation saying so and pointing handler authors at leaf values. Merged 2026-09-04.
- **Apache, [commons-text](https://github.com/apache/commons-text/pull/768) - merged.** `StringMatcher.isMatch(CharSequence, int, int, int)` forwarded `bufferEnd` where `bufferStart` belongs, so a custom matcher searching a `TextStringBuilder` through `StringSubstitutor` was handed a window that began at its own end and never matched. One argument fixed, with tests the reviewer shaped. Merged 2026-09-04 by Gary Gregory, fifty minutes after the requested rework.
- **[urfave/cli](https://github.com/urfave/cli/pull/2423) - merged.** The parser classified a positional argument from a trimmed copy and then stored the copy, so a quoted argument with leading or trailing whitespace reached the action stripped: a file named `" notes.txt"` opened as `notes.txt`. The action now receives the argument as typed; flag detection is unchanged, measured on all four quoted flag-like inputs the reviewer asked about. Merged 2026-09-04.
- **[chalk](https://github.com/chalk/chalk/pull/687) - fixed upstream.** The maintainer reproduced the finding, then wrote and merged his own fix, shipped in v6.0.0.

One more is not a fix and is not counted as one: a **security finding this loop produced in [claude-code-action](./claude-code-action/REPORT.md) is open with Anthropic's own security program**, scored Low (2.3) on 2026-08-20. Their review is ongoing, so nothing here calls it accepted, and the details stay unpublished at their request until the report resolves.

## Converged targets by language

<div align="center">

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="../media/language-pie-dark.png">
  <img src="../media/language-pie-light.png" alt="Pie chart of the 100 converged public targets by language: Python 19 at 19.0 percent, Rust 14 at 14.0 percent, Go 12 at 12.0 percent, JavaScript 10 at 10.0 percent, C++ 7 at 7.0 percent, Ruby 6 at 6.0 percent, C 5 at 5.0 percent, Java 5 at 5.0 percent, PHP 5 at 5.0 percent, Swift 5 at 5.0 percent, TypeScript 5 at 5.0 percent, Kotlin 4 at 4.0 percent, C# 3 at 3.0 percent." width="900">
</picture>

<sub>Every converged public target, by the language it was written in. Counts are derived from the receipts table below at render time by <a href="../scripts/render-language-pie.py"><code>scripts/render-language-pie.py</code></a>, largest slice first, ties alphabetical. Chart source: <a href="../media/language-pie.html"><code>media/language-pie.html</code></a>.</sub>

</div>

## Scorecard

<sub>Ordered by upstream outcome, then by stars; failures last, alphabetically. Run-by-run detail for every project, including re-attempts, is in [evals/ATTEMPTS.md](./ATTEMPTS.md).</sub>

| Project | Language | Details | Jeffy Result |
|:---|:---|:---|:---|
| bat | Rust | [details](./bat/REPORT.md) - security flag no-op piped - [PR merged](https://github.com/sharkdp/bat/pull/3862) | Fixed |
| fasthttp | Go | [details](./fasthttp/REPORT.md) - bad Content-Length accepted - [PR merged](https://github.com/valyala/fasthttp/pull/2343) | Fixed |
| PapaParse | JavaScript | [details](./papaparse/REPORT.md) - *audit*; 4 Highs in streaming - [PR merged](https://github.com/mholt/PapaParse/pull/1135), [PR open](https://github.com/mholt/PapaParse/pull/1133), [PR open](https://github.com/mholt/PapaParse/pull/1134), [PR open](https://github.com/mholt/PapaParse/pull/1136) | Fixed |
| jsoncpp | C++ | [details](./jsoncpp/REPORT.md) - secure build never compiled - [PR merged](https://github.com/open-source-parsers/jsoncpp/pull/1709) | Fixed |
| mimalloc | C | [details](./mimalloc/REPORT.md) - zalloc returned dirty memory - [PR merged](https://github.com/microsoft/mimalloc/pull/1385) | Fixed |
| ada | C++ | [details](./ada/REPORT.md) - host_end truncated the host - [PR merged](https://github.com/ada-url/ada/pull/1244) | Fixed |
| nanoid | JavaScript | [details](./nanoid/REPORT.md) - empty alphabet hung the generator - [PR merged](https://github.com/ai/nanoid/pull/609) | Fixed |
| unicode-segmentation | Rust | [details](./unicode-segmentation/REPORT.md) - empty-string size_hint panic - [PR merged](https://github.com/unicode-rs/unicode-segmentation/pull/181) | Fixed |
| go-runewidth | Go | [details](./go-runewidth/REPORT.md) - Wrap panicked at width zero - [PR merged](https://github.com/mattn/go-runewidth/pull/106), [PR merged](https://github.com/mattn/go-runewidth/pull/107) | Fixed |
| console | Rust | [details](./console/REPORT.md) - truncate_str panicked mid-character - [PR merged](https://github.com/console-rs/console/pull/296) | Fixed |
| nanostores | JavaScript | [details](./nanostores/REPORT.md) - batch() inside a listener replayed listeners - [PR merged](https://github.com/nanostores/nanostores/pull/425), [PR merged](https://github.com/nanostores/nanostores/pull/426) | Fixed |
| kotlinx-datetime | Kotlin | [details](./kotlinx-datetime/REPORT.md) - byUnicodePattern dropped the escaped quote inside a literal, and deprecation quick-fixes pointed at the wrong member - [PR merged](https://github.com/Kotlin/kotlinx-datetime/pull/650), [PR open](https://github.com/Kotlin/kotlinx-datetime/pull/649) | Fixed |
| indicatif | Rust | [details](./indicatif/REPORT.md) - draw-width underflow panic - [PR merged](https://github.com/console-rs/indicatif/pull/836) | Fixed |
| csv | PHP | [details](./csv/REPORT.md) - the TimeField separator was matched as a regex, and an empty field was escaped as a formula - [PR merged](https://github.com/thephpleague/csv/pull/592), [PR merged](https://github.com/thephpleague/csv/pull/593), [PR closed](https://github.com/thephpleague/csv/pull/591) | Fixed |
| swift-log | Swift | [details](./swift-log/REPORT.md) - a handler implementing only `log(event:)` overflowed the stack on the 1.0 entry point - [PR merged](https://github.com/apple/swift-log/pull/504), [PR open](https://github.com/apple/swift-log/pull/503) | Fixed |
| commons-text | Java | [details](./commons-text/REPORT.md) - LevenshteinDetailedDistance over-reported the distance - [PR merged](https://github.com/apache/commons-text/pull/768), [PR open](https://github.com/apache/commons-text/pull/767), [PR open](https://github.com/apache/commons-text/pull/769) | Fixed |
| urfave/cli | Go | [details](./urfave-cli/REPORT.md) - a lone - ended flag parsing - [PR merged](https://github.com/urfave/cli/pull/2423) | Fixed |
| chalk | JavaScript | [details](./chalk/REPORT.md) - maintainer wrote own fix - [fixed upstream](https://github.com/chalk/chalk/pull/687) | Fixed |
| dayjs | JavaScript | [details](./dayjs/REPORT.md) - 45 findings, 10 High - [PR open](https://github.com/iamkun/dayjs/pull/3167) | Fixed |
| yfinance | Python | [details](./yfinance/REPORT.md) - High its own test advertised - [PR open](https://github.com/ranaroussi/yfinance/pull/2927) | Fixed |
| PHP-Parser | PHP | [details](./php-parser/REPORT.md) - test class ran no code - [PR open](https://github.com/nikic/PHP-Parser/pull/1162) | Fixed |
| python-dotenv | Python | [details](./python-dotenv/REPORT.md) - 8 runs, 48 findings - [PR open](https://github.com/theskumar/python-dotenv/pull/678) | Fixed |
| PyPortfolioOpt | Python | [details](./pyportfolioopt/REPORT.md) - CI-red to 356 passing - [PR open](https://github.com/PyPortfolio/PyPortfolioOpt/pull/751) | Fixed |
| go-yaml | Go | [details](./go-yaml/REPORT.md) - 20 findings, 6 High - [PR open](https://github.com/goccy/go-yaml/pull/915) | Fixed |
| rust-url | Rust | [details](./rust-url/REPORT.md) - 20 findings, 10 High - [PR open](https://github.com/servo/rust-url/pull/1147) | Fixed |
| rouge | Ruby | [details](./rouge/REPORT.md) - unknown theme crashed the CLI - [PR open](https://github.com/rouge-ruby/rouge/pull/2332) | Fixed |
| pflag | Go | [details](./pflag/REPORT.md) - deprecated flag field ignored - [PR open](https://github.com/spf13/pflag/pull/507) | Fixed |
| classnames | JavaScript | [details](./classnames/REPORT.md) - null-prototype objects crashed all three modules - [PR open](https://github.com/JedWatson/classnames/pull/579) | Fixed |
| assert | PHP | [details](./assert/REPORT.md) - isInitialized threw the wrong exception - [PR open](https://github.com/webmozarts/assert/pull/365), [PR open](https://github.com/webmozarts/assert/pull/366) | Fixed |
| natsort | Python | [details](./natsort/REPORT.md) - locale sentinel was three ASCII bytes - [PR open](https://github.com/SethMMorton/natsort/pull/196) | Fixed |
| uuid | Rust | [details](./uuid/REPORT.md) - v7 counter lost its top four bits to the version nibble - [PR open](https://github.com/uuid-rs/uuid/pull/907) | Fixed |
| i18n | Ruby | [details](./i18n/REPORT.md) - a pluralized lookup handed out the store's own String - [PR open](https://github.com/ruby-i18n/i18n/pull/751), [PR open](https://github.com/ruby-i18n/i18n/pull/752) | Fixed |
| kotlinx-io | Kotlin | [details](./kotlinx-io/REPORT.md) - the temporary directory was an empty path when TMPDIR was unset - [PR open](https://github.com/Kotlin/kotlinx-io/pull/521) | Fixed |
| shouldly | C# | [details](./shouldly/REPORT.md) - a failing dictionary assertion over a pair sequence threw InvalidCastException - [PR open](https://github.com/shouldly/shouldly/pull/1335) | Fixed |
| valinor | PHP | [details](./valinor/REPORT.md) - a captured closure earlier in the file made registerConstructor resolve a class that does not exist - [PR open](https://github.com/CuyZ/Valinor/pull/838) | Fixed |
| swift-http-types | Swift | [details](./swift-http-types/REPORT.md) - a schemeless URL trapped an Optional-returning conversion, and the fast path of == ignored two of a field's three stored properties - [PR open](https://github.com/apple/swift-http-types/pull/152), [PR closed](https://github.com/apple/swift-http-types/pull/153) | Fixed |
| money | Ruby | [details](./money/REPORT.md) - imported JSON rates went through JSON.load, and reset! kept a key cache that turned UnknownCurrency into NoMethodError - [PR open](https://github.com/RubyMoney/money/pull/1227), [PR open](https://github.com/RubyMoney/money/pull/1228) | Fixed |
| ohash | TypeScript | [details](./ohash/REPORT.md) - the browser digest crashed on a lone surrogate, and diff dropped a leaf-to-container change and overflowed on cycles - [PR open](https://github.com/unjs/ohash/pull/204) | Fixed |
| typer | Python | [details](./typer/REPORT.md) - hash seed chose which app runs - [PR open](https://github.com/fastapi/typer/pull/1952), [PR closed as a duplicate](https://github.com/fastapi/typer/pull/1946) | Fixed |
| claude-agent-sdk-python | Python | [details](./claude-agent-sdk-python/REPORT.md) - converged on attempt 2 - [PR open](https://github.com/anthropics/claude-agent-sdk-python/pull/1247) | Fixed |
| commons-csv | Java | [details](./commons-csv/REPORT.md) - six documented promises the code did not keep, and a serialization skew the loop introduced and caught - [PR open](https://github.com/apache/commons-csv/pull/633) | Fixed |
| mustache.js | JavaScript | [details](./mustache.js/REPORT.md) - revived a dead suite - [issue filed](https://github.com/janl/mustache.js/issues/848) | Fixed |
| Spectre.Console | C# | [details](./spectre.console/REPORT.md) - panel header dropped - [issue filed](https://github.com/spectreconsole/spectre.console/issues/2184) | Fixed |
| quantstats | Python | [details](./quantstats/REPORT.md) - 29 findings behind green - [issue filed](https://github.com/ranaroussi/quantstats/issues/537) | Fixed |
| records | Python | [details](./records/REPORT.md) - 4 High data-loss bugs - [issue filed](https://github.com/kennethreitz/records/issues/236) | Fixed |
| cobra | Go | [details](./cobra/REPORT.md) - timezone-dependent build | Fixed |
| zod | TypeScript | [details](./zod/REPORT.md) - cyclic value validated | Fixed |
| commander.js | JavaScript | [details](./commander-js/REPORT.md) - error named wrong argument | Fixed |
| underscore | JavaScript | [details](./underscore/REPORT.md) - __proto__ prototype write | Fixed |
| gson | Java | [details](./gson/REPORT.md) - one audit, nothing changed | Fixed |
| rack | Ruby | [details](./rack/REPORT.md) - multipart limits off by one | Fixed |
| Catch2 | C++ | [details](./catch2/REPORT.md) - 18 findings, 6 High | Fixed |
| validator | Go | [details](./validator/REPORT.md) - cyclic struct killed process | Fixed |
| clap | Rust | [details](./clap/REPORT.md) - 35 rows over 4 runs | Fixed |
| uuid (JS) | JavaScript | [details](./js-uuid/REPORT.md) - crash on unpaired surrogates | Fixed |
| speedtest-cli | Python | [details](./speedtest-cli/REPORT.md) - small findings only | Fixed |
| phpdotenv | PHP | [details](./phpdotenv/REPORT.md) - silent [] on bad multiline | Fixed |
| cJSON | C | [details](./cjson/REPORT.md) - sort dropped later appends | Fixed |
| nlohmann/json | C++ | [details](./json/REPORT.md) - Bazel header list omitted a dep | Fixed |
| RuboCop | Ruby | [details](./rubocop/REPORT.md) - null result, zero findings | Fixed |
| lz4 | C | [details](./lz4/REPORT.md) - silent data loss, exit 0 | Fixed |
| godotenv | Go | [details](./godotenv/REPORT.md) - parser panic from .env | Fixed |
| moshi | Kotlin | [details](./moshi/REPORT.md) - 5 Highs behind green CI | Fixed |
| FluentValidation | C# | [details](./fluentvalidation/REPORT.md) - CreditCard() took no digits | Fixed |
| qs | JavaScript | [details](./qs/REPORT.md) - global state leaked | Fixed |
| claude-code-action | TypeScript | [details](./claude-code-action/REPORT.md) - converged on attempt 2 | Fixed |
| path-to-regexp | TypeScript | [details](./path-to-regexp/REPORT.md) - 4 REJECTs on evidence | Fixed |
| marshmallow | Python | [details](./marshmallow/REPORT.md) - 3 Highs in load path | Fixed |
| swift-algorithms | Swift | [details](./swift-algorithms/REPORT.md) - doc examples did not compile | Fixed |
| magic_enum | C++ | [details](./magic_enum/REPORT.md) - 6 members never compiled | Fixed |
| vavr | Java | [details](./vavr/REPORT.md) - BitSet.removeAll threw | Fixed |
| go-uuid | Go | [details](./go-uuid/REPORT.md) - SQL NULL returned stale UUID | Fixed |
| ta | Python | [details](./ta/REPORT.md) - wrong numbers since 2023 | Fixed |
| go-cmp | Go | [details](./go-cmp/REPORT.md) - 2 grouping bugs, +31/-13 | Fixed |
| CLI11 | C++ | [details](./cli11/REPORT.md) - empty strtoX read as a value | Fixed |
| more-itertools | Python | [details](./more-itertools/REPORT.md) - sample() wrong on negatives | Fixed |
| idna | Python | [details](./idna/REPORT.md) - empty label raised IndexError | Fixed |
| sqlparse | Python | [details](./sqlparse/REPORT.md) - converged on run 5 of 5 | Fixed |
| sqlfluff | Python | [details](./sqlfluff/REPORT.md) - fix commented out the statement | Fixed |
| rrule | TypeScript | [details](./rrule/REPORT.md) - 23 findings, 10 High | Fixed |
| humanize | Python | [details](./humanize/REPORT.md) - 4 float-range Highs | Fixed |
| ryu | Rust | [details](./ryu/REPORT.md) - s2f rejected 7,807 strings | Fixed |
| rust-semver | Rust | [details](./rust-semver/REPORT.md) - ledger nearly shipped | Fixed |
| heck | Rust | [details](./heck/REPORT.md) - NFD lost combining marks | Fixed |
| mapstructure | Go | [details](./mapstructure/REPORT.md) - silent numeric overflow | Fixed |
| itoa | Rust | [details](./itoa/REPORT.md) - no-panic build failed to link | Fixed |
| cachetools | Python | [details](./cachetools/REPORT.md) - held iterator froze the clock | Fixed |
| memchr | Rust | [details](./memchr/REPORT.md) - crate shipped loop state | Fixed |
| python-slugify | Python | [details](./python-slugify/REPORT.md) - one bad entity voided all decoding | Fixed |
| bidict | Python | [details](./bidict/REPORT.md) - declared dependency floor could not import | Fixed |
| unicode-width | Rust | [details](./unicode-width/REPORT.md) - published crate lacked its own test corpus | Fixed |
| itertools | Rust | [details](./itertools/REPORT.md) - 1 Medium, 3 Lows, 8 iterations | Fixed |
| xid | Go | [details](./xid/REPORT.md) - 5 Mediums in 10 iterations | Fixed |
| fast_float | C++ | [details](./fast_float/REPORT.md) - chars_format::hex silently parsed decimal | Fixed |
| swift-collections | Swift | [details](./swift-collections/REPORT.md) - README pinned a tools version that does not exist | Fixed |
| utf8proc | C | [details](./utf8proc/REPORT.md) - MANIFEST one soname behind the install | Fixed |
| rubyzip | Ruby | [details](./rubyzip/REPORT.md) - a failed extraction destroyed the file it was overwriting | Fixed |
| commons-cli | Java | [details](./commons-cli/REPORT.md) - Properties defaults were written onto the caller's Option | Fixed |
| jansson | C | [details](./jansson/REPORT.md) - the CMake shared build exported 46 internal symbols | Fixed |
| swift-system | Swift | [details](./swift-system/REPORT.md) - the Windows `open` skipped the documented permissions trap and nested temp directories leaked | Fixed |
| kotlinx-collections-immutable | Kotlin | [details](./kotlinx-collections-immutable/REPORT.md) - the vector builder broke its build() identity promise on a no-op set, and two pass-through sentences promised more than the code | Fixed |
| BurntSushi/toml | Go | [details](./ATTEMPTS.md) - 5 runs, 52 iters, not converged | Failed |
| Carbon | PHP | [details](./ATTEMPTS.md) - 4 runs, 17 iters, not converged | Failed |
| casbin | Go | [details](./casbin/REPORT.md) - 5 runs, 46 iters, not converged - [PR open](https://github.com/apache/casbin/pull/1753) | Failed |
| cast | Go | [details](./ATTEMPTS.md) - 2 runs, 22 iters, not converged | Failed |
| chroma.js | JavaScript | [details](./ATTEMPTS.md) - 4 runs, 30 iters, not converged | Failed |
| click | Python | [details](./ATTEMPTS.md) - 5 runs, 42 iters, not converged | Failed |
| decimal.js | JavaScript | [details](./ATTEMPTS.md) - 4 runs, 41 iters, not converged | Failed |
| diff-so-fancy | Perl | [details](./ATTEMPTS.md) - 3 runs, 30 iters, not converged | Failed |
| eemeli/yaml | TypeScript | [details](./ATTEMPTS.md) - 5 runs, 50 iters, not converged | Failed |
| faker | Ruby | [details](./ATTEMPTS.md) - 3 runs, 30 iters, not converged | Failed |
| go-humanize | Go | [details](./ATTEMPTS.md) - 2 runs, 21 iters, not converged | Failed |
| go-querystring | Go | [details](./ATTEMPTS.md) - 2 runs, 20 iters, not converged | Failed |
| goldmark | Go | [details](./ATTEMPTS.md) - 5 runs, 47 iters, not converged | Failed |
| Humanizer | C# | [details](./ATTEMPTS.md) - 4 runs, 32 iters, not converged | Failed |
| image-rs | Rust | [details](./ATTEMPTS.md) - 5 runs, 40 iters, not converged | Failed |
| immer | TypeScript | [details](./immer/journal.md) - 3 runs, 31 iters, not converged | Failed |
| itsdangerous | Python | [details](./ATTEMPTS.md) - 3 runs, 31 iters, not converged | Failed |
| libuv | C | [details](./ATTEMPTS.md) - started, then abandoned | Failed |
| mruby | C | [details](./ATTEMPTS.md) - 10 runs, 113 iters, not converged | Failed |
| node-semver | JavaScript | [details](./ATTEMPTS.md) - 4 runs, 30 iters, not converged | Failed |
| picomatch | JavaScript | [details](./ATTEMPTS.md) - 5 runs, 45 iters, not converged - [PR open](https://github.com/micromatch/picomatch/pull/204), [PR open](https://github.com/micromatch/picomatch/pull/205) | Failed |
| shopspring/decimal | Go | [details](./ATTEMPTS.md) - 4 runs, 33 iters, not converged | Failed |
| spdlog | C++ | [details](./ATTEMPTS.md) - 4 runs, 40 iters, not converged | Failed |
| tenacity | Python | [details](./ATTEMPTS.md) - 2 runs, 20 iters, not converged | Failed |
| testify | Go | [details](./ATTEMPTS.md) - 4 runs, 40 iters, not converged | Failed |
| thor | Ruby | [details](./ATTEMPTS.md) - 2 runs, 20 iters, not converged | Failed |
| validator.js | JavaScript | [details](./ATTEMPTS.md) - 2 runs, 20 iters, not converged | Failed |
| zstd | C | [details](./ATTEMPTS.md) - 6 runs, 54 iters, not converged | Failed |

## Greenfield: three builds judged by suites the loop did not write

Every receipt above is brownfield - the project arrived with a test suite the loop did not author. The white paper's own limits section names the residual weakness anyway: the loop writes many of the tests that certify the loop. Greenfield is that weakness at its maximum, so the answer was pre-registered: start from an empty directory, commit the goal and a Verify command naming an **external judge** before iteration 1, ship the backlog empty so the task decomposition is the loop's own work, and never intervene in a run. The engine is unmodified. All three targets converged.

| Target | Judge | Final position | Rows swept | Iterations | Runs |
|:---|:---|:---|---:|---:|---:|
| [TOML 1.0 decoder, Rust](https://github.com/lenamonj/jeffy-greenfield-toml) | `toml-test` v2.2.0 - 679 external assertions | **205 of 205 valid, 474 of 474 invalid** | 17 of 17 | 11 | 1 |
| [gitignore matcher, Rust](https://github.com/lenamonj/jeffy-greenfield-gitignore) | `git check-ignore` 2.50.1, differential | **106 cases, 300 queries, 0 disagreements** | 12 of 12 | 42 | 5 |
| [TOML-M decoder, Rust](https://github.com/lenamonj/jeffy-greenfield-toml-mutated) - *mutated spec* | `toml-test` v2.2.0 through a frozen output adapter | **205 of 205 valid, 474 of 474 invalid** (and 169 of 205 against *standard* TOML) | 17 of 17 | 14 | 1 |

The TOML decoder's zero measurement was the suite failing because the binary did not exist; eleven iterations later every one of 679 externally authored assertions passed, and even the surface-inventory rows were the suite's own test groups rather than the loop's choice. The gitignore matcher is the stopping-discipline story: its frozen corpus was fully green from the first iteration of run 2, and everything after that was the adversarial evaluator probing beyond the corpus and refusing to countersign - **invoked 8 times, rejecting 7**, filing findings that marched from matcher semantics into `wildmatch.c`'s escaped-slash clause, git's four-byte `isspace`, NTFS case folding, 8.3 short-name aliases, and the Win32 normalization layer git's own file opens bypass. Three runs ended blocked and are published as the receipts they are; once, the loop reproduced two of its gate's three rejection reasons and **refuted the third with direct oracle evidence**, filing exactly what reproduced.

The third target answers the objection the first two invite: TOML and gitignore saturate any plausible training set, so convergence there might measure recall. **TOML-M is TOML v1.0.0 with two rules deliberately inverted** - `true` and `false` swap payloads, and tab and line feed swap inside string values - so remembering the real format produces wrong answers. Both amendments are involutions, which lets the unmodified `toml-test` binary stay the judge through a frozen 61-line adapter that inverts the decoder's output. The receipt reports two numbers from one binary: **205 of 205 against the mutated suite, and 169 of 205 against standard TOML**, failing on exactly the cases the mutation touches. It built the dialect rather than recalling the format, at a cost of 14 iterations against 11 for the unmutated build. That receipt also discloses a rule violation on its own front page: an audit ran inside the closing extension window, which the engine forbids, and the convergence declaration cites it.

Stated as narrowly as the result deserves: the same engine, unmodified, converged on builds whose completeness was decided by judges it did not write - including one where recalling the real specification actively hurts. Not claimed: any completion rate (three chosen targets are not a sample), or invention (a two-rule dialect is not a novel format). The gitignore corpus is self-authored - frozen at 53 cases, grown monotonically to 106, never shrunk, and since scored cold against 119 blind-authored queries with no disagreements - and the white paper weighs that honestly against the TOML target's fully external 679. All three repositories ship their complete run record - pre-registration, journal, backlog, every iteration commit - because for a greenfield build the process is the evidence.

