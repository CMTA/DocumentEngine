//SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import "OZ/access/extensions/AccessControlEnumerable.sol";
import {IAccessControl} from "OZ/access/IAccessControl.sol";
import {IERC1643} from "CMTAT/interfaces/tokenization/draft-IERC1643.sol";
import {IERC1643MultiDocument} from "./interfaces/IERC1643MultiDocument.sol";
import "OZ/metatx/ERC2771Context.sol";
import "./DocumentEngineBase.sol";
import "./modules/VersionModule.sol";

/**
 * @title DocumentEngine
 * @notice Deployment contract to manage documents on-chain through ERC-1643.
 * @dev Wires the document-management logic ({DocumentEngineBase}) with a
 * concrete access-control implementation. The authorization hooks are defined
 * here (role-based `AccessControlEnumerable`, which additionally allows
 * enumerating role members), keeping the access control separate from the
 * document-management logic (CMTAT / CMTA-RuleEngine pattern). The contract
 * version is exposed through the {VersionModule} (ERC-8303), and it also wires
 * the ERC-2771 (gasless) meta-transaction support.
 */
contract DocumentEngine is
    DocumentEngineBase,
    VersionModule,
    AccessControlEnumerable,
    ERC2771Context
{
    // Role allowed to manage documents on behalf of any smart contract (admin path)
    bytes32 public constant DOCUMENT_MANAGER_ROLE =
        keccak256("DOCUMENT_MANAGER_ROLE");

    // Role granted to a token bound to the engine, allowing it to manage its own
    // documents through the standard ERC-1643 functions (msg.sender is the token).
    // Mirrors the RuleEngine binding pattern (CMTA/RuleEngine `TOKEN_CONTRACT_ROLE`).
    bytes32 public constant TOKEN_CONTRACT_ROLE =
        keccak256("TOKEN_CONTRACT_ROLE");

    // Constructor to initialize the admin role
    constructor(
        address admin,
        address forwarderIrrevocable
    ) ERC2771Context(forwarderIrrevocable) {
        if (admin == address(0)) {
            revert AdminWithAddressZeroNotAllowed();
        }
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /*//////////////////////////////////////////////////////////////
                        ACCESS CONTROL (implementation)
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Authorization for the admin document-management path.
     * The caller must hold `DOCUMENT_MANAGER_ROLE`. Override to customize.
     */
    function _authorizeDocumentManagement() internal view virtual override {
        _checkRole(DOCUMENT_MANAGER_ROLE);
    }

    /**
     * @dev Authorization for the bound-token document-management path.
     * The caller must hold `TOKEN_CONTRACT_ROLE` (the RuleEngine binding
     * pattern). Override to customize.
     */
    function _authorizeBoundTokenDocumentManagement()
        internal
        view
        virtual
        override
    {
        _checkRole(TOKEN_CONTRACT_ROLE);
    }

    /*
     * @dev Returns `true` if `account` has been granted `role`.
     */
    function hasRole(
        bytes32 role,
        address account
    ) public view virtual override(AccessControl, IAccessControl) returns (bool) {
        // The Default Admin has all roles
        if (super.hasRole(DEFAULT_ADMIN_ROLE, account)) {
            return true;
        }
        return super.hasRole(role, account);
    }

    /**
     * @dev ERC-165 discovery: advertises ERC-1643 and its multi-token extension,
     * plus the version module (ERC-8303) and `AccessControlEnumerable`.
     * The engine implements the base single-argument functions, so it advertises
     * `type(IERC1643).interfaceId`; it also implements the address-scoped
     * extension, so it advertises `type(IERC1643MultiDocument).interfaceId`.
     * See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    )
        public
        view
        virtual
        override(VersionModule, AccessControlEnumerable)
        returns (bool)
    {
        return
            interfaceId == type(IERC1643).interfaceId ||
            interfaceId == type(IERC1643MultiDocument).interfaceId ||
            super.supportsInterface(interfaceId);
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
