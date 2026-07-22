//SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {DeployDocumentEngine} from "../script/DeployDocumentEngine.s.sol";
import {DeployDocumentEngineOwnable} from "../script/DeployDocumentEngineOwnable.s.sol";
import {DocumentEngine} from "../src/DocumentEngine.sol";
import {DocumentEngineOwnable} from "../src/DocumentEngineOwnable.sol";

contract DeployDocumentEngineTest is Test {
    DeployDocumentEngine internal deployer;
    address internal admin = makeAddr("admin");
    address internal forwarder = makeAddr("forwarder");

    function setUp() public {
        deployer = new DeployDocumentEngine();
    }

    function testDeploySetsAdminAndForwarder() public {
        DocumentEngine engine = deployer.deploy(admin, forwarder);

        assertTrue(engine.hasRole(engine.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(engine.isTrustedForwarder(forwarder));
        assertEq(engine.version(), "0.4.0");
    }

    function testDeployWithoutForwarder() public {
        DocumentEngine engine = deployer.deploy(admin, address(0));

        assertTrue(engine.hasRole(engine.DEFAULT_ADMIN_ROLE(), admin));
        assertFalse(engine.isTrustedForwarder(forwarder));
    }

    function testRunReadsEnv() public {
        vm.setEnv("DOCUMENT_ENGINE_ADMIN", vm.toString(admin));
        vm.setEnv("DOCUMENT_ENGINE_FORWARDER", vm.toString(forwarder));

        DocumentEngine engine = deployer.run();

        assertTrue(engine.hasRole(engine.DEFAULT_ADMIN_ROLE(), admin));
        assertTrue(engine.isTrustedForwarder(forwarder));
    }
}

contract DeployDocumentEngineOwnableTest is Test {
    DeployDocumentEngineOwnable internal deployer;
    address internal owner = makeAddr("owner");
    address internal forwarder = makeAddr("forwarder");

    function setUp() public {
        deployer = new DeployDocumentEngineOwnable();
    }

    function testDeploySetsOwnerAndForwarder() public {
        DocumentEngineOwnable engine = deployer.deploy(owner, forwarder);

        assertEq(engine.owner(), owner);
        assertTrue(engine.isTrustedForwarder(forwarder));
        assertEq(engine.version(), "0.4.0");
    }

    function testDeployWithoutForwarder() public {
        DocumentEngineOwnable engine = deployer.deploy(owner, address(0));

        assertEq(engine.owner(), owner);
        assertFalse(engine.isTrustedForwarder(forwarder));
    }

    function testRunReadsEnv() public {
        vm.setEnv("DOCUMENT_ENGINE_OWNER", vm.toString(owner));
        vm.setEnv("DOCUMENT_ENGINE_FORWARDER", vm.toString(forwarder));

        DocumentEngineOwnable engine = deployer.run();

        assertEq(engine.owner(), owner);
        assertTrue(engine.isTrustedForwarder(forwarder));
    }
}
