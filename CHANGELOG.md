# CHANGELOG

Please follow [https://changelog.md](https://changelog.md) conventions and the other conventions below

## Semantic Version 2.0.0

Given a version number MAJOR.MINOR.PATCH, increment the:

1. MAJOR version when the new version makes:
   -  Incompatible proxy **storage** change internally or through the upgrade of an external library (OpenZeppelin)
   - A significant change in external APIs (public/external functions) or in the internal architecture
2. MINOR version when the new version adds functionality in a backward compatible manner
3. PATCH version when the new version makes backward compatible bug fixes

See [https://semver.org](https://semver.org)

## Type of changes

- `Added` for new features.
- `Changed` for changes in existing functionality.
- `Deprecated` for soon-to-be removed features.
- `Removed` for now removed features.
- `Fixed` for any bug fixes.
- `Security` in case of vulnerabilities.

Reference: [keepachangelog.com/en/1.1.0/](https://keepachangelog.com/en/1.1.0/)

## Checklist

> Before a new release, perform the following tasks

- Code: Update the version name in the `Version` core module, variable VERSION
- Run the formatter

> forge fmt

- Documentation
  - Perform a code coverage and update the files in the corresponding directory [./doc/coverage](./doc/coverage)
    (`forge coverage --report lcov --report-file /tmp/lcov-full.info`, then
    `lcov --extract /tmp/lcov-full.info 'src/*' -o doc/coverage/lcov.info` and
    `genhtml doc/coverage/lcov.info --output-directory doc/coverage/coverage`; the `src/*` filter keeps
    `test/` and `script/` out of the published figure)
  - Perform an audit with several audit tools (Aderyn and Slither), update the report in the corresponding directory  [./doc/audits/tools](./doc/audits/tools)
  - Update surya doc by running the 3 scripts in [./doc/script](./doc/script)
  
  - Update changelog

## v0.4.0

Targets **CMTAT `v3.3.0-rc3`** — see the [compatibility matrix](./doc/README.md#version-compatibility)
for which CMTAT release each version of this engine is built against.

> **Versioning note.** `getDocument` changes shape relative to `v0.3.0`, which the convention above
> classifies as a MAJOR bump. `MINOR` is used because the project is still in its `0.x` line, where a
> `1.0.0` would wrongly signal a stable, audited release. Treat this release as breaking for any
> consumer decoding `getDocument`.

### Changed

- **Dependencies**
  - Upgrade CMTAT `v2.5.0-rc0` → [`v3.3.0-rc3`](https://github.com/CMTA/CMTAT/releases/tag/v3.3.0-rc3)
    (`lib/CMTAT` → `658672f190d56d3f61663a7d6d51962b8980df70`). Development passed through
    `v3.3.0-rc1` and `v3.3.0-rc2`. rc1 is **not** compatible with the code as shipped here, because
    it declares neither the ERC-1643 errors nor the flat `getDocument` return (see below); rc2 and
    rc3 are interchangeable for this engine — between them, the whole document surface
    (`draft-IERC1643.sol`, `IDocumentEngine.sol`, `DocumentEngineModule.sol`,
    `DocumentERC1643Module.sol`) changed only its pragma, `^0.8.20` → `^0.8.24`.
  - Upgrade OpenZeppelin Contracts (and Contracts Upgradeable) `v5.0.2` → [`v5.7.0`](https://github.com/OpenZeppelin/openzeppelin-contracts/releases/tag/v5.7.0).
    `v5.7.0` deprecates `EnumerableSet.at()` in favour of `pos()` (the old name clashes with a
    keyword scheduled for Solidity); `at()` remains as a forwarding alias, and this engine has no
    call sites either way. The only exposure is inherited — `AccessControlEnumerable.getRoleMember`
    switched to `pos()` internally, with no change to its signature, selector or behaviour.
    Verified: `DocumentEngine`'s runtime code is **byte-identical** across `v5.6.1` and `v5.7.0`
    (8436 bytes; only the CBOR metadata trailer moves, because the source text of
    `AccessControlEnumerable.sol` changed), and `DocumentEngineOwnable`'s bytecode is unchanged
    including metadata.
  - Add [CMTA/RuleEngine](https://github.com/CMTA/RuleEngine) [`v3.0.0-rc5`](https://github.com/CMTA/RuleEngine/releases/tag/v3.0.0-rc5) as a submodule (binding-pattern reference; see [Why not reuse RuleEngine's compliance module?](./doc/README.md#why-not-reuse-ruleengines-erc-3643-compliance-module) — its `ERC3643ComplianceExtendedModule` is not reused)
  - `foundry.lock` now records every submodule by tag; all five entries had gone stale since `v0.3.0`.
- **Toolchain**: bump Solidity `0.8.26` → `0.8.34` and `evm_version` `cancun` → `prague` to match CMTAT v3 (CMTAT uses `require(cond, CustomError())`, which needs solc ≥ 0.8.27)
- **Code-quality review** (`doc/audits/tools/v0.4.0/claude/CLAUDE_ANALYSIS.md`) — 14 findings, none a vulnerability.
  Six implemented:
  - **Gas, `_removeDocumentName`**: the `_documentNames[subject]` mapping slot was re-hashed on every
    loop iteration; cached as a storage pointer. Measured **−2200 gas** on a 20-entry full scan.
  - **Gas, `_removeDocument`**: the whole `Document` (URI included) was copied to memory to be read
    three times; now read through a storage pointer. A further **−645 gas**. Combined, removal is
    **−2845 gas (−3.3 %)** worst case. The emit must stay ahead of the `delete` — verified by
    mutating the order and confirming `testRemoveDocumentEmitsForSubjectEvent` fails.
    Side effect: Slither's `incorrect-equality` (Medium) and `timestamp` (Low) stopped firing on the
    unchanged `doc.lastModified == 0`, taking it from 4 results to 2. **Not a fix** — both were
    already false positives and the detector merely loses the taint through a storage pointer.
  - **`hasRole` NatSpec**: documented that a role is **unrevokable from the default admin** —
    `revokeRole` succeeds, emits `RoleRevoked` and drops `getRoleMemberCount`, yet the admin keeps the
    access. Not a privilege issue (an admin can re-grant itself anything) but the call misreports.
    Pinned by the new `testRevokingRoleFromDefaultAdminDoesNotRemoveAccess`.
  - **`DocumentEngineInvariant`**: the error-location comment misattributed `NotBoundToken(address)`
    to `ITokenBinding`; it is declared by `TokenBindingModule`.
  - **Documentation pointers removed from contract comments.** Three comments referenced
    `doc/ERCSpecification…`; documentation moves but deployed source does not, and this repo had
    already renamed that file once (`ERC-1643-proposition.md` → `erc-draft_multi_document_management.md`),
    leaving a dangling README link behind. Someone reading verified source on an explorer has the
    comment and not the file. All three pointers are gone and each comment is now **shorter**, not
    longer — the `IERC1643MultiDocument` header dropped from 10 lines to 9 by replacing an
    enumeration that gestured at the draft's rationale with the one operative fact: `subject` need
    not be a token.
  - **All 12 `internal` functions are now `virtual`** (`_setDocument`, `_removeDocument`,
    `_removeDocumentName`, `_getDocument`, `_setTokenBinding`, `_checkTokenBound`, and the ERC-2771
    context trio in both deployments), resolving an inconsistency where `TokenBindingModule` exposed
    its public surface for override while `DocumentEngineBase` exposed nothing but its two abstract
    hooks. A deployment can now override the document write/read paths and the binding check, matching
    what CMTAT's equivalent module allows. **Runtime cost is zero:** the executable bytecode of both
    deployments is byte-identical before and after (7457 / 6111 bytes, metadata trailer excluded).
    Guarded by `OverridingDocumentEngine` +
    `testInternalHooksAreVirtualAndOverridesAreReached` — removing `virtual` from any of the three
    overridden hooks fails the build (`Error (4334): Trying to override non-virtual function`).

  Notable non-changes, recorded so they are not re-raised: `unchecked { ++i }` buys **0 gas** on solc
  0.8.34 (measured); `string calldata` on the admin `setDocument` is **49 gas worse** than `memory`
  (measured); and the duplicated ERC-2771 context overrides **cannot** be extracted into a shared
  module — C3 linearization forces each deployment to re-state them, proven by compiler error.
- **Style pass across `src/` and `script/` — behaviour-preserving.** Brought the sources in line with
  the Solidity style guide: functions reordered by visibility group (external → public → internal,
  `view`/`pure` last within each), so the `_authorize*` hooks and the ERC-2771 context overrides now
  follow the public API instead of preceding it; every brace-less global import replaced by a named
  one (which required adding the previously implicit `Context` and `AccessControl` imports, since a
  named import no longer re-exports a dependency's own imports); and NatSpec completed with a
  `@param` per argument and a `@return` per return value. No signature, visibility, body or storage
  layout changed — verified by an unchanged per-contract function set, a clean `forge build`, and
  72/72 tests passing.
- **Source pragma raised `^0.8.20` → `^0.8.24`** across `src/`, `script/` and `test/`. This is a
  correction, not a new restriction: `^0.8.20` had become an over-promise, advertising a range the
  sources could not actually compile in. OpenZeppelin's `AccessControlEnumerable.sol` and
  `EnumerableSet.sol` are `^0.8.24`, and CMTAT `v3.3.0-rc3` moved `draft-IERC1643.sol` to `^0.8.24`
  as well, so every contract in `src/` now transitively requires it — `forge build --use 0.8.23`
  fails to resolve a compiler. `0.8.24` is the real `src/` floor; the full project including the
  CMTAT-importing tests needs `0.8.27`, because `require(cond, CustomError())` is restricted to the
  via-ir pipeline before then. Deployed bytecode is unaffected — the pinned compiler is still `0.8.34`.
- **`IERC1643` (CMTAT v3) breaking changes**
  - `getDocument` keeps returning `(string uri, bytes32 documentHash, uint256 lastModified)` — the
    flat ERC-1643 ABI — on **both** overloads, `getDocument(bytes32)` and
    `getDocument(address subject, bytes32)`. CMTAT `v3.3.0-rc1` briefly replaced this with a
    `Document` struct and `v3.3.0-rc2` reverted it; this engine follows rc2/rc3, so relative to
    `v0.3.0` the external shape is unchanged.

    The distinction is worth recording because it is invisible to interface detection: return types
    are not part of a function signature, so both shapes share the same selectors and the same
    `type(IERC1643).interfaceId` (`0xecfecec8`). A consumer built from the specification ABI decodes
    a struct return as garbage *without reverting* — `uri` becomes binary junk, `documentHash`
    becomes `0x…60`, and `lastModified` becomes the real hash as a `uint256`. `getDocument` is now
    covered by `testGetDocumentReturnsFlatErc1643Abi`, which inspects the returndata directly since
    ERC-165 structurally cannot.
  - The `Document` struct and the `DocumentUpdated`/`DocumentRemoved` events are now provided by `IERC1643`; the duplicate local declarations were removed from `DocumentEngineInvariant`. The struct is retained internally for storage only.
  - `ERC1643InvalidName()` / `ERC1643MissingDocument()` are likewise declared by `IERC1643` as of
    CMTAT `v3.3.0-rc2` and are **not** re-declared here. The multi-subject draft requires a contract
    implementing both interfaces to obtain each error exactly once ("MUST NOT declare them twice"),
    and re-declaring is a compile error. Selectors, and hence revert data, are unchanged.
    The same principle was applied to every other error: `MultiDocumentInvalidSubject()` moved to
    `IERC1643MultiDocument` and `TokenBindingInvalidToken()` is declared on `ITokenBinding`, so an
    ABI generated from an interface carries its errors. `DocumentEngineInvariant` now holds only
    `InvalidInputLength` and `AdminWithAddressZeroNotAllowed`, which no interface defines.
  - Import path moved: `CMTAT/interfaces/engine/draft-IERC1643.sol` → `CMTAT/interfaces/tokenization/draft-IERC1643.sol`.

- **`ERC1643InvalidSubject()` renamed to `MultiDocumentInvalidSubject()`** and moved from
  `DocumentEngineInvariant` to `IERC1643MultiDocument`, matching the multi-subject draft. **This
  changes the error selector**, so integrators decoding this revert must update.

  The draft's rule is that an error is prefixed by the proposal that *defines* its condition, not by
  the one it sits next to. The null-`subject` condition cannot arise in ERC-1643 at all — its
  `setDocument` has no `subject` argument, so the subject is implicitly the contract itself, which is
  never the null address — so borrowing the `ERC1643` prefix named the error after a standard in
  which it is unreachable. The two genuinely-shared errors keep their prefix for the opposite reason.
- **Token binding rejects `address(0)` and is idempotent.** `bindToken` / `unbindToken` now revert
  `TokenBindingInvalidToken()` on the null address — which can never call the engine, so binding it
  granted nothing while still emitting an event indexers key on — and write plus emit
  `TokenBindingSet` **only when the binding actually changes**. A repeated call still succeeds, since
  the caller's intent already holds, but emits nothing, so every event in the log is a real
  transition and an indexer never has to de-duplicate.

### Added

- **Bound-token document management**: implement the now-mandatory `IERC1643.setDocument(name, uri, hash)` and `removeDocument(name)`, gated by the `onlyBoundToken` modifier and scoped to the caller (`_msgSender()`) own namespace. A token bound with `bindToken(token)` (see the shared binding module below) manages its own documents and can never affect another contract's documents. The admin overloads (explicit `address`, `DOCUMENT_MANAGER_ROLE`) are unchanged, so both systems work side by side. (RuleEngine's `ERC3643ComplianceExtendedModule` was evaluated for the binding but intentionally not reused — see the README.)
- **Optional multi-token events**: alongside the standard `IERC1643` events, the engine now also emits `DocumentUpdatedForContract` / `DocumentRemovedForContract`, which carry the `smartContract` (token) address so off-chain indexers can tell which contract a document belongs to during multi-contract operations. See [`erc-draft_multi_document_management.md`](./doc/ERCSpecification/erc-draft_multi_document_management.md) for the proposed optional standard extension.
- **Flexible access control (CMTAT / RuleEngine pattern)**: the restricted functions use the `onlyDocumentManager` / `onlyBoundToken` modifiers, which delegate to overridable `internal virtual` authorization hooks `_authorizeDocumentManagement()` / `_authorizeBoundTokenDocumentManagement()`. Each deployment implements the admin hook (`DOCUMENT_MANAGER_ROLE` or `owner`); the bound-token hook is implemented once by `TokenBindingModule` (the shared allowlist). This separates the document-management implementation from the authorization logic.
- **Split into a base contract and a deployment contract** (CMTAT module/deployment pattern): the document-management logic and storage now live in the new abstract `DocumentEngineBase` (with abstract `_authorize*` hooks), while `DocumentEngine` is the deployment contract that defines the access control (`AccessControl`, the concrete hooks and `hasRole`) and the ERC-2771 wiring. The deployable `DocumentEngine` API and behavior are unchanged.
- **Version module implementing ERC-8303**: the version is now exposed through a dedicated `VersionModule` (`src/modules/VersionModule.sol`) implementing the `IERC8303` interface (`src/interfaces/IERC8303.sol`). It adds a standard `version()` view function (in addition to the existing public `VERSION` constant) and advertises ERC-8303 via ERC-165 (`supportsInterface(0x54fd4d50) == true`). `DocumentEngine` combines the module's `supportsInterface` with the access-control base.
- **Second deployment `DocumentEngineOwnable`** (`src/DocumentEngineOwnable.sol`): an alternative deployment that uses OpenZeppelin `Ownable2Step` (single owner, two-step transfer) instead of role-based access control, reusing the same `DocumentEngineBase` logic and the shared `TokenBindingModule`. Both document management and token binding are restricted to the `owner`.

### Changed (access control)

- `DocumentEngine` now inherits **`AccessControlEnumerable`** instead of `AccessControl`, adding on-chain enumeration of role members (`getRoleMember`, `getRoleMemberCount`) and advertising `IAccessControlEnumerable` via ERC-165. Default authorization behavior is unchanged.
- Moved the `DOCUMENT_MANAGER_ROLE` constant out of the shared `DocumentEngineInvariant` and into the role-based `DocumentEngine`, so `DocumentEngineInvariant` (and the `DocumentEngineOwnable` deployment) no longer carry access-control-specific constants. The invariant now holds only the shared errors.

### Fixed (ERC-1643 conformance)

Aligned the implementation with the updated [ERC-1643](./doc/ERCSpecification/erc-1643.md) (which now folds in the multi-token extension and the emission-responsibility rules):

- **Emission responsibility.** As a shared, multi-token manager the engine now emits **only** the address-carrying extension events and **no longer** emits the base `DocumentUpdated` / `DocumentRemoved` events (the spec's `MUST NOT` for a shared manager — those events carry no `subject` and belong on the token contract).
- **Extension events/interface.** Renamed the multi-token events to the standard `DocumentUpdatedForSubject` / `DocumentRemovedForSubject` (parameter `subject`), and introduced the `IERC1643MultiDocument` interface (`src/interfaces/IERC1643MultiDocument.sol`) that the base now implements — the address-scoped `getDocument` / `getAllDocuments` / `setDocument` / `removeDocument`.
- **Input validation.** `setDocument` now reverts `ERC1643InvalidName()` when `name == bytes32(0)` and `MultiDocumentInvalidSubject()` when `subject == address(0)` (the multi-subject draft's null-namespace guard); `removeDocument` now reverts `ERC1643MissingDocument()` for a non-existent document (previously it silently emitted a spurious removal event). See [`erc-draft_multi_document_management.md`](./doc/ERCSpecification/erc-draft_multi_document_management.md) for the corresponding multi-subject draft.
- **ERC-165 discovery.** `supportsInterface` now returns `true` for `type(IERC1643).interfaceId`, `type(IERC1643MultiDocument).interfaceId` and `type(ITokenBinding).interfaceId` (both deployments).

  The base id is advertised because the engine implements the base single-argument functions, and because a **token** uses it: before wiring itself to the engine with `setDocumentEngine(engine)`, or before forwarding `setDocument(name, uri, hash)`, it can confirm through ERC-165 that those endpoints exist. It does **not** mean documents should be read from the engine's address — the base functions are `_msgSender()`-scoped, so a third-party read returns the caller's own empty namespace. Documented in the README and asserted by `testBaseERC1643IsAdvertisedButReadsAreCallerScoped`.

### Added (token binding)

- **Shared `ITokenBinding` interface + `TokenBindingModule`.** `bindToken(token)` / `unbindToken(token)` / `isTokenBound(token)` + `TokenBindingSet` event (`src/interfaces/ITokenBinding.sol`), implemented once for both deployments by `src/modules/TokenBindingModule.sol` — a single **allowlist**, not a role. Both deployments now share the exact same binding mechanism (same functions, event, and `NotBoundToken` revert on an unbound write) and advertise `type(ITokenBinding).interfaceId` via ERC-165. The role deployment **no longer uses `TOKEN_CONTRACT_ROLE`** (removed) — binding is authorized by the document-management hook (`DOCUMENT_MANAGER_ROLE`, or the `owner` in `DocumentEngineOwnable`).

### Notes / bottlenecks

- **Subject-side emission is CMTAT `v3.3.0-rc2` or later.** rc2 made `DocumentEngineModule` re-emit
  the standard `DocumentUpdated` / `DocumentRemoved` on the **token's own address** after forwarding
  to the engine, and revert with `CMTAT_DocumentEngineModule_NoDocumentEngine` when no engine is set.
  Combined with this engine emitting only the address-carrying `*ForSubject` events, the
  subject-initiated call topology is fully conformant with the multi-subject draft's *Emission
  Responsibility* rules. The **admin path remains non-conformant by construction** — a write sent
  straight to the engine has no execution point in the subject, so the subject emits nothing.
  See `OPEN-2` in [`AUDIT_OVERVIEW.md`](./doc/audits/AUDIT_OVERVIEW.md).
- Open items are tracked under *Known open items* in
  [`AUDIT_OVERVIEW.md`](./doc/audits/AUDIT_OVERVIEW.md): the most severe is admin-path call topology
  (`OPEN-2`); also authorization granularity (`OPEN-1`) and enumeration cost (`OPEN-4`).
- CMTAT v3 no longer ships a *standalone* token that consumes an external document engine through its constructor; the standard token stores documents on-chain (`DocumentERC1643Module`). External-engine integration now goes through CMTAT's `DocumentEngineModule` (`setDocumentEngine`). The test suite was updated to exercise this real integration path via a minimal token built on `DocumentEngineModule`.

## v0.3.0

- Add ERC-2771 support

## v0.2.0

-  Add the constant VERSION
- Add batch function to manage documents for one target contract

## v0.1.0

- 🎉 first release!