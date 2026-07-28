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

    /// @notice Reverts when a document is set for the null `subject` (`address(0)`).
    /// @dev Multi-token extension guard. The multi-subject draft names this condition
    /// `MultiDocumentInvalidSubject()`; see
    /// `doc/ERCSpecification/erc-draft_multi_document_management.md` and `ERC_RESULT.md` §4.4.
    error ERC1643InvalidSubject();

    // `ERC1643InvalidName()` and `ERC1643MissingDocument()` are NOT declared here: since
    // CMTAT v3.3.0-rc2 they are declared by `IERC1643` itself, and the multi-subject draft
    // requires a contract implementing both interfaces to obtain each error exactly once
    // ("MUST NOT declare them twice"). Re-declaring them is a compile error.
}
