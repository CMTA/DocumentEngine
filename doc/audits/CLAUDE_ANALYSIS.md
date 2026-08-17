# DocumentEngine — Code Quality Review

| | |
| --- | --- |
| Scope | `src/` (9 files, 307 nSLOC) and `script/` (2 files). `lib/`, `test/` excluded except where cited as evidence. |
| Version | `v0.4.0` (unreleased) |
| Dependencies | CMTAT `v3.3.0-rc3`, OpenZeppelin `v5.7.0`, RuleEngine `v3.0.0-rc5` |
| Compiler | solc `0.8.34`, `evm_version = prague`, optimizer on (200 runs) |
| Date | 2026-08-17 |
| Produced with | Claude Code |

> **This is a code-quality review, not a security audit.** Nothing in this report is a
> vulnerability. No finding lets an unauthorized party move value, bypass a restriction, or brick a
> contract. The one finding that *looks* like an access-control problem on first reading — **H-1**,
> revoking a role from the default admin does not remove its access — is analysed below and is not
> exploitable: the default admin can re-grant itself any role in the same transaction, so the
> "revocation" could never have been a durable restriction. Its defect is misleading feedback, not
> lost containment.
>
> For the static-analysis passes see [`AUDIT_OVERVIEW.md`](./AUDIT_OVERVIEW.md); both Aderyn and
> Slither found nothing to fix. This review covers what those tools structurally cannot see.

## Disposition summary

| ID | Finding | Outcome | Where |
| --- | --- | --- | --- |
| A-1 | `unchecked { ++i }` would buy nothing on this compiler | ⬜ left as is (anti-recommendation) | `DocumentEngineBase.sol:118,141,158,175,264` |
| A-2 | `string memory` on the admin `setDocument` — `calldata` is **slower** here | ⬜ left as is (measured) | `DocumentEngineBase.sol:245` |
| B-1 | Mapping slot re-hashed every iteration in `_removeDocumentName` | ✅ fixed, **−2200 gas** | `DocumentEngineBase.sol:263` |
| B-2 | `_removeDocument` copied the whole `Document` (incl. the URI) to memory | ✅ fixed, **−645 gas** | `DocumentEngineBase.sol:281` |
| C-1 | Every event has exactly one emit site | ⬜ nothing to do — verified good | — |
| C-2 | Trusted forwarder set at construction without an event | ⬜ left as is | `DocumentEngine.sol:40` |
| D-1 | ERC-2771 trio duplicated byte-for-byte across both deployments | ⬜ left as is — **extraction proven impossible** | `DocumentEngine.sol:137`, `DocumentEngineOwnable.sol:73` |
| E-1 | `virtual` coverage inconsistent between the two modules | ⚠️ decide — not implemented | `DocumentEngineBase.sol`, `TokenBindingModule.sol` |
| F-1 | ERC-165 interface IDs — no inherited-selector trap | ⬜ nothing to do — verified correct | `DocumentEngine.sol:115` |
| G-1 | `DocumentEngineInvariant` comment misattributes `NotBoundToken` | ✅ fixed | `DocumentEngineInvariant.sol` |
| G-2 | Contracts point at documentation paths that have already moved once | ⚠️ decide — not implemented | 3 sites |
| G-3 | NatSpec block-length distribution is healthy | ⬜ nothing to do — measured | — |
| H-1 | A role cannot be revoked from the default admin, but the call succeeds | ✅ documented + regression test | `DocumentEngine.sol:73` |
| H-2 | Caller-scoped reads return an empty namespace instead of reverting | ⬜ left as is — already documented and tested | `DocumentEngineBase.sol:186` |

Rows: 14. Fixed: 4. Left deliberately: 8. Open decisions: 2.

## Outstanding

| ID | Item | Why it is still open |
| --- | --- | --- |
| E-1 | Make the document-management API and the binding internals `virtual` | Changes the extension surface the project commits to. Free at runtime (measured, 0 gas) but it is a design commitment, so it is the maintainer's call — see the two options in E-1. |
| G-2 | Remove the `doc/…` pointers baked into contract comments | Two of the three sites *lean* on the doc rather than merely citing it; removing the pointer alone would leave an incomplete warning. Needs a sentence written per site, which is an editorial decision. |

