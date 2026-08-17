//SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

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
abstract contract DocumentEngineBase is IERC1643, IERC1643MultiDocument, DocumentEngineInvariant, Context {
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
    function setDocument(address subject, bytes32 name_, string memory uri_, bytes32 documentHash_)
        public
        override
        onlyDocumentManager
    {
        _setDocument(subject, name_, uri_, documentHash_);
    }

    /**
     * @notice Restricted function to remove a document for a given smart contract and name
     */
    function removeDocument(address subject, bytes32 name_) external override onlyDocumentManager {
        _removeDocument(subject, name_);
    }

    /* ============ ERC-1643 (bound token) ============ */

    /**
     * @notice ERC-1643 function to set or update a document for the caller.
     * @dev The document is stored under the caller (`_msgSender()`) namespace.
     * Restricted by the `onlyBoundToken` hook: the caller must be a token bound to
     * this engine. How a token is bound is deployment-specific (see the
     * {_authorizeBoundTokenDocumentManagement} implementations). A bound token can
     * only manage its own documents; it can never affect another contract's documents.
     */
    function setDocument(bytes32 name_, string calldata uri_, bytes32 documentHash_) external override onlyBoundToken {
        _setDocument(_msgSender(), name_, uri_, documentHash_);
    }

    /**
     * @notice ERC-1643 function to remove a document for the caller.
     * @dev See {setDocument}. Scoped to the caller (`_msgSender()`) namespace.
     */
    function removeDocument(bytes32 name_) external override onlyBoundToken {
        _removeDocument(_msgSender(), name_);
    }

    /**
     * @notice Batch version of setDocument to handle multiple documents at once
     */
    function batchSetDocuments(
        address[] calldata subjects,
        bytes32[] calldata names,
        string[] calldata uris,
        bytes32[] calldata hashes
    ) external onlyDocumentManager {
        if (
            subjects.length == 0 || subjects.length != names.length || names.length != uris.length
                || uris.length != hashes.length
        ) {
            revert InvalidInputLength();
        }
        uint256 length = subjects.length;
        for (uint256 i = 0; i < length; ++i) {
            _setDocument(subjects[i], names[i], uris[i], hashes[i]);
        }
    }

    /**
     * @notice Batch version of setDocument to handle multiple documents at once
     */
    function batchSetDocuments(
        address subject,
        bytes32[] calldata names,
        string[] calldata uris,
        bytes32[] calldata hashes
    ) external onlyDocumentManager {
        if (names.length == 0 || names.length != uris.length || uris.length != hashes.length) {
            revert InvalidInputLength();
        }
        uint256 length = names.length;
        for (uint256 i = 0; i < length; ++i) {
            _setDocument(subject, names[i], uris[i], hashes[i]);
        }
    }

    /**
     * @notice Batch version of removeDocument to handle multiple documents at once
     */
    function batchRemoveDocuments(address[] calldata subjects, bytes32[] calldata names) external onlyDocumentManager {
        if (subjects.length == 0 || (subjects.length != names.length)) {
            revert InvalidInputLength();
        }

        uint256 length = subjects.length;
        for (uint256 i = 0; i < length; ++i) {
            _removeDocument(subjects[i], names[i]);
        }
    }

    /**
     * @notice Batch version of removeDocument to handle multiple documents at once
     */
    function batchRemoveDocuments(address subject, bytes32[] calldata names) external onlyDocumentManager {
        if (names.length == 0) {
            revert InvalidInputLength();
        }

        uint256 length = names.length;
        for (uint256 i = 0; i < length; ++i) {
            _removeDocument(subject, names[i]);
        }
    }

    /**
     * @notice ERC-1643 function to get a document for the caller (`_msgSender()`)
     * @dev Returns the three fields as flat values, matching the ERC-1643 ABI. The `Document`
     * struct is kept for storage only: returning it would prepend a struct offset word to the
     * returndata, so a consumer decoding per the ERC-1643 signature would silently mis-decode.
     */
    function getDocument(bytes32 name_)
        external
        view
        override
        returns (string memory uri, bytes32 documentHash, uint256 lastModified)
    {
        return _getDocument(_msgSender(), name_);
    }

    /**
     * @notice Public function to get a document for a specific contract address
     * @dev Flat return, see {getDocument(bytes32)}.
     */
    function getDocument(address subject, bytes32 name_)
        external
        view
        override
        returns (string memory uri, bytes32 documentHash, uint256 lastModified)
    {
        return _getDocument(subject, name_);
    }

    /**
     * @notice Get all document names for msg.sender
     */
    function getAllDocuments() external view override returns (bytes32[] memory) {
        return _documentNames[_msgSender()];
    }

    /**
     * @notice Get all document names for a specific smart contract
     */
    function getAllDocuments(address subject) external view override returns (bytes32[] memory) {
        return _documentNames[subject];
    }

    /*//////////////////////////////////////////////////////////////
                            INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Internal function to fetch a document, as flat values
     */
    function _getDocument(address subject, bytes32 name_)
        internal
        view
        returns (string memory uri, bytes32 documentHash, uint256 lastModified)
    {
        Document storage doc = _documents[subject][name_];
        return (doc.uri, doc.documentHash, doc.lastModified);
    }

    /**
     * @dev Internal helper to remove the document name from the list of document names
     */
    function _removeDocumentName(address subject, bytes32 name_) internal {
        uint256 length = _documentNames[subject].length;
        for (uint256 i = 0; i < length; ++i) {
            if (_documentNames[subject][i] == name_) {
                _documentNames[subject][i] = _documentNames[subject][length - 1];
                _documentNames[subject].pop();
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
        emit DocumentRemovedForSubject(subject, name_, doc.uri, doc.documentHash);

        delete _documents[subject][name_];
        _removeDocumentName(subject, name_);
    }

    function _setDocument(address subject, bytes32 name_, string memory uri_, bytes32 documentHash_) internal {
        // Multi-token guard: `subject` must be a real contract address, never the
        // null namespace. (The bound-token path passes `_msgSender()`, never zero.)
        if (subject == address(0)) {
            revert MultiDocumentInvalidSubject();
        }
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
