# Review of `docs/wip/frag/plans/01.md` — Second Pass

## Verdict: Plan is ready for execution

All 11 items from the first review have been addressed. No new issues found.

---

## Disposition of Previous Review Items

| #   | Item                                           | Status                                                  | Evidence                                                                 |
| --- | ---------------------------------------------- | ------------------------------------------------------- | ------------------------------------------------------------------------ |
| 1.1 | Stash note for remediation worktree            | **Addressed**                                           | Line 43                                                                  |
| 1.2 | `test_cli.py` scope imprecision                | **Dismissed** (was cosmetic, said "no change required") | —                                                                        |
| 2.1 | Chunk 4 pull-forward option                    | **Addressed**                                           | Lines 512, 677                                                           |
| 2.2 | 3C dependency rationale in summary             | **Addressed**                                           | Line 678                                                                 |
| 2.3 | 5B scope ambiguity                             | **Addressed**                                           | Lines 536-557 (renamed, blockquote clarification, both outcomes covered) |
| 3.1 | `_ensure_home_alignment` dead-code risk for 5C | **Addressed**                                           | Line 583                                                                 |
| 3.2 | `shared_assets_identity` mismatch test for 3A  | **Addressed**                                           | Line 425                                                                 |
| 3.3 | `MappingKind` → `StrEnum` in Chunk 2           | **Addressed**                                           | Lines 387-388                                                            |
| 3.4 | `smoke_verify.py` one-line description         | **Addressed**                                           | Line 291                                                                 |
| 3.5 | `dockerTools` as primary candidate for 5C      | **Addressed**                                           | Line 570                                                                 |
| 4.1 | Code review reference correct                  | **Confirmed**                                           | —                                                                        |
| 4.2 | Stale review item section correct              | **Confirmed**                                           | —                                                                        |
| 4.3 | Build verification command complexity          | **Not addressed** (minor DX note, not a plan issue)     | —                                                                        |
| 4.4 | Timing instrumentation earlier                 | **Addressed**                                           | Lines 299-301                                                            |
| 4.5 | `prompts.py` in responsibility map             | **Addressed**                                           | Lines 173-174                                                            |

---

## Remaining Notes (not blockers)

These are observations, not issues requiring plan changes:

1. **Build command DX** (4.3 from first review): The `nix build --impure --expr ...` at line 722 is still complex. Not a plan correctness issue — just something the executing agent will need to copy carefully or wrap.

2. **Blank line at 44 and 302-303**: Minor formatting artifacts. No impact on readability.

---

## Assessment

The plan is well-calibrated:

- Execution order is sound with appropriate flexibility noted
- Dependencies between chunks are documented both inline and in the summary
- Verification criteria are specific and testable
- The four workstreams (measurement, cleanup, wins, experiments) are properly sequenced
- All locked decisions and context are captured upfront

No further changes needed.