---

## A. Loops and iteration

### A-1. `unchecked { ++i }` would buy exactly nothing — do not add it

`DocumentEngineBase.sol:118, 141, 158, 175, 264`. All five loops already use `++i` with a bound
read once into a local:

```solidity
uint256 length = subjects.length;
for (uint256 i = 0; i < length; ++i) {
```

This project compiles with solc `0.8.34`. Since **0.8.22** the compiler elides the overflow check on
a loop counter it can prove bounded, so the `unchecked` block that reviewers habitually recommend is
dead weight. Measured rather than asserted — two contracts, each with a single function of the same
name, so selector-dispatch depth cannot skew the comparison:

| variant | gas, 100 iterations |
| --- | --- |
| `++i` | 33 005 |
| `unchecked { ++i }` | 33 005 |
| **delta** | **0** |

**Verdict: leave.** Recorded here specifically so the next review does not re-raise it. Adding the
`unchecked` block would cost three lines of noise and buy zero gas.

### A-2. `string memory` on the admin `setDocument` — `calldata` is measurably *worse*

`DocumentEngineBase.sol:245`:

```solidity
function setDocument(address subject, bytes32 name_, string memory uri_, bytes32 documentHash_)
    public override onlyDocumentManager
```

The standing advice is that an external-only entrypoint should take `calldata`. This function
qualifies — nothing calls it internally — and the interface it overrides already declares
`string calldata`. I toggled it to `external` + `string calldata` in place and re-ran the same
harness:

| path | `string memory` | `string calldata` | delta |
| --- | --- | --- | --- |
| new document, short URI | 107 895 | 107 944 | **+49** |
| new document, long URI (105 chars) | 194 876 | 194 925 | **+49** |
| update, long URI | 105 500 | 105 549 | **+49** |

Consistently **49 gas worse**, and flat in URI length — so it is not the copy. The reason the
expected saving does not materialise is that `_setDocument` takes `string memory`, so the
calldata→memory copy happens either way; `calldata` only moves it and adds offset handling.

**Verdict: leave.** This is the case where the textbook optimization is a pessimisation. Changing
`_setDocument` to take `calldata` too is not possible — the bound-token path already passes
`calldata` there and the batch paths pass array elements, so the parameter must stay `memory` for
one of its callers regardless.

## B. Storage reads

### B-1. The mapping slot was re-hashed on every loop iteration — **fixed, −2200 gas**

`DocumentEngineBase.sol:262`. Before:

```solidity
uint256 length = _documentNames[subject].length;
for (uint256 i = 0; i < length; ++i) {
    if (_documentNames[subject][i] == name_) {
        _documentNames[subject][i] = _documentNames[subject][length - 1];
        _documentNames[subject].pop();
```

Every `_documentNames[subject]` recomputes `keccak256(subject . slot)` — a hash per access, twice per
iteration on the comparison path. Caching the array as a storage pointer computes it once:

```solidity
bytes32[] storage names = _documentNames[subject];
uint256 length = names.length;
for (uint256 i = 0; i < length; ++i) {
    if (names[i] == name_) {
```

Measured on a subject holding 20 documents, toggled in place, same harness both times:

| case | before | after | delta |
| --- | --- | --- | --- |
| target at index 19 (full scan) | 87 250 | 85 050 | **−2200** |
| target at index 0 (early exit) | 28 397 | 28 002 | −395 |

≈116 gas per iteration. This is the function `IMPROVEMENT.md` item 4 already flags as the O(n)
scalability hotspot, and `batchRemoveDocuments` compounds it to O(n·m), so the saving multiplies.

**Verdict: implemented.** Note this does not change the complexity — it lowers the constant. The
index-mapping fix that would make removal O(1) remains the open item it was.

### B-2. `_removeDocument` copied the entire struct, URI included — **fixed, −645 gas**

`DocumentEngineBase.sol:281`. `Document memory doc = _documents[subject][name_];` copies all three
fields into memory, including the dynamic `uri` string, before the existence check. Both the check
and the event read the fields, but they can read them through a storage pointer instead:

```solidity
Document storage doc = _documents[subject][name_];
```

