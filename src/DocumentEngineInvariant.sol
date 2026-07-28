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

    // Only errors that no interface defines belong here. Every specification error is declared by
    // the interface that defines its condition, so that an ABI generated from the interface carries
    // it and a contract implementing several interfaces obtains each error exactly once — the
    // multi-subject draft's "MUST NOT declare them twice", which the compiler also enforces:
    //   - `ERC1643InvalidName()` / `ERC1643MissingDocument()` → `IERC1643` (since CMTAT v3.3.0-rc2)
    //   - `MultiDocumentInvalidSubject()`                     → `IERC1643MultiDocument`
    //   - `NotBoundToken(address)`                            → `ITokenBinding`
    //   - `TokenBindingInvalidToken()`                        → `ITokenBinding`
}
