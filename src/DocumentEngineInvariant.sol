//SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

/**
 * @title DocumentEngineInvariant
 * @notice Shared errors for the DocumentEngine, common to every deployment
 * regardless of its access-control model.
 * @dev Access-control specifics (roles, owner, ...) are intentionally NOT
 * defined here; they belong to the deployment contract (e.g. the role constants
 * live in {DocumentEngine}, the owner logic in {DocumentEngineOwnable}). This
 * contract is only ever used as a base, never deployed on its own.
 */
abstract contract DocumentEngineInvariant {
    error InvalidInputLength();
    error AdminWithAddressZeroNotAllowed();

    /// @notice Reverts when `setDocument` is called with `name == bytes32(0)`.
    /// @dev ERC-1643-recommended error name.
    error ERC1643InvalidName();

    /// @notice Reverts when `removeDocument` targets a document that does not exist.
    /// @dev ERC-1643-recommended error name.
    error ERC1643MissingDocument();
}
