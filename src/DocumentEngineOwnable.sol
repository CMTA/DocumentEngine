//SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.24;

import {Ownable} from "OZ/access/Ownable.sol";
import {Ownable2Step} from "OZ/access/Ownable2Step.sol";
import {Context} from "OZ/utils/Context.sol";
import {ERC2771Context} from "OZ/metatx/ERC2771Context.sol";
import {IERC1643} from "CMTAT/interfaces/tokenization/draft-IERC1643.sol";
import {IERC1643MultiDocument} from "./interfaces/IERC1643MultiDocument.sol";
import {ITokenBinding} from "./interfaces/ITokenBinding.sol";
import {TokenBindingModule} from "./modules/TokenBindingModule.sol";
import {VersionModule} from "./modules/VersionModule.sol";

/**
 * @title DocumentEngineOwnable
 * @notice Alternative deployment of the DocumentEngine that uses a single owner
 * ({Ownable2Step}) instead of role-based access control.
 * @dev Reuses the same document-management logic ({DocumentEngineBase}) and token
 * binding ({TokenBindingModule}), swapping only the access-control implementation:
 * document management and token binding are both restricted to the `owner`, and a
 * bound token manages only its own documents. Ownership uses the two-step transfer
 * flow for safety, and the contract also exposes its version through ERC-8303
 * ({VersionModule}) and wires ERC-2771.
 */
contract DocumentEngineOwnable is TokenBindingModule, VersionModule, Ownable2Step, ERC2771Context {
    /**
     * @notice Deploys the engine with `owner_` as its single privileged account.
     * @param owner_ initial owner of the contract
     * @param forwarderIrrevocable address of the ERC-2771 forwarder (gasless support)
     */
    constructor(address owner_, address forwarderIrrevocable) Ownable(owner_) ERC2771Context(forwarderIrrevocable) {}

    /*//////////////////////////////////////////////////////////////
                           ERC165
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns whether this contract implements `interfaceId`.
     * @dev ERC-165 discovery: advertises ERC-1643 and its multi-subject extension, the token-binding
     * surface and the version module (ERC-8303). See the rationale on
     * {DocumentEngine-supportsInterface} for what `type(IERC1643).interfaceId` does and does not
     * tell a caller here. See {IERC165-supportsInterface}.
     * @param interfaceId The ERC-165 interface identifier to query.
     * @return True when `interfaceId` is one of the advertised interfaces or is supported by a base
     * contract.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(VersionModule) returns (bool) {
        return interfaceId == type(IERC1643).interfaceId || interfaceId == type(IERC1643MultiDocument).interfaceId
            || interfaceId == type(ITokenBinding).interfaceId || super.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                        ACCESS CONTROL (implementation)
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Authorization for the admin document-management path (and, via
     * {TokenBindingModule}, for token binding): only the owner.
     */
    function _authorizeDocumentManagement() internal view virtual override {
        _checkOwner();
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
