//SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Ownable} from "OZ/access/Ownable.sol";
import {Ownable2Step} from "OZ/access/Ownable2Step.sol";
import "OZ/metatx/ERC2771Context.sol";
import "./DocumentEngineBase.sol";
import "./modules/VersionModule.sol";

/**
 * @title DocumentEngineOwnable
 * @notice Alternative deployment of the DocumentEngine that uses a single owner
 * ({Ownable2Step}) instead of role-based access control.
 * @dev Reuses the same document-management logic ({DocumentEngineBase}) and only
 * swaps the access-control implementation, illustrating the base/deployment
 * separation:
 *  - admin path (`onlyDocumentManager`): restricted to the `owner`;
 *  - bound-token path (`onlyBoundToken`): restricted to tokens the owner has
 *    bound to the engine (owner-managed allowlist, the analog of the role-based
 *    `TOKEN_CONTRACT_ROLE` binding). A bound token manages only its own documents.
 * Ownership uses the two-step transfer flow for safety, and the contract also
 * exposes its version through ERC-8303 ({VersionModule}) and wires ERC-2771.
 */
contract DocumentEngineOwnable is
    DocumentEngineBase,
    VersionModule,
    Ownable2Step,
    ERC2771Context
{
    /// @dev Tokens bound to the engine, allowed to manage their own documents.
    mapping(address => bool) private _boundTokens;

    /// @notice Emitted when a token binding is set or removed by the owner.
    event TokenBindingSet(address indexed token, bool bound);

    /// @notice Thrown when a non-bound caller uses the bound-token path.
    error NotBoundToken(address caller);

    /**
     * @param owner_ initial owner of the contract
     * @param forwarderIrrevocable address of the ERC-2771 forwarder (gasless support)
     */
    constructor(
        address owner_,
        address forwarderIrrevocable
    ) Ownable(owner_) ERC2771Context(forwarderIrrevocable) {}

    /*//////////////////////////////////////////////////////////////
                            TOKEN BINDING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Bind or unbind a token, allowing it to manage its own documents.
     * @dev Owner-managed analog of granting/revoking `TOKEN_CONTRACT_ROLE`.
     */
    function setTokenBinding(address token, bool bound) external onlyOwner {
        _boundTokens[token] = bound;
        emit TokenBindingSet(token, bound);
    }

    /// @notice Returns whether `token` is bound to the engine.
    function isBoundToken(address token) external view returns (bool) {
        return _boundTokens[token];
    }

    /*//////////////////////////////////////////////////////////////
                        ACCESS CONTROL (implementation)
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Authorization for the admin document-management path: only the owner.
     */
    function _authorizeDocumentManagement() internal view virtual override {
        _checkOwner();
    }

    /**
     * @dev Authorization for the bound-token document-management path: the
     * caller must be a token bound by the owner.
     */
    function _authorizeBoundTokenDocumentManagement()
        internal
        view
        virtual
        override
    {
        if (!_boundTokens[_msgSender()]) {
            revert NotBoundToken(_msgSender());
        }
    }

    /*//////////////////////////////////////////////////////////////
                           ERC2771
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev This surcharge is not necessary if you do not use ERC2771
     */
    function _msgSender()
        internal
        view
        override(ERC2771Context, Context)
        returns (address sender)
    {
        return ERC2771Context._msgSender();
    }

    /**
     * @dev This surcharge is not necessary if you do not use ERC2771
     */
    function _msgData()
        internal
        view
        override(ERC2771Context, Context)
        returns (bytes calldata)
    {
        return ERC2771Context._msgData();
    }

    /**
     * @dev This surcharge is not necessary if you do not use the MetaTxModule
     */
    function _contextSuffixLength()
        internal
        view
        override(ERC2771Context, Context)
        returns (uint256)
    {
        return ERC2771Context._contextSuffixLength();
    }
}
