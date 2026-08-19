//SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import {Script, console2} from "forge-std/Script.sol";
import {DocumentEngine} from "../src/DocumentEngine.sol";

/**
 * @title DeployDocumentEngine
 * @notice Deploys the role-based {DocumentEngine} (AccessControlEnumerable).
 * @dev Configuration via environment variables:
 *  - `DOCUMENT_ENGINE_ADMIN`     : address granted `DEFAULT_ADMIN_ROLE` (default: `msg.sender`)
 *  - `DOCUMENT_ENGINE_FORWARDER` : ERC-2771 trusted forwarder, `address(0)` disables gasless (default: `address(0)`)
 *
 * Usage:
 *   forge script script/DeployDocumentEngine.s.sol \
 *     --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
 *
 * Warning: the environment variables above and passing a raw key with
 * `--private-key` are for local testing only, not for production. For production
 * use a secure signing method (encrypted keystore, hardware wallet, ...) as
 * described in the Foundry Key Management documentation (getfoundry.sh).
 */
contract DeployDocumentEngine is Script {
    /**
     * @notice Reads the deployment configuration from the environment and deploys the engine.
     * @return documentEngine The freshly deployed {DocumentEngine}.
     */
    function run() external returns (DocumentEngine documentEngine) {
        address admin = vm.envOr("DOCUMENT_ENGINE_ADMIN", msg.sender);
        address forwarder = vm.envOr("DOCUMENT_ENGINE_FORWARDER", address(0));

        documentEngine = deploy(admin, forwarder);

        console2.log("DocumentEngine deployed at:", address(documentEngine));
        console2.log("  admin            :", admin);
        console2.log("  trusted forwarder:", forwarder);
        console2.log("  version          :", documentEngine.version());
    }

    /**
     * @notice Deploys the engine with an explicit configuration.
     * @dev Broadcasted deployment, isolated from env parsing so it can be reused/tested.
     * @param admin address granted `DEFAULT_ADMIN_ROLE`
     * @param forwarder ERC-2771 trusted forwarder; `address(0)` disables gasless support
     * @return documentEngine The freshly deployed {DocumentEngine}.
     */
    function deploy(address admin, address forwarder) public returns (DocumentEngine documentEngine) {
        vm.startBroadcast();
        documentEngine = new DocumentEngine(admin, forwarder);
        vm.stopBroadcast();
    }
}
