---
title: Multi-Subject Document Management
description: Interface for a contract that attaches, updates, removes, and enumerates documents on behalf of multiple subject contracts.
author: Ryan Sauge (@rya-sge)
discussions-to: https://ethereum-magicians.org/t/erc-1643-document-management-standard-erc-1400/27437
status: Draft
type: Standards Track
category: ERC
created: 2026-07-28
requires: 165, 1643
---

## Abstract

This ERC defines an interface for a contract that stores and manages documents on behalf of **several other contracts**, called *subjects*. Every function is scoped by a `subject` address, and every event carries that address, so a single management contract can serve many subjects while remaining observable and operable per subject.

It is a companion to [ERC-1643](./eip-1643.md), which defines the equivalent per-contract interface. A subject is not required to implement ERC-1643, or any other particular interface, to have documents managed on its behalf.

## Motivation

[ERC-1643](./eip-1643.md) associates documents with the contract that exposes the interface. Its `DocumentUpdated` and `DocumentRemoved` events carry only `(name, uri, documentHash)` — no address — so consumers attribute an event to the address that emitted it. This is unambiguous when a single contract both exposes the interface and stores its own documents.

A common operational and gas optimization is to **delegate** document management to a separate contract. When that contract is dedicated to one subject, nothing new is needed: it effectively is that subject's ERC-1643 implementation, and its events are unambiguous. But when **one management contract serves many subjects**, the per-contract events break down — a consumer watching the management contract cannot tell which subject a change belongs to, and the management contract has no compliant way to report per-subject changes at all.

Shared document management is worth supporting directly. An issuer operating many tokens, funds, or vaults typically maintains one document library and one set of operators, and duplicating that storage and access-control logic into every subject contract is redundant and expensive. What the shared case needs is an address in the event and an address in the function signature. That is the whole of this proposal.

The scope is deliberately broader than tokens. A subject is any contract that documents can belong to — an [ERC-20](./eip-20.md) or [ERC-721](./eip-721.md) token, an [ERC-1155](./eip-1155.md) multi-token, a vault, or any other on-chain product. Nothing in this interface inspects the subject or calls into it.

## Specification

The key words "MUST", "MUST NOT", "REQUIRED", "SHALL", "SHALL NOT", "SHOULD", "SHOULD NOT", "RECOMMENDED", "NOT RECOMMENDED", "MAY", and "OPTIONAL" in this document are to be interpreted as described in RFC 2119 and RFC 8174.

A document entry is identified by a `subject` (`address`) together with a name (`bytes32`), and stores:

- A URI (`string`) pointing to the document location.
- A content hash (`bytes32`) for integrity checks.
- A last-modified timestamp (`uint256`) set when the entry is written.

This is the [ERC-1643](./eip-1643.md) data model, extended with the `subject` address. Entries under different subjects are independent: a `name` written for one subject MUST NOT affect the entry stored under the same `name` for any other subject.

### Interface

This interface is declared **independently of `IERC1643`** — it does not inherit it — so a management contract can implement the address-scoped surface without being forced to implement the per-contract single-argument functions. 

A contract MAY implement both, in which case it implements, and advertises, each interface separately.

Two of the three errors below, `ERC1643InvalidName` and `ERC1643MissingDocument`, are **the same errors defined by [ERC-1643](./eip-1643.md)** — same names, same signatures, hence the same 4-byte selectors — reused deliberately so that a caller sees identical revert data for identical conditions whether it is talking to an ERC-1643 contract or to a management contract. They are restated here rather than inherited because this interface does not inherit `IERC1643`; a contract implementing both obtains each error once, from `IERC1643`, and MUST NOT declare them twice.

`MultiDocumentInvalidSubject` has no ERC-1643 counterpart: the condition it reports cannot arise there, because ERC-1643's `setDocument` has no `subject` argument — its subject is implicitly the contract itself, which is never the null address.

