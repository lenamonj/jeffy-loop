# Journal: iamkun/dayjs audit under Jeffy's method

2026-07-27. Node v22.18.0, Windows 11, Git Bash and PowerShell. All work in a scratch
clone. Nothing pushed, no issue or PR opened upstream.

This is an audit conducted under Jeffy's method. It is not a /jeffy loop run and there
were no loop iterations; the numbered steps below are the order the work happened in.

## 0. Target pinned

    git -c core.autocrlf=false clone https://github.com/iamkun/dayjs.git
    git log -1 --format='%H %ci %s'
    98364bcebc047529345cc8c2bbcc44a6a8c18e79  2026-06-30 19:46:40 +0800  chore: update doc

Branch `dev`. Stars 48,655, from `gh api repos/iamkun/dayjs --jq .stargazers_count`.
npm downloads 63,006,037 for 2026-07-18 to 2026-07-24, from the npm downloads API.
Latest release v1.11.21, 2026-05-26. 968 open issues, 322 open pull requests.

Upstream CI on this exact commit: `gh api repos/iamkun/dayjs/commits/98364bc.../check-runs`
returns one run, `check / lint-and-test`, conclusion `success`, 2026-06-30T11:47:48Z,
workflow run 28441915404. So upstream believes this commit is green. Holding that fact
against whatever the local suite says was the whole shape of the audit.

`npm install` produced 1791 packages and a wall of deprecation warnings, three of them
for `core-js@2.6.12`.

## 1. First run of the suite, and a result that was too neat

Ran the full `jest --coverage=false` under seven zones with `TZ=... npx jest`. Result:
UTC green at 773/773, and every single other zone red with the same two failures,
`DayOfYear set` and `Should not interpolate characters inside square brackets`, with
byte-identical output. Europe/London, Asia/Kolkata, Pacific/Auckland, America/New_York,
America/Whitehorse and Australia/Lord_Howe all agreeing to the character is not what
timezone-sensitive code does. Europe/London is UTC+00 in January; it cannot produce the
same wrong answer as America/New_York for a January instant.

So I stopped and probed the harness instead of the library:

    node -e "console.log(process.env.TZ, Intl.DateTimeFormat().resolvedOptions().timeZone)"

    no TZ                -> null              America/New_York
    TZ=UTC               -> "UTC"             UTC
    TZ=Europe/London     -> null              America/New_York
    TZ=Pacific/Auckland  -> null              America/New_York

The variable never arrives. MSYS2, which is what Git Bash runs on, strips a `TZ` value
containing a slash before handing the environment to a native Windows process. Only
`TZ=UTC` survives because it has no slash. Every "different timezone" run had actually
executed in the machine's own zone, America/New_York.

That is exactly the artifact the brief warned about, except it worked in the opposite
direction from the one expected: it did not invent a Windows failure, it disguised the
machine's own zone as seven different ones and produced a fake consensus. The earlier
report of a dayOfYear failure under Pacific/Auckland came from this. The process was
never in Auckland.

Fix: drive every run through the repo's own `cross-env`, which sets the variable from
inside Node. Verified it lands:

    cross-env TZ=Pacific/Auckland node -> "Pacific/Auckland", offset -780 in January

## 2. The suite, re-measured honestly

Full suite via `cross-env`, coverage off:

    UTC                  773/773 pass
    Europe/London        773/773 pass
    Asia/Kolkata         773/773 pass
    America/New_York     771/773   dayOfYear, localizedFormat
    Pacific/Auckland     770/773   get-set, pluralGetSet, calendar
    Australia/Lord_Howe  770/773   get-set, pluralGetSet, calendar
    America/Whitehorse   767/773   dayOfYear, localizedFormat, plugin/timezone (4)

The primary lead is dead on arrival: under Pacific/Auckland the dayOfYear test passes.
The dayOfYear failure appears only on hosts west of Greenwich.

## 3. Settling dayOfYear: library or fixture

`src/plugin/dayOfYear/index.js` is five lines and computes a purely local-calendar
value. `dayjs('2015-01-01T00:00:00.000Z')` on a host at UTC-5 is 2014-12-31 local, so
`dayOfYear()` is 365 of 2014, and setting it to 4 lands on 2014-01-04 local, which is
2014-01-05T00:00:00Z. The "wrong year" is the correct answer to the question actually
asked.