| case | before B-1 | after B-1 | after B-1+B-2 | total |
| --- | --- | --- | --- | --- |
| full scan | 87 250 | 85 050 | **84 405** | **−2845 (−3.3 %)** |
| early exit | 28 397 | 28 002 | **27 357** | **−1040 (−3.7 %)** |

**The hazard, and how it was checked.** With a storage pointer the emit *must* stay before the
`delete`; move it after and the event silently logs an empty URI and a zero hash rather than
reverting. Rather than assume the suite catches that, I introduced the mutation deliberately:

```
[FAIL: DocumentRemovedForSubject != expected DocumentRemovedForSubject]
    testRemoveDocumentEmitsForSubjectEvent()
```

The guard is real. Ordering restored, 73/73 passing.

**Verdict: implemented.** Storage layout re-checked from the compiled artifacts afterwards
(`--extra-output storageLayout`, 5 non-empty entries per deployment, unchanged).

## C. Events

### C-1. Single emit site per event — verified, nothing to do

The usual failure here is an event emitted from several places, so "every write emits" holds by
convention rather than structurally. Counted:

| event | emit sites |
| --- | --- |
| `DocumentUpdatedForSubject` | 1 (`_setDocument`) |
| `DocumentRemovedForSubject` | 1 (`_removeDocument`) |
| `TokenBindingSet` | 1 (`_setTokenBinding`) |

All three already funnel through a single internal writer that owns validation + write + event, and
every public entrypoint delegates to it — including the batch variants, which call `_setDocument` /
`_removeDocument` rather than re-implementing. This is the shape the check exists to recommend; it is
already in place.

**Verdict: nothing to do.** Recorded because it is the strongest structural property in the codebase
and a future refactor should preserve it.

### C-2. The trusted forwarder is not evented at construction

`DocumentEngine.sol:40` / `DocumentEngineOwnable.sol:32` pass `forwarderIrrevocable` to
`ERC2771Context` and emit nothing, so a log-only indexer never sees the value. That matters more than
usual here because the forwarder can act as any bound subject (`IMPROVEMENT.md` item 5).

Against that: the value is `immutable`, so it can never change and there is no sequence to
reconstruct; it is publicly readable — `trustedForwarder()` (`0x7da0a877`) and
`isTrustedForwarder(address)` are both in the ABI, confirmed with `forge inspect`; and OpenZeppelin
itself emits nothing here, so adding an event departs from upstream for a one-off value anyone can
read.

**Verdict: leave.** A single `SLOAD`-free public getter of an immutable is adequate observability.

## D. Duplication

### D-1. The ERC-2771 trio is byte-identical across both deployments — and cannot be shared

`DocumentEngine.sol:137-157` and `DocumentEngineOwnable.sol:73-93` contain `_msgSender`, `_msgData`
and `_contextSuffixLength`, **10 code lines each** (NatSpec excluded), byte-for-byte identical
(`diff` confirms).

Both projects this codebase cites as its pattern reference do extract this: RuleEngine has
`ERC2771ModuleStandalone`, CMTAT has `ERC2771Module` plus `6_CMTATBaseERC2771.sol`, which holds the
trio and marks it `virtual`. On that evidence the obvious recommendation is "extract a shared
`ERC2771Module`".

**I built it, and it does not compile.** First attempt — module inherits `ERC2771Context` and
declares the three overrides:

```
Error (2353): Invalid contract specified in override list: "Context".
Error (6480): Derived contract must override function "_msgData".
              Two or more base classes define function with same name and parameter types.
  --> src/DocumentEngine.sol
```

Second attempt — module inherits `Context, ERC2771Context`, which fixes the first error:

```
Error (6480): Derived contract must override function "_msgSender".
Error (6480): Derived contract must override function "_msgData".
Error (6480): Derived contract must override function "_contextSuffixLength".
  --> src/DocumentEngine.sol
```

The reason is C3 linearization, and it is why the reference projects can do what this one cannot.
CMTAT's inheritance is a single linear chain (`1_…` → `7_`), so one base can resolve `Context` for
everything below it. Here the two deployments **diverge at the access-control base** —
`AccessControlEnumerable` in one, `Ownable2Step` in the other — and each of those brings its own
`Context` branch. Solidity requires the most-derived contract to resolve the ambiguity, so the
override must be re-stated in each deployment no matter what a shared parent does.