```solidity
/// @title IERC1643MultiDocument Multi-Subject Document Management
interface IERC1643MultiDocument {
    /// @notice Emitted when a document is created or updated for `subject`.
    /// @param subject Address of the contract the document belongs to.
    /// @param name Identifier of the document.
    /// @param uri Document location.
    /// @param documentHash Hash of the document contents.
    event DocumentUpdatedForSubject(address indexed subject, bytes32 indexed name, string uri, bytes32 documentHash);

    /// @notice Emitted when a document is removed for `subject`.
    /// @param subject Address of the contract the document belonged to.
    /// @param name Identifier of the document.
    /// @param uri Document location at the time of removal.
    /// @param documentHash Hash of the document contents at the time of removal.
    event DocumentRemovedForSubject(address indexed subject, bytes32 indexed name, string uri, bytes32 documentHash);

    /// @notice Reverts when `setDocument` or `removeDocument` is called with `subject == address(0)`.
    /// @dev Specific to this proposal; has no ERC-1643 counterpart.
    error MultiDocumentInvalidSubject();

    /// @notice Reverts when `setDocument` is called with `name == bytes32(0)`.
    /// @dev Same error as defined by ERC-1643, reused unchanged.
    error ERC1643InvalidName();

    /// @notice Reverts when `removeDocument` is called for a missing document.
    /// @dev Same error as defined by ERC-1643, reused unchanged.
    error ERC1643MissingDocument();

    /// @notice Creates or updates a document entry for `subject`.
    /// @dev MUST emit `DocumentUpdatedForSubject` on success.
    /// @param subject Address of the contract the document belongs to.
    /// @param name Identifier of the document.
    /// @param uri Document location.
    /// @param documentHash Hash of the document contents.
    function setDocument(address subject, bytes32 name, string calldata uri, bytes32 documentHash) external;

    /// @notice Removes an existing document entry for `subject`.
    /// @dev MUST emit `DocumentRemovedForSubject` on success.
    /// @param subject Address of the contract the document belongs to.
    /// @param name Identifier of the document to remove.
    function removeDocument(address subject, bytes32 name) external;

    /// @notice Returns metadata for the document identified by `name` belonging to `subject`.
    /// @param subject Address of the contract the documents belong to.
    /// @param name Identifier of the document.
    /// @return uri Document location.
    /// @return documentHash Hash of the document contents.
    /// @return lastModified Last update timestamp.
    function getDocument(address subject, bytes32 name)
        external
        view
        returns (string memory uri, bytes32 documentHash, uint256 lastModified);

    /// @notice Returns all document names currently tracked for `subject`.
    /// @param subject Address of the contract the documents belong to.
    /// @return documentNames Names of all documents that are currently set for `subject`.
    function getAllDocuments(address subject) external view returns (bytes32[] memory documentNames);
}
```

### Function Requirements

- `getDocument`:
  - MUST return the latest values for the provided `subject` and `name`.
  - MUST return empty values when the entry does not exist (`""`, `bytes32(0)`, `0`).
  - MUST NOT revert solely because the entry does not exist.

- `setDocument`:
  - MUST create a new entry when `name` is not present for `subject`.
  - MUST overwrite the existing entry when `name` already exists for `subject`.
  - MUST update the stored last-modified timestamp.
  - MUST emit `DocumentUpdatedForSubject` after state changes.
  - MUST revert if the update cannot be persisted.
  - SHOULD revert when `name == bytes32(0)`, using `ERC1643InvalidName()`.
  - `uri` and `documentHash` MAY be empty (`""` and `bytes32(0)`), depending on issuer workflow and document lifecycle stage. Implementations MAY reject empty values based on policy requirements.

- `removeDocument`:
  - MUST remove the entry identified by `subject` and `name`.
  - MUST emit `DocumentRemovedForSubject` with the removed metadata.
  - MUST revert if removal cannot be completed.
  - SHOULD revert when the named document does not exist for `subject`, using `ERC1643MissingDocument()`.

- `getAllDocuments`:
  - MUST include every name added for `subject` by `setDocument` and not removed by `removeDocument`.
  - MUST NOT include removed names, or names belonging to any other subject.

- `setDocument` and `removeDocument` SHOULD revert when `subject == address(0)`, since the null address is never a valid document subject, using `MultiDocumentInvalidSubject()`.
  - Guarding the write path is sufficient: when `setDocument` rejects `subject == address(0)`, no document can exist under that subject, so `removeDocument` there already fails with `ERC1643MissingDocument()`.

- Implementations MAY use different error names/signatures than those shown in this specification.

### Authorization

Implementations MUST authorize writes per `subject`, so that a caller cannot create, update, or remove documents for a `subject` it is not permitted to manage. A single management contract holding the document sets of unrelated subjects behind one address makes this the central security property of the proposal; see Security Considerations.

### Interface Detection ([ERC-165](./eip-165.md))

Implementations SHOULD support ERC-165 interface detection. When ERC-165 is implemented, `supportsInterface` SHOULD return `true` for `type(IERC1643MultiDocument).interfaceId` and for the ERC-165 interface id.

