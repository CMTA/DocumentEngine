//SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

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

    // Role allowed to manage documents on behalf of any smart contract (admin path)
    bytes32 public constant DOCUMENT_MANAGER_ROLE =
        keccak256("DOCUMENT_MANAGER_ROLE");

    // Role granted to a token bound to the engine, allowing it to manage its own
    // documents through the standard ERC-1643 functions (msg.sender is the token).
    // Mirrors the RuleEngine binding pattern (CMTA/RuleEngine `TOKEN_CONTRACT_ROLE`).
    bytes32 public constant TOKEN_CONTRACT_ROLE =
        keccak256("TOKEN_CONTRACT_ROLE");
}
