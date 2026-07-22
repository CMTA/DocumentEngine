//SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import "OZ/utils/Context.sol";
import "CMTAT/interfaces/tokenization/draft-IERC1643.sol";
import {IERC1643MultiDocument} from "./interfaces/IERC1643MultiDocument.sol";
import "./DocumentEngineInvariant.sol";

/**
 * @title DocumentEngineBase
 * @notice Document management logic (ERC-1643) for several smart contracts.
 * @dev This abstract base holds the document storage and all the
 * document-management functions, but it is **agnostic to the access-control
 * implementation**. Authorization is delegated to the abstract hooks
 * {_authorizeDocumentManagement} and {_authorizeBoundTokenDocumentManagement}
 * (through the `onlyDocumentManager` / `onlyBoundToken` modifiers), which a
 * deployment contract must implement (see {DocumentEngine}).
 *
 * This separation (base logic + deployment-defined access control) follows the
 * CMTAT and CMTA/RuleEngine pattern.
 */
abstract contract DocumentEngineBase is
    IERC1643,
    IERC1643MultiDocument,
    DocumentEngineInvariant,
    Context
{
    // Mapping from contract addresses to document names to their corresponding Document structs
    mapping(address => mapping(bytes32 => Document)) private _documents;
    mapping(address => bytes32[]) private _documentNames;

    /*//////////////////////////////////////////////////////////////
                        ACCESS CONTROL (hooks)
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Restricts a function to accounts allowed to manage documents on
     * behalf of any smart contract (admin path). Delegates the authorization
     * to {_authorizeDocumentManagement} so that the document-management
     * implementation stays separate from the access-control logic.
     */
    modifier onlyDocumentManager() {
        _authorizeDocumentManagement();
        _;
    }

    /**
     * @dev Restricts a function to tokens bound to this engine, letting them
     * manage their own documents (bound-token path). Delegates to
     * {_authorizeBoundTokenDocumentManagement}.
     */
    modifier onlyBoundToken() {
        _authorizeBoundTokenDocumentManagement();
        _;
    }

    /**
     * @dev Authorization hook for the admin document-management path.
     * Implemented by the deployment contract (e.g. a role check).
     */
    function _authorizeDocumentManagement() internal view virtual;

    /**
     * @dev Authorization hook for the bound-token document-management path.
     * Implemented by the deployment contract (e.g. a role check).
     */
    function _authorizeBoundTokenDocumentManagement() internal view virtual;

    /*//////////////////////////////////////////////////////////////
                            PUBLIC/EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Restricted function to set or update a document
     */
    function setDocument(
        address subject,
        bytes32 name_,
        string memory uri_,
        bytes32 documentHash_
    ) public override onlyDocumentManager {
        _setDocument(subject, name_, uri_, documentHash_);
    }

    /**
     * @notice Restricted function to remove a document for a given smart contract and name
     */
    function removeDocument(
        address subject,
        bytes32 name_
    ) external override onlyDocumentManager {
        _removeDocument(subject, name_);
    }

    /* ============ ERC-1643 (bound token) ============ */

    /**
     * @notice ERC-1643 function to set or update a document for the caller.
     * @dev The document is stored under the caller (`_msgSender()`) namespace.
     * The caller must be a token bound to this engine (`TOKEN_CONTRACT_ROLE`),
     * following the RuleEngine binding pattern. A bound token can only manage
     * its own documents; it can never affect another contract's documents.
     */
    function setDocument(
        bytes32 name_,
        string calldata uri_,
        bytes32 documentHash_
    ) external override onlyBoundToken {
        _setDocument(_msgSender(), name_, uri_, documentHash_);
    }

    /**
     * @notice ERC-1643 function to remove a document for the caller.
     * @dev See {setDocument}. Scoped to the caller (`_msgSender()`) namespace.
     */
    function removeDocument(
        bytes32 name_
    ) external override onlyBoundToken {
        _removeDocument(_msgSender(), name_);
    }

    /**
     * @notice Batch version of setDocument to handle multiple documents at once
     */
    function batchSetDocuments(
        address[] calldata smartContracts,
        bytes32[] calldata names,
        string[] calldata uris,
        bytes32[] calldata hashes
    ) external onlyDocumentManager {
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
     * @notice Batch version of setDocument to handle multiple documents at once
     */
    function batchSetDocuments(
        address smartContract,
        bytes32[] calldata names,
        string[] calldata uris,
        bytes32[] calldata hashes
    ) external onlyDocumentManager {
        if (
            names.length == 0 ||
            names.length != uris.length ||
            uris.length != hashes.length
        ) {
            revert InvalidInputLength();
        }
        for (uint256 i = 0; i < names.length; ++i) {
            _setDocument(smartContract, names[i], uris[i], hashes[i]);
        }
    }

    /**
     * @notice Batch version of removeDocument to handle multiple documents at once
     */
    function batchRemoveDocuments(
        address[] calldata smartContracts,
        bytes32[] calldata names
    ) external onlyDocumentManager {
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
     * @notice Batch version of removeDocument to handle multiple documents at once
     */
    function batchRemoveDocuments(
        address smartContract,
        bytes32[] calldata names
    ) external onlyDocumentManager {
        if (names.length == 0) {
            revert InvalidInputLength();
        }

        for (uint256 i = 0; i < names.length; ++i) {
            _removeDocument(smartContract, names[i]);
        }
    }

    /**
     * @notice ERC-1643 function to get a document for the caller (`_msgSender()`)
     */
    function getDocument(
        bytes32 name_
    ) external view override returns (Document memory) {
        return _getDocument(_msgSender(), name_);
    }

    /**
     * @notice Public function to get a document for a specific contract address
     */
    function getDocument(
        address subject,
        bytes32 name_
    ) external view override returns (Document memory) {
        return _getDocument(subject, name_);
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
        return _documentNames[_msgSender()];
    }

    /**
     * @notice Get all document names for a specific smart contract
     */
    function getAllDocuments(
        address subject
    ) external view override returns (bytes32[] memory) {
        return _documentNames[subject];
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Internal function to fetch a document
     */
    function _getDocument(
        address smartContract,
        bytes32 name_
    ) internal view returns (Document memory) {
        return _documents[smartContract][name_];
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

    function _removeDocument(address subject, bytes32 name_) internal {
        Document memory doc = _documents[subject][name_];
        // ERC-1643: reverts when the named document does not exist
        if (doc.lastModified == 0) {
            revert ERC1643MissingDocument();
        }

        // This engine is a shared, multi-subject manager: per the ERC-1643
        // "Emission Responsibility" rules it emits only the address-carrying
        // extension event (the base `DocumentRemoved` is the token contract's
        // responsibility). See doc/ERCSpecification.
        emit DocumentRemovedForSubject(
            subject,
            name_,
            doc.uri,
            doc.documentHash
        );

        delete _documents[subject][name_];
        _removeDocumentName(subject, name_);
    }

    function _setDocument(
        address subject,
        bytes32 name_,
        string memory uri_,
        bytes32 documentHash_
    ) internal {
        // ERC-1643: reject the null name (ambiguous / default key)
        if (name_ == bytes32(0)) {
            revert ERC1643InvalidName();
        }

        Document storage doc = _documents[subject][name_];
        if (doc.lastModified == 0) {
            // new document
            _documentNames[subject].push(name_);
        }
        doc.uri = uri_;
        doc.documentHash = documentHash_;
        doc.lastModified = block.timestamp;

        // Shared, multi-subject manager: emit only the address-carrying extension
        // event (see {_removeDocument} note and doc/ERCSpecification).
        emit DocumentUpdatedForSubject(subject, name_, uri_, documentHash_);
    }
}