`type(IERC1643MultiDocument).interfaceId` is the XOR of only this interface's own address-scoped functions. Because this interface does not inherit `IERC1643`, and because Solidity excludes inherited selectors from `type(I).interfaceId` in any case, advertising it says nothing about whether the per-contract single-argument functions are implemented. Accordingly, a contract MUST return `true` for `type(IERC1643).interfaceId` only if it also implements those base functions; a management contract exposing only the address-scoped surface MUST NOT advertise `type(IERC1643).interfaceId`.

Events are not part of any ERC-165 interface id, so `supportsInterface` reflects only which functions a contract implements, not whether it emits the events defined here.

### Optional: Subject-Side Manager Discovery

Nothing above lets a consumer that knows only a subject find the management contract holding that subject's documents; the address has to be learned out of band. Subjects MAY close this gap by implementing the following interface. It is **implemented by the subject, not by the management contract**, and is optional for both.

```solidity
/// @title IMultiDocumentSubject Manager discovery (optional)
interface IMultiDocumentSubject {
    /// @notice Emitted when the managing contract changes.
    /// @param previousManager Address that previously managed this contract's documents.
    /// @param newManager Address that manages this contract's documents from now on.
    event DocumentManagerUpdated(address indexed previousManager, address indexed newManager);

    /// @notice Returns the contract managing this contract's documents.
    /// @dev MUST NOT revert. MUST emit `DocumentManagerUpdated` when the returned value changes.
    /// @return manager Address of the managing contract, or `address(0)` when documents are managed in-contract.
    function documentManager() external view returns (address manager);
}
```

- `documentManager`:
  - MUST return the address of the contract to which this contract's document management is delegated.
  - MUST return `address(0)` when document management is not delegated.
  - MUST NOT revert.
- A contract that changes the returned value MUST emit `DocumentManagerUpdated`, so a consumer that cached the address learns of the migration. Without this, discovery would be a one-shot read that silently goes stale.
- This interface is declared independently of both `IERC1643` and `IERC1643MultiDocument`, so its ERC-165 id is distinct and advertising it perturbs neither. A subject implementing it SHOULD return `true` for `type(IMultiDocumentSubject).interfaceId`.

The returned address is an **assertion by the subject**, not a verified link: nothing requires the named contract to acknowledge the relationship, or to have any documents for that subject at all. Consumers MUST treat it as a discovery hint and not as evidence of authorization; see Security Considerations.

### Relationship to [ERC-1643](./eip-1643.md)

A subject need not implement ERC-1643. This section applies only when it does, and constrains such deployments; it places no requirement on ERC-1643 itself, which is unchanged by this proposal.

#### Emission Responsibility

ERC-1643's `DocumentUpdated` / `DocumentRemoved` carry no address, so consumers attribute them to the address that emitted them. Those events MUST therefore be emitted by the contract that exposes ERC-1643 to consumers — the address consumers are expected to subscribe to. When an ERC-1643 subject delegates to a management contract, the emitter MUST be chosen so per-contract observability is preserved:

- A management contract **dedicated to a single** subject MAY be that subject's ERC-1643 implementation and MUST emit `DocumentUpdated` / `DocumentRemoved`; those events are unambiguous because only one subject is served. Such a contract does not need this proposal.
- A management contract **serving several** subjects MUST NOT report per-subject changes through ERC-1643's events, since those events cannot identify the subject. In this configuration each subject MUST emit ERC-1643's events for its own documents, and the management contract emits `DocumentUpdatedForSubject` / `DocumentRemovedForSubject` instead, as those carry the `subject` address.
- Implementations SHOULD NOT emit ERC-1643's events from **both** the subject and the management contract; it is redundant and wastes gas.

#### Call Topology

A contract can only emit an event in a transaction in which it executes. The requirement that each subject emit ERC-1643's events for its own documents therefore constrains how a write reaches the management contract, not only which contract is nominally responsible for emitting.

A write that creates, updates, or removes a document for an ERC-1643 subject MUST include an execution point in that subject at which the event is emitted. Two topologies satisfy this:

- **Subject-initiated.** The subject calls the management contract's address-scoped write and emits ERC-1643's event itself. The management contract emits the corresponding event defined here.
- **Manager-initiated with callback.** An authorized operator calls the management contract, which calls back into the subject through an implementation-defined permissioned hook; the subject emits ERC-1643's event. This proposal does not define the signature of that hook.

