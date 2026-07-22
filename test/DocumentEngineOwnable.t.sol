//SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/DocumentEngineOwnable.sol";
import {Ownable} from "OZ/access/Ownable.sol";
import {IAccessControl} from "OZ/access/IAccessControl.sol";
import {IERC165} from "OZ/utils/introspection/IERC165.sol";
import {IERC8303} from "../src/interfaces/IERC8303.sol";
import {IERC1643} from "CMTAT/interfaces/tokenization/draft-IERC1643.sol";
import {IERC1643MultiDocument} from "../src/interfaces/IERC1643MultiDocument.sol";
import {ITokenBinding} from "../src/interfaces/ITokenBinding.sol";
import {TokenBindingModule} from "../src/modules/TokenBindingModule.sol";

contract DocumentEngineOwnableTest is Test {
    DocumentEngineOwnable public engine;
    address public owner = address(0x1);
    address public newOwner = address(0x2);
    address public attacker = address(0x3);
    address private testContract = address(0x4);
    bytes32 public documentName = keccak256("doc1");
    string public documentURI = "https://example.com/doc1";
    bytes32 public documentHash = keccak256("doc1Hash");
    address AddressZero = address(0);

    function setUp() public {
        engine = new DocumentEngineOwnable(owner, AddressZero);
    }

    /* ============ DEPLOYMENT ============ */

    function testDeploySetsOwner() public {
        assertEq(engine.owner(), owner);
    }

    function testDeployRevertsWithZeroOwner() public {
        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, AddressZero)
        );
        new DocumentEngineOwnable(AddressZero, AddressZero);
    }

    /* ============ ADMIN PATH (owner) ============ */

    function testOwnerCanSetAndRemoveDocument() public {
        vm.prank(owner);
        engine.setDocument(testContract, documentName, documentURI, documentHash);

        IERC1643.Document memory doc = engine.getDocument(
            testContract,
            documentName
        );
        assertEq(doc.uri, documentURI);
        assertEq(doc.documentHash, documentHash);
        assertEq(doc.lastModified, block.timestamp);

        vm.prank(owner);
        engine.removeDocument(testContract, documentName);
        doc = engine.getDocument(testContract, documentName);
        assertEq(doc.lastModified, 0);
    }

    function testNonOwnerCannotSetDocument() public {
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                attacker
            )
        );
        engine.setDocument(testContract, documentName, documentURI, documentHash);
    }

    /* ============ BOUND-TOKEN PATH ============ */

    function testOwnerCanBindToken() public {
        vm.prank(owner);
        engine.bindToken(testContract);
        assertTrue(engine.isTokenBound(testContract));
    }

    function testNonOwnerCannotBindToken() public {
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                attacker
            )
        );
        engine.bindToken(testContract);
    }

    function testBoundTokenCanManageOwnDocument() public {
        vm.prank(owner);
        engine.bindToken(testContract);

        vm.prank(testContract);
        engine.setDocument(documentName, documentURI, documentHash);

        IERC1643.Document memory doc = engine.getDocument(
            testContract,
            documentName
        );
        assertEq(doc.uri, documentURI);

        vm.prank(testContract);
        engine.removeDocument(documentName);
        doc = engine.getDocument(testContract, documentName);
        assertEq(doc.lastModified, 0);
    }

    function testUnbindTokenRevokesSelfManagement() public {
        vm.prank(owner);
        engine.bindToken(testContract);
        assertTrue(engine.isTokenBound(testContract));

        vm.prank(owner);
        engine.unbindToken(testContract);
        assertFalse(engine.isTokenBound(testContract));

        // once unbound, the token can no longer self-manage
        vm.prank(testContract);
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenBindingModule.NotBoundToken.selector,
                testContract
            )
        );
        engine.setDocument(documentName, documentURI, documentHash);
    }

    function testUnboundTokenCannotSelfManage() public {
        vm.prank(attacker);
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenBindingModule.NotBoundToken.selector,
                attacker
            )
        );
        engine.setDocument(documentName, documentURI, documentHash);
    }

    /* ============ TWO-STEP OWNERSHIP ============ */

    function testTwoStepOwnershipTransfer() public {
        vm.prank(owner);
        engine.transferOwnership(newOwner);
        // ownership not transferred until accepted
        assertEq(engine.owner(), owner);
        assertEq(engine.pendingOwner(), newOwner);

        vm.prank(newOwner);
        engine.acceptOwnership();
        assertEq(engine.owner(), newOwner);
        assertEq(engine.pendingOwner(), AddressZero);
    }

    /* ============ VERSION (ERC-8303) ============ */

    function testVersionAndInterface() public {
        assertEq(engine.version(), "0.4.0");
        assertTrue(engine.supportsInterface(type(IERC8303).interfaceId));
        assertTrue(engine.supportsInterface(type(IERC165).interfaceId));
        assertTrue(engine.supportsInterface(type(IERC1643).interfaceId));
        assertTrue(
            engine.supportsInterface(type(IERC1643MultiDocument).interfaceId)
        );
        assertTrue(engine.supportsInterface(type(ITokenBinding).interfaceId));
        // no role-based access control here
        assertFalse(engine.supportsInterface(type(IAccessControl).interfaceId));
        assertFalse(engine.supportsInterface(bytes4(0xffffffff)));
    }
}
