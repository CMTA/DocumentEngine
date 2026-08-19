# Slither report — triage (DocumentEngine `v0.4.0`)

| | |
| --- | --- |
| Report | [`slither-report.md`](./slither-report.md) |
| Command | `slither . --checklist --filter-paths "node_modules,lib,test,forge-std,mocks"` |
| Tool version | `slither 0.11.5` |
| Scope | `src/` only — 28 contracts analysed with 101 detectors. **Mocks and tests excluded.** This project keeps its mocks (`CMTATDocumentEngineMock`, `OpenDocumentEngine`) inside `test/DocumentEngine.t.sol`, which the `test` filter removes; there is no `src/mocks`, so the `mocks` filter entry matched nothing. |
| Dependencies | CMTAT `v3.3.0-rc3` (`658672f1`), OpenZeppelin `v5.7.0` (`cab19933`) |
| Result | **0 High · 0 Medium · 0 Low · 2 Informational** (2 results) — was 4; see the correction below |

## Executive triage

**Nothing to fix.** No finding is exploitable, and none blocks the `v0.4.0` release.

Both remaining results are the same thing: **`dead-code` ×2** flags the `_msgData()` overrides.
These are not dead — Solidity **requires** them. Verified by deleting one and compiling:
`Error (6480): Derived contract must override function "_msgData". Two or more base classes define
function with same name and parameter types.`

### Correction — two findings disappeared, and not because anything was fixed

The previous run of this report carried two further results, both on
`_removeDocument`'s `doc.lastModified == 0`:

| ID | Detector | Sev | Status now |
| --- | --- | --- | --- |
| (was ID-0) | `incorrect-equality` | Medium | **No longer reported** |
| (was ID-1) | `timestamp` | Low | **No longer reported** |

They stopped firing when the code-quality review's finding B-2 changed
`Document memory doc = _documents[subject][name_]` to `Document storage doc = …` — a gas
optimisation that left the comparison character-for-character identical. Slither's taint tracking
classifies `lastModified` as timestamp-derived when it arrives via a memory copy of the struct, and
apparently loses that classification when the field is read through a storage pointer.

**Nothing was fixed.** The original triage (retained below) established both as false positives on
their merits; their disappearance is a detector artefact, not an improvement, and the same reasoning
would apply verbatim if a future Slither release started reporting them again. Recorded here rather
than deleted, because a reader comparing "4 results" against "2 results" across the two runs would
otherwise conclude a Medium had been remediated.

**The original triage, still the operative reasoning if these ever return.** Slither's
`incorrect-equality` detector targets strict equality against a *quantity that can step past the
compared value* — a balance that can be donated to, or a timestamp compared with `==` where a block
can skip the exact second. Neither shape applies: `0` is not a point on a timeline the value passes
through, it is the default of an unwritten struct. `lastModified` is only ever assigned
`block.timestamp`, which is non-zero on every live chain, so a *stored* document can never read back
as `0`; the comparison is a total existence test, and the ERC-1643 spec requires the
revert-on-missing behaviour it implements. Covered by `testCannotRemoveMissingDocument`. The
`timestamp` detector's concern — a validator nudging `block.timestamp` to flip a branch — needs an
ordering comparison; there is none here, and no achievable manipulation sets `block.timestamp` to
`0`.

## Findings

| ID | Detector | Sev | Conf | Instances | Disposition | Reason (verified against the cited lines) |
| --- | --- | --- | --- | --- | --- | --- |
| ID-0 | `dead-code` | Info | Medium | 1 | **False positive — required override** | `DocumentEngine.sol:155-157`, `_msgData()`. `DocumentEngine` inherits `Context` through two paths (`AccessControlEnumerable` → `AccessControl` → `Context`, and `ERC2771Context` → `Context`), and `ERC2771Context` overrides `_msgData()`. Solidity therefore demands an explicit `override(ERC2771Context, Context)` in the derived contract. **Verified empirically:** removing the function fails to compile with `Error (6480): Derived contract must override function "_msgData"`. Slither reports it "never used" because nothing in this project calls `_msgData()` directly — but it is what makes ERC-2771 calldata handling correct for any inherited code that does. |
| ID-1 | `dead-code` | Info | Medium | 1 | **False positive — required override** | `DocumentEngineOwnable.sol:82-84`. Identical to ID-0, via `Ownable2Step` → `Ownable` → `Context` and `ERC2771Context` → `Context`. |

## What Slither did *not* flag

Worth recording, since absences are easy to misread as "not analysed". With 101 detectors over the
full `src/` tree, Slither reported **no** reentrancy, no access-control gap, no uninitialised state,
no unchecked external call, no shadowing, and no arbitrary-`from` issue. That is the expected result
for this contract — the engine holds no funds, makes no external calls, and every state-changing
entry point is behind `onlyDocumentManager` or `onlyBoundToken`.

Note also that Slither did **not** reproduce Aderyn's L-6 (`_grantRole` return value ignored) or its
loop advisories (L-4, L-5). The two tools disagree on what is worth reporting rather than on the
facts; every one of those is triaged in the Aderyn feedback file.

## Delta from the previous version

None — this is the **first** Slither run recorded for this repository. `v0.4.0`'s earlier audit pass
ran Aderyn only, and the `doc/audits/tools/v0.4.0/slither/` directory did not exist. There is no
baseline to diff against; future runs should diff against this one.

Two notes for whoever runs it next:

1. **Use `lib` as the dependency filter, not individual submodule names.** This is a Foundry project,
   so every dependency lives under `lib/`. The command previously documented in the README —
   `--filter-paths "node_modules,test,forge-std,CMTAT,openzeppelin-contracts"` — names submodules
   individually and omits `lib/RuleEngine` entirely. Slither's `--filter-paths` fails *open*: an
   entry that matches nothing silently widens scope rather than erroring. The README has been
   updated to the `lib` form used here.
2. **Slither writes the checklist to stdout and its detector log to stderr, and exits non-zero when
   it finds anything.** `exit=255` with a populated report is the normal, successful outcome — do not
   read it as a failed run.