**Verdict: leave.** The duplication is forced by the language, not an oversight. Ten lines is the
price of supporting two access-control models, and this entry exists so the next reviewer does not
spend the same hour discovering it. (RuleEngine's `ERC2771ModuleStandalone`, worth noting, contains
only a constructor — *not* the trio — which is consistent with this conclusion.)

## E. `virtual` / override convention

### E-1. The two modules disagree about what is overridable

`CLAUDE.md` states the convention as *"restricted functions use the `onlyDocumentManager` /
`onlyBoundToken` modifiers, which delegate to overridable `internal virtual` hooks"*. Both hooks are
`virtual`, so the documented convention is met. The inconsistency is one level out:

| contract | `virtual` | not `virtual` |
| --- | --- | --- |
| `TokenBindingModule` | `bindToken`, `unbindToken`, `isTokenBound`, `_authorizeBoundTokenDocumentManagement` | `_setTokenBinding`, `_checkTokenBound` |
| `DocumentEngineBase` | `_authorizeDocumentManagement`, `_authorizeBoundTokenDocumentManagement` (both abstract) | all 13 others — `setDocument` ×2, `removeDocument` ×2, `batchSetDocuments` ×2, `batchRemoveDocuments` ×2, `getDocument` ×2, `getAllDocuments` ×2, `_setDocument`, `_removeDocument`, `_removeDocumentName`, `_getDocument` |

So `TokenBindingModule` exposes its whole public surface for override while hiding its internals, and
`DocumentEngineBase` does the reverse — nothing overridable but the two abstract hooks. Two modules
in one codebase, opposite conventions. That inconsistency is the finding, independent of which is
right.

For reference, CMTAT's `DocumentERC1643Module` — the module this engine mirrors — is **5 of 5**
public/external/internal functions `virtual`.

