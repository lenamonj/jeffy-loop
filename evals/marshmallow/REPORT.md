# Jeffy eval: marshmallow

The serialization and validation library a large share of Python APIs
load their input through, run in the 2026-08-24 Python wave on engine
1.16.0. **1 run, 10 iterations, converged** at
`e29ed17e989b572548c277450daab40837cf334b` on the project's `dev` branch,
against a **pre-registered budget of 2 rounds of 10** - round 2 was never
needed.

**Convergence standard**: evaluator countersigned.

| | |
|---|---|
| Base | `0c05c83d8a0602bef2520e54f5fd62c2f8ccc955` (dev) |
| Findings closed | **6** - 3 High, 3 Medium |
| Shipped-code change | 11 files, **+508 / -69** |
| Surface inventory | **20 of 20 rows swept** |
| Ledger at convergence | **7 Lows carried**, each with a runnable acceptance line |
| Evaluator | **2 invocations: REJECT, PASS** |

## What the loop found

Three Highs in the load path of a library whose one job is loading
safely:

- **`MH-01`** - the structural task the three-strike rule assigned to a
  whole class: 4.0 removals that left their documentation or error
  surface behind, closed as a class rather than as instances.
- **`MH-02`** - `_invoke_field_validators` read the deserialized mapping
  with a flat lookup while `_deserialize` writes nested paths, so
  validators ran against the wrong slot.
- **`MH-03`** - `_invoke_schema_validators` paired items with raw input
  via `zip(strict=True)`, so a `pass_collection` pre-load that changes
  the collection's length crashed instead of validating.

The Mediums: a class-registry re-registration that silently kept the
first-registered class; a bare `KeyError` where `only`/`exclude` raise a
helpful error; `get_class(all=True)` returning a bare class instead of a
list at exactly one registration.

## The gate earned its invocation

REJECT 1 caught **two Highs this run itself introduced** - the reason
this receipt can be trusted:

- The `MH-02` fix swapped a guarded subscript for `get_value`, whose
  `getattr` fallback means an *absent* field named like any of dict's 11
  public attributes (`items`, `keys`, `values`...) hands the validator a
  **bound method instead of `missing`**. Reproduced:
  `OrderSchema().load({})` crashes on HEAD, passes on the baseline.
- The `MH-03` fix narrowed original-data pairing to `Sequence`, silently
  breaking `pass_original` hooks for sets, dict views and Django-style
  QuerySets - a silently wrong dump, reproduced both ways against the
  baseline. The run's own journal claim ("byte-identical for a list, a
  tuple and a generator") was true and its enumeration omitted exactly
  the class the change moved.

Both fixed; invocation 2 re-scored all seven carried Lows individually
against reproductions and PASSed. The carried Lows are published in the
ledger with acceptance lines, including `dump(None, many=True)`
returning `{}` and `Length(min=0, equal=3)` silently ignoring its bound.

## Declared limits

- Converged on the `dev` branch (marshmallow's default), pre-4.1 work
  included; the base is pinned in the table.
- Graded on Python 3.14.4, linux under WSL2, run headless as a systemd
  user unit by `claude -p` on **claude-opus-5 (1M context)**, engine
  **1.16.0**.

## Nothing was sent upstream

Every finding rests on tests this loop wrote; no existing test was
deleted, disabled or weakened. Whether any of this goes upstream is a
separate decision, made one finding at a time.