A deployment in which an operator calls `setDocument(address subject, ...)` or `removeDocument(address subject, bytes32 name)` directly, with no execution point in the subject, does **not** satisfy ERC-1643's emission requirement for that subject: a consumer subscribed to the subject never observes the change, so the subject does not support subscribing to updates on its documentation and is not a conformant ERC-1643 implementation in that deployment, even though it exposes the ERC-1643 functions. Note this is a consequence of ERC-1643's own requirements, not an additional obligation imposed here.

Accordingly, a management contract SHOULD restrict its address-scoped writes to callers for which one of the two topologies above holds — the subject itself, or an operator whose write path calls back into the subject. This is narrower than, and consistent with, the per-`subject` authorization required above: authorization decides *who* may write for a subject, while call topology decides whether that write remains observable on the subject's own address.

Consumers of this proposal's events are unaffected in either topology: `DocumentUpdatedForSubject` / `DocumentRemovedForSubject` carry the `subject` address and are emitted by the management contract in every case.

## Rationale

The `subject` parameter is named generically rather than "token" because the contract documents belong to is not necessarily a token, and because the on-chain identifiers should not hard-code an assumption the interface does not enforce. The event names follow the parameter (`DocumentUpdatedForSubject`), keeping the event and its attribute aligned.

The interface is declared independently of `IERC1643` rather than inheriting it. Inheritance would force every shared management contract to implement the per-contract single-argument functions, which have no meaningful subject in the shared case, and would invite contracts to advertise an ERC-165 interface id for functions they do not implement.

Separate address-scoped functions are used instead of overloading the per-contract ones with a subject-carrying variant of the same name because the resulting selectors are distinct either way; declaring them here keeps this proposal self-contained and readable without reference to ERC-1643's interface.

The data model is inherited from ERC-1643 unchanged — `bytes32` names for compact, directly comparable on-chain identifiers, a URI pointer instead of on-chain storage, and a content hash for integrity — so that a subject can migrate between self-managed and delegated document storage without changing what consumers read.

Errors are prefixed by the proposal that defines the condition, not by the proposal that declares them. `ERC1643InvalidName` and `ERC1643MissingDocument` keep their ERC-1643 prefix because they are ERC-1643's errors, reused so revert data stays identical across both interfaces; renaming them here would fragment that. `MultiDocumentInvalidSubject` is defined by this proposal alone and is therefore named after it, rather than borrowing a prefix from a standard in which the condition cannot occur.

Manager discovery is defined here, and as a separate optional interface, for three reasons. It is a function on the *subject*, so folding it into ERC-1643 would grow that proposal with a function about a delegation arrangement ERC-1643 does not itself define. It is meaningful only where delegation exists, which is the subject of this proposal. And keeping it out of `IERC1643MultiDocument` means a management contract is never asked to implement a getter about itself that only its subjects can answer, while the distinct ERC-165 id lets a consumer detect discovery support without inferring anything about either document interface.

The names `IERC1643MultiDocument`, `MultiDocumentInvalidSubject` and `IMultiDocumentSubject` are all provisional. They record the companion relationship while this proposal is unnumbered, and SHOULD be revisited together to track this proposal's own number once an editor assigns one. The two reused ERC-1643 error names are **not** provisional and are expected to stay as they are.

## Backwards Compatibility

This proposal introduces a new interface and does not modify [ERC-1643](./eip-1643.md) or any other proposal.

- **Function selectors.** `getDocument(address,bytes32)`, `getAllDocuments(address)`, `setDocument(address,bytes32,string,bytes32)` and `removeDocument(address,bytes32)` have different signatures — hence different 4-byte selectors — than their single-argument ERC-1643 counterparts. A contract implementing both exposes both sets side by side with no collision.
- **Events.** `DocumentUpdatedForSubject` / `DocumentRemovedForSubject` are new event topics. ERC-1643's `DocumentUpdated` / `DocumentRemoved` are untouched and keep their exact meaning.
- **ERC-165.** Advertising `type(IERC1643MultiDocument).interfaceId` does not disturb `supportsInterface(type(IERC1643).interfaceId)`. A consumer that only knows ERC-1643 detects it exactly as before.
- **Manager discovery.** `IMultiDocumentSubject` is optional and separate. It adds one selector and one event topic to a subject that chooses to implement it, and is declared independently of both document interfaces, so it perturbs neither interface id. A subject that does not implement it is unaffected, and a consumer that does not know it behaves exactly as before.

A consumer that only knows ERC-1643 is unaffected: it continues to call the per-contract functions and subscribe to the per-contract events on the address it was directed to watch. The one way to break such a consumer is to direct it at a management contract that emits only the events defined here — a deployment error, addressed by the Emission Responsibility and Call Topology requirements above rather than by the interface itself.

