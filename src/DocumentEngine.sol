//SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import {AccessControl} from "OZ/access/AccessControl.sol";
import {AccessControlEnumerable} from "OZ/access/extensions/AccessControlEnumerable.sol";
import {IAccessControl} from "OZ/access/IAccessControl.sol";
import {Context} from "OZ/utils/Context.sol";
import {ERC2771Context} from "OZ/metatx/ERC2771Context.sol";
import {IERC1643} from "CMTAT/interfaces/tokenization/draft-IERC1643.sol";
import {IERC1643MultiDocument} from "./interfaces/IERC1643MultiDocument.sol";
import {ITokenBinding} from "./interfaces/ITokenBinding.sol";
import {TokenBindingModule} from "./modules/TokenBindingModule.sol";
import {VersionModule} from "./modules/VersionModule.sol";

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
contract DocumentEngine is TokenBindingModule, VersionModule, AccessControlEnumerable, ERC2771Context {
    /**
     * @notice Role allowed to manage documents on behalf of any smart contract, and to
     * bind/unbind tokens (admin path).
     * @dev Token binding uses the shared allowlist in {TokenBindingModule}, not a dedicated role.
     */
    bytes32 public constant DOCUMENT_MANAGER_ROLE = keccak256("DOCUMENT_MANAGER_ROLE");

    /**
     * @notice Deploys the engine and grants `admin` the default admin role.
     * @param admin address granted `DEFAULT_ADMIN_ROLE`; must not be the null address
     * @param forwarderIrrevocable address of the ERC-2771 forwarder (gasless support)
     */
    constructor(address admin, address forwarderIrrevocable) ERC2771Context(forwarderIrrevocable) {
        if (admin == address(0)) {
            revert AdminWithAddressZeroNotAllowed();
        }
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
    }

    /*//////////////////////////////////////////////////////////////
                        ACCESS CONTROL (public surface)
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns whether `account` holds `role`.
     * @dev Returns `true` if `account` has been granted `role`. The default admin
     * (`DEFAULT_ADMIN_ROLE`) is treated as holding **every** role.
     *
     * Note: this virtual "admin has all roles" behavior is NOT reflected by
     * {AccessControlEnumerable} enumeration. `getRoleMember` / `getRoleMemberCount`
     * report only explicit grants, so a `DEFAULT_ADMIN_ROLE` holder satisfies
     * `hasRole(anyRole, admin)` yet does not appear in `getRoleMember(anyRole, ...)`.
     *
     * WARNING: the same short-circuit makes a role **unrevokable from the default admin**.
     * `revokeRole(someRole, admin)` succeeds and emits `RoleRevoked` — the explicit grant is
     * genuinely removed, and `getRoleMemberCount` drops — but this function still answers
     * `true`, so the admin keeps the access the caller believed it had just removed. Only
     * revoking `DEFAULT_ADMIN_ROLE` itself actually withdraws it. This is inherent to the
     * "admin has all roles" model rather than a defect (an admin can always re-grant itself
     * any role), but the success of the call is misleading. Pinned by
     * `testRevokingRoleFromDefaultAdminDoesNotRemoveAccess`.
     * @param role The role identifier to check.
     * @param account The account to check.
     * @return True when `account` holds `role`, or holds `DEFAULT_ADMIN_ROLE`.
     */
    function hasRole(bytes32 role, address account)
        public
        view
        virtual
        override(AccessControl, IAccessControl)
        returns (bool)
    {
        // The Default Admin has all roles
        if (super.hasRole(DEFAULT_ADMIN_ROLE, account)) {
            return true;
        }
        return super.hasRole(role, account);
    }

    /*//////////////////////////////////////////////////////////////
                           ERC165
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns whether this contract implements `interfaceId`.
     * @dev ERC-165 discovery: advertises ERC-1643 and its multi-subject extension, the token-binding
     * surface, the version module (ERC-8303) and `AccessControlEnumerable`.
     *
     * `type(IERC1643).interfaceId` is advertised because the engine does implement the base
     * single-argument functions, which is exactly what the draft conditions the id on. Its audience
     * is a **token wiring itself to this engine**: before calling `setDocumentEngine(engine)`, or
     * before forwarding `setDocument(name, uri, hash)` to it, a token can confirm through ERC-165
     * that the single-argument ERC-1643 endpoints exist here, rather than finding out from a failed
     * call. `type(ITokenBinding).interfaceId` answers the complementary question — whether this
     * engine has a binding surface at all — and `isTokenBound(address(this))` whether that
     * particular token may use it.
     *
     * It is **not** an invitation to read documents from this address. The base functions are
     * `_msgSender()`-scoped, so a consumer calling `getDocument(name)` here reads its own, empty
     * namespace, and this engine emits only the address-carrying `*ForSubject` events. Point
     * document consumers at the **subject**, or use the address-scoped `getDocument(subject, name)`.
     *
     * See {IERC165-supportsInterface}.
     * @param interfaceId The ERC-165 interface identifier to query.
     * @return True when `interfaceId` is one of the advertised interfaces or is supported by a base
     * contract.
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(VersionModule, AccessControlEnumerable)
        returns (bool)
    {
        return interfaceId == type(IERC1643).interfaceId || interfaceId == type(IERC1643MultiDocument).interfaceId
            || interfaceId == type(ITokenBinding).interfaceId || super.supportsInterface(interfaceId);
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

    /*//////////////////////////////////////////////////////////////
                           ERC2771
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev This surcharge is not necessary if you do not use ERC2771
     * @return sender The transaction sender, unwrapped from the ERC-2771 calldata suffix when the
     * call came through the trusted forwarder.
     */
    function _msgSender() internal view override(ERC2771Context, Context) returns (address sender) {
        return ERC2771Context._msgSender();
    }

    /**
     * @dev This surcharge is not necessary if you do not use ERC2771
     * @return The calldata, stripped of the ERC-2771 sender suffix when the call came through the
     * trusted forwarder.
     */
    function _msgData() internal view override(ERC2771Context, Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    /**
     * @dev This surcharge is not necessary if you do not use the MetaTxModule
     * @return The length of the ERC-2771 calldata suffix holding the sender address.
     */
    function _contextSuffixLength() internal view override(ERC2771Context, Context) returns (uint256) {
        return ERC2771Context._contextSuffixLength();
    }
}