The decisive check is the oracle the test file itself already imports:

    host America/New_York
      dayjs  dayOfYear()                    365
      moment dayOfYear()                    365
      dayjs  .dayOfYear(4).toISOString()    2014-01-05T00:00:00.000Z
      moment .dayOfYear(4).toISOString()    2014-01-05T00:00:00.000Z

Identical. `test/plugin/calendar.test.js` makes the same point against itself: the
assertion that dayjs equals moment passes, and the hardcoded-string assertion on the
next line is the one that fails. Same for get-set and pluralGetSet, whose fixtures use
`...Z` literals whose local calendar date moves, and localizedFormat, which builds
`new Date(0)` and then asserts the year is 1970.

Filed as DAYJS-4, Medium, testing. Not a correctness finding. Publishing it as one
would have been the worst available outcome.

## 4. The four Whitehorse failures, which are a different animal

`test/plugin/timezone.test.js` fails under `TZ=America/Whitehorse` only. Those tests
call `dayjs.tz(s, 'America/New_York')`, an explicit zone conversion whose result must
not depend on the machine at all. Built the library and probed directly:

    host America/Whitehorse
      dayjs.tz('2012-03-11 02:00:00','America/New_York')
        format()      2012-03-11T04:00:00-04:00     (= 08:00Z)
        valueOf()     1331449200000                 (= 07:00Z)
        moment        2012-03-11T03:00:00-04:00

An object whose rendered wall clock and whose own timestamp are an hour apart. That
cannot be a data problem, it is arithmetic.

Traced it to `src/plugin/utc/index.js:105`. `.utcOffset(n)` parks the target wall clock
into a native Date's local fields by shifting the instant `offset + hostOffset` minutes,
where `hostOffset` is read before the shift. Whitehorse observed DST in 2012 and springs
forward inside that four-hour window, so the offset used no longer applies where the
shift lands, and the local fields come out an hour late.

Then a second, worse variant on host Europe/London:

    dayjs.tz('2012-10-28 00:30:00','America/New_York')
      host UTC     -> 2012-10-28T04:30:00.000Z    (moment agrees)
      host London  -> 2012-10-28T05:30:00.000Z

Here `valueOf()` itself is wrong. `src/plugin/utc/index.js:121` reads
`this.$x.$localOffset || this.$d.getTimezoneOffset()`. London sat at GMT for that shift,
so the stored offset is 0, which is falsy, so the guard treats a correct value as
missing and substitutes a different one. Any host that is UTC+00 for part of the year
is exposed: London, Lisbon, Dublin, Casablanca.

Two mechanisms, one code region. Filed together as DAYJS-1, High, correctness.

Windows tzdata check, so this is not blamed on ICU: America/Whitehorse reads 01:59 PST
at 2012-03-11T09:59:00Z and 03:00 PDT one minute later, and permanent UTC-7 from 2020,
which is exactly the published Yukon history. The platform data is right.

## 5. DST as a class

Two sweeps, both against moment as oracle.

Core, host-local, no plugins: `add(1,'day')`, `subtract(1,'day')`, `add(24,'hour')`,
`add(1,'week')`, `add(1,'month')`, `startOf('day')`, `endOf('day')`, and `diff` in
hours, days and minutes, at both the spring-forward and the fall-back boundary, on
UTC, America/New_York, Europe/London, Pacific/Auckland and Australia/Lord_Howe.
100 checks, 0 mismatches. The core is clean, including the half-hour DST zone. Worth
saying plainly: the interesting failures are all in the plugins.

Timezone plugin: 6 operations across 14 boundary timestamps in 4 target zones, 84
checks, repeated on 10 host zones. At HEAD, 22 to 37 mismatches per host, and the count
differs by host. Two separate problems live in that number, and separating them mattered:

- ones that are host-dependent, which is DAYJS-1;
- ones present identically on every host including UTC, where `add`, `subtract`,
  `startOf` and `endOf` on a `.tz()` instance keep the offset frozen at construction.
  `dayjs.tz('2021-03-13 23:30:00','America/New_York').add(1,'day')` renders `-05:00`
  on a day New York is on `-04:00`. That is DAYJS-3, and it is upstream issue 1260,
  open since 2020-12-07.

## 6. Determinism, found while reading fixOffset

`src/plugin/timezone/index.js:138` seeds the ambiguity guess with
`tzOffset(+d(), timezone)`: the target zone's offset *now*. Froze the clock and checked
on host UTC, where no host zone history is involved:

    dayjs.tz('2021-11-07 01:30:00','America/New_York')
      clock in January   1636266600000
      clock in July      1636263000000

