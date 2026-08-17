# Aderyn report — triage (DocumentEngine `v0.4.0`)

| | |
| --- | --- |
| Report | [`aderyn-report.md`](./aderyn-report.md) |
| Command | `aderyn -x mocks --output doc/audits/tools/v0.4.0/aderyn/aderyn-report.md` |
| Tool version | `aderyn 0.6.5` |
| Scope | `src/` only — 9 files, 307 nSLOC. **Mocks and tests excluded.** This project keeps its mocks (`CMTATDocumentEngineMock`, `OpenDocumentEngine`) inside `test/DocumentEngine.t.sol`, which Aderyn does not scan, so `-x mocks` matched nothing and changed nothing. |
| Dependency | CMTAT `v3.3.0-rc2` (`35d8940b`) |
| Result | **0 High · 6 Low** |

## Executive triage

**Nothing to fix.** No finding is exploitable, and none blocks the `v0.4.0` release.

Five of the six are the analyzer's standing advisories about deliberate design choices (a privileged
operator, a caret pragma, PUSH0, revert-in-loop, storage-writes-in-loop) and one is a false positive.

The one result worth keeping in view is **L-5 at `DocumentEngineBase.sol:238`**, which is not a batch
loop but the linear scan in `_removeDocumentName`. Aderyn reached it from the "costly operation in a
loop" heuristic; it happens to land on the same code as `IMPROVEMENT.md` item 4, which flags the O(n)
removal against the multi-subject draft's expectation of "index tracking to support O(1) removals".
That is a scalability item, not a vulnerability — a subject with a large document set makes
`removeDocument` progressively more expensive, and `batchRemoveDocuments` compounds it to O(n·m).
Two independent routes arriving at the same line is a reasonable argument for doing the index-mapping
fix in a later release. It is deliberately **not** being done in `v0.4.0`, which is scoped to the
CMTAT upgrade.

## Findings

| ID | Detector | Sev | Instances | Disposition | Reason (verified against the cited lines) |
| --- | --- | --- | --- | --- | --- |
| L-1 | Centralization Risk | Low | 2 | **By design** | `DocumentEngine.sol:24`, `DocumentEngineOwnable.sol:24`. The whole premise of the contract is that a trusted operator manages documents for a fleet of subjects; `DOCUMENT_MANAGER_ROLE` (and `owner`) are that operator. Documented in the README and analysed in `IMPROVEMENT.md` item 1, which concludes the global role is the correct model for the single-issuer fleet this engine targets. Aderyn cannot express that distinction. |
| L-2 | Unspecific Solidity Pragma | Low | 9 | **By design** (floor since raised) | Every file uses a caret pragma, intentionally, so the sources stay consumable as a library by projects on a different `0.8.x`; the compiler actually used for the deployed bytecode is pinned to `0.8.34` in `foundry.toml`, and `foundry.lock` pins every dependency. Verified: no file uses a construct that behaves differently across the allowed range. **Update (post-run):** the floor this report saw, `^0.8.20`, over-promised once CMTAT `v3.3.0-rc3` moved `draft-IERC1643.sol` to `^0.8.24` — `0.8.20`–`0.8.23` could not in fact compile the tree (`AccessControlEnumerable.sol` and `EnumerableSet.sol` were already `^0.8.24`). Every file is now `^0.8.24`, which is the true `src/` floor; the full project including the CMTAT-importing tests needs `0.8.27`, because `require(cond, CustomError())` is legacy-pipeline-only from that version on. |
| L-3 | PUSH0 Opcode | Low | 9 | **Environment** | Consequence of the caret pragma plus `evm_version = prague`: the compiler emits `PUSH0`, which is unavailable on chains that have not adopted Shanghai. Not a source defect. A deployer targeting such a chain must lower `evm_version` in `foundry.toml` — but CMTAT v3 itself requires `prague`, so that configuration is out of scope for this engine. |
| L-4 | Loop Contains `require`/`revert` | Low | 4 | **By design** | `DocumentEngineBase.sol:124, 142, 156, 170` — the four batch loops. The reverts are raised inside `_setDocument` / `_removeDocument` (`ERC1643InvalidName`, `MultiDocumentInvalidSubject`, `ERC1643MissingDocument`). Batch operations are deliberately **all-or-nothing**: a batch containing one bad entry must not half-apply, since partial application would leave the operator unable to tell which documents were written without re-reading every entry. Skipping bad entries instead would silently drop them. |
| L-5 | Costly operations inside loop | Low | 5 | **By design** ×4, **known item** ×1 | Four instances (`:124, 142, 156, 170`) are storage writes in the batch loops — unavoidable, and the reason the batch functions exist is to amortise the 21 000-gas transaction overhead across those writes. The fifth (`:238`) is `_removeDocumentName`'s linear scan with swap-and-pop; see the triage note above and `IMPROVEMENT.md` item 4. |
| L-6 | Unchecked Return | Low | 1 | **False positive** | `DocumentEngine.sol:35`, `_grantRole(DEFAULT_ADMIN_ROLE, admin);`. OpenZeppelin's `_grantRole` returns `false` only when the account already holds the role. This call is in the constructor of a freshly deployed contract, where no role has been granted yet, so it always returns `true`; `admin == address(0)` is already rejected on the preceding lines. There is no state to check and no recovery path to take. |

## Delta

This report was regenerated after the error-naming and token-binding fixes (error renaming and
relocation; `bindToken`/`unbindToken` null-address rejection and idempotence). **Nothing moved**:
the same six detectors fire with the same instance counts, and every cited line is unchanged. nSLOC
rose 298 → 307 for the added guard and its NatSpec.

Worth noting explicitly, since it is a null result that is easy to misread as "not analysed": the new
`TokenBindingModule._setTokenBinding` — which adds a revert and an early return — triggered **no**
new finding, including no addition to L-4 (`revert` in a loop), because it contains no loop.

## Delta from the previous version

None — this is the **first** static-analysis run recorded for this repository. `doc/audits/` did not
exist before `v0.4.0`; the `CHANGELOG.md` release checklist referenced `doc/audits/tools` but no
report had been committed. There is therefore no baseline to diff against, and future runs should
diff against this one.

Note for the next run: the `CLAUDE.md` file tree claims a Slither report exists under `doc/`. It does
not. Slither is installed (`slither --version` resolves) and was **not** run for `v0.4.0` — this
release re-ran Aderyn only. A Slither run would make the next delta meaningful across both tools.
