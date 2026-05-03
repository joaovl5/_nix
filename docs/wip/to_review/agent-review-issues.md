# Agent Review Issues Log

Purpose: capture raw incidents where reviewer feedback was misguided, over-gated, or chunk-misaligned during the `frag` NixOS runtime redesign.

Non-goal: this is **not** a full review history. Most reviewer findings were real and useful. This file only records cases we may later want to use to improve reviewer/task-scope behavior.

## Incident 1 — Task 1 review drifted into CLI UX scope

- Session area: `frag` redesign, Task 1 (`NixOS runtime artifact and packaged contract`)
- Approx date: 2026-04-17/18
- Reviewer claim:
  - `handle_enter()` missing-profile / workspace mismatch paths were silent and should block Task 1 approval
- Why this was misguided:
  - Task 1 scope was packaging/runtime artifact contract:
    - `packages/frag/runtime-system.nix`
    - `packages/frag/images.nix`
    - `packages/frag/image_catalog.nix`
    - packaging contract tests
  - The flagged issue was a CLI UX/error-rendering concern, which fits Task 2 (`Rich startup UX`) / general CLI behavior, not Task 1 packaging.
- Was the underlying issue real?
  - Yes, the silent failure paths were real.
- Why this still counts as misguided:
  - The issue was treated as a **Task 1 blocker** instead of a **carry-forward into the UX chunk**.
- Effect on workflow:
  - Pulled unrelated CLI work into the packaging chunk.
  - Increased review churn and made Task 1 closure harder than necessary.

## Incident 2 — Task 3 was blocked on stopped-container recovery that belongs to Task 4

- Session area: `frag` redesign, Task 3 (`schema-2 state model, identity overlay, bootstrap signaling`)
- Approx date: 2026-04-18
- Reviewer claim:
  - exact-name non-running containers should be removed before `docker run`, otherwise stale matching stopped containers can cause Docker name conflicts
- Why this was misguided:
  - This is a real runtime recovery issue, but it belongs to Task 4 (`runtime reuse, stale-container recovery, bootstrap diagnostics`), not Task 3 state-model/bootstrap-state work.
  - The approved plan already gave Task 4 the responsibility for stale-container reuse/recovery behavior.
- Was the underlying issue real?
  - Yes.
- Why this still counts as misguided:
  - It was presented as a reason Task 3 could not close, instead of being recorded as a Task 4 carry-forward item.
- Effect on workflow:
  - Task boundary got blurred.
  - State-model work kept getting reopened by runtime-recovery concerns.

## Incident 3 — Task 3 review pulled in Task 4 bootstrap-diagnostics expectations

- Session area: `frag` redesign, Task 3
- Approx date: 2026-04-18
- Reviewer claim:
  - bootstrap wait should prefer exited-container logs and richer failure inspection before timeout fallback
- Why this was misguided:
  - Task 3 absolutely needed:
    - token-scoped `bootstrap-status.json`
    - bootstrap readiness signaling
    - persistent profile-state bootstrap metadata
  - But the **full** runtime-diagnostics/log-preference behavior was explicitly the subject of Task 4 in the approved plan.
- Was the underlying issue real?
  - Partly:
    - persisting failure status was relevant to Task 3
    - richer log-first diagnostics were real, but primarily Task 4 scope
- Why this still counts as misguided:
  - The reviewer collapsed a later runtime-diagnostics requirement into the current bootstrap/state-model chunk and treated it as immediate closure criteria.
- Effect on workflow:
  - Encouraged over-implementation in Task 3.
  - Made it harder to preserve chunk discipline.

## Incident 4 — Repeated chunk-crossing gate behavior

- Session area: `frag` redesign, multiple review rounds
- Approx date: 2026-04-18
- Pattern observed:
  - reviewer often found real bugs, but repeatedly used **future-chunk expectations** as **current-chunk blockers**
- Examples:
  - Task 1 packaging blocked by CLI UX/error-path concerns
  - Task 3 blocked by runtime reuse/stale-container recovery concerns
  - Task 3 partially blocked by richer bootstrap-diagnostics/log-preference behavior meant for Task 4
- Why this matters:
  - This is not “reviewer hallucination” in the usual sense.
  - It is a **task-boundary / scope-discipline problem**.
- Effect on workflow:
  - excessive reopen loops
  - over-fixing inside earlier chunks
  - slower convergence despite many findings being technically real

## Preliminary takeaway (raw, not final guidance)

The main reviewer weakness observed here was:

- not primarily fabricated bugs
- but **poor calibration about what should block the current chunk vs. be carried into the next planned chunk**

That distinction should likely be preserved when we later turn this raw log into reviewer-skill improvements.

## Incident 5 — Reviewer returned `incorrect` without actionable findings

- Session area: `frag` redesign, Task 1 review loop
- Approx date: 2026-04-18
- Reviewer behavior:
  - returned overall status `incorrect`
  - explanation said the runtime/helper contract was still leaky
  - **no concrete findings were listed**
- Why this is important raw data:
  - A reviewer verdict without at least one concrete finding is not operationally useful.
  - It creates churn because the controller has no precise fix target.
- Was there necessarily no issue?
  - Unknown. The problem here is not whether an issue existed; it is that the review result was not actionable.
- Effect on workflow:
  - forced extra interpretation work by the controller
  - made it harder to distinguish real blockers from reviewer uncertainty

## Incident 6 — One-issue-per-round drip feed on Task 3

- Session area: `frag` redesign, Task 3 (`schema-2 state model, identity overlay, bootstrap signaling`)
- Approx date: 2026-04-18
- Pattern observed:
  - reviewer often surfaced **one new issue per round** after the previous issue was fixed
  - this happened repeatedly across many Task 3 review loops
- Why this matters:
  - Even when findings were real, the review process behaved like a narrow incremental search rather than a more holistic pass.
  - That increases latency and makes it harder to know when a chunk is genuinely near closure.
- Was the underlying feedback necessarily wrong?
  - Not always. Many individual findings were real.
- Why it still belongs in this log:
  - This is reviewer/process raw data: the review style may be under-batching or under-synthesizing findings.
- Effect on workflow:
  - many small reopen loops
  - difficulty separating "this chunk is still fundamentally wrong" from "there is one more edge case"

## Incident 7 — P2 issues repeatedly treated as hard-stop blockers

- Session area: multiple `frag` redesign tasks, especially Task 3
- Approx date: 2026-04-18
- Pattern observed:
  - reviewer frequently returned overall `incorrect` on the basis of a single P2 issue
  - those P2s sometimes belonged to the current chunk, but not all were equally important to chunk closure
- Why this matters:
  - Severity labels and gating behavior were not always aligned.
  - In practice, `P2` often behaved like `must block closure now`, even when the issue could reasonably be carried into the next chunk or the final end-to-end pass.
- Effect on workflow:
  - over-gating
  - extra reopen loops
  - weaker distinction between "must fix now" and "should track soon"

## Additional raw insight — the biggest pattern was scope calibration, not pure hallucination

Across the redesign work so far, the most consistent reviewer problem has been:

- not mainly inventing fake bugs
- but struggling to distinguish:
  - **current-chunk blockers**
  - **next-chunk carry-forwards**
  - **real-but-lower-priority issues that should wait for final integration verification**

This should probably be treated as a first-class review-skill improvement target later.
