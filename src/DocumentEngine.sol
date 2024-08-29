//SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import "OZ/access/AccessControl.sol";
import "CMTAT/interfaces/engine/draft-IERC1643.sol";
import "./DocumentEngineInvariant.sol";

contract DocumentEngine is IERC1643, DocumentEngineInvariant, AccessControl {
    // Mapping from contract addresses to document names to their corresponding Document structs
    mapping(address => mapping(bytes32 => Document)) private _documents;
    mapping(address => bytes32[]) private _documentNames;

    // Constructor to initialize the admin role
    constructor(address admin) {
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /*//////////////////////////////////////////////////////////////
                            PUBLIC/EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Admin-only function to set or update a document
     */
    function setDocument(
        address smartContract,
        bytes32 name_,
        string memory uri_,
        bytes32 documentHash_
    ) public onlyRole(DOCUMENT_MANAGER_ROLE) {
        _setDocument(smartContract, name_, uri_, documentHash_);
    }

    /**
     * @notice Admin-only function to remove a document for a given smart contract and name
     */
    function removeDocument(
        address smartContract,
        bytes32 name_
    ) external onlyRole(DOCUMENT_MANAGER_ROLE) {
        _removeDocument(smartContract, name_);
    }

    /**
     * @notice Batch version of setDocument to handle multiple documents at once
     */
    function batchSetDocuments(
        address[] calldata smartContracts,
        bytes32[] calldata names,
        string[] calldata uris,
        bytes32[] calldata hashes
    ) external onlyRole(DOCUMENT_MANAGER_ROLE) {
        if (
            smartContracts.length == 0 ||
            smartContracts.length != names.length ||
            names.length != uris.length ||
            uris.length != hashes.length
        ) {
            revert InvalidInputLength();
        }
        for (uint256 i = 0; i < smartContracts.length; i++) {
            _setDocument(smartContracts[i], names[i], uris[i], hashes[i]);
        }
    }

    /**
     * @notice Batch version of removeDocument to handle multiple documents at once
     */
    function batchRemoveDocuments(
        address[] calldata smartContracts,
        bytes32[] calldata names
    ) external onlyRole(DOCUMENT_MANAGER_ROLE) {
        if (
            smartContracts.length == 0 ||
            (smartContracts.length != names.length)
        ) {
            revert InvalidInputLength();
        }

        for (uint256 i = 0; i < smartContracts.length; ++i) {
            _removeDocument(smartContracts[i], names[i]);
        }
    }

    /**
     * @notice Public function to get a document. Uses msg.sender if no address is provided
     */
    function getDocument(
        bytes32 name_
    ) external view override returns (string memory, bytes32, uint256) {
        return _getDocument(msg.sender, name_);
    }

    /**
     * @notice Public function to get a document for a specific contract address
     */
    function getDocument(
        address smartContract,
        bytes32 name_
    ) external view returns (string memory, bytes32, uint256) {
        return _getDocument(smartContract, name_);
    }

    /**
     * @notice Get all document names for msg.sender
     */
    function getAllDocuments()
        external
        view
        override
        returns (bytes32[] memory)
    {
        return _documentNames[msg.sender];
    }

    /**
     * @notice Get all document names for a specific smart contract
     */
    function getAllDocuments(
        address smartContract
    ) external view returns (bytes32[] memory) {
        return _documentNames[smartContract];
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Internal function to fetch a document and revert with an error if not found
     */
    function _getDocument(
        address smartContract,
        bytes32 name_
    ) internal view returns (string memory, bytes32, uint256) {
        Document memory doc = _documents[smartContract][name_];
        return (doc.uri, doc.documentHash, doc.lastModified);
    }

    /**
     * @dev Internal helper to remove the document name from the list of document names
     */
    function _removeDocumentName(
        address smartContract,
        bytes32 name_
    ) internal {
        uint256 length = _documentNames[smartContract].length;
        for (uint256 i = 0; i < length; ++i) {
            if (_documentNames[smartContract][i] == name_) {
                _documentNames[smartContract][i] = _documentNames[
                    smartContract
                ][length - 1];
                _documentNames[smartContract].pop();
                break;
            }
        }
    }

    function _removeDocument(address smartContract, bytes32 name_) internal {
        Document memory doc = _documents[smartContract][name_];
        emit DocumentRemoved(smartContract, name_, doc.uri, doc.documentHash);

        delete _documents[smartContract][name_];
        _removeDocumentName(smartContract, name_);
    }

    function _setDocument(
        address smartContract,
        bytes32 name_,
        string memory uri_,
        bytes32 documentHash_
    ) internal {
        Document storage doc = _documents[smartContract][name_];
        if (doc.lastModified == 0) {
            // new document
            _documentNames[smartContract].push(name_);
        }
        doc.uri = uri_;
        doc.documentHash = documentHash_;
        doc.lastModified = block.timestamp;
        emit DocumentUpdated(smartContract, name_, uri_, documentHash_);
    }

    /* ============ ACCESS CONTROL ============ */
    /*
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(
        bytes32 role,
        address account
    ) public view virtual override returns (bool) {
        // The Default Admin has all roles
        if (AccessControl.hasRole(DEFAULT_ADMIN_ROLE, account)) {
            return true;
        }
        return AccessControl.hasRole(role, account);
    }
}
