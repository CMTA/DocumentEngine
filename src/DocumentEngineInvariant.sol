//SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

/**
 * @title DocumentEngineInvariant
 * @notice Shared errors and events for the DocumentEngine, common to every
 * deployment regardless of its access-control model.
 * @dev Access-control specifics (roles, owner, ...) are intentionally NOT
 * defined here; they belong to the deployment contract (e.g. the role constants
 * live in {DocumentEngine}, the owner logic in {DocumentEngineOwnable}).
 */
contract DocumentEngineInvariant {
    error DocumentNotFound(address smartContract, bytes32 name);
    error InvalidInputLength();
    error AdminWithAddressZeroNotAllowed();

    /**
     * @notice Optional multi-token events emitted in addition to the standard
     * `IERC1643.DocumentUpdated` / `IERC1643.DocumentRemoved` events.
     * @dev Because this engine manages documents on behalf of several smart
     * contracts (tokens), the standard events - which only carry the document
     * `name` - are not sufficient to identify which contract a document belongs
     * to. These events add the `smartContract` address for off-chain indexers.
     * See `ERC-1643-proposition.md` for the proposed optional standard extension.
     */
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
