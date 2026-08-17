//SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/DocumentEngine.sol";
import "../src/DocumentEngineInvariant.sol";
import "OZ/access/AccessControl.sol";
import {IERC165} from "OZ/utils/introspection/IERC165.sol";
import {IERC8303} from "../src/interfaces/IERC8303.sol";
// Imported explicitly rather than relied on transitively through DocumentEngine.sol.
import {IERC1643} from "CMTAT/interfaces/tokenization/draft-IERC1643.sol";
import {IERC1643MultiDocument} from "../src/interfaces/IERC1643MultiDocument.sol";
import {ITokenBinding} from "../src/interfaces/ITokenBinding.sol";
import {TokenBindingModule} from "../src/modules/TokenBindingModule.sol";
import {DocumentEngineModule} from "CMTAT/modules/wrapper/options/DocumentEngineModule.sol";

/**
 * @dev Minimal token wired to CMTAT's official `DocumentEngineModule`.
 *
 * Since CMTAT v3, the shipped standalone tokens store documents on-chain
 * (`DocumentERC1643Module`) and no longer consume an external document engine
 * through their constructor. Integration with an external `DocumentEngine` now
 * goes through `DocumentEngineModule`, which this mock exercises with real
 * CMTAT code: reads/writes are forwarded to the engine keyed by `msg.sender`.
 */
contract CMTATDocumentEngineMock is DocumentEngineModule {
    // No access restriction for the mock: document management is authorized for anyone.
    function _authorizeDocumentManagement() internal override {}
}

/**
 * @dev Demonstrates the flexible access control: overriding the authorization
 * hook opens the admin document-management path to anyone, without touching the
 * document-management implementation.
 */
contract OpenDocumentEngine is DocumentEngine {
    constructor(address admin, address forwarder) DocumentEngine(admin, forwarder) {}

    function _authorizeDocumentManagement() internal view override {
        // no access restriction (custom authorization)
    }
}

