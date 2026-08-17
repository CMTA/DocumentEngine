# Security & audit overview — DocumentEngine

> **This project has not been audited.** No formal external security audit has been performed on any
> release. What follows is the record of the automated and AI-assisted analyses that *have* been run.
> These are **not** a substitute for an audit. Anyone deploying this engine in production must
> commission their own independent security assessment.

## In scope

The `src/` tree only — 9 files, 307 nSLOC as of `v0.4.0`:

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
| Slither `0.11.5` | `v0.4.0` | [report](./tools/v0.4.0/slither/slither-report.md) | [feedback](./tools/v0.4.0/slither/slither-report-feedback.md) |
| ERC conformance analysis (AI-assisted) | `v0.4.0` | open items: [`IMPROVEMENT.md`](../../IMPROVEMENT.md) | — |

Both tool runs are against CMTAT `v3.3.0-rc3` and OpenZeppelin `v5.7.0`, with mocks and tests
excluded.

## Static-analysis results

| Tool | High | Medium | Low | Info | Anything to fix? |
| --- | --- | --- | --- | --- | --- |
| Aderyn `0.6.5` | 0 | — | 6 | 0 | **No.** 4 by design, 1 environment, 1 false positive; 1 of the "by design" instances overlaps a known scalability item (§4.7) |
| Slither `0.11.5` | 0 | 1 | 1 | 2 | **No.** All 4 are false positives, reducing to two pieces of code: an existence check (`doc.lastModified == 0`) read as a timestamp comparison, and two `_msgData()` overrides read as dead code |

Aderyn reports no Medium or Info categories; it classifies only High and Low.

**Neither tool found anything to fix in `v0.4.0`.** The two agree on the absence of the classic
classes — no reentrancy, no access-control gap, no uninitialised state, no unchecked external call —
which is the expected result for a contract that holds no funds and makes no external calls. They
disagree only on what is worth reporting: Slither's highest result (`incorrect-equality`, Medium) is
one Aderyn ignores, and Aderyn's loop advisories draw nothing from Slither. Each dismissal was
verified against the cited line; the `_msgData()` "dead code" was verified by deleting it and
confirming the compile fails (`Error (6480): Derived contract must override function "_msgData"`).

Note the standing limitation: neither tool can see the specification-level issues that matter most
for this engine — those are tracked as open items below.

## Substantive findings fixed in `v0.4.0`

From the ERC conformance analysis (open items: [`IMPROVEMENT.md`](../../IMPROVEMENT.md)) rather than from the
static analyzers — neither tool can see these, since both are ABI- and specification-level:

| Finding | Severity | Status |
| --- | --- | --- |
| `getDocument` returned a `Document` struct where ERC-1643 mandates three flat values. Same selector and same `type(IERC1643).interfaceId` either way, so ERC-165 detection could not distinguish them and a spec-conformant consumer silently decoded corrupt values | High | **Fixed** — flat return on both overloads, pinned by `testGetDocumentReturnsFlatErc1643Abi`, which inspects the returndata directly |
| `ERC1643InvalidName` / `ERC1643MissingDocument` declared both locally and by `IERC1643`, which the multi-subject draft forbids and the compiler rejects | Blocker | **Fixed** — local declarations removed |
| Null-subject error named `ERC1643InvalidSubject`, after a standard in which the condition cannot occur, and declared on an abstract contract rather than an interface | Low | **Fixed** — renamed `MultiDocumentInvalidSubject` and moved to `IERC1643MultiDocument`; every specification error now sits on the interface defining its condition |
| `bindToken(address(0))` accepted, and bind/unbind emitted `TokenBindingSet` even when the binding did not change | Low | **Fixed** — null address rejected with `TokenBindingInvalidToken()`; both are now idempotent and emit only on a real transition |
| ERC-165 advertises `type(IERC1643).interfaceId`, which a token uses to check the base endpoints exist, but which a third party could misread as "read documents here" — the base functions are caller-scoped, so such a read silently returns an empty namespace | Low | **Documented** — the id is kept for the token's capability check; the caveat is stated in the README and both `supportsInterface` NatSpecs, and asserted by a test |

## Known open items

Not defects in the sense of being exploitable, but tracked deviations from the specifications. Full
detail, with a recommendation for each, in [`IMPROVEMENT.md`](../../IMPROVEMENT.md).

| Item | Severity | Where |
| --- | --- | --- |
| `_authorizeDocumentManagement()` takes no `subject`, so a deployment cannot make authorization per-subject by overriding the hook. Conformant for the single-issuer fleet the engine targets — `DOCUMENT_MANAGER_ROLE` is permitted to manage every subject — but it means one instance serves one trust domain | Low (Medium if shared across unrelated issuers) | item 1 |
| Admin write path has no execution point in the subject, so an ERC-1643 subject emits nothing for writes sent straight to the engine | Medium | item 2 |
| `_removeDocumentName` is O(n); no paginated enumeration | Low | item 4 — also surfaced by Aderyn L-5 |
| The ERC-2771 trusted forwarder can act as any bound subject and is immutable | Info | item 5 |

## Reporting a vulnerability

See the repository's security policy, or contact [admin@cmta.ch](mailto:admin@cmta.ch).
