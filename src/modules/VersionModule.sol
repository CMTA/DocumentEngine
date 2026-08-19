// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import {ERC165} from "OZ/utils/introspection/ERC165.sol";
import {IERC8303} from "../interfaces/IERC8303.sol";

/**
 * @title VersionModule
 * @notice Exposes the current contract version through ERC-8303 (`version()`),
 * with optional ERC-165 interface discovery.
 * @dev Implements ERC-8303 (Draft). The version string is defined here so the
 * version concern is isolated in a dedicated module (CMTAT pattern). A deployment
 * contract that also implements ERC-165 must combine this module's
 * {supportsInterface} with the others it inherits.
 */
abstract contract VersionModule is IERC8303, ERC165 {
    /**
     * @notice Get the current version of the smart contract.
     * @dev Follows Semantic Versioning 2.0.0 (`MAJOR.MINOR.PATCH`).
     */
    string public constant VERSION = "0.4.0";

    /**
     * @inheritdoc IERC8303
     */
    function version() public view virtual override(IERC8303) returns (string memory version_) {
        return VERSION;
    }

    /**
     * @notice Returns whether this contract implements `interfaceId`.
     * @dev Advertises ERC-8303 support (interface id `0x54fd4d50`).
     * See {IERC165-supportsInterface}.
     * @param interfaceId The ERC-165 interface identifier to query.
     * @return True when `interfaceId` is ERC-8303 or is supported by a base contract.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
        return interfaceId == type(IERC8303).interfaceId || super.supportsInterface(interfaceId);
    }
}
