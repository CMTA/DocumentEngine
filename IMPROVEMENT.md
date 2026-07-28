# IMPROVEMENT — open items

Known deviations, gaps and improvement opportunities in `DocumentEngine`, carried forward as of
**`v0.4.0`** (CMTAT `v3.3.0-rc2`).

They come from a clause-by-clause conformance analysis of the implementation against the two
specifications this engine implements:

| Spec | File | Role |
| --- | --- | --- |
| ERC-1643 — Document Management for Security Tokens | [`doc/ERCSpecification/erc-1643.md`](./doc/ERCSpecification/erc-1643.md) | Per-contract interface |
| Multi-Subject Document Management (unnumbered draft) | [`doc/ERCSpecification/erc-draft_multi_document_management.md`](./doc/ERCSpecification/erc-draft_multi_document_management.md) | Address-scoped companion interface |

**None of these is an exploitable vulnerability.** Items already fixed are not repeated here — they
are recorded in [`CHANGELOG.md`](./CHANGELOG.md) and in
[`doc/audits/AUDIT_OVERVIEW.md`](./doc/audits/AUDIT_OVERVIEW.md). Static-analysis findings are
tracked separately under [`doc/audits/tools/`](./doc/audits/tools).

> This project has not been audited. These items are the output of specification review and
> automated tooling, not of a formal security audit.

## Summary

