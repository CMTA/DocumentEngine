//SPDX-License-Identifier: MPL-2.0
pragma solidity ^0.8.20;

import {Ownable} from "OZ/access/Ownable.sol";
import {Ownable2Step} from "OZ/access/Ownable2Step.sol";
import {IERC1643} from "CMTAT/interfaces/tokenization/draft-IERC1643.sol";
import {IERC1643MultiDocument} from "./interfaces/IERC1643MultiDocument.sol";
import {ITokenBinding} from "./interfaces/ITokenBinding.sol";
import "OZ/metatx/ERC2771Context.sol";
import "./modules/TokenBindingModule.sol";
import "./modules/VersionModule.sol";

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
     * @param owner_ initial owner of the contract
     * @param forwarderIrrevocable address of the ERC-2771 forwarder (gasless support)
     */
    constructor(address owner_, address forwarderIrrevocable) Ownable(owner_) ERC2771Context(forwarderIrrevocable) {}

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

    /**
     * @dev ERC-165 discovery: advertises ERC-1643 and its multi-token extension,
     * plus the version module (ERC-8303). See {IERC165-supportsInterface}.
     */
    function supportsInterface(bytes4 interfaceId) public view virtual override(VersionModule) returns (bool) {
        return interfaceId == type(IERC1643).interfaceId || interfaceId == type(IERC1643MultiDocument).interfaceId
            || interfaceId == type(ITokenBinding).interfaceId || super.supportsInterface(interfaceId);
    }

    /*//////////////////////////////////////////////////////////////
                           ERC2771
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev This surcharge is not necessary if you do not use ERC2771
     */
    function _msgSender() internal view override(ERC2771Context, Context) returns (address sender) {
        return ERC2771Context._msgSender();
    }

    /**
     * @dev This surcharge is not necessary if you do not use ERC2771
     */
    function _msgData() internal view override(ERC2771Context, Context) returns (bytes calldata) {
        return ERC2771Context._msgData();
    }

    /**
     * @dev This surcharge is not necessary if you do not use the MetaTxModule
     */
    function _contextSuffixLength() internal view override(ERC2771Context, Context) returns (uint256) {
        return ERC2771Context._contextSuffixLength();
    }
}
