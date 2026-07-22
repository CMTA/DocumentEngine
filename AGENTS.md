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
  - **Bound-token path** — `TOKEN_CONTRACT_ROLE` (the CMTA RuleEngine binding
    pattern). The standard single-arg `IERC1643` functions (`setDocument(name,uri,hash)`,
    `removeDocument(name)`) let a bound token manage its **own** namespace
    (`_msgSender()`). Bind a token with `grantRole(TOKEN_CONTRACT_ROLE, token)`.
- **Events:** every write emits the standard `IERC1643` events **and** the optional
  `DocumentUpdatedForContract` / `DocumentRemovedForContract` events (which add the
  `smartContract` address). See `ERC-1643-proposition.md`.
- **ERC-2771:** meta-transaction (gasless) support; `_msgSender()` is used everywhere.
- **Access control:** `DEFAULT_ADMIN_ROLE` implicitly has every role (see the
  `hasRole` override).
- **Flexible access control (CMTAT / RuleEngine pattern):** restricted functions
  use the `onlyDocumentManager` / `onlyBoundToken` modifiers, which delegate to
  overridable `internal virtual` hooks `_authorizeDocumentManagement()` /
  `_authorizeBoundTokenDocumentManagement()` (default `DOCUMENT_MANAGER_ROLE` /
  `TOKEN_CONTRACT_ROLE`). Keep the management implementation separate from the
  authorization logic — change *who* is authorized by overriding a hook, not by
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
│                                 #   (AccessControlEnumerable, the role constants
│                                 #   DOCUMENT_MANAGER_ROLE / TOKEN_CONTRACT_ROLE, _authorize*
│                                 #   impls, hasRole), ERC-2771, supportsInterface, constructor
├── DocumentEngineOwnable.sol     # Deployment #2: Ownable2Step (single owner) instead of
│                                 #   roles; owner-managed token binding (setTokenBinding)
├── DocumentEngineInvariant.sol   # Shared errors + optional multi-token events only
│                                 #   (NO access-control specifics — roles live in the
│                                 #   role-based deployment)
├── interfaces/
│   └── IERC8303.sol              # ERC-8303 "Contract Version" interface (id 0x54fd4d50)
└── modules/
    └── VersionModule.sol         # Version module: implements ERC-8303 version() + ERC-165,
                                  #   holds the VERSION constant (currently "0.4.0")

test/
├── DocumentEngine.t.sol          # Foundry tests: deploy, access control, admin path,
│                                 #   bound-token path, batch ops, ERC-8303, CMTAT integration
│                                 #   (CMTATDocumentEngineMock built on DocumentEngineModule),
│                                 #   flexible-authorization override (OpenDocumentEngine)
└── DocumentEngineOwnable.t.sol   # Tests for the Ownable2Step deployment (owner path,
                                  #   token binding, two-step ownership, ERC-8303)
```

**Contract split (CMTAT module/deployment pattern):** `DocumentEngineBase` holds
the document logic and abstract `_authorize*` hooks; each deployment contract
supplies the concrete access control. There are two deployments —
`DocumentEngine` (role-based, `AccessControlEnumerable`) and
`DocumentEngineOwnable` (`Ownable2Step`). Add new management logic in the base;
change *who* is authorized in a deployment (implement the `_authorize*` hooks).

Other important files:

- `foundry.toml` — solc `0.8.34`, `evm_version = prague` (required by CMTAT v3).
- `remappings.txt` — `CMTAT/`, `RuleEngine/`, `OZ/`, `@openzeppelin/contracts-upgradeable/`.
- `CHANGELOG.md` — semver history; update on every release (current: `v0.4.0`).
- `ERC-1643-proposition.md` — proposed optional multi-token events / extension.
- `README.md` — full documentation and Surya schema.
- `doc/` — Surya diagrams/reports (`doc/script/`), Slither report, coverage.
- `lib/` — submodules: `CMTAT`, `RuleEngine`, `openzeppelin-contracts(-upgradeable)`, `forge-std`.

## Dependencies (tested versions)

- CMTAT `v3.3.0-rc1`, RuleEngine `v2.1.0`
- OpenZeppelin Contracts / Contracts Upgradeable `v5.6.1`
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
