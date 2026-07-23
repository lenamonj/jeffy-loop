---
name: cancel-jeffy
description: Use when the user runs /cancel-jeffy to stop the active Jeffy improvement loop in the current project
disable-model-invocation: true
---

# Cancel Jeffy

Stop the Jeffy loop in this project by removing the loop state file the Stop hook reads.

1. Project root is the directory Claude Code was started in, not wherever the shell currently sits: the Bash tool's cwd persists across calls and may have drifted into a subdirectory that holds its own orphaned state file from another session. Always check state files with absolute paths anchored at the project root, never bare relative ones.
2. Check `<project-root>/.claude/jeffy-loop.local.md`. If it exists, read its frontmatter and report its session_id, iteration, and started_at, then delete the file and confirm the loop is cancelled. Once the file is gone the Stop hook lets the session end normally.
3. Also check `<project-root>/.claude/ralph-loop.local.md`: it belongs to the ralph-loop plugin's engine or a pre-2.0 Jeffy. If it exists, report the same frontmatter fields and delete it too, so no legacy loop keeps re-feeding.
4. If neither file exists, report that no Jeffy loop is active in this project and stop.
5. Remind the user that PLAN.md, BACKLOG.md, and JOURNAL.md are untouched: the loop picks up where it left off the next time they run /jeffy.