| # | Item | Severity | Effort | Kind |
| --- | --- | --- | --- | --- |
| [1](#1--authorization-is-not-per-subject-and-the-hook-cannot-express-it) | Authorization is not per-`subject`, and the hook cannot express it | **High** | Medium | Spec `MUST` |
| [2](#2--the-admin-path-bypasses-subject-side-erc-1643-emission) | Admin path bypasses subject-side ERC-1643 emission | **Medium** | Small–Medium | Spec `SHOULD` |
| [3](#3--the-engine-advertises-ierc1643-but-is-not-a-usable-erc-1643-endpoint) | Engine advertises `IERC1643` but is not a usable ERC-1643 endpoint | Low | Trivial | Docs |
| [4](#4--enumeration-cost-and-removal-complexity) | Enumeration cost and removal complexity | Low | Medium | Gas |
| [5](#5--the-erc-2771-forwarder-is-a-universal-write-authority) | ERC-2771 forwarder is a universal write authority | Info | Trivial | Docs |
| [6](#6--_removedocument-emits-before-the-state-change) | `_removeDocument` emits before the state change | Info | Trivial | Cosmetic |
| [7](#7--upstream-imultidocumentsubject-manager-discovery) | Upstream: `IMultiDocumentSubject` manager discovery | Info | — | Upstream |

Item 1 is the only one that changes what the contract can express; everything else is documentation,
gas, or cosmetic. Item 1 is also **source-compatible** for existing deployments — the default hook
bodies would ignore the new argument — so it does not have to wait for a breaking release.

---

## 1 — Authorization is not per-`subject`, and the hook cannot express it

**Severity:** High · **Effort:** Medium · **Kind:** deviation from a specification `MUST`

**Where:** `src/DocumentEngineBase.sol:56`, `:71-84`, `:111-186`; `src/DocumentEngine.sol:46-48`;
`src/DocumentEngineOwnable.sol:39-41`

> Implementations **MUST** authorize writes per `subject`, so that a caller cannot create, update, or
> remove documents for a `subject` it is not permitted to manage.
> — draft §Authorization

`DOCUMENT_MANAGER_ROLE` is a single global permission: every holder may write for *every* subject.
`DocumentEngineOwnable` is the same with `owner`. This is precisely the risk the draft's Security
Considerations open with — "a management contract holds the document sets of unrelated subjects
behind a single address" — and the engine's design is, by default, the unmitigated case.

That alone might be defensible as a deployment choice, since the project's stated model is a single
operator managing a fleet it owns. The structural problem is that the escape hatch does not work:

```solidity
function _authorizeDocumentManagement() internal view virtual;   // no subject parameter
```

A deployment cannot override this hook to implement per-subject rules, because at the point it runs
the subject is not available. In the batch functions the situation is worse — the modifier fires
**once** for the whole call, before any element is read, so even a subject-aware hook would be
bypassed for `batchSetDocuments` / `batchRemoveDocuments`.

Consequently the draft's own test case —

> A caller not authorized for a subject failing to create, update, or remove that subject's documents.

— is untestable against this codebase, and is indeed absent from the suite. The existing
`testNonAdmin*` tests cover the globally-unauthorized case only.

**Mitigating factor.** The **bound-token path is already per-subject** and cannot be escaped: the
namespace is `_msgSender()`, structurally. A deployment that overrides
`_authorizeDocumentManagement()` to always revert is fully conformant today — but that removes the
admin path entirely rather than scoping it.

**Recommendation.** Change the hook signature and call it per subject:

```solidity
function _authorizeDocumentManagement(address subject) internal view virtual;

function batchSetDocuments(address[] calldata subjects, ...) external {
    for (uint256 i = 0; i < length; ++i) {
        _authorizeDocumentManagement(subjects[i]);
        _setDocument(subjects[i], names[i], uris[i], hashes[i]);
    }
}
```

The default implementations stay exactly as they are (`_checkRole(DOCUMENT_MANAGER_ROLE)` /
`_checkOwner()`, ignoring `subject`), so behaviour and gas are effectively unchanged, but a
deployment gains the ability to be conformant — for example a per-subject role
`keccak256("DOCUMENT_MANAGER", subject)`. Token binding needs a separate hook
(`_authorizeTokenBinding()`), since binding has no subject.

Add the draft's missing test case once the hook can express it.

## 2 — The admin path bypasses subject-side ERC-1643 emission

**Severity:** Medium · **Effort:** Small–Medium · **Kind:** deviation from a specification `SHOULD`

**Where:** `src/DocumentEngineBase.sol:71-84`; demonstrated at `test/DocumentEngine.t.sol:197`

> A deployment in which an operator calls `setDocument(address subject, ...)` … directly, with no
> execution point in the subject, does **not** satisfy ERC-1643's emission requirement for that
> subject.
> — draft §Call Topology

> a management contract SHOULD restrict its address-scoped writes to callers for which one of the two
> topologies above holds.

Neither deployment applies such a restriction. The repository's own CMTAT integration test writes
through exactly the prohibited path:

```solidity
// test/DocumentEngine.t.sol:196-197
vm.prank(admin);
documentEngine.setDocument(address(cmtat), documentName, documentURI, documentHash);
```

The engine emits `DocumentUpdatedForSubject`; the CMTAT token emits nothing; anyone subscribed to the
token's address concludes its documents are unchanged. The failure is silent in both directions, as
the draft's Security Considerations describe.

The **subject-initiated** topology, by contrast, became fully conformant with CMTAT `v3.3.0-rc2`,
which lists this under *Fixed* as "Delegating document token emits ERC-1643 events on its own address
(dual emission)". `DocumentEngineModule` forwards to the engine and then re-emits `DocumentUpdated` /
`DocumentRemoved` on the **token's** own address (`DocumentEngineModule.sol:91-92`, `:102-104`),
reading the metadata before removal so `DocumentRemoved` carries the removed values as the spec
requires; the engine emits the address-carrying events on its own address. Both mutators also revert
with `CMTAT_DocumentEngineModule_NoDocumentEngine` when no engine is set, closing a path where a
write would previously have been lost.

So the gap is narrow but sharp: whether a CMTAT subject's documents are observable on its own address
depends entirely on **which door the operator uses**. Through the token (`cmtat.setDocument(...)`) it
is; straight to the engine (`engine.setDocument(address(cmtat), ...)`) it is not. Nothing in either
contract signals the difference.

**Recommendation.** Pick one and state it:

- *Documentation-only* (cheapest): a prominent README/NatSpec note that the address-scoped writes are
  for subjects that either do not implement ERC-1643 or accept the loss of per-contract
  observability; the bound-token path is the conformant route for ERC-1643 subjects.
- *Enforced*: gate the address-scoped writes on `isTokenBound(subject) == false`, forcing ERC-1643
  subjects through their own contract.
- *Callback*: add the draft's "manager-initiated with callback" topology — an optional permissioned
  hook on the subject invoked after the write, so the subject emits.

## 3 — The engine advertises `IERC1643` but is not a usable ERC-1643 endpoint

**Severity:** Low · **Effort:** Trivial · **Kind:** documentation

**Where:** `src/DocumentEngine.sol:88`; `src/DocumentEngineOwnable.sol:47-49`

This is permitted — the draft's rule is that a contract may advertise `type(IERC1643).interfaceId`
*only if* it implements the base functions, and the engine does. But those functions are
`_msgSender()`-scoped (`DocumentEngineBase.sol:181-216`), so a consumer that ERC-165-detects
ERC-1643 on the **engine** address and then calls `getDocument(name)` receives empty values, no
revert, and never sees a base event. This is the deployment error the draft's Backwards Compatibility
section names as the one way to break a legacy consumer, and ERC-165 offers no way to detect it.

**Recommendation.** Documentation, not code: state prominently in the README and in the NatSpec of
the no-argument functions that consumers must be pointed at the **subject**, never at the engine, and
that the base functions exist solely for bound subjects calling on their own behalf.

## 4 — Enumeration cost and removal complexity

**Severity:** Low · **Effort:** Medium · **Kind:** gas / scalability

**Where:** `src/DocumentEngineBase.sol:236-245`, `:206-216`, `:150-186`

- `_removeDocumentName` is a linear scan over the subject's name array. The draft's Reference
  Implementation section expects "index tracking to support O(1) removals". `batchRemoveDocuments`
  compounds this to O(n·m) and can plausibly exceed the block gas limit for a subject with a large
  document set.
- `getAllDocuments` returns the entire array with no paginated alternative. ERC-1643's Security
  Considerations explicitly call this out: "Implementations expecting large sets should consider
  exposing an additional paginated accessor alongside this interface."

Neither is a conformance failure. Independently corroborated by Aderyn — L-5 at
`DocumentEngineBase.sol:238`, reached from its "costly operation in a loop" heuristic
([triage](./doc/audits/tools/v0.4.0/aderyn/aderyn-report-feedback.md)).

**Recommendation.** Add `mapping(address => mapping(bytes32 => uint256)) private _nameIndex` for
O(1) swap-and-pop, plus `getDocumentsPaginated(address subject, uint256 offset, uint256 limit)` and
`getDocumentCount(address subject)`.

## 5 — The ERC-2771 forwarder is a universal write authority

**Severity:** Info · **Effort:** Trivial · **Kind:** documentation

**Where:** `src/DocumentEngine.sol:99-101`; `src/modules/TokenBindingModule.sol:84-88`

`_msgSender()` drives both `_checkTokenBound()` and the role check. The trusted forwarder can
therefore present itself as any bound subject — writing into that subject's namespace — and as any
role holder. This is the ordinary ERC-2771 trust assumption, but it deserves stating explicitly given
the draft's framing:

> Subjects should treat the choice of management contract as a permissioning decision, not merely a
> storage one.

A subject binding to this engine is also trusting the engine's forwarder. `forwarderIrrevocable` is
immutable, which is the right call for predictability, but it also means a compromised forwarder
cannot be revoked — the only remedy is unbinding every subject and migrating.

**Recommendation.** Document the forwarder as part of every bound subject's trust boundary, in the
README section on ERC-2771 and in the constructor NatSpec.

## 6 — `_removeDocument` emits before the state change

**Severity:** Info · **Effort:** Trivial · **Kind:** cosmetic

**Where:** `src/DocumentEngineBase.sol:258` (emit) before `:260-261` (delete)

The specs mandate "after state changes" for `setDocument` only, and the implementation complies there
(`:286`). For removal the metadata must be read before deletion, so the current ordering is
convenient; there are no external calls anywhere in the write path, so there is no reentrancy
exposure.

**Recommendation.** Cosmetic only — the metadata is already cached in the `doc` local, so emitting
after the delete would align both paths at no cost.

## 7 — Upstream: `IMultiDocumentSubject` manager discovery

**Severity:** Info · **Kind:** upstream (CMTAT), not this repository

Not implemented here, and correctly so: the draft is explicit that this interface is "**implemented
by the subject, not by the management contract**", and it is optional for both. No action is required
of the engine.

There is, however, a near-miss upstream worth aligning. CMTAT's `DocumentEngineModule` already
exposes the same concept under a different shape:

| draft `IMultiDocumentSubject` | CMTAT `DocumentEngineModule` |
| --- | --- |
| `documentManager() returns (address)` | `documentEngine() returns (IERC1643)` |
| `DocumentManagerUpdated(address previous, address new)` | `DocumentEngine(IERC1643 engine)` — no previous address |
| MUST return `address(0)` when not delegated | ✅ default zero |
| MUST NOT revert | ✅ |

**Recommendation.** Adding the previous address to the CMTAT event, or an alias getter, would make
CMTAT tokens discoverable by any consumer implementing the draft. That is a change for CMTAT, not for
this repository.

---

## Not open items

Recorded so they are not re-raised. Verified conformant, several by explicit test:

- **Subject isolation** — `mapping(address => mapping(bytes32 => Document))` with a per-subject name
  array, covered by a fuzz test. A bound subject writes to `_msgSender()` and structurally cannot
  reach another namespace.
- **Emission responsibility** — only `DocumentUpdatedForSubject` / `DocumentRemovedForSubject`, never
  the base events, as the draft requires of a multi-subject manager. The suite asserts the *absence*
  of the base events.
- **`lastModified == 0` as the sole absent-entry sentinel** — respected as both the read convention
  and the internal existence check, keeping `uri` / `documentHash` free to be legitimately empty.
- **Null-subject guard on the write path only** — matching the draft's note that guarding
  `setDocument` suffices, since removal then fails with `ERC1643MissingDocument()` anyway.
- **`IERC1643MultiDocument` neither inherits nor imports `IERC1643`** — the independence the draft
  requires is a property of the file, not a convention.
- **`getDocument` returns the flat ERC-1643 ABI** — pinned by a test that inspects returndata, since
  the interface id is identical for both shapes and ERC-165 cannot catch a regression. Both interface
  ids are asserted as literals (`0xecfecec8`, `0xa2b1179b`).
- **Unstable ordering after removal** — explicitly permitted by ERC-1643; swap-and-pop is fine.