Same input, two instants an hour apart, decided by what month it happens to be. Three
of four boundary inputs drifted. Filed as DAYJS-2, High, correctness. This one needs no
exotic host zone at all, which also makes it the cleanest disproof of the "Windows
artifact" theory.

## 7. Why upstream CI is green anyway

`package.json:9`, `"test-tz": "date && jest test/timezone.test --coverage=false"`.
`jest test/timezone.test --listTests` returns exactly one file, `test/timezone.test.js`,
1 suite, 6 tests. It does not match `test/plugin/timezone.test.js`, which is where the
DST tests live. So the three named CI zones exercise 6 of 773 tests, and the full suite
only ever runs in the runner's default zone, UTC on `ubuntu-latest`.

That reconciles the two facts the audit started with. CI is genuinely green, and the
suite is genuinely red under two of the three zones CI names. Filed as DAYJS-5.

## 8. Fixes

`src/plugin/utc/index.js` utcOffset: probe the shift, read the host offset that actually
applies at the shifted instant, and rebuild from that when they differ. Written as a
probe plus a ternary rather than an `if` block, deliberately: the first version used an
`if` and left four lines unexecuted under UTC, which broke the repo's own `lines: 100`
coverage gate. Restructuring so every line runs on every host was the right answer, not
an istanbul ignore comment.

`src/plugin/utc/index.js` valueOf: test `$localOffset` for absence with the library's
own `u()` helper instead of for truthiness.

`src/plugin/timezone/index.js` d.tz: seed the guess from the parsed input. Also moved
the computation below the non-string early return, which removes a wasted `tzOffset`
call on that path.

Tests: five fixtures rewritten to local wall clock literals. Three regression tests
appended to `test/plugin/timezone.test.js` covering the documented instant, the
invariant that `format()` and `valueOf()` agree, and stability against a moved clock.

`package.json`: `test-tz` now runs the whole suite.

Discarded along the way: a regression test that looped `process.env.TZ` over eight zones
inside jest. It passed, and it was worthless. jest 22 runs on jsdom and the Date
implementation there does not pick up a runtime `TZ` change, so all eight iterations
measured the same zone and the assertion was vacuous. Verified with a throwaway test
that printed 19 for both UTC and Asia/Tokyo. Deleted it and put host independence in
`repro.js`, which is plain Node where the switch does work, with a self-check that
aborts if it ever stops working. That is the same class of mistake as step 1, caught the
second time by looking for it.

Not fixed: DAYJS-3 and DAYJS-6, both routed to the owner with reasons in the report.

## 9. Verification

Full suite through `cross-env` after the patch:

    UTC, Europe/London, Asia/Kolkata, America/New_York, Pacific/Auckland,
    Australia/Lord_Howe, America/Whitehorse, America/Sao_Paulo
    -> 93/93 suites, 776/776 tests, every zone

Coverage gate `jest --coverage --coverageThreshold="{ \"global\": { \"lines\": 100} }"`
passes: 99.9 statements, 99.44 branches, 100 functions, 100 lines. Baseline at HEAD was
99.9 / 99.51 / 100 / 100, measured by stashing the patch and re-running.

`eslint src/ test/ build/` exits clean. `npm run lint` as the project writes it cannot
run on Windows cmd because of the `./node_modules/.bin/` prefix, so eslint was invoked
directly with the same arguments. Not a project defect; CI is Linux.

`npm run build` succeeds; `size-limit` reports 2.79 KB against the 2.99 KB budget,
unchanged from HEAD, because nothing in core was touched.

`repro.js`, run against a pristine build of HEAD and against a patched build:

    HEAD      1 of 5 scored checks pass
    patched   5 of 5 scored checks pass
    DAYJS-3   fails in both, by design, it is reported not fixed
    DAYJS-4   passes in both, which is the evidence it was never a library defect

## 10. What I could not establish

Everything ran on win32. The argument that DAYJS-1 and DAYJS-2 reproduce on Linux is
reasoning from the mechanism plus a verified-correct platform tz database, not an
observation. A maintainer should run `TZ=America/Whitehorse` and `TZ=Europe/London` on
`ubuntu-latest` to close that. The DAYJS-4 fixture sweep covered 7 host zones, not all
of them. Recorded in the report under Disclosed limitation.

Nothing was pushed. No issue or pull request was opened upstream.
