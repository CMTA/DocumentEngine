# DocumentEngine — Agent Guide

> **Note — keep in sync:** `AGENTS.md` and `CLAUDE.md` must always be **identical**.
> Any edit to one must be applied verbatim to the other.

> **Note — commit messages:** After each group of modifications or each feature
> added, always provide a **one-line GitHub commit message** (Conventional-Commits
> style, e.g. `feat: add token binding`, `fix: correct event args`, `docs: update README`).

## What this project is

`DocumentEngine` is a standalone smart contract that manages documents on-chain
through **ERC-1643** on behalf of **several** other smart contracts (e.g. CMTAT
tokens). Using an external engine keeps each token small and lets one operator
manage documents for a whole fleet of tokens.

A document is `{ string uri, bytes32 documentHash, uint256 lastModified }`,
addressed by a `bytes32` name.

## Key concepts

- **Two management paths (both active at once):**
  - **Admin path** — `DOCUMENT_MANAGER_ROLE`. Address-scoped overloads
    (`setDocument(address,...)`, `removeDocument(address,...)`, batch variants)
    manage documents for any contract.
  - **Bound-token path** — the standard single-arg `IERC1643` functions
    (`setDocument(name,uri,hash)`, `removeDocument(name)`) let a bound token manage
    its **own** namespace (`_msgSender()`). Bind via the shared `ITokenBinding`
    surface: `bindToken(token)` / `unbindToken(token)` / `isTokenBound(token)`,
    implemented **once** for both deployments by `TokenBindingModule` — a single
    allowlist, NOT a role (there is no `TOKEN_CONTRACT_ROLE`). Binding is authorized
    by each deployment's document-management hook (DOCUMENT_MANAGER_ROLE / owner).
    NOTE: RuleEngine's `ERC3643ComplianceExtendedModule` is intentionally **not**
    reused for binding — it is an `IERC3643Compliance`, which would drag in
    transfer-compliance callbacks (`canTransfer`/`transferred`/`created`/`destroyed`)
    irrelevant to a document engine. See the README rationale section.
