# ERC-1643 — Proposition: optional multi-token document management

> Status: **draft / proposition**. This document proposes optional additions to
> [ERC-1643](https://github.com/ethereum/EIPs/issues/1643) motivated by the
> `DocumentEngine` implementation in this repository. It is not part of the
> standard and is provided for discussion.

## Context

ERC-1643 describes document management **for a single contract**: the token that
implements the interface manages its own documents. In CMTAT v3, the standard
interface is:

```solidity
interface IERC1643 {
    struct Document {
        string uri;
        bytes32 documentHash;
        uint256 lastModified;
    }

    function getDocument(bytes32 name) external view returns (Document memory document);
    function getAllDocuments() external view returns (bytes32[] memory documentNames_);
    function setDocument(bytes32 name, string calldata uri, bytes32 documentHash) external;
    function removeDocument(bytes32 name) external;

    event DocumentUpdated(bytes32 indexed name, string uri, bytes32 documentHash);
    event DocumentRemoved(bytes32 indexed name, string uri, bytes32 documentHash);
}
```

A **document engine** is a different use case: a single external contract manages
documents **on behalf of several tokens**, keyed by the token address. This
reduces the code size of each token and lets one operator manage documents for a
whole fleet of tokens.

For that multi-token use case, the standard events are **insufficient**: they only
carry the document `name`. When a single transaction sets documents for several
different tokens (batch operations), an off-chain indexer cannot tell from the
event alone which token a document belongs to — the emitting contract is always
the engine, not the token.

## Proposition 1 — Optional multi-token events

We propose two **optional** events that mirror the standard ones but add the
`smartContract` (token) address:

```solidity
event DocumentUpdatedForContract(
    address indexed smartContract,
    bytes32 indexed name,
    string uri,
    bytes32 documentHash
);

event DocumentRemovedForContract(
    address indexed smartContract,
    bytes32 indexed name,
    string uri,
    bytes32 documentHash
);
```

An engine that manages documents for several tokens SHOULD emit these events in
addition to the standard `DocumentUpdated` / `DocumentRemoved` events. The
standard events remain emitted for full backward compatibility with consumers
that only understand ERC-1643.

### Important limitation: no ERC-165 discoverability

Events are **not** part of a contract's ERC-165 interface id — `supportsInterface`
only covers function selectors. Consequently **there is no on-chain way for a
consumer to know whether a given implementation emits these optional events.**
A consumer that relies on them must obtain that information out of band (e.g.
documentation, a known implementation, or the optional extension interface below).

## Proposition 2 — Optional multi-token management extension

For implementations that want the multi-token capability to be
programmatically discoverable (via ERC-165) and callable, we propose an optional
extension interface. Unlike the events above, function selectors **are** part of
the ERC-165 interface id, so support can be detected on-chain.

```solidity
interface IERC1643MultiDocument is IERC1643 {
    /// @notice Get a document registered for `smartContract`.
    function getDocument(address smartContract, bytes32 name)
        external view returns (Document memory document);

    /// @notice Get all document names registered for `smartContract`.
    function getAllDocuments(address smartContract)
        external view returns (bytes32[] memory documentNames_);

    /// @notice Set or update a document for `smartContract`.
    function setDocument(address smartContract, bytes32 name, string calldata uri, bytes32 documentHash)
        external;

    /// @notice Remove a document for `smartContract`.
    function removeDocument(address smartContract, bytes32 name)
        external;

    event DocumentUpdatedForContract(
        address indexed smartContract,
        bytes32 indexed name,
        string uri,
        bytes32 documentHash
    );
    event DocumentRemovedForContract(
        address indexed smartContract,
        bytes32 indexed name,
        string uri,
        bytes32 documentHash
    );
}
```

The single-argument functions inherited from `IERC1643` keep their standard
meaning: they operate on the caller (`msg.sender`) namespace, i.e. a token
managing its own documents. The address-scoped functions add the operator /
multi-token capability.

## How this repository implements the proposition

The `DocumentEngine` in this repository already follows Proposition 1: every
write emits both the standard event and the `...ForContract` variant. It also
provides the address-scoped functions of Proposition 2 (under
`DOCUMENT_MANAGER_ROLE`) and the single-argument, `msg.sender`-scoped functions
(under `TOKEN_CONTRACT_ROLE`, the RuleEngine binding pattern), though it does not
yet formally declare/expose an `IERC1643MultiDocument` interface id.