## Test Cases

Implementations should verify at least the following:

- Subject isolation: the same `name` written for two different subjects yields two independent entries, and `getAllDocuments` for one subject never returns the other's names.
- Adding, updating, and removing a document for a subject, and reading it back through `getDocument`.
- Emission of `DocumentUpdatedForSubject` on create/update and `DocumentRemovedForSubject` on delete, each carrying the correct `subject`.
- A caller not authorized for a subject failing to create, update, or remove that subject's documents.
- `setDocument` rejecting `subject == address(0)` and `name == bytes32(0)`.
- `supportsInterface` returning `true` for `type(IERC1643MultiDocument).interfaceId`, and returning `false` for `type(IERC1643).interfaceId` on a contract that implements only the address-scoped surface.
- For a subject implementing `IMultiDocumentSubject`: `documentManager` returning the delegate's address, returning `address(0)` when management is not delegated, and `DocumentManagerUpdated` being emitted with the correct previous and new addresses when the delegate changes.

## Reference Implementation

A reference implementation is not yet provided. It is expected to maintain, per subject, a mapping from `bytes32` name to document metadata, a set for enumeration of active names, and index tracking to support O(1) removals — the ERC-1643 reference module's structure, keyed additionally by `subject` — together with the per-`subject` authorization required in the Specification.

## Security Considerations

- **Per-subject authorization is the central risk.** A management contract holds the document sets of unrelated subjects behind a single address. If writes are not authorized per `subject`, any caller permitted to write for one subject can modify another subject's legal or operational references. This is a stronger requirement than in the per-contract case, where a contract's own access control naturally scopes to its own documents.
- **Delegation moves the subject's trust boundary.** A subject that delegates document management is only as protected as the management contract's access control: whoever can write for that subject there can change its legal or operational references, regardless of the subject's own permissioning. Delegating to a contract serving several subjects also concentrates the document sets of unrelated parties behind a single address, so a single access-control flaw there is not contained to one subject. Subjects should treat the choice of management contract as a permissioning decision, not merely a storage one.
- **The null subject.** Implementations should reject `subject == address(0)`. This is a data-integrity concern rather than a fund-safety one: subject namespaces are isolated, and the null address cannot call the contract to read documents registered under it, so such entries are inert. They do, however, let callers populate a namespace no contract can ever own, cluttering state and misleading off-chain indexers that key on `subject`.
- **Direct writes can silently bypass subject-side emission.** When a subject implements [ERC-1643](./eip-1643.md), a write sent directly to the management contract without an execution point in the subject leaves the subject's per-contract events unemitted. The failure is quiet in both directions: the write succeeds and the event defined here is emitted, so nothing reverts, while a consumer watching the subject sees no event and concludes the documents are unchanged. Integrators who must rely on the per-contract events should confirm the deployment's write path out of band.
- **Event emission is not discoverable.** Because events are outside ERC-165, `supportsInterface(type(IERC1643MultiDocument).interfaceId)` confirms only that the functions exist, not that the address-carrying events are actually emitted. Integrators relying on those events should confirm emission out of band.
- **`documentManager` is an unverified assertion.** The value is chosen entirely by the subject, and nothing requires the named contract to acknowledge the relationship or to hold any documents for that subject. A compromised or malicious subject can point consumers at an attacker-controlled contract serving fabricated documents, and calling `getAllDocuments(subject)` on the claimed manager does not disprove this — anyone can populate their own contract with entries for any subject. Manager discovery is a convenience for locating a feed, not an authorization or authenticity signal. Consumers making decisions that depend on document contents should verify against the published `documentHash` and, where the stakes justify it, confirm the manager address through the same out-of-band channel they would have used without this interface.
- **A stale cached manager address.** A consumer that reads `documentManager` once and does not watch `DocumentManagerUpdated` may keep following a superseded contract after a migration, seeing a frozen document set with no indication it is no longer current.
- **Mutable off-chain content.** Document URIs may reference content that changes independently of the chain. Consumers are strongly encouraged to verify content against the published `documentHash` and to use trusted retrieval channels.
- **Names may not fit `bytes32`.** Long legal titles should not be lossily truncated; a deterministic hash-based identifier (for example the document content hash, or a hash of a canonical full title) is a safer choice for the `bytes32` name.
- **Events are advisory.** Applications should reconcile event streams against on-chain state when correctness is critical.

## Copyright

Copyright and related rights waived via [CC0](../LICENSE.md).
