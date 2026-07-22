//SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/DocumentEngine.sol";
import "../src/DocumentEngineInvariant.sol";
import "OZ/access/AccessControl.sol";
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
    constructor(
        address admin,
        address forwarder
    ) DocumentEngine(admin, forwarder) {}

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
    address AddressZero = address(0);

    function setUp() public {
        documentEngine = new DocumentEngine(admin, AddressZero);
        vm.prank(admin);
        documentEngine.setDocument(
            testContract,
            documentName,
            documentURI,
            documentHash
        );
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
        vm.expectRevert(
            abi.encodeWithSelector(AdminWithAddressZeroNotAllowed.selector)
        );
        documentEngine = new DocumentEngine(AddressZero, forwarder);
    }

    /*//////////////////////////////////////////////////////////////
              Access control
    ///////////////////////////////////////*/

    function testCannotNonAdminSetDocument() public {
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                attacker,
                DOCUMENT_MANAGER_ROLE
            )
        );
        documentEngine.setDocument(
            testContract,
            documentName,
            documentURI,
            documentHash
        );
    }

    function testCannotNonAdminRemoveDocument() public {
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                attacker,
                DOCUMENT_MANAGER_ROLE
            )
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
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                attacker,
                DOCUMENT_MANAGER_ROLE
            )
        );
        documentEngine.batchSetDocuments(smartContracts, names, uris, hashes);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                attacker,
                DOCUMENT_MANAGER_ROLE
            )
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
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                attacker,
                DOCUMENT_MANAGER_ROLE
            )
        );
        documentEngine.batchRemoveDocuments(smartContracts, names);

        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                attacker,
                DOCUMENT_MANAGER_ROLE
            )
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
        documentEngine.setDocument(
            address(cmtat),
            documentName,
            documentURI,
            documentHash
        );

        // Call from CMTAT, forwarded to the engine
        bytes32[] memory docs = cmtat.getAllDocuments();
        assertEq(docs.length, 1);
        assertEq(docs[0], documentName);

        IERC1643.Document memory doc = cmtat.getDocument(documentName);
        assertEq(doc.uri, documentURI);
        assertEq(doc.documentHash, documentHash);
        assertEq(doc.lastModified, lastModif);
    }

    /*//////////////////////////////////////////////////////////////
            Bound token (RuleEngine binding pattern, TOKEN_CONTRACT_ROLE)
    //////////////////////////////////////////////////////////////*/

    function testBoundTokenCanManageOwnDocument() public {
        // Bind the token to the engine
        vm.prank(admin);
        documentEngine.grantRole(TOKEN_CONTRACT_ROLE, testContract);

        // The bound token manages its own document namespace (msg.sender)
        bytes32 selfName = keccak256("self-doc");
        string memory selfURI = "https://example.com/self";
        bytes32 selfHash = keccak256("selfHash");

        vm.prank(testContract);
        documentEngine.setDocument(selfName, selfURI, selfHash);

        IERC1643.Document memory doc = documentEngine.getDocument(
            testContract,
            selfName
        );
        assertEq(doc.uri, selfURI);
        assertEq(doc.documentHash, selfHash);
        assertEq(doc.lastModified, block.timestamp);

        // and can remove it
        vm.prank(testContract);
        documentEngine.removeDocument(selfName);
        doc = documentEngine.getDocument(testContract, selfName);
        assertEq(doc.uri, "");
        assertEq(doc.documentHash, "");
        assertEq(doc.lastModified, 0);
    }

    function testUnboundContractCannotSetOwnDocument() public {
        bytes32 selfName = keccak256("self-doc");
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                attacker,
                TOKEN_CONTRACT_ROLE
            )
        );
        documentEngine.setDocument(selfName, documentURI, documentHash);
    }

    function testUnboundContractCannotRemoveOwnDocument() public {
        bytes32 selfName = keccak256("self-doc");
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                AccessControlUnauthorizedAccount.selector,
                attacker,
                TOKEN_CONTRACT_ROLE
            )
        );
        documentEngine.removeDocument(selfName);
    }

    /*//////////////////////////////////////////////////////////////
            Flexible access control (overridable authorization hook)
    //////////////////////////////////////////////////////////////*/

    function testFlexibleAuthorizationCanBeOverridden() public {
        OpenDocumentEngine openEngine = new OpenDocumentEngine(
            admin,
            AddressZero
        );

        // attacker holds no role, yet can manage documents because the
        // authorization hook was overridden to allow anyone.
        vm.prank(attacker);
        openEngine.setDocument(
            testContract,
            documentName,
            documentURI,
            documentHash
        );

        IERC1643.Document memory doc = openEngine.getDocument(
            testContract,
            documentName
        );
        assertEq(doc.uri, documentURI);
        assertEq(doc.documentHash, documentHash);
    }

    /*//////////////////////////////////////////////////////////////
                        Set documents
    //////////////////////////////////////////////////////////////*/
    function testAdminCanSetDocument() public {
        uint256 lastModif = block.timestamp;
        vm.prank(admin);
        documentEngine.setDocument(
            testContract,
            documentName,
            documentURI,
            documentHash
        );

        IERC1643.Document memory doc = documentEngine.getDocument(
            testContract,
            documentName
        );
        assertEq(doc.uri, documentURI);
        assertEq(doc.documentHash, documentHash);
        assertEq(doc.lastModified, lastModif);
    }

    function testAdminCanSetDocumentAgain() public {
        // Arrange
        vm.prank(admin);
        documentEngine.setDocument(
            testContract,
            documentName,
            documentURI,
            documentHash
        );
        bytes32[] memory docs = documentEngine.getAllDocuments(testContract);
        assertEq(docs.length, 1);
        assertEq(docs[0], documentName);
        // Act
        uint256 lastModif = block.timestamp;
        string memory documentURIV2 = "https://example.com/doc1";
        bytes32 documentHashV2 = keccak256("doc1Hash");
        vm.prank(admin);
        documentEngine.setDocument(
            testContract,
            documentName,
            documentURIV2,
            documentHashV2
        );

        // Assert
        IERC1643.Document memory doc = documentEngine.getDocument(
            testContract,
            documentName
        );
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
        IERC1643.Document memory doc1 = documentEngine.getDocument(
            testContract,
            documentName
        );
        assertEq(doc1.uri, documentURI);
        assertEq(doc1.documentHash, documentHash);
        assertEq(doc1.lastModified, block.timestamp);

        // Check the second document
        IERC1643.Document memory doc2 = documentEngine.getDocument(
            anotherSmartContract,
            names[1]
        );
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
        IERC1643.Document memory doc1 = documentEngine.getDocument(
            testContract,
            documentName
        );
        assertEq(doc1.uri, documentURI);
        assertEq(doc1.documentHash, documentHash);
        assertEq(doc1.lastModified, block.timestamp);

        // Check the second document
        IERC1643.Document memory doc2 = documentEngine.getDocument(
            testContract,
            names[1]
        );
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
        IERC1643.Document memory doc = documentEngine.getDocument(
            testContract,
            documentName
        );
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
        IERC1643.Document memory doc = documentEngine.getDocument(
            testContract,
            documentName
        );
        assertEq(doc.uri, "");
        assertEq(doc.documentHash, "");
        assertEq(doc.lastModified, 0);
        bytes32[] memory docs = documentEngine.getAllDocuments(testContract);
        assertEq(docs.length, 0);

        IERC1643.Document memory doc2 = documentEngine.getDocument(
            anotherSmartContract,
            names[1]
        );
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
        IERC1643.Document memory doc1 = documentEngine.getDocument(
            testContract,
            documentName
        );
        assertEq(doc1.uri, documentURI);
        assertEq(doc1.documentHash, documentHash);
        assertEq(doc1.lastModified, block.timestamp);

        // Check the second document
        IERC1643.Document memory doc2 = documentEngine.getDocument(
            testContract,
            names[1]
        );
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
        IERC1643.Document memory doc = documentEngine.getDocument(
            testContract,
            documentName
        );
        assertEq(doc.uri, "");
        assertEq(doc.documentHash, "");
        assertEq(doc.lastModified, 0);
        bytes32[] memory docs = documentEngine.getAllDocuments(testContract);
        assertEq(docs.length, 0);
        IERC1643.Document memory doc2 = documentEngine.getDocument(
            testContract,
            names[1]
        );
        assertEq(doc2.uri, "");
        assertEq(doc2.documentHash, "");
        assertEq(doc2.lastModified, 0);
    }

    function testCannotRemoveBatchDocumentIfEmptyLengthForOnlyOneContract()
        public
    {
        bytes32[] memory names = new bytes32[](0);

        vm.expectRevert(abi.encodeWithSelector(InvalidInputLength.selector));
        vm.prank(admin);
        documentEngine.batchRemoveDocuments(testContract, names);
    }
}
