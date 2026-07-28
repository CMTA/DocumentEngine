# Security & audit overview — DocumentEngine

> **This project has not been audited.** No formal external security audit has been performed on any
> release. What follows is the record of the automated and AI-assisted analyses that *have* been run.
> These are **not** a substitute for an audit. Anyone deploying this engine in production must
> commission their own independent security assessment.

## In scope

The `src/` tree only — 9 files, 298 nSLOC as of `v0.4.0`:

```
src/DocumentEngine.sol              src/interfaces/IERC1643MultiDocument.sol
src/DocumentEngineBase.sol          src/interfaces/IERC8303.sol
src/DocumentEngineInvariant.sol     src/interfaces/ITokenBinding.sol
src/DocumentEngineOwnable.sol       src/modules/TokenBindingModule.sol
                                    src/modules/VersionModule.sol
```

Out of scope: `lib/` (CMTAT, RuleEngine, OpenZeppelin — audited, or not, upstream), `test/`,
`script/`.

## Analyses

| Analysis | Version | Report | Triage |
| --- | --- | --- | --- |
| Aderyn `0.6.5` | `v0.4.0` | [report](./tools/v0.4.0/aderyn/aderyn-report.md) | [feedback](./tools/v0.4.0/aderyn/aderyn-report-feedback.md) |
| Slither | — | not run | — |
| ERC conformance analysis (AI-assisted) | `v0.4.0` | [`ERC_RESULT.md`](../../ERC_RESULT.md) | — |

## Static-analysis results

| Tool | High | Medium | Low | Info | Anything to fix? |
| --- | --- | --- | --- | --- | --- |
| Aderyn `0.6.5` | 0 | — | 6 | 0 | **No.** 4 by design, 1 environment, 1 false positive; 1 of the "by design" instances overlaps a known scalability item (§4.7) |
| Slither | — | — | — | — | not run for `v0.4.0` |

Aderyn reports no Medium or Info categories; it classifies only High and Low.

## Substantive findings fixed in `v0.4.0`

From the ERC conformance analysis ([`ERC_RESULT.md`](../../ERC_RESULT.md)) rather than from the
static analyzers — neither tool can see these, since both are ABI- and specification-level:

| Finding | Severity | Status |
| --- | --- | --- |
| `getDocument` returned a `Document` struct where ERC-1643 mandates three flat values. Same selector and same `type(IERC1643).interfaceId` either way, so ERC-165 detection could not distinguish them and a spec-conformant consumer silently decoded corrupt values | High | **Fixed** — flat return on both overloads, pinned by `testGetDocumentReturnsFlatErc1643Abi`, which inspects the returndata directly |
| `ERC1643InvalidName` / `ERC1643MissingDocument` declared both locally and by `IERC1643`, which the multi-subject draft forbids and the compiler rejects | Blocker | **Fixed** — local declarations removed |
| Null-subject error named `ERC1643InvalidSubject`, after a standard in which the condition cannot occur, and declared on an abstract contract rather than an interface | Low | **Fixed** — renamed `MultiDocumentInvalidSubject` and moved to `IERC1643MultiDocument`; every specification error now sits on the interface defining its condition |
| `bindToken(address(0))` accepted, and bind/unbind emitted `TokenBindingSet` even when the binding did not change | Low | **Fixed** — null address rejected with `TokenBindingInvalidToken()`; both are now idempotent and emit only on a real transition |

## Known open items

Not defects in the sense of being exploitable, but tracked deviations from the specifications. Full
detail in [`ERC_RESULT.md`](../../ERC_RESULT.md) §7.

| Item | Severity | Where |
| --- | --- | --- |
| Authorization is not per-`subject`, and `_authorizeDocumentManagement()` takes no `subject`, so a deployment cannot make it per-subject by overriding the hook | High | §4.2 |
| Admin write path has no execution point in the subject, so an ERC-1643 subject emits nothing for writes sent straight to the engine | Medium | §4.3 |
| `_removeDocumentName` is O(n); no paginated enumeration | Low | §4.7 — also surfaced by Aderyn L-5 |
| The ERC-2771 trusted forwarder can act as any bound subject and is immutable | Info | §4.9 |

## Reporting a vulnerability

See the repository's security policy, or contact [admin@cmta.ch](mailto:admin@cmta.ch).
