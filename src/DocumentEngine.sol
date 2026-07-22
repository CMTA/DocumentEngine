//SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import "OZ/access/AccessControl.sol";
import "OZ/metatx/ERC2771Context.sol";
import "./DocumentEngineBase.sol";
import "./modules/VersionModule.sol";

/**
 * @title DocumentEngine
 * @notice Deployment contract to manage documents on-chain through ERC-1643.
 * @dev Wires the document-management logic ({DocumentEngineBase}) with a
 * concrete access-control implementation. The authorization hooks are defined
 * here (role-based `AccessControl`), keeping the access control separate from
 * the document-management logic (CMTAT / CMTA-RuleEngine pattern). The contract
 * version is exposed through the {VersionModule} (ERC-8303), and it also wires
 * the ERC-2771 (gasless) meta-transaction support.
 */
contract DocumentEngine is
    DocumentEngineBase,
    VersionModule,
    AccessControl,
    ERC2771Context
{
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
    ) public view virtual override returns (bool) {
        // The Default Admin has all roles
        if (AccessControl.hasRole(DEFAULT_ADMIN_ROLE, account)) {
            return true;
        }
        return AccessControl.hasRole(role, account);
    }

    /**
     * @dev Combines the ERC-165 interface discovery of the version module
     * (ERC-8303) with `AccessControl`. See {IERC165-supportsInterface}.
     */
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(VersionModule, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
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
