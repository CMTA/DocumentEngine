# Slither report — triage (DocumentEngine `v0.4.0`)

| | |
| --- | --- |
| Report | [`slither-report.md`](./slither-report.md) |
| Command | `slither . --checklist --filter-paths "node_modules,lib,test,forge-std,mocks"` |
| Tool version | `slither 0.11.5` |
| Scope | `src/` only — 28 contracts analysed with 101 detectors. **Mocks and tests excluded.** This project keeps its mocks (`CMTATDocumentEngineMock`, `OpenDocumentEngine`) inside `test/DocumentEngine.t.sol`, which the `test` filter removes; there is no `src/mocks`, so the `mocks` filter entry matched nothing. |
| Dependencies | CMTAT `v3.3.0-rc3` (`658672f1`), OpenZeppelin `v5.7.0` (`cab19933`) |
| Result | **0 High · 1 Medium · 1 Low · 2 Informational** (4 results) |

## Executive triage

**Nothing to fix.** No finding is exploitable, and none blocks the `v0.4.0` release.

All four results reduce to two underlying pieces of code, and both are correct as written:

- **Two detectors (`incorrect-equality`, `timestamp`) fire on the same line** —
  `DocumentEngineBase.sol:250`, `doc.lastModified == 0`. Both misread an *existence sentinel* as a
  *time comparison*. See below; neither detector has a notion of "zero means absent".
- **`dead-code` ×2** flags the `_msgData()` overrides. These are not dead — Solidity **requires**
  them. Verified by deleting one and compiling: `Error (6480): Derived contract must override
  function "_msgData". Two or more base classes define function with same name and parameter types.`

The Medium severity on `incorrect-equality` deserves a word, because it is the highest-severity
result either tool produced for this release and it is worth being explicit that it is not real.
Slither's detector targets strict equality against a *quantity that can step past the compared
value* — a balance that can be donated to, or a timestamp compared with `==` where a block can skip
the exact second. Neither shape applies here: `0` is not a point on a timeline the value passes
through, it is the default of an unwritten struct.

## Findings

| ID | Detector | Sev | Conf | Instances | Disposition | Reason (verified against the cited lines) |
| --- | --- | --- | --- | --- | --- | --- |
| ID-0 | `incorrect-equality` | Medium | High | 1 | **False positive** | `DocumentEngineBase.sol:250`, inside `_removeDocument`: `if (doc.lastModified == 0) revert ERC1643MissingDocument();`. `lastModified` is only ever assigned `block.timestamp` (`:282`), which is non-zero on every live chain, so a *stored* document can never read back as `0`. The comparison is therefore a total existence test — the same idiom `_setDocument` uses at `:276` to detect a new name. The ERC-1643 spec requires the revert-on-missing behaviour this line implements. Making it `<= 0` or a range check, as the detector suggests, would change nothing and read worse. Covered by `testCannotRemoveMissingDocument` (`test/DocumentEngine.t.sol:450`). |
| ID-1 | `timestamp` | Low | Medium | 1 | **False positive** | Same line as ID-0. The detector flags any use of a timestamp in a comparison, on the theory that a validator can nudge `block.timestamp` by a few seconds and flip a branch. There is no ordering comparison here — no `<`, `>`, or deadline — only equality against the `0` sentinel. A validator cannot set `block.timestamp` to `0`, so no achievable manipulation changes which branch is taken. The stored value is metadata surfaced by `getDocument`; nothing in the engine makes a decision based on how recent it is. |
| ID-2 | `dead-code` | Info | Medium | 1 | **False positive — required override** | `DocumentEngine.sol:118-120`, `_msgData()`. `DocumentEngine` inherits `Context` through two paths (`AccessControlEnumerable` → `AccessControl` → `Context`, and `ERC2771Context` → `Context`), and `ERC2771Context` overrides `_msgData()`. Solidity therefore demands an explicit `override(ERC2771Context, Context)` in the derived contract. **Verified empirically:** removing the function fails to compile with `Error (6480): Derived contract must override function "_msgData"`. Slither reports it "never used" because nothing in this project calls `_msgData()` directly — but it is what makes ERC-2771 calldata handling correct for any inherited code that does. |
| ID-3 | `dead-code` | Info | Medium | 1 | **False positive — required override** | `DocumentEngineOwnable.sol:68-70`. Identical to ID-2, via `Ownable2Step` → `Ownable` → `Context` and `ERC2771Context` → `Context`. |

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
