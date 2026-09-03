# Contributing

Thanks for wanting to improve Jeffy Loop. The bar for every change is the same one the loop holds itself to: evidence over assertion.

## Before you open a PR

Run the repo validator and make sure it is green:

```bash
bash scripts/validate.sh
```

It gates, among other things:

- **Syntax and lint** - both installers and the Stop hook (`bash -n`, PowerShell parser, shellcheck).
- **Skill integrity** - frontmatter, referenced paths, the governance markers that keep the envelope, ratchet, verify gate, run report, and convergence rules from silently regressing - including the `Command:` line the default plan hands the hook to run - and the iteration prompt's injection invariants.
- **Behavior, not just parsing** - both installers and the Stop hook are exercised end to end, every gate proven able to fail. The full scenario list is below.

<details>
<summary>The full behavioural scenario list</summary>
<br>

Both installers run non-interactively against sandboxed profiles (skills and engine must land, and the hook registration must appear exactly once even after a re-run and carry the 600s timeout, whether written fresh or upgraded from an older entry), and the Stop hook itself is exercised through its full lifecycle: mid-budget re-feed, budget exhaustion, completion promise, foreign-session isolation, and the no-state no-op. The gates that guard the converged stop are held to the same standard - an open task, a `Converged` line that no longer certifies the tree, an unswept Surface inventory row, and a verify command that is red, that overruns its timeout, or that is declared `none` each have to produce the right outcome, a fully swept inventory and a pre-inventory `PLAN.md` are both accepted, and the verify parser is proven on the one shape the hook executes, the labelled `Command:` line - backticks stripped only when the wrapping pair is unambiguous, an annotated line named as a `bash -n` defect before anything runs, and a section carrying no command skipped with a note rather than run as prose - as are the per-iteration hygiene gates and the fail-open paths for a missing ledger, journal, or plan, a malformed counter, and a moved prompt file. The two newest gates get the same treatment: the closing extension has to be granted once at exact budget exhaustion with zero open High and zero open Medium - carried Lows included - over a swept inventory and refused everywhere else - a Medium still open, a task line whose severity the parse cannot read, a row still unswept, a flag already set, a frontmatter that never closes, an iteration already past its budget - and the granted window has to survive the Lows it was granted over while a non-evaluator refill, a Medium or a Low filed inside it, still ends the run - and a declaration must be rejected when its closing entry records no evaluator verdict, accepted on `Evaluator: PASS` backed by this run's committed evaluator artifact, rejected when that artifact is missing, belongs to another run, or sits uncommitted in the tree, rejected outright on `Evaluator: unavailable`, exempt for a ratchet, and failed open when the journal holds no entry for the run. The hygiene gates are proven both ways too: a journal heading that names the session but not the run is rejected and a legacy state file without a run token falls back cleanly, and a rotation that shrinks or deletes `JOURNAL-archive.md` is caught while an appending one passes and a never-rotated project is left alone. The stall gate is proven the same way, and from 1.7.0 against the engine's own commit behaviour rather than against synthetic state: progress on either signal stays silent, the first flat iteration draws the STALL note and arms the flag, the second consecutive one ends the run, progress resets the strike, a non-git project stalls out on the ledger signal alone, a project with neither signal skips with a stderr note, and neither budget exhaustion nor a valid promise is disturbed by an armed flag. The commit-driven cases are the ones that matter, because the loop checkpoints every iteration: two journal-only iterations that each committed draw the note and then end the run, a battery-only iteration under `.jeffy/` draws it too, a committed `.claude/settings.local.json` and a tracked loop state file are read as harness churn rather than progress, a one-line source change committed alongside the state files stays silent, all four ceremony types are exempt and carry the flag through untouched while a fourth consecutive one draws the note and a fifth ends the run, a stale entry heading at a desynced index does not exempt the entry that replaced it, a state file with no run token gets no exemption at all, a recorded head this repository cannot resolve fails open, a repository that disappears mid-run falls back to the ledger, and a forfeited closing extension is named on the way out. Both tree gates are also proven in a project that sits below the repository root, where git reports paths from the repository root and every filename the two exclusion lists carry is anchored at the project root.

</details>

CI runs the same validator on Linux, Windows, and macOS - the macOS leg exists because BSD userland differs from GNU in `sed`, `grep`, and `stat`, and nothing exercised it before.

A green local run is not the whole gate. The validator skips any check whose tool is missing, so the closing line reports both numbers - `All checks passed (N ran, M skipped)` - and reprints every skip with its reason underneath. Read that block: a skipped check covers nothing, and the exit code alone cannot tell you which ones ran. The one that catches people out is `shellcheck`, which rides the Linux CI leg: without it installed, the lint pass skips and a shell change that is green on your machine can still go red in CI. This repository has shipped a shellcheck-only breakage twice. Install it, or expect CI to find it for you. In the maintainer tree, where releases are cut, a missing `shellcheck` is a failure rather than a skip, because there the first machine to run that lint would otherwise be one the push has already reached.

## Regenerating the media

The banners, the flowchart and the language pie are rendered by the scripts under scripts/, and they need one dependency nothing else in this repository uses:

```bash
pip install playwright
python -m playwright install chromium
```

Neither the validator nor the installer touches it - only a maintainer regenerating an image does, which is why it is declared here rather than pinned in a requirements file the build would imply. The set is derived rather than typed, so a render script that gains a dependency cannot leave this paragraph behind:

```bash
python3 -c "
import ast, pathlib, sys
mods = set()
for f in sorted(pathlib.Path('scripts').glob('*.py')):
    for node in ast.walk(ast.parse(f.read_text(encoding='utf-8'))):
        if isinstance(node, ast.Import):
            mods.update(a.name.split('.')[0] for a in node.names)
        elif isinstance(node, ast.ImportFrom) and node.level == 0 and node.module:
            mods.add(node.module.split('.')[0])
print(' '.join(sorted(mods - set(sys.stdlib_module_names))))
"
```

It prints every import across scripts/*.py that is not in the standard library, and it prints exactly playwright today. Run it when a render script changes: a name it returns that is not named above is a dependency a maintainer meets as a ModuleNotFoundError with nothing in the repository to explain it.

## Ground rules

- `PLAN.md`, `BACKLOG.md`, `JOURNAL.md`, and `.claude/jeffy-loop.local.md` are loop state, not product. They are created in the projects Jeffy runs on and are never committed to this repo.
- Changes that widen the loop's autonomous authority (what it may edit, commit, or decide without the user) carry the highest review bar. Jeffy's value is its discipline; features that trade discipline for convenience will be declined.
- Keep the engine auditable. The Stop hook should stay one readable shell script, with only the shared verify and sandbox helpers under `hooks/lib/` beside it; if a change cannot be reviewed in one sitting, split it.
- Use hyphens, not em dashes, in prose. Match the README's voice.
- Agent-assisted contributions are welcome, and no disclosure is required. This project is itself an autonomous loop, so it would be a strange place to object. The bar is unchanged and it is the whole point: you understand what you are submitting, the validator is green, and any behavior change carries a check that fails without it. A patch nobody can explain under review will be declined however it was written.

## Reporting problems

The best bug report is Jeffy's own paper trail: your OS, the Claude Code version, and the `JOURNAL.md` entry plus hook output from the failing iteration. The issue templates ask for exactly that. Questions belong in [Discussions](https://github.com/lenamonj/jeffy-loop/discussions); suspected vulnerabilities follow [SECURITY.md](SECURITY.md).
