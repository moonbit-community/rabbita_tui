# Terminal Suspension Gate

## Goal

Address PR #2 review feedback by preventing overlapping terminal suspend/resume
sections when multiple `Cmd::exec_process` or `Cmd::suspend` commands are run
from a concurrent batch.

## Accepted Design

Keep `Cmd::batch` concurrent for ordinary commands. Add a runtime-private
single-permit async semaphore to `RuntimeState`, and acquire it only around the
terminal-affecting section:

- `suspend_terminal`
- the suspended task or process
- `resume_terminal`

This matches Bubble Tea's effective behavior, where `ExecProcess` execution is
serialized by the central event loop, without changing general batch
concurrency.

## Target Files And Surfaces

- `terminal.mbt`: add the private runtime gate and use it in
  `run_suspended_task` and `run_suspended_process`.
- `moon.pkg`: import the pinned async semaphore package if the implementation
  uses it directly.
- `pkg.generated.mbti`: expected to remain unchanged.

## API And Interface Diff

No public API change is intended. The semaphore is private runtime state and
should not appear in generated interfaces.

## Open Questions

None. The user confirmed the semaphore-gate approach on 2026-06-04.

## Next Implementation Step

Add the semaphore to `RuntimeState`, initialize it when the runtime starts, and
hold it only while the terminal is suspended.

## Validation Plan

Run `moon check`, relevant tests, `moon fmt`, and `moon info`, then inspect
generated interface diffs before committing.
