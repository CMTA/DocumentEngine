//SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

contract DocumentEngineInvariant {
    error DocumentNotFound(address smartContract, bytes32 name);
    error InvalidInputLength();

    event DocumentUpdated(
        address smartContract,
        bytes32 name,
        string uri,
        bytes32 documentHash
    );
    event DocumentRemoved(
        address smartContract,
        bytes32 name,
        string uri,
        bytes32 documentHash
    );

    // Document structure
    struct Document {
        string uri;
        bytes32 documentHash;
        uint256 lastModified;
    }

    bytes32 public constant DOCUMENT_MANAGER_ROLE =
        keccak256("DOCUMENT_MANAGER_ROLE");
}
