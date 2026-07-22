// SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {DocumentEngineBase} from "../DocumentEngineBase.sol";
import {ITokenBinding} from "../interfaces/ITokenBinding.sol";

/**
 * @title TokenBindingModule
 * @notice Shared token-binding registry (an allowlist) implementing {ITokenBinding},
 * used by every DocumentEngine deployment so binding behaves identically — same
 * functions, same event, same revert — regardless of the access-control model.
 * @dev A *bound* token may manage its own documents through the standard
 * single-argument ERC-1643 functions (`msg.sender` is the token). This module:
 *  - stores the allowlist and implements `bindToken` / `unbindToken` / `isTokenBound`;
 *  - wires the base bound-token hook ({_authorizeBoundTokenDocumentManagement}) to
 *    the allowlist ({_checkTokenBound});
 *  - gates binding management with the deployment's document-management
 *    authorization ({_authorizeDocumentManagement}), so whoever may manage
 *    documents may also decide bindings. It is therefore access-control agnostic:
 *    the deployment only implements {_authorizeDocumentManagement}.
 */
abstract contract TokenBindingModule is DocumentEngineBase, ITokenBinding {
    /// @dev Tokens bound to the engine, allowed to manage their own documents.
    mapping(address => bool) private _boundTokens;

    /// @notice Thrown when a non-bound caller attempts a bound-token operation.
    error NotBoundToken(address caller);

    /**
     * @inheritdoc ITokenBinding
     * @dev Authorized by the deployment's document-management check.
     */
    function bindToken(address token) external virtual override {
        _authorizeDocumentManagement();
        _boundTokens[token] = true;
        emit TokenBindingSet(token, true);
    }

    /**
     * @inheritdoc ITokenBinding
     * @dev Authorized by the deployment's document-management check.
     */
    function unbindToken(address token) external virtual override {
        _authorizeDocumentManagement();
        _boundTokens[token] = false;
        emit TokenBindingSet(token, false);
    }

    /// @inheritdoc ITokenBinding
    function isTokenBound(
        address token
    ) public view virtual override returns (bool) {
        return _boundTokens[token];
    }

    /**
     * @dev Bound-token document-management authorization: the caller
     * (`_msgSender()`) must be a bound token.
     */
    function _authorizeBoundTokenDocumentManagement()
        internal
        view
        virtual
        override
    {
        _checkTokenBound();
    }

    /// @dev Reverts {NotBoundToken} if the caller (`_msgSender()`) is not bound.
    function _checkTokenBound() internal view {
        if (!_boundTokens[_msgSender()]) {
            revert NotBoundToken(_msgSender());
        }
    }
}
