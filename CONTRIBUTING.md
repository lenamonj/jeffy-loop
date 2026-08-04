# Contributing

Thanks for wanting to improve Jeffy Loop. The bar for every change is the same one the loop holds itself to: evidence over assertion.

## Before you open a PR

Run the repo validator and make sure it is green:

```bash
bash scripts/validate.sh
```

It gates installer syntax and behavior, skill integrity, the governance markers, and the Stop hook's full lifecycle - the README's [Contributing](README.md#contributing) section describes what each pass covers. CI runs the same validator on Linux, Windows, and macOS.

## Ground rules

- `PLAN.md`, `BACKLOG.md`, `JOURNAL.md`, and `.claude/jeffy-loop.local.md` are loop state, not product. They are created in the projects Jeffy runs on and are never committed to this repo.
- Changes that widen the loop's autonomous authority (what it may edit, commit, or decide without the user) carry the highest review bar. Jeffy's value is its discipline; features that trade discipline for convenience will be declined.
- Keep the engine auditable. The Stop hook should stay one readable shell script; if a change cannot be reviewed in one sitting, split it.
- Use hyphens, not em dashes, in prose. Match the README's voice.

## Reporting problems

The best bug report is Jeffy's own paper trail: your OS, the Claude Code version, and the `JOURNAL.md` entry plus hook output from the failing iteration. The issue templates ask for exactly that. Questions belong in [Discussions](https://github.com/lenamonj/jeffy-loop/discussions); suspected vulnerabilities follow [SECURITY.md](SECURITY.md).
