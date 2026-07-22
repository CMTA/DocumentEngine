// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

/**
 * @title ITokenBinding
 * @notice Common token-binding surface shared by every DocumentEngine deployment,
 * so integrators bind, unbind and query a token the same way regardless of the
 * underlying access-control model (role-based or owner-based).
 * @dev A *bound* token is allowed to manage its own documents through the standard
 * single-argument ERC-1643 functions (`msg.sender` is the token). Binding is a
 * privileged operation; the exact authorization (a role, the owner, ...) and the
 * revert raised when a non-bound caller attempts a write are deployment-specific.
 */
interface ITokenBinding {
    /// @notice Emitted when a token is bound (`bound = true`) or unbound (`bound = false`).
    event TokenBindingSet(address indexed token, bool bound);

    /// @notice Binds `token`, allowing it to manage its own documents.
    function bindToken(address token) external;

    /// @notice Unbinds `token`.
    function unbindToken(address token) external;

    /// @notice Returns whether `token` is currently bound.
    function isTokenBound(address token) external view returns (bool);
}