- **Events (ERC-1643 emission responsibility):** this engine is a *shared,
  multi-token* manager, so it emits **only** the address-carrying extension events
  `DocumentUpdatedForSubject` / `DocumentRemovedForSubject` (param `subject`) and
  **not** the base `DocumentUpdated` / `DocumentRemoved` (those carry no address and
  are the token contract's responsibility). Extension declared in
  `src/interfaces/IERC1643MultiDocument.sol`; rationale in `ERC-1643-proposition.md`.
- **Errors live on interfaces, not on `DocumentEngineInvariant`.** Each specification
  error is declared by the interface defining its condition — `ERC1643InvalidName` /
  `ERC1643MissingDocument` on `IERC1643`, `MultiDocumentInvalidSubject` on
  `IERC1643MultiDocument`, `TokenBindingInvalidToken` on `ITokenBinding` — so an ABI
  generated from an interface carries its errors and each is obtained exactly once
  (the multi-subject draft's "MUST NOT declare them twice", also a compile error).
  `DocumentEngineInvariant` keeps only errors no interface defines.
- **Token binding is idempotent and rejects `address(0)`:** `bindToken` / `unbindToken`
  write and emit `TokenBindingSet` only on an actual change, so every event is a real
  transition; a repeat call succeeds silently. `address(0)` reverts
  `TokenBindingInvalidToken()`.
- **ERC-1643 conformance:** `setDocument` reverts `ERC1643InvalidName()` on
  `name == 0`; `removeDocument` reverts `ERC1643MissingDocument()` on a missing doc;
  `supportsInterface` advertises `IERC1643` + `IERC1643MultiDocument` + `ITokenBinding`
  (both deployments). The base id is for a **token** checking that the single-argument
  endpoints exist before wiring itself to the engine — it does **not** mean documents
  should be read from the engine's address, since those functions are `_msgSender()`-scoped.
  Both errors are declared by `IERC1643` itself since CMTAT `v3.3.0-rc2` (still true in
  `v3.3.0-rc3`) — do **not**
  re-declare them in `DocumentEngineInvariant` (duplicate declaration = compile error,
  and the multi-subject draft forbids it).
- **`getDocument` returns flat values**, `(string uri, bytes32 documentHash,
  uint256 lastModified)`, never the `Document` struct — the struct is storage-only.
  A struct return prepends an offset word to the returndata while leaving the selector
  and `type(IERC1643).interfaceId` unchanged, so the mismatch is invisible to ERC-165
  and a spec-conformant consumer silently mis-decodes. Pinned by
  `testGetDocumentReturnsFlatErc1643Abi`.
- **ERC-2771:** meta-transaction (gasless) support; `_msgSender()` is used everywhere.
- **Access control:** `DEFAULT_ADMIN_ROLE` implicitly has every role (see the
  `hasRole` override).
- **Flexible access control (CMTAT / RuleEngine pattern):** restricted functions
  use the `onlyDocumentManager` / `onlyBoundToken` modifiers, which delegate to
  overridable `internal virtual` hooks `_authorizeDocumentManagement()` (per
  deployment: `DOCUMENT_MANAGER_ROLE` / owner) and
  `_authorizeBoundTokenDocumentManagement()` (implemented once by
  `TokenBindingModule` → allowlist check). Keep the management implementation
  separate from the authorization logic — change *who* is authorized via a hook, not by
  editing the management functions.
- **CMTAT integration:** since CMTAT v3, a token uses the engine via CMTAT's
  `DocumentEngineModule` and `setDocumentEngine(engine)` (reads/writes are forwarded
  keyed by the token address). Standard CMTAT standalone tokens store documents
  on-chain instead and do **not** use this engine.

## File tree

```
src/
├── DocumentEngineBase.sol        # Abstract base: ERC-1643 document logic + storage,
│                                 #   both management paths, batch functions, modifiers,
│                                 #   and the ABSTRACT _authorize* hooks (no access control)
├── DocumentEngine.sol            # Deployment #1: role-based access control
│                                 #   (AccessControlEnumerable, DOCUMENT_MANAGER_ROLE,
│                                 #   _authorizeDocumentManagement, hasRole), ERC-2771,
│                                 #   supportsInterface, constructor
├── DocumentEngineOwnable.sol     # Deployment #2: Ownable2Step (single owner) instead of
│                                 #   roles; document mgmt + binding are owner-only
├── DocumentEngineInvariant.sol   # Non-specification errors ONLY (InvalidInputLength,
│                                 #   AdminWithAddressZeroNotAllowed). Every spec error is
│                                 #   declared by its own interface — see the note below.
│                                 #   NO access-control specifics
├── interfaces/
│   ├── IERC8303.sol              # ERC-8303 "Contract Version" interface (id 0x54fd4d50)
│   ├── IERC1643MultiDocument.sol # Multi-token ERC-1643 extension (address-scoped fns +
│   │                             #   DocumentUpdatedForSubject / DocumentRemovedForSubject +
│   │                             #   MultiDocumentInvalidSubject)
│   └── ITokenBinding.sol         # Shared binding surface: bindToken / unbindToken /
│                                 #   isTokenBound + TokenBindingSet + TokenBindingInvalidToken
└── modules/
    ├── VersionModule.sol         # Version module: implements ERC-8303 version() + ERC-165,
    │                             #   holds the VERSION constant (currently "0.4.0")
    └── TokenBindingModule.sol    # Shared token-binding allowlist (ITokenBinding) + NotBoundToken;
                                  #   wires the bound-token hook; used by both deployments

script/
├── DeployDocumentEngine.s.sol        # Deploy role-based DocumentEngine (env: DOCUMENT_ENGINE_ADMIN,
│                                     #   DOCUMENT_ENGINE_FORWARDER); run()=env, deploy(admin,fwd)=testable
└── DeployDocumentEngineOwnable.s.sol # Deploy Ownable variant (env: DOCUMENT_ENGINE_OWNER, _FORWARDER)

test/
├── DocumentEngine.t.sol          # Foundry tests: deploy, access control, admin + bound-token
│                                 #   paths, batch ops (incl. name==0 / missing-doc guards),
│                                 #   ERC-8303 + interface discovery, event emission (asserts the
│                                 #   base events are NOT emitted), msg.sender-scoped reads,
│                                 #   enumeration, fuzz round-trip/isolation, CMTAT integration
│                                 #   (CMTATDocumentEngineMock), flexible-auth override (OpenDocumentEngine)
├── DocumentEngineOwnable.t.sol   # Tests for the Ownable2Step deployment (owner path,
│                                 #   token binding, two-step ownership, ERC-8303)
└── Deploy.t.sol                  # Tests for the deployment scripts (deploy() state + run() env)
```

**Contract split (CMTAT module/deployment pattern):** `DocumentEngineBase` holds
the document logic and abstract `_authorize*` hooks; each deployment contract
supplies the concrete access control. There are two deployments —
`DocumentEngine` (role-based, `AccessControlEnumerable`) and
`DocumentEngineOwnable` (`Ownable2Step`). Add new management logic in the base;
change *who* is authorized in a deployment (implement the `_authorize*` hooks).

Other important files:

- `foundry.toml` — solc `0.8.34`, `evm_version = prague` (required by CMTAT v3).
  Sources declare `pragma solidity ^0.8.24` — the real `src/` floor, set by OpenZeppelin's
  `AccessControlEnumerable`/`EnumerableSet` and CMTAT's `draft-IERC1643` since `v3.3.0-rc3`.
  Building the tests needs `≥ 0.8.27` (CMTAT's `require(cond, CustomError())` is via-ir-only
  before then). Keep the pragma honest: if a dependency raises its floor, raise ours to match.
- `remappings.txt` — `CMTAT/`, `RuleEngine/`, `OZ/`, `@openzeppelin/contracts-upgradeable/`.
- `CHANGELOG.md` — semver history; update on every release (current: `v0.4.0`).
- `ERC-1643-proposition.md` — proposed optional multi-token events / extension.
- `README.md` — full documentation and Surya schema.
- `doc/` — Surya output in `doc/surya/{surya_graph,surya_inheritance,surya_report}`, one file per
  `.sol` in `src/` (9 each), regenerated by the three scripts in `doc/script/` — run them from that
  directory, **graph first** (it creates the scratch `docOut/`; the report script's `mkdir` lacks
  `-p`). Patch `surya/lib/graph.js` before regenerating or every contract calling `super.<fn>()`
  yields a silent 0-byte PNG; see the Surya section in `README.md`. Also coverage, and
  `doc/audits/` — the security overview (`AUDIT_OVERVIEW.md`) plus versioned
  static-analysis output under `doc/audits/tools/vX.Y.Z/<tool>/`, each with a
  `*-report.md` (summary table prepended) and a `*-report-feedback.md` triaging
  every finding. Both Aderyn `0.6.5` (0 High · 6 Low) and Slither `0.11.5`
  (0 High · 1 Med · 1 Low · 2 Info) were run for `v0.4.0` — nothing to fix in either.
  Slither's dependency filter must be `lib` (Foundry layout); `--filter-paths` fails
  open, so an entry matching nothing silently pulls the vendored tree into scope.
- `IMPROVEMENT.md` — the open items: deviations from the two ERC specifications,
  with severity, effort and a recommendation for each. Update it when an item is
  fixed (move the record to `CHANGELOG.md` and `doc/audits/AUDIT_OVERVIEW.md`)
  or when review surfaces a new one.
- `lib/` — submodules: `CMTAT`, `RuleEngine`, `openzeppelin-contracts(-upgradeable)`, `forge-std`.

## Dependencies (tested versions)

- CMTAT `v3.3.0-rc3`, RuleEngine `v3.0.0-rc5` (binding-pattern reference only; compliance module not reused)
- OpenZeppelin Contracts / Contracts Upgradeable `v5.7.0`
- Solidity `0.8.34`, Foundry

## Common commands

```bash
forge build          # compile
forge test           # run the test suite
forge fmt            # format
forge test --gas-report
```

## Conventions

- The `VERSION` constant (in `src/modules/VersionModule.sol`, exposed via
  ERC-8303 `version()`) must match the latest `CHANGELOG.md` entry on release.
- Bump `MAJOR` on incompatible proxy-storage / external-library or API changes,
  `MINOR` for backward-compatible features, `PATCH` for backward-compatible fixes.
- A bound token can only ever affect its **own** document namespace — never break
  that isolation.
