# Contributing

Thanks for wanting to improve Jeffy Loop. The bar for every change is the same one the loop holds itself to: evidence over assertion.

## Before you open a PR

Run the repo validator and make sure it is green:

```bash
bash scripts/validate.sh
```

It gates installer syntax and behavior, skill integrity, the governance markers, and the Stop hook's full lifecycle - the README's [Contributing](README.md#contributing) section describes what each pass covers. CI runs the same validator on Linux, Windows, and macOS.

A green local run is not the whole gate. The validator skips any check whose tool is missing, so the closing line reports both numbers - `All checks passed (N ran, M skipped)` - and reprints every skip with its reason underneath. Read that block: a skipped check covers nothing, and the exit code alone cannot tell you which ones ran. The one that catches people out is `shellcheck`, which rides the Linux CI leg: without it installed, the lint pass skips and a shell change that is green on your machine can still go red in CI. This repository has shipped a shellcheck-only breakage twice. Install it, or expect CI to find it for you. In the maintainer tree, where releases are cut, a missing `shellcheck` is a failure rather than a skip, because there the first machine to run that lint would otherwise be one the push has already reached.

## Ground rules

- `PLAN.md`, `BACKLOG.md`, `JOURNAL.md`, and `.claude/jeffy-loop.local.md` are loop state, not product. They are created in the projects Jeffy runs on and are never committed to this repo.
- Changes that widen the loop's autonomous authority (what it may edit, commit, or decide without the user) carry the highest review bar. Jeffy's value is its discipline; features that trade discipline for convenience will be declined.
- Keep the engine auditable. The Stop hook should stay one readable shell script; if a change cannot be reviewed in one sitting, split it.
- Use hyphens, not em dashes, in prose. Match the README's voice.
- Agent-assisted contributions are welcome, and no disclosure is required. This project is itself an autonomous loop, so it would be a strange place to object. The bar is unchanged and it is the whole point: you understand what you are submitting, the validator is green, and any behavior change carries a check that fails without it. A patch nobody can explain under review will be declined however it was written.

## Reporting problems

The best bug report is Jeffy's own paper trail: your OS, the Claude Code version, and the `JOURNAL.md` entry plus hook output from the failing iteration. The issue templates ask for exactly that. Questions belong in [Discussions](https://github.com/lenamonj/jeffy-loop/discussions); suspected vulnerabilities follow [SECURITY.md](SECURITY.md).
