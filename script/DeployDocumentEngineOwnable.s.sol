//SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {DocumentEngineOwnable} from "../src/DocumentEngineOwnable.sol";

/**
 * @title DeployDocumentEngineOwnable
 * @notice Deploys the owner-based {DocumentEngineOwnable} (Ownable2Step).
 * @dev Configuration via environment variables:
 *  - `DOCUMENT_ENGINE_OWNER`     : initial owner (default: `msg.sender`)
 *  - `DOCUMENT_ENGINE_FORWARDER` : ERC-2771 trusted forwarder, `address(0)` disables gasless (default: `address(0)`)
 *
 * Usage:
 *   forge script script/DeployDocumentEngineOwnable.s.sol \
 *     --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
 *
 * Warning: the environment variables above and passing a raw key with
 * `--private-key` are for local testing only, not for production. For production
 * use a secure signing method (encrypted keystore, hardware wallet, ...) as
 * described in the Foundry Key Management documentation (getfoundry.sh).
 */
contract DeployDocumentEngineOwnable is Script {
    /**
     * @notice Reads the deployment configuration from the environment and deploys the engine.
     * @return documentEngine The freshly deployed {DocumentEngineOwnable}.
     */
    function run() external returns (DocumentEngineOwnable documentEngine) {
        address owner = vm.envOr("DOCUMENT_ENGINE_OWNER", msg.sender);
        address forwarder = vm.envOr("DOCUMENT_ENGINE_FORWARDER", address(0));

        documentEngine = deploy(owner, forwarder);

        console2.log("DocumentEngineOwnable deployed at:", address(documentEngine));
        console2.log("  owner            :", owner);
        console2.log("  trusted forwarder:", forwarder);
        console2.log("  version          :", documentEngine.version());
    }

    /**
     * @notice Deploys the engine with an explicit configuration.
     * @dev Broadcasted deployment, isolated from env parsing so it can be reused/tested.
     * @param owner initial owner of the contract
     * @param forwarder ERC-2771 trusted forwarder; `address(0)` disables gasless support
     * @return documentEngine The freshly deployed {DocumentEngineOwnable}.
     */
    function deploy(address owner, address forwarder) public returns (DocumentEngineOwnable documentEngine) {
        vm.startBroadcast();
        documentEngine = new DocumentEngineOwnable(owner, forwarder);
        vm.stopBroadcast();
    }
}
