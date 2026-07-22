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
- Run linter

> npm run-script lint:all:prettier

- Documentation
  - Perform a code coverage and update the files in the corresponding directory [./doc/general/test/coverage](./doc/general/test/coverage)
  - Perform an audit with several audit tools (Aderyn and Slither), update the report in the corresponding directory  [./doc/audits/tools](./doc/audits/tools)
  - Update surya doc by running the 3 scripts in [./doc/script](./doc/script)
  
  - Update changelog

## v0.4.0

### Changed

- **Dependencies**
  - Upgrade CMTAT `v2.5.0-rc0` → `v3.3.0-rc1`
  - Upgrade OpenZeppelin Contracts (and Contracts Upgradeable) `v5.0.2` → `v5.6.1`
  - Add [CMTA/RuleEngine](https://github.com/CMTA/RuleEngine) `v2.1.0` as a submodule (binding-role reference)
- **Toolchain**: bump Solidity `0.8.26` → `0.8.34` and `evm_version` `cancun` → `prague` to match CMTAT v3 (CMTAT uses `require(cond, CustomError())`, which needs solc ≥ 0.8.27)
- **`IERC1643` (CMTAT v3) breaking changes**
  - `getDocument(bytes32)` now returns a `Document` struct instead of the `(string, bytes32, uint256)` tuple. Both `getDocument` overloads updated accordingly.
  - The `Document` struct and the `DocumentUpdated`/`DocumentRemoved` events are now provided by `IERC1643`; the duplicate local declarations were removed from `DocumentEngineInvariant`.
  - Import path moved: `CMTAT/interfaces/engine/draft-IERC1643.sol` → `CMTAT/interfaces/tokenization/draft-IERC1643.sol`.

### Added

- **Bound-token document management (RuleEngine binding pattern)**: implement the now-mandatory `IERC1643.setDocument(name, uri, hash)` and `removeDocument(name)`. They are gated by a new `TOKEN_CONTRACT_ROLE` and scoped to the caller (`_msgSender()`) own namespace. A token bound with `grantRole(TOKEN_CONTRACT_ROLE, token)` manages its own documents and can never affect another contract's documents. The existing admin overloads (explicit `address`, `DOCUMENT_MANAGER_ROLE`) are unchanged, so both systems work side by side.
- **Optional multi-token events**: alongside the standard `IERC1643` events, the engine now also emits `DocumentUpdatedForContract` / `DocumentRemovedForContract`, which carry the `smartContract` (token) address so off-chain indexers can tell which contract a document belongs to during multi-contract operations. See [`ERC-1643-proposition.md`](./ERC-1643-proposition.md) for the proposed optional standard extension.
- **Flexible access control (CMTAT / RuleEngine pattern)**: the restricted functions now use the `onlyDocumentManager` / `onlyBoundToken` modifiers, which delegate to overridable `internal virtual` authorization hooks `_authorizeDocumentManagement()` / `_authorizeBoundTokenDocumentManagement()` (default: `DOCUMENT_MANAGER_ROLE` / `TOKEN_CONTRACT_ROLE`). This separates the document-management implementation from the authorization logic, so a subclass can change *who* is authorized without touching the management functions. Default behavior is unchanged.
- **Split into a base contract and a deployment contract** (CMTAT module/deployment pattern): the document-management logic and storage now live in the new abstract `DocumentEngineBase` (with abstract `_authorize*` hooks), while `DocumentEngine` is the deployment contract that defines the access control (`AccessControl`, the concrete hooks and `hasRole`) and the ERC-2771 wiring. The deployable `DocumentEngine` API and behavior are unchanged.

### Notes / bottlenecks

- CMTAT v3 no longer ships a *standalone* token that consumes an external document engine through its constructor; the standard token stores documents on-chain (`DocumentERC1643Module`). External-engine integration now goes through CMTAT's `DocumentEngineModule` (`setDocumentEngine`). The test suite was updated to exercise this real integration path via a minimal token built on `DocumentEngineModule`.

## v0.3.0

- Add ERC-2771 support

## v0.2.0

-  Add the constant VERSION
- Add batch function to manage documents for one target contract

## v0.1.0

- 🎉 first release!