The consequence is concrete: a deployment cannot override `getAllDocuments` to paginate, or
`setDocument` to add a per-subject policy, even though the architecture is explicitly built around
subclassing (the suite's own `OpenDocumentEngine` demonstrates the pattern).

Cost: **zero**, measured rather than asserted — `virtual` on an internal function is resolved
statically unless actually overridden:

| variant | gas |
| --- | --- |
| `internal` | 885 |
| `internal virtual` | 885 |

**Verdict: decide.** Two coherent options, either better than today's split:
1. **Match CMTAT** — mark the `DocumentEngineBase` public API and the `TokenBindingModule` internals
   `virtual`. Maximum extensibility, zero runtime cost, but it commits the project to a much larger
   override surface as public API.
2. **Tighten instead** — drop `virtual` from `bindToken`/`unbindToken`/`isTokenBound` so that only the
   authorization hooks are overridable, matching what `CLAUDE.md` actually promises.

Not implemented: this is a commitment about the extension surface, which is the maintainer's call,
not a reviewer's.

## F. ERC / specification conformance

### F-1. No ERC-165 inherited-selector trap — verified correct

The classic bug is `type(IFoo).interfaceId` covering only the selectors declared *directly* on `IFoo`
while the contract advertises it as covering inherited ones too. Checked all four interfaces:

| interface | inherits | functions declared directly | id covers all |
| --- | --- | --- | --- |
| `IERC1643` (CMTAT) | nothing | 4 | yes |
| `IERC1643MultiDocument` | nothing (deliberately not `IERC1643`) | 4 | yes |
| `ITokenBinding` | nothing | 3 | yes |
| `IERC8303` | nothing | 1 | yes |

Every interface is flat, so each `interfaceId` is the complete XOR of its surface and the trap cannot
arise. `IERC1643MultiDocument`'s deliberate non-inheritance of `IERC1643` — documented in its own
NatSpec — is what makes this safe, and is worth preserving for that reason as well as the one already
given.

Sentinel handling checked too: `_setDocument` rejects `subject == address(0)`
(`MultiDocumentInvalidSubject`) and `_setTokenBinding` rejects `token == address(0)`
(`TokenBindingInvalidToken`), so `address(0)` can never become a document-holding subject. The read
paths do not re-check it, but a read against a namespace that cannot be populated returns empty and
is harmless.

**Verdict: nothing to do.**

## G. Code / documentation mismatch

### G-1. `DocumentEngineInvariant` misattributes an error — **fixed**

`DocumentEngineInvariant.sol` carried a comment mapping each specification error to the interface
that declares it:

```
//   - `NotBoundToken(address)`                            → `ITokenBinding`
```

`NotBoundToken` is **not** declared by `ITokenBinding`. It is declared in `TokenBindingModule`
(`error NotBoundToken(address caller);`); `ITokenBinding` declares only `TokenBindingInvalidToken`.
The comment exists precisely to tell a reader where each error lives, so an incorrect entry defeats
its own purpose — and this one would send an integrator building an ABI from `ITokenBinding` looking
for a selector that is not there.

**Verdict: implemented** — the line now names `TokenBindingModule`, with a note on why that one
differs (it is the module's own operational error, not a specification error, so no interface
declares it).

### G-2. Three contract comments point at documentation paths — one has already broken once

```
src/DocumentEngineBase.sol:289          // responsibility). See doc/ERCSpecification.
src/DocumentEngineBase.sol:325          // event (see {_removeDocument} note and doc/ERCSpecification).
src/interfaces/IERC1643MultiDocument.sol:13
    * on-chain product). See `doc/ERCSpecification/erc-draft_multi_document_management.md`.
```

Documentation moves; deployed source does not. Someone reading verified source on a block explorer
has the comment and not the file. This is normally a theoretical risk — here it is a demonstrated
one, from this repo's own history:

```
1233b42  A  doc/ERCSpecification/ERC-1643-proposition.md
113a348  D  doc/ERCSpecification/ERC-1643-proposition.md
5d13ee0  A  doc/ERCSpecification/erc-draft_multi_document_management.md
```

The file was added, deleted, and replaced under a different name inside four commits. A `README`
pointer to the old name survived that rename as a dangling link until it was fixed in this session.
The pointer now baked into `IERC1643MultiDocument.sol` names the *replacement*, which is one rename
away from the same fate — except that this one would be frozen in verified bytecode.

**Verdict: decide.** The fix is not deletion — it is to move the substance in and drop only the
pointer. The three sites differ:
- `DocumentEngineBase.sol:289` — the preceding sentence already states the emission rule in full; the
  pointer comes out cleanly.
- `DocumentEngineBase.sol:325` — same, and the `{_removeDocument}` cross-reference is a NatSpec link
  that resolves within the source, so it stays.
- `IERC1643MultiDocument.sol:13` — this one *leans* on the document; removing the pointer alone
  leaves "the reasoning applies to any … on-chain product" with no statement of what the reasoning
  is. A replacement clause has to be written.

Not implemented because that third site needs an editorial decision about how much of the draft's
rationale belongs in the interface.

Two exemptions deliberately **not** flagged: mocks and tests (never deployed), and citations of audit
records by bare filename (`CLAUDE_ANALYSIS.md` plus a finding ID) — those are immutable historical
records, the bare filename survives a move, and the ID carries context a comment cannot restate. The
regression test added under H-1 cites this report exactly that way, on purpose.

### G-3. NatSpec block lengths are healthy — measured, nothing to do

The usual finding here is a handful of 30–40 line contract headers a reader must wade through before
reaching any code. Measured across `src/`:

| metric | value |
| --- | --- |
| NatSpec blocks | 65 |
| median | 6 lines |
| 90th percentile | 11 lines |
| max | 24 lines |
| blocks ≥ 20 lines | **1** |

One outlier: the 24-line block on `DocumentEngine.supportsInterface`. Its content is a genuine
footgun warning — that advertising `type(IERC1643).interfaceId` is *not* an invitation to read
documents from the engine's address, because the base functions are caller-scoped and a third-party
read silently returns an empty namespace. That is a safety precondition with a non-obvious failure
mode, which is exactly what earns space in a comment.

**Verdict: nothing to do.** Reported with the distribution attached, because "24 lines" only means
something next to a median of 6 — and here the ratio is defensible.

## H. Weird behaviour

### H-1. Revoking a role from the default admin succeeds but removes nothing — **documented**

`DocumentEngine.sol:73` overrides `hasRole` so that `DEFAULT_ADMIN_ROLE` implicitly holds every role.
The existing NatSpec documented one consequence (the enumeration mismatch). It did not document this
one, which I verified by running it:

```
after revokeRole, hasRole(admin): TRUE
getRoleMemberCount:               0
admin STILL wrote a document after its role was revoked
```

`revokeRole(DOCUMENT_MANAGER_ROLE, admin)` **succeeds**, emits `RoleRevoked`, and genuinely removes
the explicit grant — `getRoleMemberCount` drops to 0. Yet `hasRole` still answers `true`, so the
admin sails through `_checkRole` and writes a document. An operator watching events, or a dashboard
reading `getRoleMemberCount`, sees a successful revocation that did not happen. The contrast case
behaves correctly: an ordinary grantee is properly blocked after revocation.

**Why this is a quality finding and not a vulnerability.** No privilege is gained. The default admin
is the most privileged account by construction and can call `grantRole` to restore any role in the
same transaction, so "revoking a role from the admin" could never have been a durable restriction —
only revoking `DEFAULT_ADMIN_ROLE` itself withdraws anything. The defect is that the call reports
success for something it cannot do.

**Verdict: documented, not changed.** Making `revokeRole` revert here would deviate from
`IAccessControl` semantics and break the "admin has all roles" model the contract deliberately
adopts. Instead:
- a `WARNING:` paragraph was added to the `hasRole` NatSpec stating that a role is unrevokable from
  the default admin and that only `DEFAULT_ADMIN_ROLE` itself can be withdrawn;
- `testRevokingRoleFromDefaultAdminDoesNotRemoveAccess` pins the behaviour, asserting all three
  facts — `hasRole` still true, `getRoleMemberCount` zero, write still succeeds — so the surprise is
  a tested property rather than a latent one.

### H-2. Caller-scoped reads return empty rather than reverting

`getDocument(bytes32)` and `getAllDocuments()` resolve against `_msgSender()`. A third party calling
them on the engine reads *its own* namespace: no revert, no error, just empty values. This is the
"hardcoded everything-is-fine answer" shape, and it travels — an integrator who wires a UI to the
engine address sees a document set that is silently empty rather than an error telling them they
asked the wrong contract.

**Verdict: leave.** This is inherent to ERC-1643's single-argument signature, which has no subject
parameter; the engine cannot know which namespace a reader meant. It is already handled about as well
as it can be: stated in the README, in both `supportsInterface` NatSpec blocks, and asserted by
`testBaseERC1643IsAdvertisedButReadsAreCallerScoped` and
`testMsgSenderScopedReadReturnsEmptyForOther`. The address-scoped `getDocument(subject, name)` is the
correct entrypoint for third parties and is advertised through `IERC1643MultiDocument`.

Recorded here so it is visible as a deliberate trade-off rather than rediscovered as a defect.

---

## Verification performed

- `forge build` — clean; `forge test` — **73/73 passing** (72 before, +1 regression test from H-1).
- `forge fmt --check` — clean. Style checker (`check_order.py`) — 0 violations across `src/` + `script/`.
- Storage layout re-read from compiled artifacts after B-1/B-2
  (`forge build --force --extra-output storageLayout`): 5 non-empty entries per deployment, unchanged.
  No signature, visibility or ABI change in any finding implemented.
- All four temporary benchmark harnesses deleted; test count returned to its expected value.
- Gas figures come from `gasleft()` deltas after identical warm-ups, each variant either in its own
  single-function contract (A-1, E-1) or toggled in place and re-run against the same harness
  (A-2, B-1, B-2).

## What was assumed rather than executed

- The claim in A-1 that solc elides the bounded-counter overflow check *from 0.8.22 onwards* is the
  documented compiler behaviour; what I measured is that on **0.8.34** the delta is zero. I did not
  bisect the compiler versions.
- D-1's conclusion is that a shared module cannot resolve the override under C3 linearization. I
  proved the two natural formulations fail to compile; I did not exhaustively enumerate every
  possible inheritance arrangement.
- H-2's reach ("an integrator who wires a UI to the engine address") is reasoning about consumer
  behaviour, not something observed.
