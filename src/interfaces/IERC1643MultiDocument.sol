// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

/**
 * @title IERC1643MultiDocument — optional multi-token ERC-1643 extension
 * @notice Address-scoped document management for a contract that manages
 * documents on behalf of several `subject` contracts.
 * @dev Declared **independently of `IERC1643`** (it does not inherit it), so a
 * shared management contract can implement the address-scoped surface without
 * being forced to implement the base single-argument functions. `subject` is the
 * address of the contract the documents belong to (typically a token contract,
 * but the reasoning applies to any ERC-721/ERC-1155 token, vault, or other
 * on-chain product). See `doc/ERCSpecification/erc-draft_multi_document_management.md`.
 */
interface IERC1643MultiDocument {
    /**
     * @notice Emitted when a document is created or updated for `subject`.
     * @param subject The contract the document belongs to.
     * @param name The document name.
     * @param uri The document location.
     * @param documentHash The hash of the document contents.
     */
    event DocumentUpdatedForSubject(address indexed subject, bytes32 indexed name, string uri, bytes32 documentHash);

    /**
     * @notice Emitted when a document is removed for `subject`.
     * @param subject The contract the document belonged to.
     * @param name The document name.
     * @param uri The document location as it was before removal.
     * @param documentHash The hash of the document contents as it was before removal.
     */
    event DocumentRemovedForSubject(address indexed subject, bytes32 indexed name, string uri, bytes32 documentHash);

    /**
     * @notice Reverts when `setDocument` or `removeDocument` is called with `subject == address(0)`.
     * @dev Specific to this proposal; it has no ERC-1643 counterpart, because ERC-1643's
     * `setDocument` has no `subject` argument — its subject is implicitly the contract itself,
     * which is never the null address. Named after the proposal that defines the condition, not
     * after one in which the condition cannot occur; the two errors this interface shares with
     * ERC-1643 (`ERC1643InvalidName`, `ERC1643MissingDocument`) keep their prefix for the opposite
     * reason, and are declared by `IERC1643`, never here.
     */
    error MultiDocumentInvalidSubject();

    /**
     * @notice Creates or updates a document entry for `subject`.
     * @dev MUST emit {DocumentUpdatedForSubject} on success.
     * @param subject The contract the document belongs to.
     * @param name The document name.
     * @param uri The document location.
     * @param documentHash The hash of the document contents.
     */
    function setDocument(address subject, bytes32 name, string calldata uri, bytes32 documentHash) external;

    /**
     * @notice Removes an existing document entry for `subject`.
     * @dev MUST emit {DocumentRemovedForSubject} on success.
     * @param subject The contract the document belongs to.
     * @param name The document name.
     */
    function removeDocument(address subject, bytes32 name) external;

    /**
     * @notice Returns metadata for the document `name` belonging to `subject`.
     * @dev Returns the three fields as flat values, matching the specification ABI. A missing
     * document yields empty values (`""`, `bytes32(0)`, `0`) and does not revert.
     * @param subject The contract the document belongs to.
     * @param name The document name.
     * @return uri Document location.
     * @return documentHash Hash of the document contents.
     * @return lastModified Last update timestamp.
     */
    function getDocument(address subject, bytes32 name)
        external
        view
        returns (string memory uri, bytes32 documentHash, uint256 lastModified);

    /**
     * @notice Returns all document names currently tracked for `subject`.
     * @param subject The contract to enumerate documents for.
     * @return documentNames The names of every document currently tracked for `subject`.
     */
    function getAllDocuments(address subject) external view returns (bytes32[] memory documentNames);
}
