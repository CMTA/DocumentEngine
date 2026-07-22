// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {IERC1643} from "CMTAT/interfaces/tokenization/draft-IERC1643.sol";

/**
 * @title IERC1643MultiDocument — optional multi-token ERC-1643 extension
 * @notice Address-scoped document management for a contract that manages
 * documents on behalf of several `subject` contracts.
 * @dev Declared **independently of `IERC1643`** (it does not inherit it), so a
 * shared management contract can implement the address-scoped surface without
 * being forced to implement the base single-argument functions. `subject` is the
 * address of the contract the documents belong to (typically a token contract,
 * but the reasoning applies to any ERC-721/ERC-1155 token, vault, or other
 * on-chain product). See `doc/ERCSpecification/ERC-1643-proposition.md`.
 */
interface IERC1643MultiDocument {
    /// @notice Returns metadata for the document `name` belonging to `subject`.
    function getDocument(address subject, bytes32 name) external view returns (IERC1643.Document memory document);

    /// @notice Returns all document names currently tracked for `subject`.
    function getAllDocuments(address subject) external view returns (bytes32[] memory documentNames);

    /// @notice Creates or updates a document entry for `subject`.
    /// @dev MUST emit {DocumentUpdatedForSubject} on success.
    function setDocument(address subject, bytes32 name, string calldata uri, bytes32 documentHash) external;

    /// @notice Removes an existing document entry for `subject`.
    /// @dev MUST emit {DocumentRemovedForSubject} on success.
    function removeDocument(address subject, bytes32 name) external;

    /// @notice Emitted when a document is created or updated for `subject`.
    event DocumentUpdatedForSubject(address indexed subject, bytes32 indexed name, string uri, bytes32 documentHash);

    /// @notice Emitted when a document is removed for `subject`.
    event DocumentRemovedForSubject(address indexed subject, bytes32 indexed name, string uri, bytes32 documentHash);
}