contract DocumentEngineTest is Test, DocumentEngineInvariant, AccessControl {
    DocumentEngine public documentEngine;
    address public admin = address(0x1);
    address public user = address(0x2);
    address public attacker = address(0x3);
    address private testContract = address(0x4);
    address private anotherSmartContract = address(0x5);
    bytes32 public documentName = keccak256("doc1");
    string public documentURI = "https://example.com/doc1";
    bytes32 public documentHash = keccak256("doc1Hash");
    bytes32 public constant DOCUMENT_ROLE = keccak256("DOCUMENT_ROLE");
    // Roles are defined on the role-based deployment (DocumentEngine), not on the
    // shared DocumentEngineInvariant; mirrored here for the assertions.
    bytes32 public constant DOCUMENT_MANAGER_ROLE = keccak256("DOCUMENT_MANAGER_ROLE");
    address AddressZero = address(0);

    // Local copies of the extension events, so `vm.expectEmit` can emit and match them.
    event DocumentUpdatedForSubject(address indexed subject, bytes32 indexed name, string uri, bytes32 documentHash);
    event DocumentRemovedForSubject(address indexed subject, bytes32 indexed name, string uri, bytes32 documentHash);
    event TokenBindingSet(address indexed token, bool bound);
    // Base ERC-1643 event signatures (this shared engine must NOT emit them).
    bytes32 internal constant BASE_UPDATED_SIG = keccak256("DocumentUpdated(bytes32,string,bytes32)");
    bytes32 internal constant BASE_REMOVED_SIG = keccak256("DocumentRemoved(bytes32,string,bytes32)");

    /**
     * @dev Since CMTAT `v3.3.0-rc2`, `getDocument` returns the three ERC-1643 fields as flat
     * values instead of a `Document` struct. These helpers repack them so the assertions below
     * stay readable; {testGetDocumentReturnsFlatErc1643Abi} pins the wire format itself.
     */
    function _doc(IERC1643MultiDocument engine_, address subject, bytes32 name_)
        internal
        view
        returns (IERC1643.Document memory document)
    {
        (document.uri, document.documentHash, document.lastModified) = engine_.getDocument(subject, name_);
    }

    /// @dev See {_doc(IERC1643MultiDocument,address,bytes32)}; caller-scoped ERC-1643 read.
    function _doc(IERC1643 engine_, bytes32 name_) internal view returns (IERC1643.Document memory document) {
        (document.uri, document.documentHash, document.lastModified) = engine_.getDocument(name_);
    }

    function setUp() public {
        documentEngine = new DocumentEngine(admin, AddressZero);
        vm.prank(admin);
        documentEngine.setDocument(testContract, documentName, documentURI, documentHash);
    }

    /*//////////////////////////////////////////////////////////////
            DEPLOYMENT
    ///////////////////////////////////////*/

    function testDeploy() public {
        address forwarder = address(0x1);
        documentEngine = new DocumentEngine(admin, forwarder);

        // Forwarder
        assertEq(documentEngine.isTrustedForwarder(forwarder), true);
        // admin
        vm.expectRevert(abi.encodeWithSelector(AdminWithAddressZeroNotAllowed.selector));
        documentEngine = new DocumentEngine(AddressZero, forwarder);
    }

    /*//////////////////////////////////////////////////////////////
              Access control
    ///////////////////////////////////////*/

    function testCannotNonAdminSetDocument() public {
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, attacker, DOCUMENT_MANAGER_ROLE)
        );
        documentEngine.setDocument(testContract, documentName, documentURI, documentHash);
    }

    function testCannotNonAdminRemoveDocument() public {
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, attacker, DOCUMENT_MANAGER_ROLE)
        );
        documentEngine.removeDocument(testContract, documentName);
    }

    function testNonAdminCannotBatchSetDocuments() public {
        address[] memory smartContracts = new address[](2);
        smartContracts[0] = testContract;
        smartContracts[1] = anotherSmartContract;

        bytes32[] memory names = new bytes32[](2);
        names[0] = documentName;
        names[1] = keccak256("doc2");

        string[] memory uris = new string[](2);
        uris[0] = documentURI;
        uris[1] = "https://example.com/doc2";

        bytes32[] memory hashes = new bytes32[](2);
        hashes[0] = documentHash;
        hashes[1] = keccak256("doc2Hash");

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, attacker, DOCUMENT_MANAGER_ROLE)
        );
        documentEngine.batchSetDocuments(smartContracts, names, uris, hashes);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, attacker, DOCUMENT_MANAGER_ROLE)
        );
        documentEngine.batchSetDocuments(testContract, names, uris, hashes);
    }

    function testNonAdminCannotBatchRemoveDocuments() public {
        address[] memory smartContracts = new address[](2);
        smartContracts[0] = testContract;
        smartContracts[1] = anotherSmartContract;

        bytes32[] memory names = new bytes32[](2);
        names[0] = documentName;
        names[1] = keccak256("doc2");

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, attacker, DOCUMENT_MANAGER_ROLE)
        );
        documentEngine.batchRemoveDocuments(smartContracts, names);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, attacker, DOCUMENT_MANAGER_ROLE)
        );
        documentEngine.batchRemoveDocuments(testContract, names);
    }

    /*//////////////////////////////////////////////////////////////
                  Get
    //////////////////////////////////////////////////////////////*/

    function testGetAllDocuments() public {
        bytes32[] memory docs = documentEngine.getAllDocuments(testContract);
        assertEq(docs.length, 1);
        assertEq(docs[0], documentName);
    }

    /*//////////////////////////////////////////////////////////////
            CMTAT integration (external engine via DocumentEngineModule)
    //////////////////////////////////////////////////////////////*/

    function testCanReturnCMTATDocument() public {
        // Arrange: a CMTAT-style token bound to the engine
        CMTATDocumentEngineMock cmtat = new CMTATDocumentEngineMock();
        cmtat.setDocumentEngine(documentEngine);

        uint256 lastModif = block.timestamp;
        vm.prank(admin);
        documentEngine.setDocument(address(cmtat), documentName, documentURI, documentHash);

        // Call from CMTAT, forwarded to the engine
        bytes32[] memory docs = cmtat.getAllDocuments();
        assertEq(docs.length, 1);
        assertEq(docs[0], documentName);

        IERC1643.Document memory doc = _doc(cmtat, documentName);
        assertEq(doc.uri, documentURI);
        assertEq(doc.documentHash, documentHash);
        assertEq(doc.lastModified, lastModif);
    }

    /*//////////////////////////////////////////////////////////////
            Bound token (shared ITokenBinding allowlist / TokenBindingModule)
    //////////////////////////////////////////////////////////////*/

    function testBoundTokenCanManageOwnDocument() public {
        // Bind the token to the engine (shared ITokenBinding surface)
        vm.prank(admin);
        documentEngine.bindToken(testContract);
        assertTrue(documentEngine.isTokenBound(testContract));

        // The bound token manages its own document namespace (msg.sender)
        bytes32 selfName = keccak256("self-doc");
        string memory selfURI = "https://example.com/self";
        bytes32 selfHash = keccak256("selfHash");

        vm.prank(testContract);
        documentEngine.setDocument(selfName, selfURI, selfHash);

        IERC1643.Document memory doc = _doc(documentEngine, testContract, selfName);
        assertEq(doc.uri, selfURI);
        assertEq(doc.documentHash, selfHash);
        assertEq(doc.lastModified, block.timestamp);

        // and can remove it
        vm.prank(testContract);
        documentEngine.removeDocument(selfName);
        doc = _doc(documentEngine, testContract, selfName);
        assertEq(doc.uri, "");
        assertEq(doc.documentHash, "");
        assertEq(doc.lastModified, 0);
    }

    function testNonAdminCannotBindToken() public {
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(AccessControlUnauthorizedAccount.selector, attacker, DOCUMENT_MANAGER_ROLE)
        );
        documentEngine.bindToken(testContract);
    }

    function testAdminCanUnbindToken() public {
        vm.prank(admin);
        documentEngine.bindToken(testContract);
        assertTrue(documentEngine.isTokenBound(testContract));

        vm.prank(admin);
        documentEngine.unbindToken(testContract);
        assertFalse(documentEngine.isTokenBound(testContract));
    }

    function testCannotBindZeroAddress() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(ITokenBinding.TokenBindingInvalidToken.selector));
        documentEngine.bindToken(AddressZero);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(ITokenBinding.TokenBindingInvalidToken.selector));
        documentEngine.unbindToken(AddressZero);

        assertFalse(documentEngine.isTokenBound(AddressZero));
    }

    /**
     * @dev Binding is idempotent: the repeated call succeeds, because the caller's intent already
     * holds, but emits nothing — so every {TokenBindingSet} in the log is a real transition and an
     * indexer never has to de-duplicate.
     */
    function testBindTokenIsIdempotentAndDoesNotReEmit() public {
        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit TokenBindingSet(testContract, true);
        documentEngine.bindToken(testContract);

        // second bind: succeeds, changes nothing, emits nothing
        vm.recordLogs();
        vm.prank(admin);
        documentEngine.bindToken(testContract);
        assertEq(vm.getRecordedLogs().length, 0, "re-binding must not emit");
        assertTrue(documentEngine.isTokenBound(testContract));
    }

    function testUnbindTokenIsIdempotentAndDoesNotReEmit() public {
        // unbinding a token that was never bound: succeeds, emits nothing
        vm.recordLogs();
        vm.prank(admin);
        documentEngine.unbindToken(testContract);
        assertEq(vm.getRecordedLogs().length, 0, "unbinding an unbound token must not emit");
        assertFalse(documentEngine.isTokenBound(testContract));

        vm.prank(admin);
        documentEngine.bindToken(testContract);

        vm.prank(admin);
        vm.expectEmit(true, false, false, true);
        emit TokenBindingSet(testContract, false);
        documentEngine.unbindToken(testContract);

        vm.recordLogs();
        vm.prank(admin);
        documentEngine.unbindToken(testContract);
        assertEq(vm.getRecordedLogs().length, 0, "re-unbinding must not emit");
        assertFalse(documentEngine.isTokenBound(testContract));
    }

    function testUnboundContractCannotSetOwnDocument() public {
        bytes32 selfName = keccak256("self-doc");
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(TokenBindingModule.NotBoundToken.selector, attacker));
        documentEngine.setDocument(selfName, documentURI, documentHash);
    }

    function testUnboundContractCannotRemoveOwnDocument() public {
        bytes32 selfName = keccak256("self-doc");
        vm.prank(attacker);
        vm.expectRevert(abi.encodeWithSelector(TokenBindingModule.NotBoundToken.selector, attacker));
        documentEngine.removeDocument(selfName);
    }

    /*//////////////////////////////////////////////////////////////
            Flexible access control (overridable authorization hook)
    //////////////////////////////////////////////////////////////*/

    function testFlexibleAuthorizationCanBeOverridden() public {
        OpenDocumentEngine openEngine = new OpenDocumentEngine(admin, AddressZero);

        // attacker holds no role, yet can manage documents because the
        // authorization hook was overridden to allow anyone.
        vm.prank(attacker);
        openEngine.setDocument(testContract, documentName, documentURI, documentHash);

        IERC1643.Document memory doc = _doc(openEngine, testContract, documentName);
        assertEq(doc.uri, documentURI);
        assertEq(doc.documentHash, documentHash);
    }

    /*//////////////////////////////////////////////////////////////
                        Version (ERC-8303)
    //////////////////////////////////////////////////////////////*/

    function testVersionReturnsNonEmptyString() public {
        string memory v = documentEngine.version();
        assertGt(bytes(v).length, 0);
        assertEq(v, "0.4.0");
        // the public VERSION constant matches version()
        assertEq(documentEngine.VERSION(), v);
    }

    function testSupportsInterfaceERC8303() public {
        // interface id declared by ERC-8303
        assertEq(type(IERC8303).interfaceId, bytes4(0x54fd4d50));
        assertTrue(documentEngine.supportsInterface(type(IERC8303).interfaceId));
    }

    function testSupportsERC1643Interfaces() public {
        // Pinned literals: an interface id is the XOR of the selectors, which depend only on the
        // function names and argument types. The CMTAT `v3.3.0-rc2` change of the `getDocument`
        // return shape therefore moved neither id — which is exactly why that change was
        // undetectable through ERC-165 (see {testGetDocumentReturnsFlatErc1643Abi}).
        assertEq(type(IERC1643).interfaceId, bytes4(0xecfecec8));
        assertEq(type(IERC1643MultiDocument).interfaceId, bytes4(0xa2b1179b));

        // implements the base single-argument functions, so a token can detect them here...
        assertTrue(documentEngine.supportsInterface(type(IERC1643).interfaceId));
        // ...the address-scoped multi-subject interface...
        assertTrue(documentEngine.supportsInterface(type(IERC1643MultiDocument).interfaceId));
        // ...and the shared token-binding surface
        assertTrue(documentEngine.supportsInterface(type(ITokenBinding).interfaceId));
    }

    /**
     * @dev What `type(IERC1643).interfaceId` does and does not promise here.
     *
     * It promises the base single-argument functions exist, which is what a token checks before
     * wiring itself to the engine. It does **not** make this address a document endpoint for third
     * parties: those functions are `_msgSender()`-scoped, so an external reader gets its own empty
     * namespace rather than the subject's documents — silently, with no revert. That asymmetry is
     * asserted here so it stays a documented property rather than a surprise.
     */
    function testBaseERC1643IsAdvertisedButReadsAreCallerScoped() public {
        assertTrue(documentEngine.supportsInterface(type(IERC1643).interfaceId));

        // `documentName` exists — but only under `testContract`, not under an arbitrary reader.
        (,, uint256 lastModifiedForSubject) = documentEngine.getDocument(testContract, documentName);
        assertGt(lastModifiedForSubject, 0);

        vm.prank(user);
        (string memory uri, bytes32 hash_, uint256 lastModified) = documentEngine.getDocument(documentName);
        assertEq(uri, "");
        assertEq(hash_, bytes32(0));
        assertEq(lastModified, 0, "a caller-scoped read returns the caller's own namespace, not the subject's");
    }

    /**
     * @dev Pins the `getDocument` wire format to the flat ERC-1643 ABI.
     *
     * Return types do not take part in a function signature, so returning a `Document` struct
     * instead of the three flat values leaves both the selector and `type(IERC1643).interfaceId`
     * unchanged: ERC-165 discovery cannot catch the difference, and a consumer built from the
     * specification ABI would silently decode a struct return as garbage. The only way to catch a
     * regression is to inspect the returndata, so assert the first word is the string offset
     * (`0x60`) of a flat `(string,bytes32,uint256)` and not the `0x20` struct offset.
     */
    function testGetDocumentReturnsFlatErc1643Abi() public {
        (bool okSubject, bytes memory subjectScoped) = address(documentEngine)
            .staticcall(abi.encodeWithSignature("getDocument(address,bytes32)", testContract, documentName));
        assertTrue(okSubject);
        assertEq(_firstWord(subjectScoped), 0x60, "getDocument(address,bytes32) must return flat values");

        vm.prank(testContract);
        (bool okSelf, bytes memory selfScoped) =
            address(documentEngine).staticcall(abi.encodeWithSignature("getDocument(bytes32)", documentName));
        assertTrue(okSelf);
        assertEq(_firstWord(selfScoped), 0x60, "getDocument(bytes32) must return flat values");

        // The decoded values must round-trip through the specification's own signature.
        (string memory uri, bytes32 hash_, uint256 lastModified) = abi.decode(subjectScoped, (string, bytes32, uint256));
        assertEq(uri, documentURI);
        assertEq(hash_, documentHash);
        assertEq(lastModified, block.timestamp);
    }

    function _firstWord(bytes memory data) private pure returns (uint256 word) {
        assembly {
            word := mload(add(data, 0x20))
        }
    }

    /*//////////////////////////////////////////////////////////////
                    ERC-1643 input validation
    //////////////////////////////////////////////////////////////*/

    function testCannotSetDocumentWithZeroName() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IERC1643.ERC1643InvalidName.selector));
        documentEngine.setDocument(testContract, bytes32(0), documentURI, documentHash);
    }

    function testCannotRemoveMissingDocument() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IERC1643.ERC1643MissingDocument.selector));
        documentEngine.removeDocument(testContract, keccak256("does-not-exist"));
    }

    function testBoundTokenCannotSetZeroName() public {
        vm.prank(admin);
        documentEngine.bindToken(testContract);
        vm.prank(testContract);
        vm.expectRevert(abi.encodeWithSelector(IERC1643.ERC1643InvalidName.selector));
        documentEngine.setDocument(bytes32(0), documentURI, documentHash);
    }

    function testSupportsInterfaceERC165AndAccessControl() public {
        assertTrue(documentEngine.supportsInterface(type(IERC165).interfaceId));
        assertTrue(documentEngine.supportsInterface(type(IAccessControl).interfaceId));
    }

    function testDoesNotSupportInvalidInterface() public {
        assertFalse(documentEngine.supportsInterface(bytes4(0xffffffff)));
    }

    /*//////////////////////////////////////////////////////////////
                        Set documents
    //////////////////////////////////////////////////////////////*/
    function testAdminCanSetDocument() public {
        uint256 lastModif = block.timestamp;
        vm.prank(admin);
        documentEngine.setDocument(testContract, documentName, documentURI, documentHash);

        IERC1643.Document memory doc = _doc(documentEngine, testContract, documentName);
        assertEq(doc.uri, documentURI);
        assertEq(doc.documentHash, documentHash);
        assertEq(doc.lastModified, lastModif);
    }

    function testAdminCanSetDocumentAgain() public {
        // Arrange
        vm.prank(admin);
        documentEngine.setDocument(testContract, documentName, documentURI, documentHash);
        bytes32[] memory docs = documentEngine.getAllDocuments(testContract);
        assertEq(docs.length, 1);
        assertEq(docs[0], documentName);
        // Act
        uint256 lastModif = block.timestamp;
        string memory documentURIV2 = "https://example.com/doc1";
        bytes32 documentHashV2 = keccak256("doc1Hash");
        vm.prank(admin);
        documentEngine.setDocument(testContract, documentName, documentURIV2, documentHashV2);

        // Assert
        IERC1643.Document memory doc = _doc(documentEngine, testContract, documentName);
        assertEq(doc.uri, documentURIV2);
        assertEq(doc.documentHash, documentHashV2);
        assertEq(doc.lastModified, lastModif);
        docs = documentEngine.getAllDocuments(testContract);
        assertEq(docs.length, 1);
        assertEq(docs[0], documentName);
    }

    function testAdminCanBatchSetDocuments() public {
        address[] memory smartContracts = new address[](2);
        smartContracts[0] = testContract;
        smartContracts[1] = anotherSmartContract;

        bytes32[] memory names = new bytes32[](2);
        names[0] = documentName;
        names[1] = keccak256("doc2");

        string[] memory uris = new string[](2);
        uris[0] = documentURI;
        uris[1] = "https://example.com/doc2";

        bytes32[] memory hashes = new bytes32[](2);
        hashes[0] = documentHash;
        hashes[1] = keccak256("doc2Hash");

        vm.prank(admin);
        documentEngine.batchSetDocuments(smartContracts, names, uris, hashes);

        // Check the first document
        IERC1643.Document memory doc1 = _doc(documentEngine, testContract, documentName);
        assertEq(doc1.uri, documentURI);
        assertEq(doc1.documentHash, documentHash);
        assertEq(doc1.lastModified, block.timestamp);

        // Check the second document
        IERC1643.Document memory doc2 = _doc(documentEngine, anotherSmartContract, names[1]);
        assertEq(doc2.uri, uris[1]);
        assertEq(doc2.documentHash, hashes[1]);
        assertEq(doc2.lastModified, block.timestamp);
    }

    function testAdminCanBatchSetDocumentsForTheSameContract() public {
        address[] memory smartContracts = new address[](2);
        smartContracts[0] = testContract;
        smartContracts[1] = testContract;

        bytes32[] memory names = new bytes32[](2);
        names[0] = documentName;
        names[1] = keccak256("doc2");

        string[] memory uris = new string[](2);
        uris[0] = documentURI;
        uris[1] = "https://example.com/doc2";

        bytes32[] memory hashes = new bytes32[](2);
        hashes[0] = documentHash;
        hashes[1] = keccak256("doc2Hash");

        vm.prank(admin);
        documentEngine.batchSetDocuments(smartContracts, names, uris, hashes);

        // Check the first document
        IERC1643.Document memory doc1 = _doc(documentEngine, testContract, documentName);
        assertEq(doc1.uri, documentURI);
        assertEq(doc1.documentHash, documentHash);
        assertEq(doc1.lastModified, block.timestamp);

        // Check the second document
        IERC1643.Document memory doc2 = _doc(documentEngine, testContract, names[1]);
        assertEq(doc2.uri, uris[1]);
        assertEq(doc2.documentHash, hashes[1]);
        assertEq(doc2.lastModified, block.timestamp);
    }

    function testCannotAddBatchDocumentIfLengthMismatch_A() public {
        address[] memory smartContracts = new address[](2);
        bytes32[] memory names = new bytes32[](1);
        string[] memory uris = new string[](2);
        bytes32[] memory hashes = new bytes32[](2);
        vm.expectRevert(abi.encodeWithSelector(InvalidInputLength.selector));
        vm.prank(admin);
        documentEngine.batchSetDocuments(smartContracts, names, uris, hashes);
    }

    function testCannotAddBatchDocumentIfLengthMismatch_B() public {
        address[] memory smartContracts = new address[](2);
        bytes32[] memory names = new bytes32[](2);
        string[] memory uris = new string[](1);
        bytes32[] memory hashes = new bytes32[](2);
        vm.expectRevert(abi.encodeWithSelector(InvalidInputLength.selector));
        vm.prank(admin);
        documentEngine.batchSetDocuments(smartContracts, names, uris, hashes);
    }

    function testCannotAddBatchDocumentIfEmptyLength() public {
        address[] memory smartContracts = new address[](0);
        bytes32[] memory names = new bytes32[](0);
        string[] memory uris = new string[](0);
        bytes32[] memory hashes = new bytes32[](0);
        vm.expectRevert(abi.encodeWithSelector(InvalidInputLength.selector));
        vm.prank(admin);
        documentEngine.batchSetDocuments(smartContracts, names, uris, hashes);
    }

    /*//////////////////////////////////////////////////////////////
                          REMOVE documents
    //////////////////////////////////////////////////////////////*/

    function testCannotRemoveBatchDocumentIfLengthMismatch() public {
        address[] memory smartContracts = new address[](2);

        bytes32[] memory names = new bytes32[](1);

        vm.expectRevert(abi.encodeWithSelector(InvalidInputLength.selector));
        vm.prank(admin);
        documentEngine.batchRemoveDocuments(smartContracts, names);
    }

    function testCannotRemoveBatchDocumentIfEmptyLength() public {
        address[] memory smartContracts = new address[](0);

        bytes32[] memory names = new bytes32[](0);

        vm.expectRevert(abi.encodeWithSelector(InvalidInputLength.selector));
        vm.prank(admin);
        documentEngine.batchRemoveDocuments(smartContracts, names);
    }

    function testAdminCanRemoveDocuments() public {
        // Set up documents
        testAdminCanBatchSetDocuments();
        // Remove the documents
        // Act
        vm.prank(admin);
        documentEngine.removeDocument(testContract, documentName);

        // Check that both documents are removed
        // Check the second document
        IERC1643.Document memory doc = _doc(documentEngine, testContract, documentName);
        assertEq(doc.uri, "");
        assertEq(doc.documentHash, "");
        assertEq(doc.lastModified, 0);
        bytes32[] memory docs = documentEngine.getAllDocuments(testContract);
        assertEq(docs.length, 0);
    }

    function testAdminCanBatchRemoveDocuments() public {
        // Set up documents
        testAdminCanBatchSetDocuments();

        // Remove the documents
        address[] memory smartContracts = new address[](2);
        smartContracts[0] = testContract;
        smartContracts[1] = anotherSmartContract;

        bytes32[] memory names = new bytes32[](2);
        names[0] = documentName;
        names[1] = keccak256("doc2");

        vm.prank(admin);
        documentEngine.batchRemoveDocuments(smartContracts, names);

        // Check that both documents are removed
        // Check the second document
        IERC1643.Document memory doc = _doc(documentEngine, testContract, documentName);
        assertEq(doc.uri, "");
        assertEq(doc.documentHash, "");
        assertEq(doc.lastModified, 0);
        bytes32[] memory docs = documentEngine.getAllDocuments(testContract);
        assertEq(docs.length, 0);

        IERC1643.Document memory doc2 = _doc(documentEngine, anotherSmartContract, names[1]);
        assertEq(doc2.uri, "");
        assertEq(doc2.documentHash, "");
        assertEq(doc2.lastModified, 0);
        docs = documentEngine.getAllDocuments(anotherSmartContract);
        assertEq(docs.length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                       Batch same contract
    //////////////////////////////////////////////////////////////*/

    function testCannotAddBatchDocumentIfLengthMismatch_C() public {
        address smartContract = address(0x1);
        bytes32[] memory names = new bytes32[](1);
        string[] memory uris = new string[](2);
        bytes32[] memory hashes = new bytes32[](2);
        vm.expectRevert(abi.encodeWithSelector(InvalidInputLength.selector));
        vm.prank(admin);
        documentEngine.batchSetDocuments(smartContract, names, uris, hashes);
    }

    function testCannotAddBatchDocumentIfLengthMismatch_D() public {
        address smartContract = address(0x1);
        bytes32[] memory names = new bytes32[](0);
        string[] memory uris = new string[](2);
        bytes32[] memory hashes = new bytes32[](2);
        vm.expectRevert(abi.encodeWithSelector(InvalidInputLength.selector));
        vm.prank(admin);
        documentEngine.batchSetDocuments(smartContract, names, uris, hashes);
    }

    function testAdminCanBatchSetDocumentsForOnlyOneContract() public {
        bytes32[] memory names = new bytes32[](2);
        names[0] = documentName;
        names[1] = keccak256("doc2");

        string[] memory uris = new string[](2);
        uris[0] = documentURI;
        uris[1] = "https://example.com/doc2";

        bytes32[] memory hashes = new bytes32[](2);
        hashes[0] = documentHash;
        hashes[1] = keccak256("doc2Hash");

        vm.prank(admin);
        documentEngine.batchSetDocuments(testContract, names, uris, hashes);

        // Check the first document
        IERC1643.Document memory doc1 = _doc(documentEngine, testContract, documentName);
        assertEq(doc1.uri, documentURI);
        assertEq(doc1.documentHash, documentHash);
        assertEq(doc1.lastModified, block.timestamp);

        // Check the second document
        IERC1643.Document memory doc2 = _doc(documentEngine, testContract, names[1]);
        assertEq(doc2.uri, uris[1]);
        assertEq(doc2.documentHash, hashes[1]);
        assertEq(doc2.lastModified, block.timestamp);
    }

    function testAdminCanBatchRemoveDocumentsForOnlyOneContract() public {
        // Set up documents
        testAdminCanBatchSetDocumentsForOnlyOneContract();

        // Remove the documents
        bytes32[] memory names = new bytes32[](2);
        names[0] = documentName;
        names[1] = keccak256("doc2");

        vm.prank(admin);
        documentEngine.batchRemoveDocuments(testContract, names);

        // Check that both documents are removed
        // Check the second document
        IERC1643.Document memory doc = _doc(documentEngine, testContract, documentName);
        assertEq(doc.uri, "");
        assertEq(doc.documentHash, "");
        assertEq(doc.lastModified, 0);
        bytes32[] memory docs = documentEngine.getAllDocuments(testContract);
        assertEq(docs.length, 0);
        IERC1643.Document memory doc2 = _doc(documentEngine, testContract, names[1]);
        assertEq(doc2.uri, "");
        assertEq(doc2.documentHash, "");
        assertEq(doc2.lastModified, 0);
    }

    function testCannotRemoveBatchDocumentIfEmptyLengthForOnlyOneContract() public {
        bytes32[] memory names = new bytes32[](0);

        vm.expectRevert(abi.encodeWithSelector(InvalidInputLength.selector));
        vm.prank(admin);
        documentEngine.batchRemoveDocuments(testContract, names);
    }

    /*//////////////////////////////////////////////////////////////
                        Events (emission responsibility)
    //////////////////////////////////////////////////////////////*/

    function testSetDocumentEmitsForSubjectEvent() public {
        bytes32 name = keccak256("evt-doc");
        vm.expectEmit(true, true, false, true, address(documentEngine));
        emit DocumentUpdatedForSubject(testContract, name, documentURI, documentHash);
        vm.prank(admin);
        documentEngine.setDocument(testContract, name, documentURI, documentHash);
    }

    function testRemoveDocumentEmitsForSubjectEvent() public {
        // `documentName` for `testContract` was registered in setUp
        vm.expectEmit(true, true, false, true, address(documentEngine));
        emit DocumentRemovedForSubject(testContract, documentName, documentURI, documentHash);
        vm.prank(admin);
        documentEngine.removeDocument(testContract, documentName);
    }

    function testSetDocumentDoesNotEmitBaseEvent() public {
        vm.recordLogs();
        vm.prank(admin);
        documentEngine.setDocument(testContract, keccak256("evt-doc"), documentURI, documentHash);
        _assertBaseEventNotEmitted(BASE_UPDATED_SIG);
    }

    function testRemoveDocumentDoesNotEmitBaseEvent() public {
        vm.recordLogs();
        vm.prank(admin);
        documentEngine.removeDocument(testContract, documentName);
        _assertBaseEventNotEmitted(BASE_REMOVED_SIG);
    }

    /// @dev Asserts no recorded log emitted by the engine carries the base ERC-1643 signature.
    function _assertBaseEventNotEmitted(bytes32 baseSig) internal {
        Vm.Log[] memory logs = vm.getRecordedLogs();
        for (uint256 i = 0; i < logs.length; ++i) {
            if (logs[i].emitter == address(documentEngine)) {
                assertTrue(logs[i].topics[0] != baseSig, "base ERC-1643 event must not be emitted");
            }
        }
    }

    /*//////////////////////////////////////////////////////////////
                    msg.sender-scoped reads (base ERC-1643)
    //////////////////////////////////////////////////////////////*/

    function testMsgSenderScopedReads() public {
        // setUp registered `documentName` for `testContract`; read it as that caller
        vm.prank(testContract);
        IERC1643.Document memory doc = _doc(documentEngine, documentName);
        assertEq(doc.uri, documentURI);
        assertEq(doc.documentHash, documentHash);

        vm.prank(testContract);
        bytes32[] memory names = documentEngine.getAllDocuments();
        assertEq(names.length, 1);
        assertEq(names[0], documentName);
    }

    function testMsgSenderScopedReadReturnsEmptyForOther() public {
        // `attacker` has no documents of its own
        vm.prank(attacker);
        IERC1643.Document memory doc = _doc(documentEngine, documentName);
        assertEq(doc.uri, "");
        assertEq(doc.documentHash, "");
        assertEq(doc.lastModified, 0);

        vm.prank(attacker);
        assertEq(documentEngine.getAllDocuments().length, 0);
    }

    /*//////////////////////////////////////////////////////////////
                    Batch edge cases (name==0 / missing doc)
    //////////////////////////////////////////////////////////////*/

    function testCannotSetDocumentForZeroSubject() public {
        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IERC1643MultiDocument.MultiDocumentInvalidSubject.selector));
        documentEngine.setDocument(AddressZero, documentName, documentURI, documentHash);
    }

    function testBatchSetRevertsOnZeroSubject() public {
        address[] memory subjects = new address[](1);
        subjects[0] = AddressZero;
        bytes32[] memory names = new bytes32[](1);
        names[0] = documentName;
        string[] memory uris = new string[](1);
        uris[0] = documentURI;
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = documentHash;

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IERC1643MultiDocument.MultiDocumentInvalidSubject.selector));
        documentEngine.batchSetDocuments(subjects, names, uris, hashes);
    }

    function testBatchSetRevertsOnZeroName() public {
        address[] memory subjects = new address[](1);
        subjects[0] = testContract;
        bytes32[] memory names = new bytes32[](1);
        names[0] = bytes32(0);
        string[] memory uris = new string[](1);
        uris[0] = documentURI;
        bytes32[] memory hashes = new bytes32[](1);
        hashes[0] = documentHash;

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IERC1643.ERC1643InvalidName.selector));
        documentEngine.batchSetDocuments(subjects, names, uris, hashes);
    }

    function testBatchRemoveRevertsOnMissingDocument() public {
        address[] memory subjects = new address[](1);
        subjects[0] = testContract;
        bytes32[] memory names = new bytes32[](1);
        names[0] = keccak256("never-set");

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(IERC1643.ERC1643MissingDocument.selector));
        documentEngine.batchRemoveDocuments(subjects, names);
    }

    /*//////////////////////////////////////////////////////////////
                        Enumeration & fuzz
    //////////////////////////////////////////////////////////////*/

    function testEnumerationAfterMixedOps() public {
        address subj = address(0xBEEF);
        bytes32 n1 = keccak256("n1");
        bytes32 n2 = keccak256("n2");
        bytes32 n3 = keccak256("n3");

        vm.startPrank(admin);
        documentEngine.setDocument(subj, n1, "u1", bytes32(0));
        documentEngine.setDocument(subj, n2, "u2", bytes32(0));
        documentEngine.setDocument(subj, n3, "u3", bytes32(0));
        assertEq(documentEngine.getAllDocuments(subj).length, 3);

        // overwrite does not add a new entry
        documentEngine.setDocument(subj, n2, "u2-updated", bytes32(0));
        assertEq(documentEngine.getAllDocuments(subj).length, 3);

        // removal shrinks the set (swap-and-pop)
        documentEngine.removeDocument(subj, n2);
        vm.stopPrank();

        bytes32[] memory names = documentEngine.getAllDocuments(subj);
        assertEq(names.length, 2);
        assertTrue(
            (names[0] == n1 && names[1] == n3) || (names[0] == n3 && names[1] == n1),
            "remaining names must be n1 and n3"
        );
    }

    function testFuzzSetGetRemoveRoundTrip(address subject, bytes32 name, string calldata uri, bytes32 hash) public {
        vm.assume(name != bytes32(0)); // the null name reverts by design
        vm.assume(subject != AddressZero); // the null subject reverts by design

        vm.prank(admin);
        documentEngine.setDocument(subject, name, uri, hash);

        IERC1643.Document memory doc = _doc(documentEngine, subject, name);
        assertEq(doc.uri, uri);
        assertEq(doc.documentHash, hash);
        assertEq(doc.lastModified, block.timestamp);

        vm.prank(admin);
        documentEngine.removeDocument(subject, name);

        doc = _doc(documentEngine, subject, name);
        assertEq(doc.uri, "");
        assertEq(doc.documentHash, "");
        assertEq(doc.lastModified, 0);
    }

    function testFuzzDocumentsAreIsolatedPerSubject(address subjectA, address subjectB, bytes32 name) public {
        vm.assume(name != bytes32(0));
        vm.assume(subjectA != subjectB);
        vm.assume(subjectA != AddressZero); // the null subject reverts by design
        // `testContract` is pre-populated in setUp; exclude it from the "untouched" subject
        vm.assume(subjectB != testContract);

        vm.prank(admin);
        documentEngine.setDocument(subjectA, name, documentURI, documentHash);

        // subjectB is unaffected
        IERC1643.Document memory docB = _doc(documentEngine, subjectB, name);
        assertEq(docB.lastModified, 0);
        assertEq(documentEngine.getAllDocuments(subjectB).length, 0);
    }
}
