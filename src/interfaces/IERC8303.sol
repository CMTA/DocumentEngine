// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

/**
 * @title IERC8303 - Contract Version
 * @notice Interface for exposing a contract implementation version string.
 * @dev ERC-8303 (Draft) — https://ethereum-magicians.org/t/erc-8303-contract-version/28795
 * The interface id is `0x54fd4d50` (the `version()` selector).
 */
interface IERC8303 {
    /// @notice Returns the implementation version string.
    /// @return The version value, for example "1.0.0".
    function version() external view returns (string memory);
}
