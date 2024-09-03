//SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/DocumentEngine.sol";
import "../src/DocumentEngineInvariant.sol";
import "OZ/access/AccessControl.sol";
import "CMTAT/CMTAT_STANDALONE.sol";
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
    CMTAT_STANDALONE cmtat;
    function setUp() public {
        documentEngine = new DocumentEngine(admin);
        vm.prank(admin);
        documentEngine.setDocument(
            testContract,
            documentName,
            documentURI,
            documentHash
        );

        // CMTAT
        ICMTATConstructor.ERC20Attributes
            memory erc20Attributes = ICMTATConstructor.ERC20Attributes(
                "CMTA Token",
                "CMTAT",
                0
            );
        ICMTATConstructor.BaseModuleAttributes
            memory baseModuleAttributes = ICMTATConstructor
                .BaseModuleAttributes(
                    "CMTAT_ISIN",
                    "https://cmta.ch",
                    "CMTAT_info"
                );
        ICMTATConstructor.Engine memory engines = ICMTATConstructor.Engine(
            IRuleEngine(AddressZero),
            IDebtEngine(AddressZero),
            IAuthorizationEngine(AddressZero),
            IERC1643(AddressZero)
        );
        cmtat = new CMTAT_STANDALONE(
            AddressZero,
            admin,
            erc20Attributes,
            baseModuleAttributes,
            engines
        );
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

    function testGetAllDocuments() public view {
        bytes32[] memory docs = documentEngine.getAllDocuments(testContract);
        assertEq(docs.length, 1);
        assertEq(docs[0], documentName);
    }

    function testCanReturnCMTATDocument() public {
        // Arrange
        uint256 lastModif = block.timestamp;
        vm.prank(admin);
        documentEngine.setDocument(
            address(cmtat),
            documentName,
            documentURI,
            documentHash
        );
        vm.prank(admin);
        cmtat.setDocumentEngine(documentEngine);

        // Call from CMTAT, return document
        bytes32[] memory docs = cmtat.getAllDocuments();
        assertEq(docs.length, 1);
        assertEq(docs[0], documentName);

        (string memory uri, bytes32 hash, uint256 lastModified) = cmtat
            .getDocument(documentName);
        assertEq(uri, documentURI);
        assertEq(hash, documentHash);
        assertEq(lastModif, lastModified);
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

        (string memory uri, bytes32 hash, uint256 lastModified) = documentEngine
            .getDocument(testContract, documentName);
        assertEq(uri, documentURI);
        assertEq(hash, documentHash);
        assertEq(lastModif, lastModified);
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
        (string memory uri, bytes32 hash, uint256 lastModified) = documentEngine
            .getDocument(testContract, documentName);
        assertEq(uri, documentURIV2);
        assertEq(hash, documentHashV2);
        assertEq(lastModif, lastModified);
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
        (
            string memory uri1,
            bytes32 hash1,
            uint256 lastModified1
        ) = documentEngine.getDocument(testContract, documentName);
        assertEq(uri1, documentURI);
        assertEq(hash1, documentHash);
        assertEq(lastModified1, block.timestamp);

        // Check the second document
        (
            string memory uri2,
            bytes32 hash2,
            uint256 lastModified2
        ) = documentEngine.getDocument(anotherSmartContract, names[1]);
        assertEq(uri2, uris[1]);
        assertEq(hash2, hashes[1]);
        assertEq(lastModified2, block.timestamp);
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
        (
            string memory uri1,
            bytes32 hash1,
            uint256 lastModified1
        ) = documentEngine.getDocument(testContract, documentName);
        assertEq(uri1, documentURI);
        assertEq(hash1, documentHash);
        assertEq(lastModified1, block.timestamp);

        // Check the second document
        (
            string memory uri2,
            bytes32 hash2,
            uint256 lastModified2
        ) = documentEngine.getDocument(testContract, names[1]);
        assertEq(uri2, uris[1]);
        assertEq(hash2, hashes[1]);
        assertEq(lastModified2, block.timestamp);
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
        (string memory uri, bytes32 hash, uint256 lastModified) = documentEngine
            .getDocument(testContract, documentName);
        assertEq(uri, "");
        assertEq(hash, "");
        assertEq(lastModified, 0);
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
        (string memory uri, bytes32 hash, uint256 lastModified) = documentEngine
            .getDocument(testContract, documentName);
        assertEq(uri, "");
        assertEq(hash, "");
        assertEq(lastModified, 0);
        bytes32[] memory docs = documentEngine.getAllDocuments(testContract);
        assertEq(docs.length, 0);

        (
            string memory uri2,
            bytes32 hash2,
            uint256 lastModified2
        ) = documentEngine.getDocument(anotherSmartContract, names[1]);
        assertEq(uri2, "");
        assertEq(hash2, "");
        assertEq(lastModified2, 0);
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
        (
            string memory uri1,
            bytes32 hash1,
            uint256 lastModified1
        ) = documentEngine.getDocument(testContract, documentName);
        assertEq(uri1, documentURI);
        assertEq(hash1, documentHash);
        assertEq(lastModified1, block.timestamp);

        // Check the second document
        (
            string memory uri2,
            bytes32 hash2,
            uint256 lastModified2
        ) = documentEngine.getDocument(testContract, names[1]);
        assertEq(uri2, uris[1]);
        assertEq(hash2, hashes[1]);
        assertEq(lastModified2, block.timestamp);
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
        (string memory uri, bytes32 hash, uint256 lastModified) = documentEngine
            .getDocument(testContract, documentName);
        assertEq(uri, "");
        assertEq(hash, "");
        assertEq(lastModified, 0);
        bytes32[] memory docs = documentEngine.getAllDocuments(testContract);
        assertEq(docs.length, 0);
        (
            string memory uri2,
            bytes32 hash2,
            uint256 lastModified2
        ) = documentEngine.getDocument(testContract, names[1]);
        assertEq(uri2, "");
        assertEq(hash2, "");
        assertEq(lastModified2, 0);
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
